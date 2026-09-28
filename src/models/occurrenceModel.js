const { FIELD_NAMES, ENVELOPE_FIELDS, DERIVED_FIELDS } = require('../utils/dwcTerms');
const { parseEventDate, deriveYearMonthDay, parseDMS, collectWarnings } = require('../utils/validation');
const { findDuplicates } = require('../utils/duplicates');

const EDITABLE_FIELDS = FIELD_NAMES.filter((f) => f !== 'occurrenceID' && !DERIVED_FIELDS.has(f));

// Aplica las reglas de la seccion 4: valida bloqueantes, calcula derivados y advertencias.
// Lanza un Error con .fieldErrors = [{field, message}] si hay algo bloqueante.
function processRecordInput(input) {
  const record = {};
  // No se recorta el valor: la seccion 4 exige poder advertir sobre espacios
  // sobrantes, y la seccion 6 exige guardar los valores tal como se escribieron.
  for (const f of FIELD_NAMES) {
    const v = input[f];
    record[f] = v != null && String(v).trim() !== '' ? String(v) : null;
  }

  const blocking = [];

  const { iso, error: dateError } = parseEventDate(record.eventDate);
  if (dateError) blocking.push({ field: 'eventDate', message: dateError });
  record.eventDate = iso;

  const derived = deriveYearMonthDay(iso);
  // Seccion 4: year/month/day se calculan desde eventDate; si el archivo importado
  // trae valores propios que no coinciden, se bloquea para que el usuario corrija.
  for (const [field, computed] of [['year', derived.year], ['month', derived.month], ['day', derived.day]]) {
    if (record[field] != null && Number(record[field]) !== computed) {
      blocking.push({ field, message: `${field} ("${record[field]}") no coincide con el valor calculado desde eventDate (${computed}).` });
    }
  }
  record.year = derived.year;
  record.month = derived.month;
  record.day = derived.day;

  const lat = parseDMS(record.verbatimLatitude, 'lat');
  if (lat.error) blocking.push({ field: 'verbatimLatitude', message: lat.error });
  record.decimalLatitude = lat.decimal;

  const lon = parseDMS(record.verbatimLongitude, 'lon');
  if (lon.error) blocking.push({ field: 'verbatimLongitude', message: lon.error });
  record.decimalLongitude = lon.decimal;

  if (blocking.length) {
    const err = new Error('Errores de validación bloqueantes.');
    err.fieldErrors = blocking;
    throw err;
  }

  record.modified = new Date().toISOString().slice(0, 19).replace('T', ' ');

  const warnings = collectWarnings(record);
  return { record, warnings };
}

function computeStatus(record, warnings) {
  const missing = ENVELOPE_FIELDS.filter((f) => !record[f] || String(record[f]).trim() === '');
  if (missing.length > 0) return 'incompleto';
  if (warnings.length > 0) return 'con_advertencias';
  return 'completo_para_sobre';
}

// Asigna el siguiente numero libre del rango de la clase (seccion 7), de forma atomica.
async function assignOccurrenceId(conn, classCodeId) {
  const [rows] = await conn.query('SELECT * FROM class_codes WHERE id = ? FOR UPDATE', [classCodeId]);
  const clase = rows[0];
  if (!clase) throw new Error('Código de clase no encontrado.');
  if (clase.estado !== 'activo') throw new Error('El código de clase no está activo.');
  if (clase.siguiente_numero > clase.rango_final) {
    throw new Error('El rango de números de catálogo de esta clase se ha agotado.');
  }
  const numero = clase.siguiente_numero;
  await conn.query('UPDATE class_codes SET siguiente_numero = siguiente_numero + 1 WHERE id = ?', [classCodeId]);
  return `${clase.prefijo_occurrence_id}${numero}`;
}

async function createOccurrence(pool, input, { usuarioCreadorId, classCodeId, profesorId, isAdmin }) {
  const { record, warnings } = processRecordInput(input);
  const status = computeStatus(record, warnings);

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // El estudiante no puede editar occurrenceID (seccion 7): si no es admin, el valor
    // que traiga el formulario o el archivo importado se ignora y se asigna uno nuevo.
    let occurrenceId = isAdmin ? record.occurrenceID : null;
    if (!occurrenceId) {
      if (!classCodeId) throw new Error('Debe estar vinculado a un código de clase para crear registros.');
      occurrenceId = await assignOccurrenceId(conn, classCodeId);
    }

    const columns = ['usuario_creador_id', 'class_code_id', 'profesor_id', 'estado_validacion', 'occurrenceID', ...EDITABLE_FIELDS, 'year', 'month', 'day', 'decimalLatitude', 'decimalLongitude', 'modified'];
    const values = [usuarioCreadorId, classCodeId, profesorId, status, occurrenceId, ...EDITABLE_FIELDS.map((f) => record[f]), record.year, record.month, record.day, record.decimalLatitude, record.decimalLongitude, record.modified];

    const placeholders = columns.map(() => '?').join(', ');
    const backtickCols = columns.map((c) => (['usuario_creador_id', 'class_code_id', 'profesor_id', 'estado_validacion'].includes(c) ? c : `\`${c}\``));
    const [result] = await conn.query(
      `INSERT INTO occurrences (${backtickCols.join(', ')}) VALUES (${placeholders})`,
      values
    );

    await conn.commit();

    const duplicates = await findDuplicates(pool, { ...record, occurrenceID: occurrenceId }, { excludeId: result.insertId });
    return { id: result.insertId, occurrenceID: occurrenceId, warnings, status, duplicates };
  } catch (e) {
    await conn.rollback();
    throw e;
  } finally {
    conn.release();
  }
}

async function updateOccurrence(pool, id, input, usuarioId) {
  const [existingRows] = await pool.query('SELECT * FROM occurrences WHERE id = ? AND eliminado = FALSE', [id]);
  const existing = existingRows[0];
  if (!existing) throw new Error('Registro no encontrado.');

  const merged = { ...existing };
  for (const f of EDITABLE_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(input, f)) merged[f] = input[f];
  }
  merged.occurrenceID = existing.occurrenceID;

  const { record, warnings } = processRecordInput(merged);
  const status = computeStatus(record, warnings);

  const changedFields = [];
  for (const f of [...EDITABLE_FIELDS, 'year', 'month', 'day', 'decimalLatitude', 'decimalLongitude']) {
    const before = existing[f] == null ? null : String(existing[f]);
    const after = record[f] == null ? null : String(record[f]);
    if (before !== after) changedFields.push({ field: f, before, after });
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    if (changedFields.length > 0) {
      const setCols = [...EDITABLE_FIELDS, 'year', 'month', 'day', 'decimalLatitude', 'decimalLongitude', 'modified', 'estado_validacion', 'version'];
      const setSql = setCols
        .map((c) => (c === 'estado_validacion' || c === 'version' ? `${c} = ?` : `\`${c}\` = ?`))
        .join(', ');
      const setValues = [
        ...EDITABLE_FIELDS.map((f) => record[f]),
        record.year,
        record.month,
        record.day,
        record.decimalLatitude,
        record.decimalLongitude,
        record.modified,
        status,
        existing.version + 1,
      ];
      await conn.query(`UPDATE occurrences SET ${setSql} WHERE id = ?`, [...setValues, id]);

      for (const change of changedFields) {
        await conn.query(
          `INSERT INTO occurrence_history (occurrence_id, usuario_id, campo, valor_anterior, valor_nuevo, version_resultante) VALUES (?, ?, ?, ?, ?, ?)`,
          [id, usuarioId, change.field, change.before, change.after, existing.version + 1]
        );
      }
    }

    await conn.commit();

    const duplicates = await findDuplicates(pool, record, { excludeId: id });
    return { warnings, status, changed: changedFields.length, duplicates };
  } catch (e) {
    await conn.rollback();
    throw e;
  } finally {
    conn.release();
  }
}

async function softDeleteOccurrence(pool, id) {
  await pool.query('UPDATE occurrences SET eliminado = TRUE, eliminado_en = NOW() WHERE id = ?', [id]);
}

module.exports = {
  EDITABLE_FIELDS,
  processRecordInput,
  computeStatus,
  createOccurrence,
  updateOccurrence,
  softDeleteOccurrence,
};

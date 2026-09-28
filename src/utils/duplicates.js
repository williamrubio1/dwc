const { normalizeForDuplicate } = require('./validation');

// Seccion 6 dice literalmente "occurrenceID, license, recordNumber y fieldNotes",
// pero occurrenceID lo asigna el sistema y es UNIQUE (seccion 7): dos registros
// activos nunca pueden compartirlo, asi que incluirlo en la comparacion volveria
// la regla inalcanzable (se verifico en pruebas: nunca coincide entre registros
// distintos). Se compara por los tres campos que si pueden coincidir legitimamente;
// occurrenceID ya queda cubierto por su propia restriccion UNIQUE en la base.
const DUP_FIELDS = ['license', 'recordNumber', 'fieldNotes'];

// Seccion 6: posible duplicado si license, recordNumber y fieldNotes
// coinciden a la vez (normalizados), y al menos uno de los tres tiene valor.
async function findDuplicates(pool, record, { excludeId = null } = {}) {
  const hasAnyValue = DUP_FIELDS.some((f) => String(record[f] ?? '').trim() !== '');
  if (!hasAnyValue) return [];

  const normalized = {};
  for (const f of DUP_FIELDS) normalized[f] = normalizeForDuplicate(record[f]);

  let sql = `SELECT id, occurrenceID, license, recordNumber, fieldNotes FROM occurrences WHERE eliminado = FALSE`;
  const params = [];
  if (excludeId) {
    sql += ' AND id <> ?';
    params.push(excludeId);
  }
  const [rows] = await pool.query(sql, params);

  const matches = rows.filter((row) =>
    DUP_FIELDS.every((f) => normalizeForDuplicate(row[f]) === normalized[f])
  );

  return matches.map((row) => ({
    id: row.id,
    occurrenceID: row.occurrenceID,
    matchedFields: DUP_FIELDS,
  }));
}

// Para importacion masiva: revisa tambien las filas ya procesadas del mismo archivo.
function findDuplicateWithinBatch(record, previousRecords) {
  const hasAnyValue = DUP_FIELDS.some((f) => String(record[f] ?? '').trim() !== '');
  if (!hasAnyValue) return null;
  const normalized = {};
  for (const f of DUP_FIELDS) normalized[f] = normalizeForDuplicate(record[f]);

  for (let i = 0; i < previousRecords.length; i++) {
    const other = previousRecords[i];
    const otherHasValue = DUP_FIELDS.some((f) => String(other[f] ?? '').trim() !== '');
    if (!otherHasValue) continue;
    const isMatch = DUP_FIELDS.every((f) => normalizeForDuplicate(other[f]) === normalized[f]);
    if (isMatch) return { rowIndex: i };
  }
  return null;
}

module.exports = { DUP_FIELDS, findDuplicates, findDuplicateWithinBatch };

const { randomBytes } = require('crypto');

function generateCode() {
  return randomBytes(4).toString('hex').toUpperCase();
}

// Seccion 7: el sistema impide que dos rangos con el mismo prefijo se superpongan en toda la base.
async function rangeOverlaps(pool, prefijo, inicio, fin, excludeId = null) {
  let sql = 'SELECT id FROM class_codes WHERE prefijo_occurrence_id = ? AND rango_inicial <= ? AND rango_final >= ?';
  const params = [prefijo, fin, inicio];
  if (excludeId) {
    sql += ' AND id <> ?';
    params.push(excludeId);
  }
  const [rows] = await pool.query(sql, params);
  return rows.length > 0;
}

async function createClassCode(pool, { profesorId, nombreClase, periodoAcademico, prefijo, rangoInicial, rangoFinal }) {
  if (rangoFinal < rangoInicial) throw new Error('El número final debe ser mayor o igual al inicial.');
  const overlap = await rangeOverlaps(pool, prefijo, rangoInicial, rangoFinal);
  if (overlap) throw new Error('El rango se superpone con otro código existente que usa el mismo prefijo.');

  let codigo;
  for (let i = 0; i < 5; i++) {
    codigo = generateCode();
    const [existing] = await pool.query('SELECT id FROM class_codes WHERE codigo_unico = ?', [codigo]);
    if (existing.length === 0) break;
  }

  const [result] = await pool.query(
    `INSERT INTO class_codes (codigo_unico, profesor_id, nombre_clase, periodo_academico, prefijo_occurrence_id, rango_inicial, rango_final, siguiente_numero)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [codigo, profesorId, nombreClase, periodoAcademico, prefijo, rangoInicial, rangoFinal, rangoInicial]
  );
  return { id: result.insertId, codigo };
}

async function findByCodigo(pool, codigo) {
  const [rows] = await pool.query('SELECT * FROM class_codes WHERE codigo_unico = ?', [codigo]);
  return rows[0] || null;
}

async function findById(pool, id) {
  const [rows] = await pool.query('SELECT * FROM class_codes WHERE id = ?', [id]);
  return rows[0] || null;
}

async function listByProfessor(pool, profesorId) {
  const [rows] = await pool.query('SELECT * FROM class_codes WHERE profesor_id = ? ORDER BY created_at DESC', [profesorId]);
  return rows;
}

async function listAll(pool) {
  const [rows] = await pool.query(
    `SELECT cc.*, u.nombre AS profesor_nombre FROM class_codes cc JOIN users u ON u.id = cc.profesor_id ORDER BY cc.created_at DESC`
  );
  return rows;
}

async function setEstado(pool, id, estado) {
  await pool.query('UPDATE class_codes SET estado = ? WHERE id = ?', [estado, id]);
}

async function expandRange(pool, id, nuevoRangoFinal) {
  const clase = await findById(pool, id);
  if (!clase) throw new Error('Código de clase no encontrado.');
  if (nuevoRangoFinal < clase.rango_final) throw new Error('El nuevo rango final debe ser mayor al actual.');
  const overlap = await rangeOverlaps(pool, clase.prefijo_occurrence_id, clase.rango_inicial, nuevoRangoFinal, id);
  if (overlap) throw new Error('El nuevo rango se superpone con otro código existente.');
  await pool.query('UPDATE class_codes SET rango_final = ? WHERE id = ?', [nuevoRangoFinal, id]);
}

module.exports = { createClassCode, findByCodigo, findById, listByProfessor, listAll, setEstado, expandRange };

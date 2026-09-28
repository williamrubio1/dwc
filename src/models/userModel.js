const bcrypt = require('bcryptjs');

async function findByUsername(pool, username) {
  const [rows] = await pool.query('SELECT * FROM users WHERE username = ?', [username]);
  return rows[0] || null;
}

async function findByEmail(pool, email) {
  const [rows] = await pool.query('SELECT * FROM users WHERE email = ?', [email]);
  return rows[0] || null;
}

async function findById(pool, id) {
  const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [id]);
  return rows[0] || null;
}

async function ensureAdmin(pool) {
  const existing = await findByUsername(pool, 'admin');
  if (existing) return;
  const initialPassword = process.env.ADMIN_INITIAL_PASSWORD;
  if (!initialPassword) {
    console.warn(
      '[darwin-core] ADMIN_INITIAL_PASSWORD no está definida: no se creó la cuenta admin. Defínala en .env y reinicie.'
    );
    return;
  }
  const hash = await bcrypt.hash(initialPassword, 12);
  await pool.query(
    `INSERT INTO users (role, username, email, password_hash, nombre, activo) VALUES ('administrador', 'admin', 'admin@darwincore.local', ?, 'Administrador', TRUE)`,
    [hash]
  );
  console.log('[darwin-core] Cuenta admin creada. Cambie la contraseña inicial cuanto antes.');
}

// Autorregistro de estudiante (seccion 2): solo correos @unillanos.edu.co
async function registerStudent(pool, { email, password, nombre, documento, programa, semestre, codigoEstudiantil, telefono }) {
  if (!/@unillanos\.edu\.co$/i.test(email)) {
    throw new Error('Solo se admiten cuentas con correo institucional @unillanos.edu.co.');
  }
  const existing = await findByEmail(pool, email);
  if (existing) throw new Error('Ya existe una cuenta con ese correo.');
  const hash = await bcrypt.hash(password, 12);
  const username = email.split('@')[0];
  const [result] = await pool.query(
    `INSERT INTO users (role, username, email, password_hash, nombre, documento, programa, semestre, codigo_estudiantil, telefono, activo)
     VALUES ('estudiante', ?, ?, ?, ?, ?, ?, ?, ?, ?, TRUE)`,
    [username, email, hash, nombre, documento, programa, semestre, codigoEstudiantil, telefono]
  );
  return result.insertId;
}

// El administrador crea o habilita profesores (seccion 2)
async function createProfessor(pool, { email, password, nombre, documento, dependenciaPrograma, telefono }) {
  if (!/@unillanos\.edu\.co$/i.test(email)) {
    throw new Error('Solo se admiten cuentas con correo institucional @unillanos.edu.co.');
  }
  const existing = await findByEmail(pool, email);
  if (existing) throw new Error('Ya existe una cuenta con ese correo.');
  const hash = await bcrypt.hash(password, 12);
  const username = email.split('@')[0];
  const [result] = await pool.query(
    `INSERT INTO users (role, username, email, password_hash, nombre, documento, dependencia_programa, telefono, activo)
     VALUES ('profesor', ?, ?, ?, ?, ?, ?, ?, TRUE)`,
    [username, email, hash, nombre, documento, dependenciaPrograma, telefono]
  );
  return result.insertId;
}

async function verifyPassword(user, password) {
  return bcrypt.compare(password, user.password_hash);
}

async function setActive(pool, id, activo) {
  await pool.query('UPDATE users SET activo = ? WHERE id = ?', [activo, id]);
}

async function linkClassCode(pool, userId, classCodeId) {
  await pool.query('UPDATE users SET current_class_code_id = ? WHERE id = ?', [classCodeId, userId]);
}

module.exports = {
  findByUsername,
  findByEmail,
  findById,
  ensureAdmin,
  registerStudent,
  createProfessor,
  verifyPassword,
  setActive,
  linkClassCode,
};

const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { requireRole } = require('../middleware/auth');
const userModel = require('../models/userModel');
const classCodeModel = require('../models/classCodeModel');

router.use(requireRole('administrador'));

// ---- Usuarios ----
router.get('/users', async (req, res) => {
  const [users] = await pool.query('SELECT * FROM users ORDER BY role, nombre');
  res.render('admin/users', { users });
});

router.get('/users/new-professor', (req, res) => {
  res.render('admin/new-professor');
});

router.post('/users/new-professor', async (req, res) => {
  const { email, password, nombre, documento, dependenciaPrograma, telefono } = req.body;
  try {
    await userModel.createProfessor(pool, { email, password, nombre, documento, dependenciaPrograma, telefono });
    req.flash('success', 'Profesor creado.');
    res.redirect('/admin/users');
  } catch (e) {
    req.flash('error', e.message);
    res.redirect('/admin/users/new-professor');
  }
});

router.post('/users/:id/toggle', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [req.params.id]);
  if (rows[0]) await userModel.setActive(pool, rows[0].id, !rows[0].activo);
  res.redirect('/admin/users');
});

// ---- Codigos de clase ----
router.get('/classes', async (req, res) => {
  const clases = await classCodeModel.listAll(pool);
  res.render('admin/classes', { clases });
});

router.post('/classes/:id/toggle', async (req, res) => {
  const clase = await classCodeModel.findById(pool, req.params.id);
  if (clase) await classCodeModel.setEstado(pool, clase.id, clase.estado === 'activo' ? 'inactivo' : 'activo');
  res.redirect('/admin/classes');
});

// ---- Tipos de organismo (seccion 9) ----
router.get('/organism-types', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM organism_types ORDER BY phylum');
  res.render('admin/organism-types', { rows });
});

router.post('/organism-types', async (req, res) => {
  const { phylum, tipoImpreso } = req.body;
  await pool.query(
    'INSERT INTO organism_types (phylum, tipo_impreso) VALUES (?, ?) ON DUPLICATE KEY UPDATE tipo_impreso = VALUES(tipo_impreso)',
    [phylum, tipoImpreso]
  );
  req.flash('success', 'Tipo de organismo guardado.');
  res.redirect('/admin/organism-types');
});

router.post('/organism-types/:id/delete', async (req, res) => {
  await pool.query('DELETE FROM organism_types WHERE id = ?', [req.params.id]);
  res.redirect('/admin/organism-types');
});

// ---- Textos de ayuda por termino Darwin Core (seccion 3) ----
router.get('/help-texts', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM dwc_term_help ORDER BY seccion, etiqueta');
  res.render('admin/help-texts', { rows });
});

router.get('/help-texts/:term/edit', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM dwc_term_help WHERE term = ?', [req.params.term]);
  if (!rows[0]) return res.status(404).render('error', { message: 'Término no encontrado.' });
  res.render('admin/help-text-edit', { term: rows[0] });
});

router.post('/help-texts/:term/edit', async (req, res) => {
  const { definicion, ejemplo } = req.body;
  await pool.query('UPDATE dwc_term_help SET definicion = ?, ejemplo = ? WHERE term = ?', [definicion, ejemplo, req.params.term]);
  req.flash('success', 'Texto de ayuda actualizado.');
  res.redirect('/admin/help-texts');
});

// ---- Plantilla documental del sobre (encabezado configurable, seccion 9) ----
router.get('/settings', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM app_settings');
  const settings = Object.fromEntries(rows.map((r) => [r.clave, r.valor]));
  res.render('admin/settings', { settings });
});

router.post('/settings', async (req, res) => {
  const { sobre_encabezado } = req.body;
  await pool.query('INSERT INTO app_settings (clave, valor) VALUES (?, ?) ON DUPLICATE KEY UPDATE valor = VALUES(valor)', [
    'sobre_encabezado', sobre_encabezado,
  ]);
  req.flash('success', 'Configuración guardada.');
  res.redirect('/admin/settings');
});

// ---- Consulta de toda la base (seccion 2, 8) ----
router.get('/records', async (req, res) => {
  const [rows] = await pool.query(
    `SELECT o.id, o.occurrenceID, o.scientificName, o.family, o.eventDate, o.estado_validacion, o.updated_at,
            u.nombre AS estudiante, cc.nombre_clase
     FROM occurrences o
     JOIN users u ON u.id = o.usuario_creador_id
     LEFT JOIN class_codes cc ON cc.id = o.class_code_id
     WHERE o.eliminado = FALSE ORDER BY o.updated_at DESC LIMIT 500`
  );
  res.render('admin/records', { records: rows });
});

router.get('/records/:id', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM occurrences WHERE id = ?', [req.params.id]);
  if (!rows[0]) return res.status(404).render('error', { message: 'Registro no encontrado.' });
  const [history] = await pool.query(
    `SELECT h.*, u.nombre AS usuario_nombre FROM occurrence_history h JOIN users u ON u.id = h.usuario_id WHERE occurrence_id = ? ORDER BY fecha DESC`,
    [rows[0].id]
  );
  res.render('classes/record-detail', { record: rows[0], history, clase: null });
});

module.exports = router;

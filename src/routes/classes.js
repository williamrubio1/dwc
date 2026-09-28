const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { requireRole } = require('../middleware/auth');
const classCodeModel = require('../models/classCodeModel');

router.use(requireRole('profesor'));

router.get('/', async (req, res) => {
  const clases = await classCodeModel.listByProfessor(pool, req.session.user.id);
  res.render('classes/list', { clases });
});

router.get('/new', (req, res) => {
  res.render('classes/form');
});

router.post('/', async (req, res) => {
  const { nombreClase, periodoAcademico, prefijo, rangoInicial, rangoFinal } = req.body;
  try {
    const { codigo } = await classCodeModel.createClassCode(pool, {
      profesorId: req.session.user.id,
      nombreClase,
      periodoAcademico,
      prefijo,
      rangoInicial: Number(rangoInicial),
      rangoFinal: Number(rangoFinal),
    });
    req.flash('success', `Código de clase creado: ${codigo}`);
    res.redirect('/classes');
  } catch (e) {
    req.flash('error', e.message);
    res.redirect('/classes/new');
  }
});

router.get('/:id/expand', async (req, res) => {
  const clase = await classCodeModel.findById(pool, req.params.id);
  if (!clase || clase.profesor_id !== req.session.user.id) return res.status(404).render('error', { message: 'No encontrado.' });
  res.render('classes/expand', { clase });
});

router.post('/:id/expand', async (req, res) => {
  const clase = await classCodeModel.findById(pool, req.params.id);
  if (!clase || clase.profesor_id !== req.session.user.id) return res.status(404).render('error', { message: 'No encontrado.' });
  try {
    await classCodeModel.expandRange(pool, clase.id, Number(req.body.nuevoRangoFinal));
    req.flash('success', 'Rango ampliado correctamente.');
  } catch (e) {
    req.flash('error', e.message);
  }
  res.redirect('/classes');
});

router.get('/:id/records', async (req, res) => {
  const clase = await classCodeModel.findById(pool, req.params.id);
  if (!clase || clase.profesor_id !== req.session.user.id) return res.status(404).render('error', { message: 'No encontrado.' });

  const { fechaCreacionDesde, fechaCreacionHasta, fechaModDesde, fechaModHasta, recordNumber } = req.query;
  let sql = `SELECT o.id, o.occurrenceID, o.scientificName, o.family, o.recordNumber, o.eventDate, o.estado_validacion, o.created_at, o.updated_at, u.nombre AS estudiante
             FROM occurrences o JOIN users u ON u.id = o.usuario_creador_id
             WHERE o.class_code_id = ? AND o.eliminado = FALSE`;
  const params = [clase.id];
  if (fechaCreacionDesde) { sql += ' AND o.created_at >= ?'; params.push(fechaCreacionDesde); }
  if (fechaCreacionHasta) { sql += ' AND o.created_at <= ?'; params.push(fechaCreacionHasta + ' 23:59:59'); }
  if (fechaModDesde) { sql += ' AND o.updated_at >= ?'; params.push(fechaModDesde); }
  if (fechaModHasta) { sql += ' AND o.updated_at <= ?'; params.push(fechaModHasta + ' 23:59:59'); }
  if (recordNumber) { sql += ' AND o.recordNumber LIKE ?'; params.push(`%${recordNumber}%`); }
  sql += ' ORDER BY o.updated_at DESC';

  const [rows] = await pool.query(sql, params);
  res.render('classes/records', { clase, records: rows, query: req.query });
});

router.get('/:id/records/:recordId', async (req, res) => {
  const clase = await classCodeModel.findById(pool, req.params.id);
  if (!clase || clase.profesor_id !== req.session.user.id) return res.status(404).render('error', { message: 'No encontrado.' });
  const [rows] = await pool.query('SELECT * FROM occurrences WHERE id = ? AND class_code_id = ?', [req.params.recordId, clase.id]);
  if (!rows[0]) return res.status(404).render('error', { message: 'Registro no encontrado.' });
  const [history] = await pool.query(
    `SELECT h.*, u.nombre AS usuario_nombre FROM occurrence_history h JOIN users u ON u.id = h.usuario_id WHERE occurrence_id = ? ORDER BY fecha DESC`,
    [rows[0].id]
  );
  res.render('classes/record-detail', { record: rows[0], history, clase });
});

router.get('/:id/students', async (req, res) => {
  const clase = await classCodeModel.findById(pool, req.params.id);
  if (!clase || clase.profesor_id !== req.session.user.id) return res.status(404).render('error', { message: 'No encontrado.' });
  const { email } = req.query;
  let sql = 'SELECT id, nombre, email, programa, semestre, codigo_estudiantil FROM users WHERE current_class_code_id = ?';
  const params = [clase.id];
  if (email) { sql += ' AND email LIKE ?'; params.push(`%${email}%`); }
  const [students] = await pool.query(sql, params);
  res.render('classes/students', { clase, students, email: email || '' });
});

module.exports = router;

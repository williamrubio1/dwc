const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { requireRole } = require('../middleware/auth');
const { generateEnvelopeDocx, generateEnvelopePdf } = require('../utils/envelope');

router.use(requireRole('estudiante', 'administrador'));

async function loadEnvelopeOptions(pool) {
  const [types] = await pool.query('SELECT phylum, tipo_impreso FROM organism_types');
  const organismTypeByPhylum = Object.fromEntries(types.map((t) => [t.phylum, t.tipo_impreso]));
  const [[settingRow]] = await pool.query("SELECT valor FROM app_settings WHERE clave = 'sobre_encabezado'");
  const encabezado = settingRow ? settingRow.valor : 'HERBARIO UNIVERSIDAD DE LOS LLANOS (LLANOS)';
  return { organismTypeByPhylum, encabezado };
}

async function loadAccessibleRecord(req) {
  const user = req.session.user;
  let sql = 'SELECT * FROM occurrences WHERE id = ? AND eliminado = FALSE';
  const params = [req.params.id];
  if (user.role === 'estudiante') {
    sql += ' AND usuario_creador_id = ?';
    params.push(user.id);
  }
  const [rows] = await pool.query(sql, params);
  return rows[0] || null;
}

async function logGeneration(pool, userId, modalidad, formato, records) {
  await pool.query(
    `INSERT INTO envelope_generations (usuario_id, modalidad, formato, tamano_hoja, registros_incluidos) VALUES (?, ?, ?, 'Carta', ?)`,
    [userId, modalidad, formato, JSON.stringify(records.map((r) => ({ id: r.id, occurrenceID: r.occurrenceID, version: r.version })))]
  );
}

router.get('/records/:id/envelope/preview', async (req, res) => {
  const record = await loadAccessibleRecord(req);
  if (!record) return res.status(404).render('error', { message: 'Registro no encontrado.' });
  const options = await loadEnvelopeOptions(pool);
  const buffer = await generateEnvelopePdf([record], options);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', 'inline; filename="vista-previa-sobre.pdf"');
  res.send(buffer);
});

router.get('/records/:id/envelope.docx', async (req, res) => {
  const record = await loadAccessibleRecord(req);
  if (!record) return res.status(404).render('error', { message: 'Registro no encontrado.' });
  const options = await loadEnvelopeOptions(pool);
  const buffer = await generateEnvelopeDocx([record], options);
  await logGeneration(pool, req.session.user.id, 'individual', 'docx', [record]);
  res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
  res.setHeader('Content-Disposition', `attachment; filename="sobre-${record.occurrenceID}.docx"`);
  res.send(buffer);
});

router.get('/records/:id/envelope.pdf', async (req, res) => {
  const record = await loadAccessibleRecord(req);
  if (!record) return res.status(404).render('error', { message: 'Registro no encontrado.' });
  const options = await loadEnvelopeOptions(pool);
  const buffer = await generateEnvelopePdf([record], options);
  await logGeneration(pool, req.session.user.id, 'individual', 'pdf', [record]);
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename="sobre-${record.occurrenceID}.pdf"`);
  res.send(buffer);
});

router.get('/envelopes/consolidated', async (req, res) => {
  const user = req.session.user;
  let sql = 'SELECT id, occurrenceID, scientificName, family FROM occurrences WHERE eliminado = FALSE';
  const params = [];
  if (user.role === 'estudiante') { sql += ' AND usuario_creador_id = ?'; params.push(user.id); }
  const [rows] = await pool.query(sql, params);
  res.render('envelopes/consolidated', { records: rows });
});

router.post('/envelopes/consolidated', async (req, res) => {
  const user = req.session.user;
  let ids = req.body.ids;
  if (!ids) ids = [];
  if (!Array.isArray(ids)) ids = [ids];
  if (ids.length === 0) {
    req.flash('error', 'Seleccione al menos un registro.');
    return res.redirect('/envelopes/consolidated');
  }

  let sql = `SELECT * FROM occurrences WHERE eliminado = FALSE AND id IN (${ids.map(() => '?').join(',')})`;
  const params = [...ids];
  if (user.role === 'estudiante') { sql += ' AND usuario_creador_id = ?'; params.push(user.id); }

  const [records] = await pool.query(sql, params);
  const options = await loadEnvelopeOptions(pool);
  const formato = req.body.formato === 'pdf' ? 'pdf' : 'docx';

  await logGeneration(pool, user.id, 'consolidado', formato, records);

  if (formato === 'pdf') {
    const buffer = await generateEnvelopePdf(records, options);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename="sobres-consolidado.pdf"');
    return res.send(buffer);
  }
  const buffer = await generateEnvelopeDocx(records, options);
  res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
  res.setHeader('Content-Disposition', 'attachment; filename="sobres-consolidado.docx"');
  res.send(buffer);
});

module.exports = router;

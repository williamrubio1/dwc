const express = require('express');
const router = express.Router();
const multer = require('multer');
const pool = require('../config/db');
const { requireAuth, requireRole } = require('../middleware/auth');
const { toCsv, toXlsx, parseImportBuffer } = require('../utils/importExport');
const { FIELD_NAMES } = require('../utils/dwcTerms');
const { processRecordInput, computeStatus, createOccurrence } = require('../models/occurrenceModel');
const { findDuplicateWithinBatch, findDuplicates } = require('../utils/duplicates');
const classCodeModel = require('../models/classCodeModel');
const userModel = require('../models/userModel');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 20 * 1024 * 1024 } });

function onlyDwcFields(row) {
  const clean = {};
  for (const f of FIELD_NAMES) clean[f] = row[f] ?? null;
  return clean;
}

// ---- Exportacion (seccion 8) ----
router.get('/export', requireAuth, async (req, res) => {
  const clasesDisponibles = [];
  if (req.session.user.role === 'profesor') {
    clasesDisponibles.push(...(await classCodeModel.listByProfessor(pool, req.session.user.id)));
  } else if (req.session.user.role === 'administrador') {
    clasesDisponibles.push(...(await classCodeModel.listAll(pool)));
  }
  res.render('export', { clasesDisponibles, role: req.session.user.role });
});

router.get('/export/download', requireAuth, async (req, res) => {
  const user = req.session.user;
  const { formato = 'csv', fechaDesde, fechaHasta, recordNumber, claseId, estudianteEmail } = req.query;

  let sql = 'SELECT * FROM occurrences WHERE eliminado = FALSE';
  const params = [];

  if (user.role === 'estudiante') {
    sql += ' AND usuario_creador_id = ?';
    params.push(user.id);
  } else if (user.role === 'profesor') {
    sql += ' AND profesor_id = ?';
    params.push(user.id);
  }

  if (fechaDesde) { sql += ' AND created_at >= ?'; params.push(fechaDesde); }
  if (fechaHasta) { sql += ' AND created_at <= ?'; params.push(fechaHasta + ' 23:59:59'); }
  if (recordNumber) { sql += ' AND recordNumber LIKE ?'; params.push(`%${recordNumber}%`); }
  if (claseId) { sql += ' AND class_code_id = ?'; params.push(claseId); }
  if (estudianteEmail && user.role !== 'estudiante') {
    sql += ' AND usuario_creador_id IN (SELECT id FROM users WHERE email LIKE ?)';
    params.push(`%${estudianteEmail}%`);
  }

  const [rows] = await pool.query(sql, params);
  const clean = rows.map(onlyDwcFields);

  if (formato === 'xlsx') {
    res.setHeader('Content-Disposition', 'attachment; filename="darwin-core-export.xlsx"');
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    return res.send(await toXlsx(clean));
  }
  res.setHeader('Content-Disposition', 'attachment; filename="darwin-core-export.csv"');
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.send(toCsv(clean));
});

// ---- Plantilla descargable (seccion 3) ----
router.get('/plantilla-descargable', requireAuth, (req, res) => {
  const ejemplo = FIELD_NAMES.reduce((acc, f) => ({ ...acc, [f]: '' }), {});
  res.setHeader('Content-Disposition', 'attachment; filename="plantilla-darwin-core.csv"');
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.send(toCsv([ejemplo]));
});

// ---- Importacion (seccion 3, 4, 6): solo estudiante, hacia su clase vigente ----
router.get('/import', requireRole('estudiante'), (req, res) => {
  res.render('import', { preview: null });
});

router.post('/import/preview', requireRole('estudiante'), upload.single('archivo'), async (req, res) => {
  if (!req.file) {
    req.flash('error', 'Debe seleccionar un archivo CSV o XLSX.');
    return res.redirect('/import');
  }
  const rawRows = await parseImportBuffer(req.file.buffer, req.file.originalname);
  const results = [];
  const acceptedRows = [];
  const previousAccepted = [];

  for (let i = 0; i < rawRows.length; i++) {
    const rowNumber = i + 2; // fila 1 = encabezado
    const raw = rawRows[i];
    const rowResult = { rowNumber, blocking: [], warnings: [], duplicateInFile: null, duplicateInDb: null };

    try {
      const { record, warnings } = processRecordInput(raw);
      rowResult.warnings = warnings;

      const dupBatch = findDuplicateWithinBatch(record, previousAccepted);
      if (dupBatch) {
        rowResult.blocking.push({ field: '(varios)', message: `Duplicado exacto de la fila ${dupBatch.rowIndex + 2} dentro del mismo archivo.` });
      } else {
        const dupDb = await findDuplicates(pool, record);
        if (dupDb.length) rowResult.duplicateInDb = dupDb;
        previousAccepted.push(record);
        acceptedRows.push(raw);
      }
    } catch (e) {
      rowResult.blocking = e.fieldErrors || [{ field: '?', message: e.message }];
    }

    results.push(rowResult);
  }

  req.session.pendingImport = { rows: acceptedRows, resultsSummary: results.map((r) => ({ rowNumber: r.rowNumber, blocked: r.blocking.length > 0 })) };
  res.render('import', { preview: results });
});

router.post('/import/confirm', requireRole('estudiante'), async (req, res) => {
  const pending = req.session.pendingImport;
  if (!pending) {
    req.flash('error', 'No hay una importación pendiente. Vuelva a cargar el archivo.');
    return res.redirect('/import');
  }
  const user = await userModel.findById(pool, req.session.user.id);
  if (!user.current_class_code_id) {
    req.flash('error', 'Debe estar vinculado a un código de clase para importar registros.');
    return res.redirect('/import');
  }
  const clase = await classCodeModel.findById(pool, user.current_class_code_id);

  let insertados = 0;
  let fallidos = 0;
  for (const raw of pending.rows) {
    try {
      await createOccurrence(pool, raw, {
        usuarioCreadorId: user.id,
        classCodeId: user.current_class_code_id,
        profesorId: clase.profesor_id,
        isAdmin: false,
      });
      insertados++;
    } catch (e) {
      fallidos++;
    }
  }
  delete req.session.pendingImport;
  req.flash('success', `Importación completa: ${insertados} registros creados, ${fallidos} con error al guardar.`);
  res.redirect('/records');
});

module.exports = router;

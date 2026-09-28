const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { requireRole } = require('../middleware/auth');
const { groupedBySection, SECTION_ORDER, DERIVED_FIELDS } = require('../utils/dwcTerms');
const occurrenceModel = require('../models/occurrenceModel');
const { findDuplicates } = require('../utils/duplicates');
const { collectWarnings } = require('../utils/validation');
const classCodeModel = require('../models/classCodeModel');
const userModel = require('../models/userModel');

router.use(requireRole('estudiante'));

router.get('/', async (req, res) => {
  const [rows] = await pool.query(
    `SELECT id, occurrenceID, scientificName, family, eventDate, estado_validacion, version, updated_at
     FROM occurrences WHERE usuario_creador_id = ? AND eliminado = FALSE ORDER BY updated_at DESC`,
    [req.session.user.id]
  );
  res.render('records/list', { records: rows });
});

router.get('/new', (req, res) => {
  if (!req.session.user.current_class_code_id) {
    req.flash('error', 'Debe vincular un código de clase activo en su perfil antes de crear registros.');
    return res.redirect('/records');
  }
  res.render('records/form', {
    record: {},
    sections: groupedBySection(),
    sectionOrder: SECTION_ORDER,
    derivedFields: DERIVED_FIELDS,
    isNew: true,
    fieldErrors: {},
    warnings: [],
  });
});

router.post('/new/check-duplicates', async (req, res) => {
  const matches = await findDuplicates(pool, req.body);
  res.json({ matches });
});

router.post('/', async (req, res) => {
  try {
    const user = await userModel.findById(pool, req.session.user.id);
    const result = await occurrenceModel.createOccurrence(pool, req.body, {
      usuarioCreadorId: user.id,
      classCodeId: user.current_class_code_id,
      profesorId: user.current_class_code_id ? (await classCodeModel.findById(pool, user.current_class_code_id)).profesor_id : null,
      isAdmin: false,
    });
    if (result.warnings.length) {
      req.flash('success', `Registro ${result.occurrenceID} creado con advertencias (ver detalle).`);
    } else {
      req.flash('success', `Registro ${result.occurrenceID} creado correctamente.`);
    }
    if (result.duplicates.length) {
      req.flash('error', `Posible duplicado: coincide con occurrenceID ${result.duplicates.map((d) => d.occurrenceID).join(', ')}. Revise antes de continuar.`);
    }
    res.redirect(`/records/${result.id}/edit`);
  } catch (e) {
    if (e.fieldErrors) {
      return res.render('records/form', {
        record: req.body,
        sections: groupedBySection(),
        sectionOrder: SECTION_ORDER,
        derivedFields: DERIVED_FIELDS,
        isNew: true,
        fieldErrors: Object.fromEntries(e.fieldErrors.map((fe) => [fe.field, fe.message])),
        warnings: [],
      });
    }
    req.flash('error', e.message);
    res.redirect('/records/new');
  }
});

async function loadOwnRecord(req, res, next) {
  const [rows] = await pool.query(
    'SELECT * FROM occurrences WHERE id = ? AND usuario_creador_id = ? AND eliminado = FALSE',
    [req.params.id, req.session.user.id]
  );
  if (!rows[0]) return res.status(404).render('error', { message: 'Registro no encontrado.' });
  req.record = rows[0];
  next();
}

router.get('/:id/edit', loadOwnRecord, (req, res) => {
  res.render('records/form', {
    record: req.record,
    sections: groupedBySection(),
    sectionOrder: SECTION_ORDER,
    derivedFields: DERIVED_FIELDS,
    isNew: false,
    fieldErrors: {},
    warnings: collectWarnings(req.record),
  });
});

router.post('/:id', loadOwnRecord, async (req, res) => {
  try {
    const result = await occurrenceModel.updateOccurrence(pool, req.record.id, req.body, req.session.user.id);
    req.flash('success', `Registro actualizado (versión ${req.record.version + (result.changed ? 1 : 0)}).`);
    if (result.duplicates.length) {
      req.flash('error', `Posible duplicado: coincide con occurrenceID ${result.duplicates.map((d) => d.occurrenceID).join(', ')}. Revise antes de continuar.`);
    }
    res.redirect(`/records/${req.record.id}/edit`);
  } catch (e) {
    if (e.fieldErrors) {
      return res.render('records/form', {
        record: { ...req.record, ...req.body },
        sections: groupedBySection(),
        sectionOrder: SECTION_ORDER,
        derivedFields: DERIVED_FIELDS,
        isNew: false,
        fieldErrors: Object.fromEntries(e.fieldErrors.map((fe) => [fe.field, fe.message])),
        warnings: [],
      });
    }
    req.flash('error', e.message);
    res.redirect(`/records/${req.record.id}/edit`);
  }
});

router.get('/:id/history', loadOwnRecord, async (req, res) => {
  const [history] = await pool.query(
    `SELECT h.*, u.nombre AS usuario_nombre FROM occurrence_history h
     JOIN users u ON u.id = h.usuario_id
     WHERE occurrence_id = ? ORDER BY fecha DESC`,
    [req.record.id]
  );
  res.render('records/history', { record: req.record, history });
});

router.get('/:id/delete', loadOwnRecord, async (req, res) => {
  const perteneceAClase = !!req.record.class_code_id;
  res.render('records/delete-confirm', { record: req.record, perteneceAClase });
});

router.post('/:id/delete', loadOwnRecord, async (req, res) => {
  await occurrenceModel.softDeleteOccurrence(pool, req.record.id);
  req.flash('success', `Registro ${req.record.occurrenceID} eliminado.`);
  res.redirect('/records');
});

module.exports = router;

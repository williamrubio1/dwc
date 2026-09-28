const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { requireAuth, requireRole } = require('../middleware/auth');
const classCodeModel = require('../models/classCodeModel');
const userModel = require('../models/userModel');

router.get('/profile', requireAuth, async (req, res) => {
  const user = await userModel.findById(pool, req.session.user.id);
  let clase = null;
  if (user.current_class_code_id) clase = await classCodeModel.findById(pool, user.current_class_code_id);
  res.render('profile', { user, clase });
});

// Seccion 7: vinculacion del estudiante a un codigo de clase
router.post('/profile/link-class', requireRole('estudiante'), async (req, res) => {
  const { codigo } = req.body;
  try {
    const clase = await classCodeModel.findByCodigo(pool, codigo.trim());
    if (!clase) throw new Error('El código no existe.');
    if (clase.estado !== 'activo') throw new Error('El código no está activo.');
    if (clase.siguiente_numero > clase.rango_final) throw new Error('Este código ya no admite nuevas vinculaciones (rango agotado).');

    await userModel.linkClassCode(pool, req.session.user.id, clase.id);
    req.session.user.current_class_code_id = clase.id;
    req.flash('success', `Vinculado a la clase "${clase.nombre_clase}".`);
  } catch (e) {
    req.flash('error', e.message);
  }
  res.redirect('/profile');
});

module.exports = router;

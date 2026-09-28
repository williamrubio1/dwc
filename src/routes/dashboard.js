const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { requireAuth } = require('../middleware/auth');

router.get('/', (req, res) => {
  res.redirect(req.session.user ? '/dashboard' : '/login');
});

router.get('/dashboard', requireAuth, async (req, res) => {
  const user = req.session.user;
  const stats = {};

  if (user.role === 'estudiante') {
    const [[row]] = await pool.query(
      `SELECT
        COUNT(*) AS total,
        SUM(estado_validacion = 'incompleto') AS incompletos,
        SUM(estado_validacion = 'con_advertencias') AS con_advertencias,
        SUM(estado_validacion = 'completo_para_sobre') AS completos
       FROM occurrences WHERE usuario_creador_id = ? AND eliminado = FALSE`,
      [user.id]
    );
    stats.registros = row;
    stats.vinculado = !!user.current_class_code_id;
  } else if (user.role === 'profesor') {
    const [[row]] = await pool.query(
      `SELECT COUNT(*) AS clases FROM class_codes WHERE profesor_id = ?`,
      [user.id]
    );
    stats.clases = row.clases;
    const [[row2]] = await pool.query(
      `SELECT COUNT(*) AS registros FROM occurrences WHERE profesor_id = ? AND eliminado = FALSE`,
      [user.id]
    );
    stats.registros = row2.registros;
  } else if (user.role === 'administrador') {
    const [[row]] = await pool.query(`SELECT COUNT(*) AS usuarios FROM users`);
    const [[row2]] = await pool.query(`SELECT COUNT(*) AS registros FROM occurrences WHERE eliminado = FALSE`);
    const [[row3]] = await pool.query(`SELECT COUNT(*) AS clases FROM class_codes`);
    stats.usuarios = row.usuarios;
    stats.registros = row2.registros;
    stats.clases = row3.clases;
  }

  res.render('dashboard', { stats });
});

module.exports = router;

const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const userModel = require('../models/userModel');

router.get('/login', (req, res) => {
  if (req.session.user) return res.redirect('/dashboard');
  res.render('auth/login');
});

router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  try {
    const user = (await userModel.findByUsername(pool, username)) || (await userModel.findByEmail(pool, username));
    if (!user || !user.activo) {
      req.flash('error', 'Usuario o contraseña incorrectos, o cuenta inactiva.');
      return res.redirect('/login');
    }
    const ok = await userModel.verifyPassword(user, password);
    if (!ok) {
      req.flash('error', 'Usuario o contraseña incorrectos.');
      return res.redirect('/login');
    }
    req.session.user = {
      id: user.id,
      role: user.role,
      nombre: user.nombre,
      email: user.email,
      username: user.username,
      current_class_code_id: user.current_class_code_id,
    };
    res.redirect('/dashboard');
  } catch (e) {
    req.flash('error', e.message);
    res.redirect('/login');
  }
});

router.get('/register', (req, res) => {
  if (req.session.user) return res.redirect('/dashboard');
  res.render('auth/register');
});

router.post('/register', async (req, res) => {
  const { email, password, nombre, documento, programa, semestre, codigoEstudiantil, telefono } = req.body;
  try {
    await userModel.registerStudent(pool, {
      email, password, nombre, documento, programa, semestre, codigoEstudiantil, telefono,
    });
    req.flash('success', 'Cuenta creada. Ya puede iniciar sesión.');
    res.redirect('/login');
  } catch (e) {
    req.flash('error', e.message);
    res.redirect('/register');
  }
});

router.post('/logout', (req, res) => {
  req.session.destroy(() => res.redirect('/login'));
});

module.exports = router;

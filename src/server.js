require('dotenv').config();
const path = require('path');
const express = require('express');
const session = require('express-session');
const flash = require('connect-flash');
const methodOverride = require('method-override');

const pool = require('./config/db');
const { attachUser } = require('./middleware/auth');
const { ensureAdmin } = require('./models/userModel');

const authRoutes = require('./routes/auth');
const dashboardRoutes = require('./routes/dashboard');
const profileRoutes = require('./routes/profile');
const recordRoutes = require('./routes/records');
const classRoutes = require('./routes/classes');
const adminRoutes = require('./routes/admin');
const exportImportRoutes = require('./routes/exportImport');
const envelopeRoutes = require('./routes/envelopes');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.locals.isoToDisplay = require('./utils/validation').isoToDisplay;
app.locals.dwcTerms = require('./utils/dwcTerms');

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(methodOverride('_method'));
app.use(express.static(path.join(__dirname, '..', 'public')));

app.use(session({
  secret: process.env.SESSION_SECRET || 'darwin-core-secret',
  resave: false,
  saveUninitialized: false,
  cookie: { maxAge: 1000 * 60 * 60 * 8 },
}));
app.use(flash());
app.use(attachUser);
app.use((req, res, next) => {
  res.locals.messages = { success: req.flash('success'), error: req.flash('error') };
  next();
});

app.use('/', authRoutes);
app.use('/', dashboardRoutes);
app.use('/', profileRoutes);
app.use('/records', recordRoutes);
app.use('/classes', classRoutes);
app.use('/admin', adminRoutes);
app.use('/', exportImportRoutes);
app.use('/', envelopeRoutes);

app.use((req, res) => {
  res.status(404).render('error', { message: 'Página no encontrada.' });
});

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).render('error', { message: err.message || 'Error interno del servidor.' });
});

const PORT = process.env.PORT || 3000;

ensureAdmin(pool)
  .catch((e) => console.error('No se pudo verificar/crear la cuenta admin:', e.message))
  .finally(() => {
    app.listen(PORT, () => console.log(`Darwin Core escuchando en el puerto ${PORT}`));
  });

module.exports = app;

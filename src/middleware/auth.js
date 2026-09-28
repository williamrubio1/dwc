function requireAuth(req, res, next) {
  if (!req.session.user) return res.redirect('/login');
  next();
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.session.user) return res.redirect('/login');
    if (!roles.includes(req.session.user.role)) {
      return res.status(403).render('error', { message: 'No tiene permisos para acceder a esta sección.' });
    }
    next();
  };
}

function attachUser(req, res, next) {
  res.locals.currentUser = req.session.user || null;
  next();
}

module.exports = { requireAuth, requireRole, attachUser };

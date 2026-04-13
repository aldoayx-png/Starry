const jwt = require('jsonwebtoken');

// Autenticación requerida
const auth = function (req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader) return res.status(401).json({ error: 'Token no proporcionado' });

  const token = authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Token no válido' });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = decoded.id;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Token inválido o expirado' });
  }
};

// Autenticación opcional
const optionalAuth = function (req, res, next) {
  const authHeader = req.headers['authorization'];
  if (authHeader) {
    const token = authHeader.split(' ')[1];
    if (token) {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.userId = decoded.id;
      } catch (err) {
        // Token inválido, simplemente continuar sin userId
      }
    }
  }
  next();
};

module.exports = auth;
module.exports.optionalAuth = optionalAuth;

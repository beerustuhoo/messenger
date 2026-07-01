const jwt = require('jsonwebtoken');

function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  try {
    const payload = jwt.verify(header.slice(7), process.env.JWT_SECRET);
    req.userId = payload.sub;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired session' });
  }
}

function validatePassword(password) {
  const errors = [];
  if (!password || password.length < 8) errors.push('at least 8 characters');
  if (!/[a-z]/.test(password)) errors.push('at least 1 lowercase letter');
  if (!/[A-Z]/.test(password)) errors.push('at least 1 uppercase letter');
  if (!/\d/.test(password)) errors.push('at least 1 digit');
  if (!/[!@#$%^&*()_+\-=[\]{};':"\\|,.<>/?`~]/.test(password)) {
    errors.push('at least 1 special character');
  }
  return errors;
}

module.exports = { authMiddleware, validatePassword };

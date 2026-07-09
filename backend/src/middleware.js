const jwt = require('jsonwebtoken');
const { isFirebaseEnabled } = require('./firebase');
const { resolveUserIdFromBearer } = require('./auth_tokens');

async function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  const token = header.slice(7);
  const resolved = await resolveUserIdFromBearer(token);

  if (!resolved) {
    return res.status(401).json({ error: 'Invalid or expired session' });
  }

  if (resolved.needsSync) {
    return res.status(401).json({ error: 'Profile not synced', code: 'NEEDS_SYNC' });
  }

  if (!resolved.userId) {
    return res.status(401).json({ error: 'Invalid or expired session' });
  }

  req.userId = resolved.userId;
  req.firebase = resolved.firebase;
  next();
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

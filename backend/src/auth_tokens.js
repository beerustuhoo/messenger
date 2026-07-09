const jwt = require('jsonwebtoken');
const { pool } = require('./db');
const { isFirebaseEnabled, verifyFirebaseToken } = require('./firebase');

async function resolveUserIdFromBearer(token) {
  if (!token) return null;

  if (isFirebaseEnabled()) {
    try {
      const fb = await verifyFirebaseToken(token);
      const result = await pool.query('SELECT id FROM users WHERE firebase_uid = $1', [fb.uid]);
      if (result.rows.length) return { userId: result.rows[0].id, firebase: fb };
      return { userId: null, firebase: fb, needsSync: true };
    } catch {
      return null;
    }
  }

  if (!process.env.JWT_SECRET) return null;
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    return { userId: payload.sub, firebase: null };
  } catch {
    return null;
  }
}

module.exports = { resolveUserIdFromBearer };

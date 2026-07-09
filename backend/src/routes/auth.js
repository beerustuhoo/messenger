const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { pool } = require('../db');
const { encrypt, decrypt } = require('../crypto');
const { authMiddleware, validatePassword } = require('../middleware');
const { sendVerificationEmail, sendPasswordResetEmail } = require('../email');
const { isFirebaseEnabled, verifyFirebaseToken } = require('../firebase');

const router = express.Router();

function emailHash(email) {
  return crypto.createHash('sha256').update(email.toLowerCase().trim()).digest('hex');
}

function normalizeToken(raw) {
  return String(raw || '')
    .trim()
    .replace(/=3D/gi, '')
    .replace(/=\r?\n/g, '')
    .replace(/\s+/g, '');
}

function signTokens(userId) {
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET is not configured');
  }
  const accessToken = jwt.sign({ sub: String(userId) }, process.env.JWT_SECRET, { expiresIn: '1h' });
  const refreshToken = crypto.randomBytes(48).toString('hex');
  return { accessToken, refreshToken };
}

async function storeRefreshToken(userId, refreshToken) {
  const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
  const expires = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  await pool.query(
    'INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)',
    [userId, hash, expires]
  );
}

function userPayload(row, email) {
  return {
    id: row.id,
    username: row.username,
    email: email ?? undefined,
    emailVerified: row.email_verified,
    about: row.about_enc ? decrypt(row.about_enc) || '' : '',
    avatarUrl: row.avatar_url,
  };
}

router.get('/mode', (_req, res) => {
  res.json({ firebase: isFirebaseEnabled() });
});

router.post('/sync', async (req, res) => {
  if (!isFirebaseEnabled()) {
    return res.status(503).json({ error: 'Firebase auth is not enabled on this server' });
  }
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  let fb;
  try {
    fb = await verifyFirebaseToken(header.slice(7));
  } catch {
    return res.status(401).json({ error: 'Invalid Firebase token' });
  }
  const email = fb.email?.toLowerCase().trim();
  if (!email) return res.status(400).json({ error: 'Firebase account has no email' });

  const { username } = req.body;
  const uname = username?.trim();

  try {
    const existing = await pool.query('SELECT * FROM users WHERE firebase_uid = $1', [fb.uid]);
    if (existing.rows.length) {
      await pool.query(
        `UPDATE users SET email_verified = $1, email_hash = $2, email_enc = $3 WHERE firebase_uid = $4`,
        [fb.emailVerified, emailHash(email), encrypt(email), fb.uid]
      );
      const updated = await pool.query('SELECT * FROM users WHERE firebase_uid = $1', [fb.uid]);
      return res.json({ user: userPayload(updated.rows[0], email) });
    }

    if (!uname || uname.length < 3) {
      return res.status(400).json({ error: 'Username must be at least 3 characters', field: 'username' });
    }

    const takenEmail = await pool.query('SELECT * FROM users WHERE email_hash = $1', [emailHash(email)]);
    if (takenEmail.rows.length) {
      const legacy = takenEmail.rows[0];
      if (legacy.firebase_uid && legacy.firebase_uid !== fb.uid) {
        return res.status(409).json({ error: 'Email already in use', field: 'email' });
      }
      if (!legacy.firebase_uid) {
        await pool.query(
          `UPDATE users
           SET firebase_uid = $1, email_verified = $2, email_hash = $3, email_enc = $4, password_hash = NULL
           WHERE id = $5`,
          [fb.uid, fb.emailVerified, emailHash(email), encrypt(email), legacy.id]
        );
        const updated = await pool.query('SELECT * FROM users WHERE id = $1', [legacy.id]);
        return res.json({ user: userPayload(updated.rows[0], email) });
      }
    }
    const takenUser = await pool.query('SELECT id FROM users WHERE username = $1', [uname]);
    if (takenUser.rows.length) {
      return res.status(409).json({ error: 'Username already in use', field: 'username' });
    }

    const result = await pool.query(
      `INSERT INTO users (firebase_uid, email_hash, email_enc, username, password_hash, email_verified)
       VALUES ($1, $2, $3, $4, NULL, $5)
       RETURNING *`,
      [fb.uid, emailHash(email), encrypt(email), uname, fb.emailVerified]
    );
    res.status(201).json({ user: userPayload(result.rows[0], email) });
  } catch (err) {
    console.error('Sync error:', err);
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Email or username already in use' });
    }
    res.status(500).json({ error: 'Profile sync failed' });
  }
});

router.post('/register', async (req, res) => {
  if (isFirebaseEnabled()) {
    return res.status(400).json({
      error: 'Registration is handled by Firebase Auth in the app',
      code: 'FIREBASE_AUTH',
    });
  }
  try {
    const { email, password, username } = req.body;
    if (!email || !password || !username) {
      return res.status(400).json({ error: 'Email, password, and username are required' });
    }
    const pwErrors = validatePassword(password);
    if (pwErrors.length) {
      return res.status(400).json({ error: 'Password does not meet requirements', details: pwErrors });
    }
    const uname = username.trim();
    if (uname.length < 3) {
      return res.status(400).json({ error: 'Username must be at least 3 characters' });
    }

    const existingEmail = await pool.query('SELECT id FROM users WHERE email_hash = $1', [emailHash(email)]);
    if (existingEmail.rows.length) {
      return res.status(409).json({ error: 'Email already in use', field: 'email' });
    }
    const existingUser = await pool.query('SELECT id FROM users WHERE username = $1', [uname]);
    if (existingUser.rows.length) {
      return res.status(409).json({ error: 'Username already in use', field: 'username' });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const verificationToken = crypto.randomBytes(32).toString('hex');
    const result = await pool.query(
      `INSERT INTO users (email_hash, email_enc, username, password_hash, verification_token)
       VALUES ($1, $2, $3, $4, $5) RETURNING id, username, email_verified`,
      [emailHash(email), encrypt(email.toLowerCase().trim()), uname, passwordHash, verificationToken]
    );
    const user = result.rows[0];
    const mailResult = await sendVerificationEmail(email, verificationToken);

    const { accessToken, refreshToken } = signTokens(user.id);
    await storeRefreshToken(user.id, refreshToken);

    res.status(201).json({
      user: {
        id: user.id,
        username: user.username,
        email: email.toLowerCase().trim(),
        emailVerified: user.email_verified,
      },
      accessToken,
      refreshToken,
      verificationToken,
      emailSent: mailResult.ok === true,
      message: mailResult.ok
        ? 'Account created. Please check your email to verify.'
        : 'Account created. Email could not be sent — use Verify now in the app.',
    });
  } catch (err) {
    console.error('Register error:', err);
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Email or username already in use' });
    }
    const msg = err.message || '';
    if (msg.includes('ENCRYPTION_KEY')) {
      return res.status(503).json({ error: 'Server misconfigured: encryption key' });
    }
    if (msg.includes('JWT_SECRET')) {
      return res.status(503).json({ error: 'Server misconfigured: auth secret' });
    }
    res.status(500).json({ error: 'Registration failed' });
  }
});

router.post('/login', async (req, res) => {
  if (isFirebaseEnabled()) {
    return res.status(400).json({
      error: 'Login is handled by Firebase Auth in the app',
      code: 'FIREBASE_AUTH',
    });
  }
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    const result = await pool.query('SELECT * FROM users WHERE email_hash = $1', [emailHash(email)]);
    if (!result.rows.length) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const { accessToken, refreshToken } = signTokens(user.id);
    await storeRefreshToken(user.id, refreshToken);

    res.json({
      user: {
        id: user.id,
        username: user.username,
        emailVerified: user.email_verified,
        about: decrypt(user.about_enc) || '',
        avatarUrl: user.avatar_url,
      },
      accessToken,
      refreshToken,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Login failed' });
  }
});

router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(400).json({ error: 'Refresh token required' });
    const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    const result = await pool.query(
      `SELECT rt.*, u.username, u.email_verified FROM refresh_tokens rt
       JOIN users u ON u.id = rt.user_id
       WHERE rt.token_hash = $1 AND rt.expires_at > NOW()`,
      [hash]
    );
    if (!result.rows.length) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }
    const row = result.rows[0];
    await pool.query('DELETE FROM refresh_tokens WHERE token_hash = $1', [hash]);
    const tokens = signTokens(row.user_id);
    await storeRefreshToken(row.user_id, tokens.refreshToken);
    res.json({
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: { id: row.user_id, username: row.username, emailVerified: row.email_verified },
    });
  } catch (err) {
    res.status(500).json({ error: 'Token refresh failed' });
  }
});

router.post('/logout', authMiddleware, async (req, res) => {
  const { refreshToken } = req.body;
  if (refreshToken) {
    const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
    await pool.query('DELETE FROM refresh_tokens WHERE token_hash = $1 AND user_id = $2', [hash, req.userId]);
  }
  res.json({ ok: true });
});

router.post('/verify-email', authMiddleware, async (req, res) => {
  const token = normalizeToken(req.body.token);
  if (!token) return res.status(400).json({ error: 'Verification token required' });
  const result = await pool.query(
    'SELECT id FROM users WHERE id = $1 AND verification_token = $2',
    [req.userId, token]
  );
  if (!result.rows.length) {
    return res.status(400).json({ error: 'Invalid verification token' });
  }
  await pool.query(
    'UPDATE users SET email_verified = TRUE, verification_token = NULL WHERE id = $1',
    [req.userId]
  );
  res.json({ ok: true, message: 'Email verified successfully' });
});

router.get('/verify', async (req, res) => {
  const token = normalizeToken(req.query.token);
  if (!token) return res.status(400).send('Missing token');
  const result = await pool.query('SELECT id FROM users WHERE verification_token = $1', [token]);
  if (!result.rows.length) return res.status(400).send('Invalid token');
  await pool.query(
    'UPDATE users SET email_verified = TRUE, verification_token = NULL WHERE verification_token = $1',
    [token]
  );
  res.send('<h1>Email verified! You can return to the app.</h1>');
});

router.post('/resend-verification', authMiddleware, async (req, res) => {
  const result = await pool.query('SELECT email_enc, email_verified FROM users WHERE id = $1', [req.userId]);
  const user = result.rows[0];
  if (!user) return res.status(401).json({ error: 'User not found' });
  if (user.email_verified) return res.json({ message: 'Already verified' });
  const token = crypto.randomBytes(32).toString('hex');
  await pool.query('UPDATE users SET verification_token = $1 WHERE id = $2', [token, req.userId]);
  const email = decrypt(user.email_enc);
  const mailResult = await sendVerificationEmail(email, token);
  res.json({
    message: mailResult.ok ? 'Verification email sent' : 'Could not send email — check SMTP settings',
    verificationToken: token,
    emailSent: mailResult.ok === true,
  });
});

router.get('/verification-token', authMiddleware, async (req, res) => {
  const result = await pool.query(
    'SELECT email_verified, verification_token FROM users WHERE id = $1',
    [req.userId]
  );
  const user = result.rows[0];
  if (!user) return res.status(401).json({ error: 'User not found' });
  if (user.email_verified) return res.json({ emailVerified: true });
  if (!user.verification_token) {
    return res.status(404).json({ error: 'No verification token available' });
  }
  res.json({ verificationToken: user.verification_token });
});

router.post('/forgot-password', async (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email required' });
  const result = await pool.query('SELECT id, email_enc FROM users WHERE email_hash = $1', [emailHash(email)]);
  if (result.rows.length) {
    const token = crypto.randomBytes(32).toString('hex');
    const expires = new Date(Date.now() + 60 * 60 * 1000);
    await pool.query(
      'UPDATE users SET reset_token = $1, reset_token_expires = $2 WHERE id = $3',
      [token, expires, result.rows[0].id]
    );
    await sendPasswordResetEmail(decrypt(result.rows[0].email_enc), token);
  }
  res.json({ message: 'If the email exists, a reset link was sent' });
});

router.post('/reset-password', async (req, res) => {
  const { token, password } = req.body;
  const pwErrors = validatePassword(password);
  if (pwErrors.length) {
    return res.status(400).json({ error: 'Password does not meet requirements', details: pwErrors });
  }
  const result = await pool.query(
    'SELECT id FROM users WHERE reset_token = $1 AND reset_token_expires > NOW()',
    [token]
  );
  if (!result.rows.length) return res.status(400).json({ error: 'Invalid or expired reset token' });
  const hash = await bcrypt.hash(password, 12);
  await pool.query(
    'UPDATE users SET password_hash = $1, reset_token = NULL, reset_token_expires = NULL WHERE id = $2',
    [hash, result.rows[0].id]
  );
  res.json({ message: 'Password reset successful' });
});

router.get('/me', authMiddleware, async (req, res) => {
  const result = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
  const u = result.rows[0];
  if (!u) return res.status(401).json({ error: 'User not found' });
  res.json({
    id: u.id,
    username: u.username,
    email: decrypt(u.email_enc),
    emailVerified: u.email_verified,
    about: decrypt(u.about_enc) || '',
    avatarUrl: u.avatar_url,
  });
});

module.exports = router;

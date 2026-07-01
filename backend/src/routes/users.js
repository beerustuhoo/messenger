const express = require('express');
const crypto = require('crypto');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../db');
const { encrypt, decrypt } = require('../crypto');
const { authMiddleware } = require('../middleware');

const router = express.Router();
const uploadDir = process.env.UPLOAD_DIR || './uploads';

if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: uploadDir,
  filename: (_req, file, cb) => {
    let ext = path.extname(file.originalname).toLowerCase();
    if (!ext || ext === '.') {
      ext = file.mimetype === 'image/png' ? '.png' : '.jpg';
    }
    cb(null, `avatar_${uuidv4()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/jpg', 'application/octet-stream'];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Only JPEG and PNG images are allowed'));
  },
});

function emailHash(email) {
  return crypto.createHash('sha256').update(email.toLowerCase().trim()).digest('hex');
}

router.get('/search', authMiddleware, async (req, res) => {
  const q = (req.query.q || '').trim();
  if (q.length < 2) return res.json([]);
  const hash = q.includes('@') ? emailHash(q) : null;
  const result = await pool.query(
    `SELECT id, username, avatar_url FROM users
     WHERE id != $1 AND (username ILIKE $2 OR ($3::varchar IS NOT NULL AND email_hash = $3))
     LIMIT 20`,
    [req.userId, `%${q}%`, hash]
  );
  res.json(result.rows.map((u) => ({
    id: u.id,
    username: u.username,
    avatarUrl: u.avatar_url,
  })));
});

router.put('/profile', authMiddleware, async (req, res) => {
  const { username, about } = req.body;
  if (username) {
    const taken = await pool.query(
      'SELECT id FROM users WHERE username = $1 AND id != $2',
      [username.trim(), req.userId]
    );
    if (taken.rows.length) {
      return res.status(409).json({ error: 'Username already in use', field: 'username' });
    }
    await pool.query('UPDATE users SET username = $1 WHERE id = $2', [username.trim(), req.userId]);
  }
  if (about !== undefined) {
    await pool.query('UPDATE users SET about_enc = $1 WHERE id = $2', [encrypt(about), req.userId]);
  }
  const result = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
  const u = result.rows[0];
  res.json({
    id: u.id,
    username: u.username,
    about: decrypt(u.about_enc) || '',
    avatarUrl: u.avatar_url,
    emailVerified: u.email_verified,
  });
});

router.post('/avatar', authMiddleware, (req, res) => {
  upload.single('avatar')(req, res, async (err) => {
    if (err) return res.status(400).json({ error: err.message });
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
    const url = `/uploads/${req.file.filename}`;
    await pool.query('UPDATE users SET avatar_url = $1 WHERE id = $2', [url, req.userId]);
    res.json({ avatarUrl: url });
  });
});

router.post('/fcm-token', authMiddleware, async (req, res) => {
  const { token } = req.body;
  await pool.query('UPDATE users SET fcm_token = $1 WHERE id = $2', [token || null, req.userId]);
  res.json({ ok: true });
});

module.exports = router;

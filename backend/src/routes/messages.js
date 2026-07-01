const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../db');
const { encrypt, decrypt } = require('../crypto');
const { authMiddleware } = require('../middleware');
const { getPollPayload } = require('./polls');

const router = express.Router();
const uploadDir = process.env.UPLOAD_DIR || './uploads';

if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: uploadDir,
  filename: (_req, file, cb) => cb(null, `media_${uuidv4()}${path.extname(file.originalname)}`),
});

const upload = multer({
  storage,
  limits: { fileSize: 20 * 1024 * 1024 },
});

async function isChatMember(userId, chatId) {
  const r = await pool.query(
    'SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2',
    [chatId, userId]
  );
  return r.rows.length > 0;
}

function formatMessage(row, userId, senderUsername) {
  return {
    id: row.id,
    chatId: row.chat_id,
    senderId: row.sender_id,
    senderUsername: senderUsername || row.sender_username,
    type: row.type,
    content: row.deleted ? null : decrypt(row.content_enc),
    mediaUrl: row.deleted ? null : row.media_path,
    mediaMime: row.media_mime,
    status: row.status,
    edited: row.edited,
    deleted: row.deleted,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    isMine: row.sender_id === userId,
    pollId: row.poll_id || null,
  };
}

router.get('/search', authMiddleware, async (req, res) => {
  const q = (req.query.q || '').trim().toLowerCase();
  const chatId = req.query.chatId;
  if (q.length < 2) return res.status(400).json({ error: 'Query must be at least 2 characters' });

  let query = `
    SELECT m.*, u.username as sender_username, p.id as poll_id
    FROM messages m
    JOIN chat_members cm ON cm.chat_id = m.chat_id AND cm.user_id = $1
    JOIN users u ON u.id = m.sender_id
    LEFT JOIN polls p ON p.message_id = m.id
    WHERE NOT m.deleted AND m.type = 'text'`;
  const params = [req.userId];

  if (chatId) {
    query += ` AND m.chat_id = $2`;
    params.push(chatId);
  }

  query += ` ORDER BY m.created_at DESC LIMIT 200`;

  const result = await pool.query(query, params);
  const matches = [];
  for (const row of result.rows) {
    const text = decrypt(row.content_enc);
    if (text && text.toLowerCase().includes(q)) {
      matches.push({
        ...formatMessage(row, req.userId, row.sender_username),
        matchIndex: text.toLowerCase().indexOf(q),
      });
    }
  }
  res.json(matches.slice(0, 50));
});

router.get('/:chatId', authMiddleware, async (req, res) => {
  if (!(await isChatMember(req.userId, req.params.chatId))) {
    return res.status(403).json({ error: 'Not a member of this chat' });
  }
  const limit = Math.min(parseInt(req.query.limit || '50', 10), 100);
  const before = req.query.before;
  let query = `SELECT * FROM messages WHERE chat_id = $1`;
  const params = [req.params.chatId];
  if (before) {
    query += ` AND created_at < $2 ORDER BY created_at DESC LIMIT $3`;
    params.push(before, limit);
  } else {
    query += ` ORDER BY created_at DESC LIMIT $2`;
    params.push(limit);
  }
  const result = await pool.query(query, params);
  const rows = result.rows.reverse();
  const formatted = [];
  for (const r of rows) {
    const u = await pool.query('SELECT username FROM users WHERE id = $1', [r.sender_id]);
    const msg = formatMessage(r, req.userId, u.rows[0]?.username);
    if (r.type === 'poll') {
      const poll = await pool.query('SELECT id FROM polls WHERE message_id = $1', [r.id]);
      if (poll.rows.length) {
        msg.pollId = poll.rows[0].id;
        msg.poll = await getPollPayload(poll.rows[0].id, req.userId);
      }
    }
    formatted.push(msg);
  }
  res.json(formatted);
});

router.post('/:chatId/text', authMiddleware, async (req, res) => {
  const { content } = req.body;
  const chatId = req.params.chatId;
  if (!(await isChatMember(req.userId, chatId))) {
    return res.status(403).json({ error: 'Not a member of this chat' });
  }
  if (!content?.trim()) return res.status(400).json({ error: 'Content required' });

  const result = await pool.query(
    `INSERT INTO messages (chat_id, sender_id, type, content_enc, status)
     VALUES ($1, $2, 'text', $3, 'sent') RETURNING *`,
    [chatId, req.userId, encrypt(content.trim())]
  );
  await pool.query('UPDATE chats SET updated_at = NOW() WHERE id = $1', [chatId]);
  const msg = formatMessage(result.rows[0], req.userId);
  broadcastMessage(req, chatId, msg);
  res.status(201).json(msg);
});

router.post('/:chatId/poll', authMiddleware, async (req, res) => {
  const { question, options, anonymous = false, multipleChoice = false } = req.body;
  const chatId = req.params.chatId;
  if (!(await isChatMember(req.userId, chatId))) {
    return res.status(403).json({ error: 'Not a member of this chat' });
  }
  if (!question?.trim()) return res.status(400).json({ error: 'Question required' });
  if (!Array.isArray(options) || options.length < 2) {
    return res.status(400).json({ error: 'At least 2 options required' });
  }

  const chat = await pool.query('SELECT type FROM chats WHERE id = $1', [chatId]);
  if (!chat.rows.length || chat.rows[0].type !== 'group') {
    return res.status(400).json({ error: 'Polls are only available in group chats' });
  }

  const msgResult = await pool.query(
    `INSERT INTO messages (chat_id, sender_id, type, content_enc, status)
     VALUES ($1, $2, 'poll', $3, 'sent') RETURNING *`,
    [chatId, req.userId, encrypt(question.trim())]
  );
  const pollResult = await pool.query(
    `INSERT INTO polls (message_id, question_enc, anonymous, multiple_choice, created_by)
     VALUES ($1, $2, $3, $4, $5) RETURNING id`,
    [msgResult.rows[0].id, encrypt(question.trim()), !!anonymous, !!multipleChoice, req.userId]
  );
  const pollId = pollResult.rows[0].id;

  for (let i = 0; i < options.length; i++) {
    await pool.query(
      `INSERT INTO poll_options (poll_id, text_enc, sort_order) VALUES ($1, $2, $3)`,
      [pollId, encrypt(String(options[i]).trim()), i]
    );
  }

  await pool.query('UPDATE chats SET updated_at = NOW() WHERE id = $1', [chatId]);
  const u = await pool.query('SELECT username FROM users WHERE id = $1', [req.userId]);
  const msg = formatMessage(msgResult.rows[0], req.userId, u.rows[0]?.username);
  msg.pollId = pollId;
  msg.poll = await getPollPayload(pollId, req.userId);
  broadcastMessage(req, chatId, msg);
  res.status(201).json(msg);
});

router.post('/:chatId/media', authMiddleware, (req, res) => {
  upload.single('file')(req, res, async (err) => {
    if (err) return res.status(400).json({ error: err.message });
    const chatId = req.params.chatId;
    if (!(await isChatMember(req.userId, chatId))) {
      return res.status(403).json({ error: 'Not a member of this chat' });
    }
    const type = req.body.type || (req.file.mimetype.startsWith('video') ? 'video' : 'image');
    const allowed = ['image', 'video', 'audio'];
    if (!allowed.includes(type)) return res.status(400).json({ error: 'Invalid media type' });

    const mediaUrl = `/uploads/${req.file.filename}`;
    const caption = req.body.caption ? encrypt(req.body.caption) : null;
    const result = await pool.query(
      `INSERT INTO messages (chat_id, sender_id, type, content_enc, media_path, media_mime, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'sent') RETURNING *`,
      [chatId, req.userId, type, caption, mediaUrl, req.file.mimetype]
    );
    await pool.query('UPDATE chats SET updated_at = NOW() WHERE id = $1', [chatId]);
    const msg = formatMessage(result.rows[0], req.userId);
    broadcastMessage(req, chatId, msg);
    res.status(201).json(msg);
  });
});

router.patch('/:messageId', authMiddleware, async (req, res) => {
  const { content } = req.body;
  const result = await pool.query(
    'SELECT * FROM messages WHERE id = $1 AND sender_id = $2 AND NOT deleted',
    [req.params.messageId, req.userId]
  );
  if (!result.rows.length) return res.status(404).json({ error: 'Message not found' });
  const row = result.rows[0];
  if (row.type !== 'text') return res.status(400).json({ error: 'Only text messages can be edited' });

  const updated = await pool.query(
    `UPDATE messages SET content_enc = $1, edited = TRUE, updated_at = NOW() WHERE id = $2 RETURNING *`,
    [encrypt(content.trim()), req.params.messageId]
  );
  const msg = formatMessage(updated.rows[0], req.userId);
  const io = req.app.get('io');
  io.to(`chat:${row.chat_id}`).emit('message:updated', msg);
  res.json(msg);
});

router.delete('/:messageId', authMiddleware, async (req, res) => {
  const result = await pool.query(
    'SELECT * FROM messages WHERE id = $1 AND sender_id = $2',
    [req.params.messageId, req.userId]
  );
  if (!result.rows.length) return res.status(404).json({ error: 'Message not found' });

  await pool.query(
    'UPDATE messages SET deleted = TRUE, content_enc = NULL, media_path = NULL WHERE id = $1',
    [req.params.messageId]
  );
  const io = req.app.get('io');
  io.to(`chat:${result.rows[0].chat_id}`).emit('message:deleted', { id: req.params.messageId });
  res.json({ ok: true });
});

router.post('/:messageId/delivered', authMiddleware, async (req, res) => {
  const result = await pool.query(
    `SELECT m.* FROM messages m
     JOIN chat_members cm ON cm.chat_id = m.chat_id AND cm.user_id = $1
     WHERE m.id = $2 AND m.sender_id != $1`,
    [req.userId, req.params.messageId]
  );
  if (!result.rows.length) return res.status(404).json({ error: 'Message not found' });
  if (result.rows[0].status === 'sent') {
    await pool.query("UPDATE messages SET status = 'delivered' WHERE id = $1", [req.params.messageId]);
    const io = req.app.get('io');
    io.to(`chat:${result.rows[0].chat_id}`).emit('message:status', {
      id: req.params.messageId,
      status: 'delivered',
    });
  }
  res.json({ ok: true });
});

router.post('/:messageId/read', authMiddleware, async (req, res) => {
  const result = await pool.query(
    `SELECT m.* FROM messages m
     JOIN chat_members cm ON cm.chat_id = m.chat_id AND cm.user_id = $1
     WHERE m.id = $2 AND m.sender_id != $1`,
    [req.userId, req.params.messageId]
  );
  if (!result.rows.length) return res.status(404).json({ error: 'Message not found' });

  await pool.query(
    `INSERT INTO message_reads (message_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
    [req.params.messageId, req.userId]
  );
  await pool.query("UPDATE messages SET status = 'read' WHERE id = $1", [req.params.messageId]);
  const io = req.app.get('io');
  io.to(`chat:${result.rows[0].chat_id}`).emit('message:status', {
    id: req.params.messageId,
    status: 'read',
  });
  res.json({ ok: true });
});

function broadcastMessage(req, chatId, msg) {
  const io = req.app.get('io');
  io.to(`chat:${chatId}`).emit('message:new', msg);
  pool.query(
    'SELECT user_id, muted FROM chat_members WHERE chat_id = $1 AND user_id != $2',
    [chatId, req.userId]
  ).then((members) => {
    members.rows.forEach((m) => {
      io.to(`user:${m.user_id}`).emit('notification', {
        type: 'message',
        chatId,
        muted: m.muted,
        preview: msg.type === 'text' ? msg.content?.slice(0, 80) : `[${msg.type}]`,
      });
    });
  });
}

module.exports = router;

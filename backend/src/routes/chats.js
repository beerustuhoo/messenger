const express = require('express');
const { pool } = require('../db');
const { decrypt } = require('../crypto');
const { authMiddleware } = require('../middleware');

const router = express.Router();

router.get('/', authMiddleware, async (req, res) => {
  const archived = req.query.archived === 'true';
  const result = await pool.query(
    `SELECT c.id, c.updated_at, cm.archived, cm.muted,
            (SELECT row_to_json(u) FROM (
              SELECT u2.id, u2.username, u2.avatar_url
              FROM chat_members cm2 JOIN users u2 ON u2.id = cm2.user_id
              WHERE cm2.chat_id = c.id AND cm2.user_id != $1 LIMIT 1
            ) u) as other_user,
            (SELECT row_to_json(m) FROM (
              SELECT m2.id, m2.type, m2.content_enc, m2.deleted, m2.created_at, m2.sender_id
              FROM messages m2 WHERE m2.chat_id = c.id AND NOT m2.deleted
              ORDER BY m2.created_at DESC LIMIT 1
            ) m) as last_message
     FROM chats c
     JOIN chat_members cm ON cm.chat_id = c.id AND cm.user_id = $1
     WHERE cm.archived = $2
     ORDER BY c.updated_at DESC`,
    [req.userId, archived]
  );

  res.json(result.rows.map((row) => ({
    id: row.id,
    updatedAt: row.updated_at,
    archived: row.archived,
    muted: row.muted,
    otherUser: row.other_user,
    lastMessage: row.last_message
      ? {
          id: row.last_message.id,
          type: row.last_message.type,
          preview: row.last_message.deleted
            ? 'Message deleted'
            : row.last_message.type === 'text'
              ? decrypt(row.last_message.content_enc)
              : `[${row.last_message.type}]`,
          createdAt: row.last_message.created_at,
          isMine: row.last_message.sender_id === req.userId,
        }
      : null,
  })));
});

router.post('/:id/archive', authMiddleware, async (req, res) => {
  const { archived } = req.body;
  await pool.query(
    'UPDATE chat_members SET archived = $1 WHERE chat_id = $2 AND user_id = $3',
    [archived !== false, req.params.id, req.userId]
  );
  res.json({ ok: true });
});

router.post('/:id/mute', authMiddleware, async (req, res) => {
  const { muted } = req.body;
  await pool.query(
    'UPDATE chat_members SET muted = $1 WHERE chat_id = $2 AND user_id = $3',
    [!!muted, req.params.id, req.userId]
  );
  res.json({ ok: true });
});

module.exports = router;

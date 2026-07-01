const express = require('express');
const { pool } = require('../db');
const { authMiddleware } = require('../middleware');

const router = express.Router();

async function usersShareDirectChat(userId1, userId2) {
  const result = await pool.query(
    `SELECT cm1.chat_id FROM chat_members cm1
     JOIN chat_members cm2 ON cm1.chat_id = cm2.chat_id
     JOIN chats c ON c.id = cm1.chat_id
     WHERE cm1.user_id = $1 AND cm2.user_id = $2 AND c.type = 'direct' LIMIT 1`,
    [userId1, userId2]
  );
  return result.rows.length > 0;
}

router.get('/pending', authMiddleware, async (req, res) => {
  const result = await pool.query(
    `SELECT i.id, i.created_at, u.id as from_id, u.username, u.avatar_url
     FROM invites i JOIN users u ON u.id = i.from_user_id
     WHERE i.to_user_id = $1 AND i.status = 'pending'
     ORDER BY i.created_at DESC`,
    [req.userId]
  );
  res.json(result.rows.map((r) => ({
    id: r.id,
    fromUser: { id: r.from_id, username: r.username, avatarUrl: r.avatar_url },
    createdAt: r.created_at,
  })));
});

router.post('/send', authMiddleware, async (req, res) => {
  const { toUserId } = req.body;
  if (!toUserId) return res.status(400).json({ error: 'toUserId required' });
  if (toUserId === req.userId) return res.status(400).json({ error: 'Cannot invite yourself' });

  if (await usersShareDirectChat(req.userId, toUserId)) {
    return res.status(400).json({ error: 'User is already in your chat list' });
  }

  const existing = await pool.query(
    `SELECT id, status FROM invites
     WHERE (from_user_id = $1 AND to_user_id = $2) OR (from_user_id = $2 AND to_user_id = $1)`,
    [req.userId, toUserId]
  );
  if (existing.rows.length && existing.rows[0].status === 'pending') {
    return res.status(400).json({ error: 'Invitation already pending' });
  }

  await pool.query(
    `INSERT INTO invites (from_user_id, to_user_id, status)
     VALUES ($1, $2, 'pending')
     ON CONFLICT (from_user_id, to_user_id) DO UPDATE SET status = 'pending', created_at = NOW()`,
    [req.userId, toUserId]
  );

  const io = req.app.get('io');
  io.to(`user:${toUserId}`).emit('invite:received', { fromUserId: req.userId });

  res.status(201).json({ ok: true });
});

router.post('/:id/respond', authMiddleware, async (req, res) => {
  const { accept } = req.body;
  const invite = await pool.query(
    'SELECT * FROM invites WHERE id = $1 AND to_user_id = $2 AND status = $3',
    [req.params.id, req.userId, 'pending']
  );
  if (!invite.rows.length) return res.status(404).json({ error: 'Invite not found' });

  const inv = invite.rows[0];
  if (!accept) {
    await pool.query("UPDATE invites SET status = 'declined' WHERE id = $1", [inv.id]);
    return res.json({ ok: true, status: 'declined' });
  }

  await pool.query("UPDATE invites SET status = 'accepted' WHERE id = $1", [inv.id]);

  const chatResult = await pool.query(
    "INSERT INTO chats (type) VALUES ('direct') RETURNING id"
  );
  const chatId = chatResult.rows[0].id;
  await pool.query(
    'INSERT INTO chat_members (chat_id, user_id) VALUES ($1, $2), ($1, $3)',
    [chatId, inv.from_user_id, inv.to_user_id]
  );

  const io = req.app.get('io');
  io.to(`user:${inv.from_user_id}`).emit('chat:created', { chatId });
  io.to(`user:${inv.to_user_id}`).emit('chat:created', { chatId });

  res.json({ ok: true, status: 'accepted', chatId });
});

module.exports = router;

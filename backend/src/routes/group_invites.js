const express = require('express');
const { pool } = require('../db');
const { authMiddleware } = require('../middleware');

const router = express.Router();

async function isGroupAdmin(userId, chatId) {
  const r = await pool.query(
    `SELECT 1 FROM chat_members cm
     JOIN chats c ON c.id = cm.chat_id
     WHERE cm.chat_id = $1 AND cm.user_id = $2 AND c.type = 'group' AND cm.role = 'admin'`,
    [chatId, userId]
  );
  return r.rows.length > 0;
}

async function isGroupMember(userId, chatId) {
  const r = await pool.query(
    'SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2',
    [chatId, userId]
  );
  return r.rows.length > 0;
}

router.get('/pending', authMiddleware, async (req, res) => {
  const result = await pool.query(
    `SELECT gi.id, gi.created_at, gi.chat_id, c.name as chat_name,
            u.id as from_id, u.username, u.avatar_url
     FROM group_invites gi
     JOIN chats c ON c.id = gi.chat_id
     JOIN users u ON u.id = gi.from_user_id
     WHERE gi.to_user_id = $1 AND gi.status = 'pending'
     ORDER BY gi.created_at DESC`,
    [req.userId]
  );
  res.json(
    result.rows.map((r) => ({
      id: r.id,
      chatId: r.chat_id,
      chatName: r.chat_name,
      fromUser: { id: r.from_id, username: r.username, avatarUrl: r.avatar_url },
      createdAt: r.created_at,
    }))
  );
});

router.post('/send', authMiddleware, async (req, res) => {
  const { chatId, toUserId } = req.body;
  if (!chatId || !toUserId) {
    return res.status(400).json({ error: 'chatId and toUserId required' });
  }
  if (toUserId === req.userId) {
    return res.status(400).json({ error: 'Cannot invite yourself' });
  }
  if (!(await isGroupAdmin(req.userId, chatId))) {
    return res.status(403).json({ error: 'Only group admins can invite' });
  }
  if (await isGroupMember(toUserId, chatId)) {
    return res.status(400).json({ error: 'User is already in this group' });
  }

  const existing = await pool.query(
    `SELECT id FROM group_invites WHERE chat_id = $1 AND to_user_id = $2 AND status = 'pending'`,
    [chatId, toUserId]
  );
  if (existing.rows.length) {
    return res.status(400).json({ error: 'Invitation already pending' });
  }

  await pool.query(
    `INSERT INTO group_invites (chat_id, from_user_id, to_user_id, status)
     VALUES ($1, $2, $3, 'pending')`,
    [chatId, req.userId, toUserId]
  );

  const io = req.app.get('io');
  io.to(`user:${toUserId}`).emit('group-invite:received', { chatId });

  res.status(201).json({ ok: true });
});

router.post('/:id/respond', authMiddleware, async (req, res) => {
  const { accept } = req.body;
  const invite = await pool.query(
    'SELECT * FROM group_invites WHERE id = $1 AND to_user_id = $2 AND status = $3',
    [req.params.id, req.userId, 'pending']
  );
  if (!invite.rows.length) return res.status(404).json({ error: 'Invite not found' });

  const inv = invite.rows[0];
  if (!accept) {
    await pool.query("UPDATE group_invites SET status = 'declined' WHERE id = $1", [inv.id]);
    return res.json({ ok: true, status: 'declined' });
  }

  await pool.query("UPDATE group_invites SET status = 'accepted' WHERE id = $1", [inv.id]);
  await pool.query(
    `INSERT INTO chat_members (chat_id, user_id, role) VALUES ($1, $2, 'member')
     ON CONFLICT DO NOTHING`,
    [inv.chat_id, req.userId]
  );

  const io = req.app.get('io');
  io.to(`chat:${inv.chat_id}`).emit('group:member-joined', { chatId: inv.chat_id, userId: req.userId });
  io.to(`user:${req.userId}`).emit('chat:created', { chatId: inv.chat_id });

  res.json({ ok: true, status: 'accepted', chatId: inv.chat_id });
});

module.exports = router;

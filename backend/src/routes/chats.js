const express = require('express');
const { pool } = require('../db');
const { decrypt } = require('../crypto');
const { authMiddleware } = require('../middleware');

const router = express.Router();

async function canManageGroup(userId, chatId) {
  const r = await pool.query(
    `SELECT 1 FROM chat_members cm
     JOIN chats c ON c.id = cm.chat_id
     WHERE cm.chat_id = $1 AND cm.user_id = $2 AND c.type = 'group'
       AND (cm.role = 'admin' OR c.created_by = cm.user_id)`,
    [chatId, userId]
  );
  return r.rows.length > 0;
}

async function addMembersToGroup(chatId, memberIds, io) {
  const added = [];
  for (const memberId of memberIds) {
    const user = await pool.query('SELECT id FROM users WHERE id = $1', [memberId]);
    if (!user.rows.length) continue;
    const inserted = await pool.query(
      `INSERT INTO chat_members (chat_id, user_id, role) VALUES ($1, $2, 'member')
       ON CONFLICT DO NOTHING RETURNING user_id`,
      [chatId, memberId]
    );
    if (inserted.rows.length) {
      added.push(memberId);
      if (io) {
        io.to(`user:${memberId}`).emit('chat:created', { chatId });
        io.to(`chat:${chatId}`).emit('group:member-joined', { chatId, userId: memberId });
      }
    }
  }
  return added;
}

function mapChatRow(row, userId) {
  const members = row.members || [];
  const otherUser = row.other_user;
  return {
    id: row.id,
    type: row.type || 'direct',
    name: row.name,
    updatedAt: row.updated_at,
    archived: row.archived,
    muted: row.muted,
    members: members.map((m) => ({
      id: m.id,
      username: m.username,
      avatarUrl: m.avatar_url,
      role: m.role,
    })),
    otherUser: otherUser
      ? { id: otherUser.id, username: otherUser.username, avatarUrl: otherUser.avatar_url }
      : null,
    lastMessage: row.last_message
      ? {
          id: row.last_message.id,
          type: row.last_message.type,
          preview: row.last_message.deleted
            ? 'Message deleted'
            : row.last_message.type === 'text'
              ? decrypt(row.last_message.content_enc)
              : row.last_message.type === 'poll'
                ? '📊 Poll'
                : `[${row.last_message.type}]`,
          createdAt: row.last_message.created_at,
          isMine: row.last_message.sender_id === userId,
        }
      : null,
  };
}

router.get('/', authMiddleware, async (req, res) => {
  const archived = req.query.archived === 'true';
  const result = await pool.query(
    `SELECT c.id, c.type, c.name, c.updated_at, cm.archived, cm.muted,
            (SELECT row_to_json(u) FROM (
              SELECT u2.id, u2.username, u2.avatar_url
              FROM chat_members cm2 JOIN users u2 ON u2.id = cm2.user_id
              WHERE cm2.chat_id = c.id AND cm2.user_id != $1 AND c.type = 'direct' LIMIT 1
            ) u) as other_user,
            (SELECT json_agg(json_build_object(
              'id', u3.id, 'username', u3.username, 'avatar_url', u3.avatar_url, 'role', cm3.role
            ) ORDER BY cm3.joined_at)
             FROM chat_members cm3 JOIN users u3 ON u3.id = cm3.user_id
             WHERE cm3.chat_id = c.id) as members,
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

  res.json(result.rows.map((row) => mapChatRow(row, req.userId)));
});

router.post('/groups', authMiddleware, async (req, res) => {
  const { name, memberIds = [] } = req.body;
  if (!name?.trim()) return res.status(400).json({ error: 'Group name required' });

  const uniqueMembers = [...new Set(memberIds.filter((id) => id && id !== req.userId))];

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const chatResult = await client.query(
      `INSERT INTO chats (type, name, created_by) VALUES ('group', $1, $2) RETURNING id`,
      [name.trim(), req.userId]
    );
    const chatId = chatResult.rows[0].id;
    const io = req.app.get('io');

    await client.query(
      `INSERT INTO chat_members (chat_id, user_id, role) VALUES ($1, $2, 'admin')`,
      [chatId, req.userId]
    );

    await client.query('COMMIT');

    const added = await addMembersToGroup(chatId, uniqueMembers, io);
    io.to(`user:${req.userId}`).emit('chat:created', { chatId });

    res.status(201).json({ ok: true, chatId, addedMembers: added });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Create group failed:', err);
    res.status(500).json({ error: 'Failed to create group' });
  } finally {
    client.release();
  }
});

router.post('/:id/members', authMiddleware, async (req, res) => {
  const chatId = req.params.id;
  const { userId, userIds } = req.body;
  const ids = [...new Set((userIds ?? (userId ? [userId] : [])).filter((id) => id && id !== req.userId))];
  if (!ids.length) return res.status(400).json({ error: 'userId or userIds required' });

  if (!(await canManageGroup(req.userId, chatId))) {
    return res.status(403).json({ error: 'Only group admins can add members' });
  }

  const io = req.app.get('io');
  const added = await addMembersToGroup(chatId, ids, io);
  if (!added.length) {
    return res.status(400).json({ error: 'User is already in this group or not found' });
  }

  res.status(201).json({ ok: true, chatId, addedMembers: added });
});

router.get('/:id/members', authMiddleware, async (req, res) => {
  const member = await pool.query(
    'SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2',
    [req.params.id, req.userId]
  );
  if (!member.rows.length) return res.status(403).json({ error: 'Not a member' });

  const result = await pool.query(
    `SELECT u.id, u.username, u.avatar_url, cm.role
     FROM chat_members cm JOIN users u ON u.id = cm.user_id
     WHERE cm.chat_id = $1 ORDER BY cm.joined_at`,
    [req.params.id]
  );
  res.json(
    result.rows.map((r) => ({
      id: r.id,
      username: r.username,
      avatarUrl: r.avatar_url,
      role: r.role,
    }))
  );
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

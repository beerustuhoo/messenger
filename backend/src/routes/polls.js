const express = require('express');
const { pool } = require('../db');
const { encrypt, decrypt } = require('../crypto');
const { authMiddleware } = require('../middleware');

const router = express.Router();

async function getPollPayload(pollId, userId) {
  const poll = await pool.query(
    `SELECT p.*, m.chat_id FROM polls p
     JOIN messages m ON m.id = p.message_id WHERE p.id = $1`,
    [pollId]
  );
  if (!poll.rows.length) return null;
  const p = poll.rows[0];

  const member = await pool.query(
    'SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2',
    [p.chat_id, userId]
  );
  if (!member.rows.length) return null;

  const options = await pool.query(
    'SELECT * FROM poll_options WHERE poll_id = $1 ORDER BY sort_order, id',
    [pollId]
  );
  const votes = await pool.query('SELECT * FROM poll_votes WHERE poll_id = $1', [pollId]);

  const voteCounts = {};
  const votersByOption = {};
  options.rows.forEach((o) => {
    voteCounts[o.id] = 0;
    votersByOption[o.id] = [];
  });
  votes.rows.forEach((v) => {
    voteCounts[v.option_id] = (voteCounts[v.option_id] || 0) + 1;
    if (!p.anonymous) votersByOption[v.option_id].push(v.user_id);
  });

  const myVotes = votes.rows.filter((v) => v.user_id === userId).map((v) => v.option_id);

  let voterNames = {};
  if (!p.anonymous) {
    const userIds = [...new Set(votes.rows.map((v) => v.user_id))];
    if (userIds.length) {
      const users = await pool.query(
        `SELECT id, username FROM users WHERE id = ANY($1::uuid[])`,
        [userIds]
      );
      users.rows.forEach((u) => {
        voterNames[u.id] = u.username;
      });
    }
  }

  return {
    id: p.id,
    messageId: p.message_id,
    chatId: p.chat_id,
    question: decrypt(p.question_enc),
    anonymous: p.anonymous,
    multipleChoice: p.multiple_choice,
    options: options.rows.map((o) => ({
      id: o.id,
      text: decrypt(o.text_enc),
      votes: voteCounts[o.id] || 0,
      voters: p.anonymous
        ? []
        : (votersByOption[o.id] || []).map((uid) => ({
            id: uid,
            username: voterNames[uid] || 'User',
          })),
    })),
    myVotes,
    totalVotes: votes.rows.length,
  };
}

router.get('/:pollId', authMiddleware, async (req, res) => {
  const payload = await getPollPayload(req.params.pollId, req.userId);
  if (!payload) return res.status(404).json({ error: 'Poll not found' });
  res.json(payload);
});

router.post('/:pollId/vote', authMiddleware, async (req, res) => {
  const { optionId } = req.body;
  if (!optionId) return res.status(400).json({ error: 'optionId required' });

  const poll = await pool.query('SELECT * FROM polls WHERE id = $1', [req.params.pollId]);
  if (!poll.rows.length) return res.status(404).json({ error: 'Poll not found' });
  const p = poll.rows[0];

  const option = await pool.query(
    'SELECT 1 FROM poll_options WHERE id = $1 AND poll_id = $2',
    [optionId, p.id]
  );
  if (!option.rows.length) return res.status(400).json({ error: 'Invalid option' });

  if (!p.multiple_choice) {
    await pool.query('DELETE FROM poll_votes WHERE poll_id = $1 AND user_id = $2', [
      p.id,
      req.userId,
    ]);
  }

  await pool.query(
    `INSERT INTO poll_votes (poll_id, option_id, user_id) VALUES ($1, $2, $3)
     ON CONFLICT DO NOTHING`,
    [p.id, optionId, req.userId]
  );

  const payload = await getPollPayload(p.id, req.userId);
  const io = req.app.get('io');
  const msg = await pool.query('SELECT chat_id FROM messages WHERE id = $1', [p.message_id]);
  if (msg.rows.length) {
    io.to(`chat:${msg.rows[0].chat_id}`).emit('poll:updated', payload);
  }
  res.json(payload);
});

router.delete('/:pollId/vote', authMiddleware, async (req, res) => {
  const { optionId } = req.query;
  const poll = await pool.query('SELECT * FROM polls WHERE id = $1', [req.params.pollId]);
  if (!poll.rows.length) return res.status(404).json({ error: 'Poll not found' });

  if (optionId) {
    await pool.query(
      'DELETE FROM poll_votes WHERE poll_id = $1 AND user_id = $2 AND option_id = $3',
      [req.params.pollId, req.userId, optionId]
    );
  } else {
    await pool.query('DELETE FROM poll_votes WHERE poll_id = $1 AND user_id = $2', [
      req.params.pollId,
      req.userId,
    ]);
  }

  const payload = await getPollPayload(req.params.pollId, req.userId);
  const io = req.app.get('io');
  const msg = await pool.query('SELECT chat_id FROM messages WHERE id = $1', [
    poll.rows[0].message_id,
  ]);
  if (msg.rows.length) {
    io.to(`chat:${msg.rows[0].chat_id}`).emit('poll:updated', payload);
  }
  res.json(payload);
});

module.exports = { router, getPollPayload };

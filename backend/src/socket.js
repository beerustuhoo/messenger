const jwt = require('jsonwebtoken');
const { pool } = require('./db');

function setupSocket(io) {
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error('Authentication required'));
    try {
      const payload = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = payload.sub;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', async (socket) => {
    socket.join(`user:${socket.userId}`);

    const chats = await pool.query(
      'SELECT chat_id FROM chat_members WHERE user_id = $1',
      [socket.userId]
    );
    chats.rows.forEach((r) => socket.join(`chat:${r.chat_id}`));

    socket.on('chat:join', (chatId) => {
      socket.join(`chat:${chatId}`);
    });

    socket.on('typing:start', ({ chatId }) => {
      socket.to(`chat:${chatId}`).emit('typing:start', {
        chatId,
        userId: socket.userId,
      });
    });

    socket.on('typing:stop', ({ chatId }) => {
      socket.to(`chat:${chatId}`).emit('typing:stop', {
        chatId,
        userId: socket.userId,
      });
    });

    socket.on('disconnect', () => {});
  });
}

module.exports = { setupSocket };

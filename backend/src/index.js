require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const path = require('path');
const { Server } = require('socket.io');
const { initDb } = require('./db');
const { setupSocket } = require('./socket');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const chatRoutes = require('./routes/chats');
const inviteRoutes = require('./routes/invites');
const messageRoutes = require('./routes/messages');

const PORT = process.env.PORT || 3000;
const uploadDir = process.env.UPLOAD_DIR || './uploads';

async function main() {
  await initDb();

  const app = express();
  const server = http.createServer(app);
  const io = new Server(server, {
    cors: { origin: '*', methods: ['GET', 'POST'] },
  });

  app.set('io', io);
  setupSocket(io);

  app.use(cors());
  app.use(express.json());
  app.use('/uploads', express.static(uploadDir));

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  app.use('/api/auth', authRoutes);
  app.use('/api/users', userRoutes);
  app.use('/api/chats', chatRoutes);
  app.use('/api/invites', inviteRoutes);
  app.use('/api/messages', messageRoutes);

  app.use((err, _req, res, _next) => {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  });

  server.listen(PORT, '0.0.0.0', () => {
    console.log(`Mobile Messenger API listening on port ${PORT}`);
    console.log(`Mail viewer: http://localhost:8025 (when using docker-compose)`);
  });
}

main().catch((err) => {
  console.error('Failed to start:', err);
  process.exit(1);
});

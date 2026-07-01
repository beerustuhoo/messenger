require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { Server } = require('socket.io');
const { initDb, pool } = require('./db');
const { setupSocket } = require('./socket');
const { isSmtpConfigured } = require('./email');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const chatRoutes = require('./routes/chats');
const inviteRoutes = require('./routes/invites');
const groupInviteRoutes = require('./routes/group_invites');
const messageRoutes = require('./routes/messages');
const { router: pollRoutes } = require('./routes/polls');

const PORT = process.env.PORT || 3000;
const uploadDir = process.env.UPLOAD_DIR || './uploads';

function validateEnv() {
  const missing = [];
  if (!process.env.DATABASE_URL) missing.push('DATABASE_URL');
  if (!process.env.JWT_SECRET) missing.push('JWT_SECRET');
  const enc = process.env.ENCRYPTION_KEY;
  if (!enc || enc.length !== 64 || !/^[0-9a-fA-F]+$/.test(enc)) {
    missing.push('ENCRYPTION_KEY (64 hex characters, run: openssl rand -hex 32)');
  }
  if (missing.length) {
    console.error('FATAL: Missing or invalid environment variables:');
    missing.forEach((m) => console.error(`  - ${m}`));
    throw new Error(`Server misconfigured: ${missing.join(', ')}`);
  }
}

async function main() {
  validateEnv();
  await initDb();

  const app = express();
  app.set('trust proxy', 1);
  const server = http.createServer(app);
  const io = new Server(server, {
    cors: { origin: '*', methods: ['GET', 'POST'] },
  });

  app.set('io', io);
  setupSocket(io);

  app.use(cors());
  app.use(express.json());
  app.use('/uploads', express.static(uploadDir));

  const publicDir = path.join(__dirname, '../public');

  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  app.get('/health/ready', async (_req, res) => {
    try {
      await pool.query('SELECT 1');
      res.json({
        status: 'ok',
        database: true,
        encryption: Boolean(process.env.ENCRYPTION_KEY?.length === 64),
        jwt: Boolean(process.env.JWT_SECRET),
        smtp: isSmtpConfigured(),
      });
    } catch (err) {
      console.error('Readiness check failed:', err);
      res.status(503).json({ status: 'error', database: false });
    }
  });

  app.get('/', (req, res, next) => {
    const indexPath = path.join(publicDir, 'index.html');
    if (fs.existsSync(indexPath)) return next();
    res.status(200).json({
      status: 'ok',
      message: 'API is running. Web UI not bundled — run scripts/prepare-render-deploy.ps1 and redeploy.',
      health: '/health',
    });
  });

  app.use('/api/auth', authRoutes);
  app.use('/api/users', userRoutes);
  app.use('/api/chats', chatRoutes);
  app.use('/api/invites', inviteRoutes);
  app.use('/api/group-invites', groupInviteRoutes);
  app.use('/api/messages', messageRoutes);
  app.use('/api/polls', pollRoutes);

  if (fs.existsSync(publicDir)) {
    app.use(express.static(publicDir));
    app.get(/^(?!\/api|\/socket\.io|\/uploads|\/health).*/, (req, res) => {
      res.sendFile(path.join(publicDir, 'index.html'));
    });
  }

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

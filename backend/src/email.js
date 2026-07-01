const nodemailer = require('nodemailer');

let transporter;

function isSmtpConfigured() {
  const host = process.env.SMTP_HOST;
  const from = process.env.SMTP_FROM;
  const pass = process.env.SMTP_PASS;
  if (!host || !from) return false;
  if (host === 'localhost' || host === '127.0.0.1') {
    return process.env.NODE_ENV !== 'production';
  }
  return Boolean(pass);
}

function getTransporter() {
  if (!transporter) {
    const port = parseInt(process.env.SMTP_PORT || '1025', 10);
    const secure = process.env.SMTP_SECURE === 'true' || port === 465;
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'localhost',
      port,
      secure,
      auth: user && pass ? { user, pass } : undefined,
      ...(secure ? {} : { requireTLS: process.env.SMTP_REQUIRE_TLS === 'true' }),
      ignoreTLS: process.env.SMTP_IGNORE_TLS === 'true',
    });
  }
  return transporter;
}

async function sendMail({ to, subject, text, html }) {
  if (!isSmtpConfigured()) {
    console.warn(`SMTP not configured — email to ${to} was not sent. Set SMTP_* env vars on Render.`);
    return { ok: false, error: 'SMTP not configured' };
  }
  try {
    const info = await getTransporter().sendMail({
      from: process.env.SMTP_FROM || 'noreply@messenger.local',
      to,
      subject,
      text,
      html,
    });
    console.log(`Email sent to ${to} (${info.messageId || 'ok'})`);
    return { ok: true };
  } catch (err) {
    console.error('Email send failed:', err.message);
    return { ok: false, error: err.message };
  }
}

async function sendVerificationEmail(email, token) {
  const base = (process.env.APP_URL || 'http://localhost:3000').replace(/\/$/, '');
  const url = `${base}/api/auth/verify?token=${encodeURIComponent(token)}`;
  return sendMail({
    to: email,
    subject: 'Verify your Mobile Messenger account',
    text: [
      'Verify your Mobile Messenger account',
      '',
      'Open this link to verify:',
      url,
      '',
      'Or copy this code into the app (Verify now / Enter token):',
      token,
    ].join('\n'),
    html: [
      '<p>Verify your Mobile Messenger account.</p>',
      `<p><a href="${url}" style="display:inline-block;padding:12px 20px;background:#2563eb;color:#fff;text-decoration:none;border-radius:8px;font-weight:600;">Verify my email</a></p>`,
      '<p>Or copy this code into the app:</p>',
      `<p style="font-family:monospace;font-size:14px;word-break:break-all;padding:12px;background:#f4f4f4;border-radius:8px;">${token}</p>`,
      `<p style="color:#666;font-size:12px;">Link not working? Paste into your browser:<br><a href="${url}">${url}</a></p>`,
    ].join(''),
  });
}

async function sendPasswordResetEmail(email, token) {
  const base = (process.env.APP_URL || 'http://localhost:3000').replace(/\/$/, '');
  const url = `${base}/api/auth/reset-password?token=${encodeURIComponent(token)}`;
  return sendMail({
    to: email,
    subject: 'Reset your Mobile Messenger password',
    text: ['Reset your password.', '', 'Open this link:', url, '', 'Token:', token].join('\n'),
    html: [
      '<p>Reset your Mobile Messenger password.</p>',
      `<p><a href="${url}">Reset password</a></p>`,
      '<p><strong>Token:</strong></p>',
      `<p style="font-family:monospace;font-size:14px;word-break:break-all;padding:12px;background:#f4f4f4;border-radius:8px;">${token}</p>`,
    ].join(''),
  });
}

module.exports = { sendVerificationEmail, sendPasswordResetEmail, sendMail, isSmtpConfigured };

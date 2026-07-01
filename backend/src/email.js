const nodemailer = require('nodemailer');

let transporter;

function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'localhost',
      port: parseInt(process.env.SMTP_PORT || '1025', 10),
      secure: false,
      ignoreTLS: true,
    });
  }
  return transporter;
}

async function sendMail({ to, subject, text, html }) {
  try {
    await getTransporter().sendMail({
      from: process.env.SMTP_FROM || 'noreply@messenger.local',
      to,
      subject,
      text,
      html,
    });
    return true;
  } catch (err) {
    console.error('Email send failed:', err.message);
    return false;
  }
}

async function sendVerificationEmail(email, token) {
  const url = `${process.env.APP_URL}/api/auth/verify?token=${token}`;
  return sendMail({
    to: email,
    subject: 'Verify your Mobile Messenger account',
    text: [
      'Verify your Mobile Messenger account',
      '',
      'Copy this token into the app (Enter token on the home screen):',
      token,
      '',
      `Or open this link on your PC: ${url}`,
    ].join('\n'),
    html: [
      '<p>Verify your Mobile Messenger account.</p>',
      '<p><strong>Copy this token into the app</strong> (tap <em>Enter token</em> on the home screen):</p>',
      `<p style="font-family:monospace;font-size:14px;word-break:break-all;padding:12px;background:#f4f4f4;border-radius:8px;">${token}</p>`,
      `<p>Or open this link on the machine running Docker:</p><p><a href="${url}">${url}</a></p>`,
    ].join(''),
  });
}

async function sendPasswordResetEmail(email, token) {
  const url = `${process.env.APP_URL}/api/auth/reset-password?token=${token}`;
  return sendMail({
    to: email,
    subject: 'Reset your Mobile Messenger password',
    text: ['Reset your password.', '', 'Token:', token, '', `Link: ${url}`].join('\n'),
    html: [
      '<p>Reset your Mobile Messenger password.</p>',
      '<p><strong>Token:</strong></p>',
      `<p style="font-family:monospace;font-size:14px;word-break:break-all;padding:12px;background:#f4f4f4;border-radius:8px;">${token}</p>`,
      `<p><a href="${url}">${url}</a></p>`,
    ].join(''),
  });
}

module.exports = { sendVerificationEmail, sendPasswordResetEmail, sendMail };

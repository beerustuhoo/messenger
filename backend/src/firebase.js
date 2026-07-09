const admin = require('firebase-admin');

let enabled = false;

function initFirebase() {
  const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!json?.trim()) return false;
  try {
    const serviceAccount = JSON.parse(json);
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
    }
    enabled = true;
    console.log('Firebase Admin initialized');
    return true;
  } catch (err) {
    console.error('Firebase Admin init failed:', err.message);
    return false;
  }
}

function isFirebaseEnabled() {
  return enabled;
}

async function verifyFirebaseToken(token) {
  const decoded = await admin.auth().verifyIdToken(token);
  return {
    uid: decoded.uid,
    email: decoded.email || null,
    emailVerified: decoded.email_verified === true,
  };
}

module.exports = { initFirebase, isFirebaseEnabled, verifyFirebaseToken };

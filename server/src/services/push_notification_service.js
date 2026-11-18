'use strict';

// Ensure server/.env is loaded safely into process.env if present
require('../config/env');

/**
 * Push Notification Service — Firebase Admin SDK integration.
 *
 * Sends FCM push notifications to Kith users for payment & trip activity events
 * so they reach devices even when app is backgrounded or terminated.
 *
 * Target Firebase Project (configured in Android): kith-7c88f
 *
 * Required environment variables:
 *   FIREBASE_PROJECT_ID   — Firebase project ID (defaults to "kith-7c88f")
 *   FIREBASE_CLIENT_EMAIL — Firebase service account client email
 *   FIREBASE_PRIVATE_KEY  — Firebase service account private key (with \n or real newlines)
 *   (or FIREBASE_SERVICE_ACCOUNT — Full JSON string or file path)
 *
 * If credentials are not configured or contain placeholder mock strings,
 * FCM push is safely bypassed without throwing unhandled exceptions.
 */

let admin;
let isInitialized = false;

/**
 * Validates whether the given string represents placeholder credentials rather than genuine keys.
 * A genuine Google 2048-bit RSA private key is typically > 1600 characters in PEM format.
 */
function isPlaceholderKey(key) {
  if (!key || typeof key !== 'string') return true;
  const trimmed = key.trim();
  if (trimmed.length < 500) return true;
  if (trimmed.includes('YOUR_KEY_HERE') || trimmed.includes('...') || trimmed.includes('example')) return true;
  return false;
}

function isPlaceholderEmail(email) {
  if (!email || typeof email !== 'string') return true;
  const trimmed = email.trim();
  if (trimmed.includes('XXXXX') || trimmed.includes('example.com') || trimmed.length < 10) return true;
  return false;
}

function initFirebaseAdmin() {
  if (isInitialized) return;
  try {
    admin = require('firebase-admin');
    const fs = require('fs');

    const projectId = process.env.FIREBASE_PROJECT_ID || 'kith-7c88f';
    let credential = null;

    // 1. Explicit Service Account JSON string or file path
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      const sa = process.env.FIREBASE_SERVICE_ACCOUNT.trim();
      if (sa.includes('YOUR_KEY_HERE') || sa.includes('...')) {
        console.warn(`[PushNotification] Placeholder FIREBASE_SERVICE_ACCOUNT detected for project: ${projectId}. Push delivery disabled.`);
        return;
      }
      if (sa.startsWith('{')) {
        credential = admin.credential.cert(JSON.parse(sa));
      } else if (fs.existsSync(sa)) {
        credential = admin.credential.cert(require(sa));
      }
    }

    // 2. Individual Environment Variables
    if (!credential) {
      const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
      const rawPrivateKey = process.env.FIREBASE_PRIVATE_KEY;

      if (clientEmail || rawPrivateKey) {
        if (isPlaceholderEmail(clientEmail) || isPlaceholderKey(rawPrivateKey)) {
          console.warn(`[PushNotification] Placeholder credentials detected for project: ${projectId}. Push delivery disabled until real credentials are provided.`);
          return;
        }

        const privateKey = rawPrivateKey.replace(/\\n/g, '\n');
        credential = admin.credential.cert({
          projectId,
          clientEmail,
          privateKey,
        });
      }
    }

    // 3. GOOGLE_APPLICATION_CREDENTIALS or Application Default Credentials
    if (!credential && (process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.GCLOUD_PROJECT)) {
      try {
        credential = admin.credential.applicationDefault();
      } catch (_) {}
    }

    if (!credential) {
      console.warn(`[PushNotification] Firebase Admin credentials not set for project: ${projectId}. Set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY (or FIREBASE_SERVICE_ACCOUNT) to enable FCM push.`);
      return;
    }

    if (!admin.apps.length) {
      admin.initializeApp({ credential });
    }

    isInitialized = true;
    console.info(`[PushNotification] Firebase Admin SDK initialized successfully for project: ${projectId}`);
  } catch (err) {
    // Sanitize error message to ensure no secrets or tokens are ever exposed
    const safeError = err.message ? err.message.replace(/([A-Za-z0-9+/=]{40,})/g, '[REDACTED]') : 'Unknown initialization error';
    console.error('[PushNotification] Firebase Admin SDK init notice:', safeError);
  }
}

// Initialize on module load
initFirebaseAdmin();

/**
 * Returns safe diagnostic status without revealing credentials or private keys.
 */
function getStatus() {
  const projectId = process.env.FIREBASE_PROJECT_ID || 'kith-7c88f';
  const email = process.env.FIREBASE_CLIENT_EMAIL;
  const key = process.env.FIREBASE_PRIVATE_KEY;
  return {
    isInitialized,
    initialized: isInitialized,
    mode: isInitialized ? 'live' : 'mock',
    targetProjectId: projectId,
    hasClientEmail: Boolean(email && !isPlaceholderEmail(email)),
    hasPrivateKey: Boolean(key && !isPlaceholderKey(key)),
    isPlaceholderConfigured: Boolean((key && isPlaceholderKey(key)) || (email && isPlaceholderEmail(email))),
  };
}

/**
 * Sends an FCM push notification to a specific user's registered devices.
 *
 * @param {Object} db - Database instance
 * @param {string} userId - Kith user ID to send notification to
 * @param {Object} payload - { title, body, data }
 */
async function sendToUser(db, userId, payload) {
  if (!isInitialized || !admin) {
    console.debug('[PushNotification] FCM not configured — skipping push for user', userId);
    return;
  }

  try {
    // Fetch all active FCM tokens registered for this user
    const tokenRecords = db.find('user_fcm_tokens', (r) => r.userId === userId && !r.deleted);
    console.info(`[PushNotification] DEVICE RESOLUTION: recipient_user_id=${userId}, active_devices=${tokenRecords.length}`);

    if (!tokenRecords.length) {
      console.debug('[PushNotification] No active FCM tokens for user', userId);
      return;
    }

    const tokens = tokenRecords.map((r) => r.token).filter(Boolean);
    if (!tokens.length) return;

    const { title, body, data = {} } = payload;

    const message = {
      notification: {
        title,
        body,
      },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      android: {
        notification: {
          channelId: data.channelId || (
            (data.type?.includes('settlement') || data.type?.includes('payment')) ? 'kith_payments' :
            data.type?.includes('ipo') ? 'kith_ipo' :
            data.type?.includes('expense') ? 'kith_expenses' :
            (data.type?.includes('trip') || data.type?.includes('member')) ? 'kith_trips' :
            'kith_activity'
          ),
          sound: 'kith_notification',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
          visibility: 'public',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
        priority: 'high',
        ttl: 86400 * 1000, // 24 hours delivery window
      },
      apns: {
        payload: {
          aps: {
            sound: 'kith_notification.wav',
            badge: 1,
            contentAvailable: true,
          },
        },
      },
      tokens,
    };

    console.info(`[PushNotification] PUSH DISPATCH: recipient_user_id=${userId}, device_count=${tokens.length}, type=${data.type || 'unknown'}`);
    const response = await admin.messaging().sendEachForMulticast(message);
    console.info(`[PushNotification] PUSH RESULT: Delivered to ${response.successCount}/${tokens.length} devices for user ${userId}`);

    // Clean up invalid/expired tokens
    const invalidTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const code = resp.error?.code;
        if (
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/registration-token-not-registered'
        ) {
          invalidTokens.push(tokens[idx]);
        }
      }
    });

    if (invalidTokens.length > 0) {
      for (const token of invalidTokens) {
        const record = db.findOne('user_fcm_tokens', (r) => r.token === token);
        if (record) {
          db.update('user_fcm_tokens', record.id, { deleted: true, deletedAt: new Date().toISOString() });
        }
      }
      console.info(`[PushNotification] Cleaned up ${invalidTokens.length} expired tokens`);
    }
  } catch (err) {
    console.error('[PushNotification] sendToUser error:', err.message);
    // Non-fatal: WebSocket delivery still works for foreground users
  }
}

module.exports = {
  sendToUser,
  initFirebaseAdmin,
  getStatus,
};

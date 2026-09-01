'use strict';

/**
 * Push Notification Service — Firebase Admin SDK integration.
 *
 * Sends FCM push notifications to Kith users for payment lifecycle events
 * so they reach devices even when app is backgrounded or terminated.
 *
 * Environment variables required:
 *   FIREBASE_PROJECT_ID   — Firebase project ID (e.g. "amazing-pipe-484506-t8")
 *   FIREBASE_CLIENT_EMAIL — Firebase service account client email
 *   FIREBASE_PRIVATE_KEY  — Firebase service account private key (replace \n with actual newlines)
 *
 * These can be set in server/.env. If not set, push is silently skipped
 * (WebSocket delivery still works for foreground users).
 */

let admin;
let isInitialized = false;

function initFirebaseAdmin() {
  if (isInitialized) return;
  try {
    admin = require('firebase-admin');
    const fs = require('fs');

    let credential = null;

    // 1. Explicit Service Account JSON string or file path
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      const sa = process.env.FIREBASE_SERVICE_ACCOUNT.trim();
      if (sa.startsWith('{')) {
        credential = admin.credential.cert(JSON.parse(sa));
      } else if (fs.existsSync(sa)) {
        credential = admin.credential.cert(require(sa));
      }
    }

    // 2. Individual Environment Variables
    if (!credential) {
      const projectId = process.env.FIREBASE_PROJECT_ID || 'kith-7c88f';
      const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
      const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

      if (clientEmail && privateKey) {
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
      console.warn('[PushNotification] Firebase Admin credentials not set. Set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY (or FIREBASE_SERVICE_ACCOUNT) to enable FCM push.');
      return;
    }

    if (!admin.apps.length) {
      admin.initializeApp({ credential });
    }

    isInitialized = true;
    console.info('[PushNotification] Firebase Admin SDK initialized successfully');
  } catch (err) {
    console.error('[PushNotification] Firebase Admin SDK init notice:', err.message);
  }
}

// Initialize on module load
initFirebaseAdmin();

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

module.exports = { sendToUser };

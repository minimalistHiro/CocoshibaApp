const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const BATCH_SIZE = 500;

exports.onNotificationCreated = functions
  .region('us-central1')
  .firestore.document('notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data) {
      return null;
    }

    const notificationId = context.params.notificationId;
    const title = (data.title || '').toString().trim() || 'ココシバからのお知らせ';
    const body = (data.body || '').toString().trim();
    if (!body) {
      functions.logger.info('Announcement body is empty. Skip push.', {
        notificationId,
      });
      return null;
    }

    const tokenData = await collectAllUserTokens();
    if (!tokenData) {
      functions.logger.info('No registered FCM tokens found for announcement.', {
        notificationId,
      });
      return null;
    }

    const notificationPayload = {
      title,
      body,
    };
    if (data.imageUrl) {
      notificationPayload.imageUrl = data.imageUrl;
    }

    const dataPayload = {
      notificationId,
      category: (data.category || 'general').toString(),
      title,
      body,
    };
    if (data.imageUrl) {
      dataPayload.imageUrl = data.imageUrl;
    }

    await sendAnnouncementBatches({
      tokens: tokenData.tokens,
      tokenOwners: tokenData.tokenOwners,
      notification: notificationPayload,
      data: dataPayload,
      notificationId,
    });

    return null;
  });

exports.onPersonalNotificationCreated = functions
  .region('us-central1')
  .firestore.document('users/{userId}/personalNotifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data) return null;

    const { userId, notificationId } = context.params;
    const title = (data.title || '').toString().trim() || 'ココシバからのお知らせ';
    const body = (data.body || '').toString().trim();
    if (!body) return null;

    const userDoc = await db.collection('users').doc(userId).get();
    const fcmTokens = (userDoc.data()?.fcmTokens || []).filter(
      (token) => typeof token === 'string' && token.length > 0
    );
    if (fcmTokens.length === 0) return null;

    await messaging.sendEachForMulticast({
      tokens: fcmTokens,
      notification: { title, body },
      data: {
        notificationId,
        category: (data.category || 'general').toString(),
        title,
        body,
      },
      android: { priority: 'high', notification: { sound: 'default' } },
      apns: {
        headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
        payload: { aps: { alert: { title, body }, sound: 'default' } },
      },
    });
    return null;
  });

exports.onOwnerNotificationCreated = functions
  .region('us-central1')
  .firestore.document('owner_notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data) return null;

    const notificationId = context.params.notificationId;
    const title = (data.title || '').toString().trim() || 'ココシバからのお知らせ';
    const body = (data.body || '').toString().trim();
    if (!body) return null;

    const ownerTokens = await collectOwnerTokens();
    if (!ownerTokens || ownerTokens.tokens.length === 0) return null;

    await sendAnnouncementBatches({
      tokens: ownerTokens.tokens,
      tokenOwners: ownerTokens.tokenOwners,
      notification: { title, body },
      data: {
        notificationId,
        category: (data.category || 'general').toString(),
        title,
        body,
      },
      notificationId,
    });
    return null;
  });

async function collectAllUserTokens() {
  const usersSnapshot = await db.collection('users').get();
  if (usersSnapshot.empty) {
    return null;
  }

  const tokens = [];
  const tokenOwners = new Map();

  usersSnapshot.forEach((doc) => {
    const userData = doc.data() || {};
    const fcmTokens = userData.fcmTokens;
    if (!Array.isArray(fcmTokens)) {
      return;
    }

    fcmTokens.forEach((token) => {
      if (typeof token !== 'string' || token.length === 0) {
        return;
      }
      if (!tokenOwners.has(token)) {
        tokenOwners.set(token, new Set());
        tokens.push(token);
      }
      tokenOwners.get(token).add(doc.id);
    });
  });

  if (tokens.length === 0) {
    return null;
  }

  return { tokens, tokenOwners };
}

async function collectOwnerTokens() {
  const tokens = [];
  const tokenOwners = new Map();

  const ownerSnapshots = await Promise.all([
    db.collection('users').where('isOwner', '==', true).get(),
    db.collection('users').where('isSubOwner', '==', true).get(),
  ]);

  ownerSnapshots.forEach((snapshot) => {
    snapshot.forEach((doc) => {
      const userData = doc.data() || {};
      const fcmTokens = userData.fcmTokens;
      if (!Array.isArray(fcmTokens)) return;

      fcmTokens.forEach((token) => {
        if (typeof token !== 'string' || token.length === 0) return;
        if (!tokenOwners.has(token)) {
          tokenOwners.set(token, new Set());
          tokens.push(token);
        }
        tokenOwners.get(token).add(doc.id);
      });
    });
  });

  if (tokens.length === 0) return null;
  return { tokens, tokenOwners };
}

async function sendAnnouncementBatches({
  tokens,
  tokenOwners,
  notification,
  data,
  notificationId,
}) {
  const invalidTokens = new Set();

  for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
    const chunk = tokens.slice(i, i + BATCH_SIZE);
    try {
      const response = await messaging.sendEachForMulticast({
        tokens: chunk,
        notification,
        data,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
          },
        },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          payload: {
            aps: {
              alert: notification,
              sound: 'default',
            },
          },
        },
      });

      response.responses.forEach((res, idx) => {
        if (!res.success) {
          const code = res.error?.code || '';
          if (
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
          ) {
            invalidTokens.add(chunk[idx]);
          } else {
            functions.logger.error('Announcement push failed', {
              code,
              error: res.error,
              token: chunk[idx],
              notificationId,
            });
          }
        }
      });
    } catch (error) {
      functions.logger.error('Failed to send announcement batch', {
        error,
        notificationId,
      });
    }
  }

  if (invalidTokens.size > 0) {
    await removeInvalidTokens(invalidTokens, tokenOwners);
  }
}

async function removeInvalidTokens(invalidTokens, tokenOwners) {
  const updates = [];
  invalidTokens.forEach((token) => {
    const owners = tokenOwners.get(token);
    if (!owners) {
      return;
    }
    owners.forEach((userId) => {
      updates.push(
        db
          .collection('users')
          .doc(userId)
          .update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
            fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          })
      );
    });
  });

  if (updates.length === 0) {
    return;
  }

  try {
    await Promise.all(updates);
  } catch (error) {
    functions.logger.error('Failed to prune invalid FCM tokens', {
      error,
    });
  }
}

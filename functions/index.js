const crypto = require('crypto');
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();
const mailConfig = functions.config().mail || {};

const EMAIL_VERIFICATION_COLLECTION = 'emailVerifications';
const EMAIL_CODE_EXPIRATION_MINUTES = 10;
const EMAIL_CODE_MAX_ATTEMPTS = 5;

const BATCH_SIZE = 500;

const mailTransport =
  mailConfig.host && mailConfig.user && mailConfig.pass
    ? nodemailer.createTransport({
        host: mailConfig.host,
        port: Number(mailConfig.port || 587),
        secure: Number(mailConfig.port || 587) === 465,
        auth: {
          user: mailConfig.user,
          pass: mailConfig.pass,
        },
      })
    : null;

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

exports.requestEmailVerification = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'You must be signed in to request verification.'
      );
    }

    if (!mailTransport) {
      functions.logger.error(
        'Mail transport is not configured. Set functions.config().mail.'
      );
      throw new functions.https.HttpsError(
        'failed-precondition',
        'メール送信設定が行われていません'
      );
    }

    const email = (data?.email || '').toString().trim();
    if (!email) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'メールアドレスが指定されていません'
      );
    }

    const uid = context.auth.uid;
    const code = generateSixDigitCode();
    const codeHash = hashCode(code);
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + EMAIL_CODE_EXPIRATION_MINUTES * 60 * 1000)
    );

    await db.collection(EMAIL_VERIFICATION_COLLECTION).doc(uid).set(
      {
        email,
        codeHash,
        status: 'pending',
        attempts: 0,
        expiresAt,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await sendVerificationEmail(email, code);
    functions.logger.info('Verification email sent', { uid, email });

    return { expiresAt: expiresAt.toMillis() };
  });

exports.verifyEmailCode = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'You must be signed in to verify the code.'
      );
    }

    const code = (data?.code || '').toString().trim();
    if (!/^[0-9]{6}$/.test(code)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        '6桁の認証コードを入力してください'
      );
    }

    const uid = context.auth.uid;
    const docRef = db.collection(EMAIL_VERIFICATION_COLLECTION).doc(uid);
    const snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        '認証コードが発行されていません'
      );
    }

    const dataMap = snapshot.data() || {};
    if (dataMap.status === 'verified') {
      return { verified: true };
    }

    const expiresAt = dataMap.expiresAt;
    if (expiresAt?.toMillis && expiresAt.toMillis() < Date.now()) {
      throw new functions.https.HttpsError(
        'deadline-exceeded',
        '認証コードの有効期限が切れています'
      );
    }

    const attempts =
      typeof dataMap.attempts === 'number' ? dataMap.attempts : 0;
    if (attempts >= EMAIL_CODE_MAX_ATTEMPTS) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        '認証コードの入力回数が上限に達しました'
      );
    }

    const expectedHash = dataMap.codeHash;
    if (expectedHash !== hashCode(code)) {
      await docRef.update({
        attempts: attempts + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw new functions.https.HttpsError(
        'permission-denied',
        '認証コードが間違っています'
      );
    }

    await Promise.all([
      docRef.update({
        status: 'verified',
        attempts: attempts + 1,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
      db
        .collection('users')
        .doc(uid)
        .set(
          {
            emailVerified: true,
            emailVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        ),
    ]);

    return { verified: true };
  });

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

function generateSixDigitCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function hashCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

async function sendVerificationEmail(email, code) {
  if (!mailTransport) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'メール送信設定が行われていません'
    );
  }

  const from = mailConfig.from || mailConfig.user;
  const mailOptions = {
    from,
    to: email,
    subject: 'ココシバ アカウントのメール認証コード',
    text: `以下の6桁のコードをアプリに入力してください。\n\n${code}\n\n有効期限：${EMAIL_CODE_EXPIRATION_MINUTES}分\n\nこのメールに心当たりがない場合は破棄してください。`,
  };

  await mailTransport.sendMail(mailOptions);
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

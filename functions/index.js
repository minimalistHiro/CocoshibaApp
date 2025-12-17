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

function formatDateYmd(value) {
  if (!value) return '';
  const date =
    typeof value.toDate === 'function'
      ? value.toDate()
      : value instanceof Date
        ? value
        : new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}/${month}/${day}`;
}

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

exports.onFeedbackCreated = functions
  .region('us-central1')
  .firestore.document('feedbacks/{feedbackId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data) return null;

    const feedbackId = context.params.feedbackId;
    const category = (data.category || '').toString().trim();
    const title = (data.title || '').toString().trim();
    const detail = (data.detail || '').toString().trim();
    const contactEmail = (data.contactEmail || '').toString().trim();
    const includeDeviceInfo = data.includeDeviceInfo === true;
    const userId = (data.userId || '').toString().trim() || null;
    const userName = (data.userName || '').toString().trim() || null;
    const userEmail = (data.userEmail || '').toString().trim() || null;

    const reporterLabel = userName || userEmail || '不明なユーザー';
    const detailSnippet = detail.length > 120 ? `${detail.slice(0, 120)}…` : detail;
    const body = `
${reporterLabel} からフィードバックが届きました
カテゴリ: ${category || '未設定'}
概要: ${title || '未設定'}
内容: ${detailSnippet || '未設定'}
`.trim();

    await db.collection('owner_notifications').add({
      title: 'フィードバック受信',
      body,
      category: 'フィードバック',
      feedbackId,
      contactEmail: contactEmail || null,
      includeDeviceInfo,
      detail: detail || null,
      userId,
      userName,
      userEmail,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return null;
  });

exports.onHomePageReservationCreated = functions
  .region('us-central1')
  .firestore
  .document('home_pages/{contentId}/reservations/{reservationId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data) return null;

    const { contentId, reservationId } = context.params;
    const userId = (data.userId || '').toString().trim() || null;
    const userName = (data.userName || '').toString().trim() || null;
    const userEmail = (data.userEmail || '').toString().trim() || null;
    const contentTitle = (data.contentTitle || '').toString().trim();
    const quantity = typeof data.quantity === 'number' ? data.quantity : null;
    const pickupDateLabel = formatDateYmd(data.pickupDate);
    const createdAtLabel = formatDateYmd(data.createdAt);

    const reserverLabel = userName || userEmail || userId || '不明なユーザー';
    const body = `
${reserverLabel} が ${contentTitle || '未設定'} の予約をしました
受け取り日: ${pickupDateLabel || '未設定'}
予約完了日: ${createdAtLabel || '未設定'}
個数: ${quantity ?? '未設定'}
`.trim();

    await db.collection('owner_notifications').add({
      title: '予約通知',
      body,
      category: '予約',
      contentId,
      contentTitle: contentTitle || null,
      reservationId,
      userId,
      userName,
      userEmail,
      pickupDate: data.pickupDate || null,
      quantity,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    const forceResend = Boolean(data?.forceResend);
    const authEmail = (context.auth.token?.email || '').toString().trim();

    if (!email) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'メールアドレスが指定されていません'
      );
    }
    if (authEmail && email.toLowerCase() !== authEmail.toLowerCase()) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'ログイン中のメールアドレスと一致しません'
      );
    }

    const uid = context.auth.uid;
    const docRef = db.collection(EMAIL_VERIFICATION_COLLECTION).doc(uid);
    const snapshot = await docRef.get();

    const existing = snapshot.exists ? snapshot.data() || {} : {};
    const existingStatus = (existing.status || '').toString();
    const existingExpiresAt = existing.expiresAt;
    const existingExpiresMs =
      existingExpiresAt?.toMillis && typeof existingExpiresAt.toMillis === 'function'
        ? existingExpiresAt.toMillis()
        : null;

    if (existingStatus === 'verified') {
      return { verified: true };
    }

    if (!forceResend && typeof existingExpiresMs === 'number' && existingExpiresMs > Date.now()) {
      return { expiresAt: existingExpiresMs, reused: true };
    }

    const code = generateSixDigitCode();
    const codeHash = hashCode(code);
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + EMAIL_CODE_EXPIRATION_MINUTES * 60 * 1000)
    );

    await docRef.set(
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

    return { expiresAt: expiresAt.toMillis(), reused: false };
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

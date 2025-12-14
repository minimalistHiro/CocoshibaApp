import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase may already be initialized when the handler is invoked.
  }

  // Handle data-only/background messages and surface them as local notifications.
  final notification = message.notification;
  final title =
      notification?.title ?? message.data['title'] ?? 'ココシバからのお知らせ';
  final body = notification?.body ?? message.data['body'];
  if (body == null || body.isEmpty) {
    return;
  }
  final notificationId = message.data['notificationId'] ??
      message.messageId ??
      DateTime.now().millisecondsSinceEpoch.toString();

  final localNotificationService = LocalNotificationService();
  await localNotificationService.showAnnouncementNotification(
    notificationId: notificationId,
    title: title,
    body: body,
  );
}

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    LocalNotificationService? localNotificationService,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _localNotificationService =
            localNotificationService ?? LocalNotificationService();

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final LocalNotificationService _localNotificationService;

  bool _initialized = false;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  Future<void> initializeAndSyncToken() async {
    await _initialize();
    await _syncCurrentToken();
  }

  Future<void> _initialize() async {
    if (_initialized) return;

    await _localNotificationService.initialize();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    _tokenSubscription ??= _messaging.onTokenRefresh.listen(_saveToken);
    _initialized = true;
  }

  Future<void> _syncCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        return;
      }
      await _saveToken(token);
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch FCM token: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null || token.isEmpty) {
      return;
    }
    try {
      await _firestore.collection('users').doc(user.uid).set(
        {
          'fcmTokens': FieldValue.arrayUnion([token]),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to sync FCM token: $error');
      debugPrint('$stackTrace');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title'] ?? 'ココシバからのお知らせ';
    final body = notification?.body ?? message.data['body'];
    if (body == null || body.isEmpty) {
      return;
    }
    final notificationId = message.data['notificationId'] ??
        message.messageId ??
        DateTime.now().millisecondsSinceEpoch.toString();

    unawaited(
      _localNotificationService.showAnnouncementNotification(
        notificationId: notificationId,
        title: title,
        body: body,
      ),
    );
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
  }
}

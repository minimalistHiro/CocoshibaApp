import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_notification.dart';

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('notifications');
  CollectionReference<Map<String, dynamic>> _personalNotificationsRef(
          String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('personalNotifications');
  CollectionReference<Map<String, dynamic>> _userReadsRef(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('notificationReads');
  CollectionReference<Map<String, dynamic>> get _ownerNotificationsRef =>
      _firestore.collection('owner_notifications');

  Stream<List<AppNotification>> watchNotifications({
    String? userId,
    bool includeOwnerNotifications = false,
  }) {
    final baseStream = _notificationsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(AppNotification.fromDocument).toList())
        .map((notifications) {
      if (userId == null || userId.isEmpty) {
        return notifications
            .where((notification) => notification.targetUserId == null)
            .toList();
      }
      return notifications
          .where((notification) =>
              notification.targetUserId == null ||
              notification.targetUserId == userId)
          .toList();
    });

    if (userId == null || userId.isEmpty) {
      if (includeOwnerNotifications) {
        return _mergeNotificationStreams(
          baseStream,
          watchOwnerNotifications(),
        );
      }
      return baseStream;
    }

    final personalStream = _personalNotificationsRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(AppNotification.fromDocument).toList());

    final combinedStream =
        _combineNotificationStreams(baseStream, personalStream);
    if (includeOwnerNotifications) {
      return _mergeNotificationStreams(
        combinedStream,
        watchOwnerNotifications(),
      );
    }
    return combinedStream;
  }

  Future<void> createNotification({
    required String title,
    required String body,
    required String category,
    String? targetUserId,
    Uint8List? imageBytes,
  }) async {
    final docRef = _notificationsRef.doc();
    String? imageUrl;

    if (imageBytes != null) {
      final storageRef = _storage.ref().child(
          'notification_images/${docRef.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = await storageRef.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      imageUrl = await uploadTask.ref.getDownloadURL();
    }

    await docRef.set({
      'title': title,
      'body': body,
      'category': category,
      'imageUrl': imageUrl,
      'targetUserId': targetUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createPersonalNotification({
    required String userId,
    required String title,
    required String body,
    required String category,
  }) async {
    await _personalNotificationsRef(userId).add({
      'title': title,
      'body': body,
      'category': category,
      'targetUserId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<Set<String>> watchReadNotificationIds(String? userId) {
    if (userId == null || userId.isEmpty) {
      return Stream.value(<String>{});
    }
    return _userReadsRef(userId).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.id).toSet(),
        );
  }

  Future<void> markAsRead({
    required String? userId,
    required String notificationId,
  }) async {
    if (userId == null || userId.isEmpty) {
      return;
    }
    await _userReadsRef(userId).doc(notificationId).set(
      {
        'readAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<bool> watchHasUnreadNotifications(String? userId) {
    if (userId == null || userId.isEmpty) {
      return Stream<bool>.value(false);
    }

    final controller = StreamController<bool>.broadcast();
    List<AppNotification> notifications = const [];
    Set<String> readIds = const <String>{};
    StreamSubscription<List<AppNotification>>? notificationSub;
    StreamSubscription<Set<String>>? readSub;

    void emitUnreadState() {
      final hasUnread =
          notifications.any((notification) => !readIds.contains(notification.id));
      controller.add(hasUnread);
    }

    controller.onListen = () {
      notificationSub = watchNotifications(userId: userId).listen(
        (value) {
          notifications = value;
          emitUnreadState();
        },
        onError: controller.addError,
      );
      readSub = watchReadNotificationIds(userId).listen(
        (value) {
          readIds = value;
          emitUnreadState();
        },
        onError: controller.addError,
      );
    };

    controller.onCancel = () async {
      await notificationSub?.cancel();
      await readSub?.cancel();
    };

    return controller.stream;
  }

  Stream<List<AppNotification>> _combineNotificationStreams(
    Stream<List<AppNotification>> globalStream,
    Stream<List<AppNotification>> personalStream,
  ) {
    final controller = StreamController<List<AppNotification>>.broadcast();
    List<AppNotification> globalNotifications = const [];
    List<AppNotification> personalNotifications = const [];
    StreamSubscription<List<AppNotification>>? globalSub;
    StreamSubscription<List<AppNotification>>? personalSub;
    int listenerCount = 0;

    void emit() {
      final combined = <AppNotification>[
        ...personalNotifications,
        ...globalNotifications,
      ]
        ..sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      controller.add(combined);
    }

    void startListening() {
      globalSub ??= globalStream.listen(
        (value) {
          globalNotifications = value;
          emit();
        },
        onError: controller.addError,
      );
      personalSub ??= personalStream.listen(
        (value) {
          personalNotifications = value;
          emit();
        },
        onError: controller.addError,
      );
    }

    Future<void> stopListening() async {
      await globalSub?.cancel();
      await personalSub?.cancel();
      globalSub = null;
      personalSub = null;
      globalNotifications = const [];
      personalNotifications = const [];
    }

    controller.onListen = () {
      listenerCount += 1;
      if (listenerCount == 1) {
        startListening();
      }
    };

    controller.onCancel = () {
      listenerCount -= 1;
      if (listenerCount <= 0) {
        listenerCount = 0;
        return stopListening();
      }
      return null;
    };

    return controller.stream;
  }

  Stream<List<AppNotification>> watchOwnerNotifications() {
    return _ownerNotificationsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(AppNotification.fromDocument).toList());
  }

  Stream<List<AppNotification>> _mergeNotificationStreams(
    Stream<List<AppNotification>> baseStream,
    Stream<List<AppNotification>> additionalStream,
  ) {
    final controller = StreamController<List<AppNotification>>.broadcast();
    List<AppNotification> baseNotifications = const [];
    List<AppNotification> additionalNotifications = const [];
    StreamSubscription<List<AppNotification>>? baseSub;
    StreamSubscription<List<AppNotification>>? additionalSub;

    void emit() {
      final merged = <AppNotification>[
        ...baseNotifications,
        ...additionalNotifications,
      ];
      merged.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      controller.add(merged);
    }

    controller.onListen = () {
      baseSub = baseStream.listen(
        (value) {
          baseNotifications = value;
          emit();
        },
        onError: controller.addError,
      );
      additionalSub = additionalStream.listen(
        (value) {
          additionalNotifications = value;
          emit();
        },
        onError: controller.addError,
      );
    };

    controller.onCancel = () async {
      await baseSub?.cancel();
      await additionalSub?.cancel();
    };

    return controller.stream;
  }

  Future<void> deleteNotification(String notificationId) async {
    final batch = _firestore.batch();
    batch.delete(_notificationsRef.doc(notificationId));
    batch.delete(_ownerNotificationsRef.doc(notificationId));
    await batch.commit();
  }
}

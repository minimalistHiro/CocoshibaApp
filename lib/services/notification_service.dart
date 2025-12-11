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
  CollectionReference<Map<String, dynamic>> _userReadsRef(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('notificationReads');

  Stream<List<AppNotification>> watchNotifications({String? userId}) {
    return _notificationsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final notifications =
          snapshot.docs.map(AppNotification.fromDocument).toList();
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
}

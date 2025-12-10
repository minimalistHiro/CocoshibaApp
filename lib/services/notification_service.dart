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

  Stream<List<AppNotification>> watchNotifications() {
    return _notificationsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AppNotification.fromDocument).toList(),
        );
  }

  Future<void> createNotification({
    required String title,
    required String body,
    required String category,
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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

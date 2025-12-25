import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/existing_event.dart';

class ExistingEventService {
  ExistingEventService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _existingEventsRef =>
      _firestore.collection('existing_events');

  Future<bool> exists(String existingEventId) async {
    if (existingEventId.isEmpty) return false;
    final doc = await _existingEventsRef.doc(existingEventId).get();
    return doc.exists;
  }

  Future<int> _nextOrderIndex() async {
    final snapshot = await _existingEventsRef.get();
    int maxOrderIndex = -1;
    for (final doc in snapshot.docs) {
      final value = doc.data()['orderIndex'];
      if (value is num && value.toInt() > maxOrderIndex) {
        maxOrderIndex = value.toInt();
      }
    }
    if (maxOrderIndex >= 0) {
      return maxOrderIndex + 1;
    }
    return snapshot.docs.length;
  }

  Future<String> createExistingEvent({
    required String name,
    required String organizer,
    required String content,
    required List<XFile> images,
    required int colorValue,
    required int capacity,
    String? existingEventId,
  }) async {
    final docRef = (existingEventId != null && existingEventId.isNotEmpty)
        ? _existingEventsRef.doc(existingEventId)
        : _existingEventsRef.doc();
    final List<String> imageUrls = [];

    for (final image in images) {
      try {
        final Uint8List bytes = await image.readAsBytes();
        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final storageRef =
            _storage.ref().child('existing_event_images/${docRef.id}/$filename');
        final uploadTask = await storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final url = await uploadTask.ref.getDownloadURL();
        imageUrls.add(url);
      } catch (_) {
        // ignore failed upload to avoid breaking other images
      }
    }

    final orderIndex = await _nextOrderIndex();
    await docRef.set({
      'name': name,
      'organizer': organizer,
      'content': content,
      'imageUrls': imageUrls,
      'colorValue': colorValue,
      'capacity': capacity,
      'orderIndex': orderIndex,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateExistingEvent({
    required String eventId,
    required String name,
    required String organizer,
    required String content,
    required List<String> remainingImageUrls,
    required List<XFile> newImages,
    required List<String> removedImageUrls,
    required int colorValue,
    required int capacity,
  }) async {
    final docRef = _existingEventsRef.doc(eventId);
    final List<String> imageUrls = List<String>.from(remainingImageUrls);

    for (final image in newImages) {
      try {
        final Uint8List bytes = await image.readAsBytes();
        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final storageRef =
            _storage.ref().child('existing_event_images/$eventId/$filename');
        final uploadTask = await storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final url = await uploadTask.ref.getDownloadURL();
        imageUrls.add(url);
      } catch (_) {
        // ignore upload errors to keep other updates running
      }
    }

    await docRef.update({
      'name': name,
      'organizer': organizer,
      'content': content,
      'imageUrls': imageUrls,
      'colorValue': colorValue,
      'capacity': capacity,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final url in removedImageUrls) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {
        // ignore cleanup failures
      }
    }
  }

  Stream<List<ExistingEvent>> watchExistingEvents() {
    return _existingEventsRef.snapshots().map((snapshot) {
      final events =
          snapshot.docs.map(ExistingEvent.fromDocument).toList(growable: false);
      events.sort((a, b) {
        final aOrder = a.orderIndex ?? (a.createdAt?.millisecondsSinceEpoch ?? 0);
        final bOrder = b.orderIndex ?? (b.createdAt?.millisecondsSinceEpoch ?? 0);
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        final aCreated = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bCreated = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return aCreated.compareTo(bCreated);
      });
      return events;
    });
  }

  Future<void> updateExistingEventOrder({
    required List<ExistingEvent> events,
  }) async {
    final batch = _firestore.batch();
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      batch.update(_existingEventsRef.doc(event.id), {
        'orderIndex': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

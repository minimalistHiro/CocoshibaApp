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

  Future<void> createExistingEvent({
    required String name,
    required String organizer,
    required String content,
    required List<XFile> images,
    required int colorValue,
    required int capacity,
  }) async {
    final docRef = _existingEventsRef.doc();
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

    await docRef.set({
      'name': name,
      'organizer': organizer,
      'content': content,
      'imageUrls': imageUrls,
      'colorValue': colorValue,
      'capacity': capacity,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
    return _existingEventsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ExistingEvent.fromDocument)
              .toList(growable: false),
        );
  }
}

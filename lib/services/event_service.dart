import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/calendar_event.dart';

class EventService {
  EventService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('events');

  Future<void> createEvent({
    required String name,
    required String organizer,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required String content,
    required List<XFile> images,
    required int colorValue,
  }) async {
    final docRef = _eventsRef.doc();
    final List<String> imageUrls = [];

    for (final image in images) {
      final Uint8List bytes = await image.readAsBytes();
      final storageRef = _storage
          .ref()
          .child('event_images/${docRef.id}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await uploadTask.ref.getDownloadURL();
      imageUrls.add(url);
    }

    await docRef.set({
      'name': name,
      'organizer': organizer,
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'content': content,
      'imageUrls': imageUrls,
      'colorValue': colorValue,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEvent(CalendarEvent event) async {
    final docRef = _eventsRef.doc(event.id);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final List<dynamic>? urls = snapshot.data()?['imageUrls'] as List<dynamic>?;
    if (urls != null) {
      for (final url in urls) {
        try {
          await _storage.refFromURL(url.toString()).delete();
        } catch (_) {
          // ignore failures for cleanup
        }
      }
    }
    await docRef.delete();
  }

  Stream<List<CalendarEvent>> watchEvents(
    DateTime startDate,
    DateTime endDate,
  ) {
    final Timestamp startTimestamp = Timestamp.fromDate(
      DateTime(startDate.year, startDate.month, startDate.day),
    );
    final Timestamp endTimestamp = Timestamp.fromDate(
      DateTime(endDate.year, endDate.month, endDate.day).add(
        const Duration(days: 1),
      ),
    );

    return _eventsRef
        .where('startDateTime', isGreaterThanOrEqualTo: startTimestamp)
        .where('startDateTime', isLessThan: endTimestamp)
        .orderBy('startDateTime')
        .snapshots()
        .map(
      (snapshot) => snapshot.docs
          .map(CalendarEvent.fromDocument)
          .toList(growable: false),
    );
  }
}

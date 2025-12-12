import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/calendar_event.dart';
import '../models/event_reservation_member.dart';

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
  CollectionReference<Map<String, dynamic>> _userReservationsRef(
          String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('event_reservations');
  CollectionReference<Map<String, dynamic>> _eventReservationsRef(
          String eventId) =>
      _eventsRef.doc(eventId).collection('event_reservations');

  Future<void> createEvent({
    required String name,
    required String organizer,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required String content,
    required List<XFile> images,
    required int colorValue,
    required int capacity,
    String? existingEventId,
  }) async {
    final docRef = _eventsRef.doc();
    final List<String> imageUrls = [];
    final String? resolvedExistingEventId =
        _resolveExistingEventId(existingEventId, docRef.id.length);

    for (final image in images) {
      final Uint8List bytes = await image.readAsBytes();
      final storageRef = _storage.ref().child(
          'event_images/${docRef.id}/${DateTime.now().millisecondsSinceEpoch}.jpg');
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
      'capacity': capacity,
      'reservationCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'existingEventId':
          resolvedExistingEventId != null && resolvedExistingEventId.isNotEmpty
              ? resolvedExistingEventId
              : null,
    });
  }

  Future<List<String>> updateEvent({
    required String eventId,
    required String name,
    required String organizer,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required String content,
    required int colorValue,
    required int capacity,
    required List<String> remainingImageUrls,
    required List<XFile> newImages,
    required List<String> removedImageUrls,
    String? existingEventId,
  }) async {
    final List<String> imageUrls = List<String>.from(remainingImageUrls);

    for (final image in newImages) {
      try {
        final Uint8List bytes = await image.readAsBytes();
        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final storageRef =
            _storage.ref().child('event_images/$eventId/$filename');
        final uploadTask = await storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final url = await uploadTask.ref.getDownloadURL();
        imageUrls.add(url);
      } catch (_) {
        // ignore single-image failures to allow other updates to proceed
      }
    }

    await _eventsRef.doc(eventId).update({
      'name': name,
      'organizer': organizer,
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'content': content,
      'imageUrls': imageUrls,
      'colorValue': colorValue,
      'capacity': capacity,
      'updatedAt': FieldValue.serverTimestamp(),
      'existingEventId':
          existingEventId != null && existingEventId.isNotEmpty
              ? existingEventId
              : null,
    });

    for (final url in removedImageUrls) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {
        // ignore cleanup failure
      }
    }

    return imageUrls;
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

  Stream<List<CalendarEvent>> watchEventsByExistingEventId(
    String existingEventId,
  ) {
    if (existingEventId.isEmpty) {
      return Stream.value(<CalendarEvent>[]);
    }
    return _eventsRef
        .where('existingEventId', isEqualTo: existingEventId)
        .orderBy('startDateTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(CalendarEvent.fromDocument)
              .where((event) => !event.isClosedDay)
              .toList(growable: false),
        );
  }

  Stream<List<CalendarEvent>> watchUpcomingEvents({
    DateTime? from,
    int limit = 5,
  }) {
    final DateTime start = from ?? DateTime.now();
    final Timestamp startTimestamp = Timestamp.fromDate(
      DateTime(start.year, start.month, start.day),
    );

    Query<Map<String, dynamic>> query = _eventsRef
        .where('startDateTime', isGreaterThanOrEqualTo: startTimestamp)
        .orderBy('startDateTime');

    if (limit > 0) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(CalendarEvent.fromDocument)
              .where((event) => !event.isClosedDay)
              .toList(growable: false),
        );
  }

  Future<bool> hasReservation({
    required String eventId,
    required String userId,
  }) async {
    final doc = await _userReservationsRef(userId).doc(eventId).get();
    return doc.exists;
  }

  Future<void> reserveEvent({
    required CalendarEvent event,
    required String userId,
  }) async {
    final reservationRef = _userReservationsRef(userId).doc(event.id);
    final eventRef = _eventsRef.doc(event.id);

    await _firestore.runTransaction((transaction) async {
      final reservationSnapshot = await transaction.get(reservationRef);
      final eventReservationSnapshot =
          await transaction.get(_eventReservationsRef(event.id).doc(userId));
      if (reservationSnapshot.exists || eventReservationSnapshot.exists) {
        return;
      }

      final userDocRef = _firestore.collection('users').doc(userId);
      final userSnapshot = await transaction.get(userDocRef);
      final userData = userSnapshot.data();
      final userName = (userData?['name'] as String?)?.trim();
      final userEmail = (userData?['email'] as String?)?.trim();
      final userArea = (userData?['area'] as String?)?.trim();
      final userAgeGroup = (userData?['ageGroup'] as String?)?.trim();

      final reservationPayload = {
        'userId': userId,
        'eventId': event.id,
        'eventName': event.name,
        'eventStartDateTime': Timestamp.fromDate(event.startDateTime),
        'eventEndDateTime': Timestamp.fromDate(event.endDateTime),
        'reservedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(reservationRef, reservationPayload);

      final eventReservationPayload = {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'userArea': userArea,
        'userAgeGroup': userAgeGroup,
        'userPhotoUrl': (userData?['photoUrl'] as String?)?.trim(),
        'reservedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(
        _eventReservationsRef(event.id).doc(userId),
        eventReservationPayload,
      );

      transaction.update(eventRef, {
        'reservationCount': FieldValue.increment(1),
      });
    });
  }

  Future<void> cancelReservation({
    required String eventId,
    required String userId,
  }) async {
    final reservationRef = _userReservationsRef(userId).doc(eventId);
    final eventRef = _eventsRef.doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final reservationSnapshot = await transaction.get(reservationRef);
      if (!reservationSnapshot.exists) {
        return;
      }

      final eventReservationDoc =
          await transaction.get(_eventReservationsRef(eventId).doc(userId));
      final eventSnapshot = await transaction.get(eventRef);

      transaction.delete(reservationRef);
      transaction.delete(eventReservationDoc.reference);

      final currentCount =
          (eventSnapshot.data()?['reservationCount'] as int?) ?? 0;
      if (currentCount > 0) {
        transaction.update(eventRef, {
          'reservationCount': FieldValue.increment(-1),
        });
      }
    });
  }

  Stream<int> watchEventReservationCount(String eventId) async* {
    final docRef = _eventsRef.doc(eventId);
    await for (final snapshot in docRef.snapshots()) {
      if (!snapshot.exists) {
        yield 0;
        continue;
      }

      final data = snapshot.data();
      final storedCount = (data?['reservationCount'] as int?);
      if (storedCount != null) {
        yield storedCount;
        continue;
      }

      final countSnapshot = await _firestore
          .collectionGroup('event_reservations')
          .where('eventId', isEqualTo: eventId)
          .get();
      final computedCount = countSnapshot.size;

      await docRef.set(
        {'reservationCount': computedCount},
        SetOptions(merge: true),
      );
      yield computedCount;
    }
  }

  Stream<List<EventReservationMember>> watchEventReservations(
    String eventId,
  ) {
    return _eventReservationsRef(eventId).snapshots().map((snapshot) {
      final members = snapshot.docs
          .map((doc) => EventReservationMember.fromReservationData(
                doc.data(),
              ))
          .where((member) => member.userId.isNotEmpty)
          .toList(growable: false);

      members.sort((a, b) {
        final aTime = a.reservedAt;
        final bTime = b.reservedAt;
        if (aTime == null && bTime == null) {
          return a.name.compareTo(b.name);
        }
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });
      return members;
    });
  }

  Stream<List<CalendarEvent>> watchReservedEvents(String userId) {
    return _userReservationsRef(userId)
        .orderBy('eventStartDateTime')
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return const <CalendarEvent>[];
      final eventIds = snapshot.docs.map((doc) => doc.id).toSet();
      if (eventIds.isEmpty) return const <CalendarEvent>[];

      final futures = eventIds.map((id) => _eventsRef.doc(id).get());
      final docs = await Future.wait(futures);
      final events = docs
          .where((doc) => doc.exists)
          .map(CalendarEvent.fromDocument)
          .where((event) => !event.isClosedDay)
          .toList(growable: false);
      events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      return events;
    });
  }

  String? _resolveExistingEventId(String? existingEventId, int fallbackLength) {
    if (existingEventId != null && existingEventId.isNotEmpty) {
      return existingEventId;
    }
    return _generateRandomId(fallbackLength);
  }

  String _generateRandomId(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}

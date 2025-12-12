import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_event.dart';

class EventInterestService {
  EventInterestService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _interestRef(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('interested_events');

  Stream<Set<String>> watchInterestedEventIds(String userId) {
    return _interestRef(userId).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.id).toSet(),
        );
  }

  Future<void> addInterest({
    required String userId,
    required CalendarEvent event,
  }) {
    return _interestRef(userId).doc(event.id).set({
      'eventId': event.id,
      'eventName': event.name,
      'eventStartDateTime': Timestamp.fromDate(event.startDateTime),
      'eventEndDateTime': Timestamp.fromDate(event.endDateTime),
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeInterest({
    required String userId,
    required String eventId,
  }) {
    return _interestRef(userId).doc(eventId).delete();
  }

  Future<void> toggleInterest({
    required String userId,
    required CalendarEvent event,
    required bool isInterested,
  }) {
    if (isInterested) {
      return removeInterest(userId: userId, eventId: event.id);
    }
    return addInterest(userId: userId, event: event);
  }

  Future<bool> isInterested({
    required String userId,
    required String eventId,
  }) async {
    final doc = await _interestRef(userId).doc(eventId).get();
    return doc.exists;
  }
}

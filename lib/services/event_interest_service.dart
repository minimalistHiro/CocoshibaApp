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

  CollectionReference<Map<String, dynamic>> _eventInterestRef(String eventId) =>
      _firestore.collection('events').doc(eventId).collection('interested_users');

  Future<Map<String, String?>> _fetchUserProfile(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    final data = snapshot.data() ?? <String, dynamic>{};
    String? trim(String? value) => (value as String?)?.trim();

    return {
      'name': trim(data['name'] as String?),
      'email': trim(data['email'] as String?),
      'area': trim(data['area'] as String?),
      'ageGroup': trim(data['ageGroup'] as String?),
      'photoUrl': trim(data['photoUrl'] as String?),
    };
  }

  Stream<Set<String>> watchInterestedEventIds(String userId) {
    return _interestRef(userId).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.id).toSet(),
        );
  }

  Future<void> addInterest({
    required String userId,
    required CalendarEvent event,
  }) async {
    final profile = await _fetchUserProfile(userId);
    final userDoc = _interestRef(userId).doc(event.id);
    final eventDoc = _eventInterestRef(event.id).doc(userId);
    final batch = _firestore.batch();

    batch.set(userDoc, {
      'eventId': event.id,
      'eventName': event.name,
      'eventStartDateTime': Timestamp.fromDate(event.startDateTime),
      'eventEndDateTime': Timestamp.fromDate(event.endDateTime),
      'addedAt': FieldValue.serverTimestamp(),
    });

    batch.set(eventDoc, {
      'userId': userId,
      'userName': profile['name'],
      'userEmail': profile['email'],
      'userArea': profile['area'],
      'userAgeGroup': profile['ageGroup'],
      'userPhotoUrl': profile['photoUrl'],
      'addedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> removeInterest({
    required String userId,
    required String eventId,
  }) async {
    final userDoc = _interestRef(userId).doc(eventId);
    final eventDoc = _eventInterestRef(eventId).doc(userId);
    final batch = _firestore.batch();

    batch.delete(userDoc);
    batch.delete(eventDoc);

    await batch.commit();
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

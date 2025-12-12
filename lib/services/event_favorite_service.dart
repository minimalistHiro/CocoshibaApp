import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_event.dart';
import '../models/existing_event.dart';

class EventFavoriteService {
  EventFavoriteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _favoritesRef(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('favorite_events');

  CollectionReference<Map<String, dynamic>> _favoriteUsersRef(
    CalendarEvent event,
  ) {
    final existingId = event.existingEventId?.trim();
    if (existingId != null && existingId.isNotEmpty) {
      return _firestore
          .collection('existing_events')
          .doc(existingId)
          .collection('favorite_users');
    }
    return _firestore.collection('events').doc(event.id).collection('favorite_users');
  }

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

  String _favoriteKey(CalendarEvent event) {
    final existingId = event.existingEventId;
    if (existingId != null && existingId.isNotEmpty) return existingId;
    return event.id;
  }

  Future<bool> isFavorite({
    required String userId,
    required CalendarEvent event,
  }) async {
    final doc = await _favoritesRef(userId).doc(_favoriteKey(event)).get();
    return doc.exists;
  }

  Future<void> addFavorite({
    required String userId,
    required CalendarEvent event,
  }) async {
    final profile = await _fetchUserProfile(userId);
    final key = _favoriteKey(event);
    final userDoc = _favoritesRef(userId).doc(key);
    final eventDoc = _favoriteUsersRef(event).doc(userId);
    final batch = _firestore.batch();

    batch.set(userDoc, {
      'targetId': key,
      'existingEventId': event.existingEventId,
      'eventId': event.id,
      'eventName': event.name,
      'eventOrganizer': event.organizer,
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

  Future<void> removeFavorite({
    required String userId,
    required CalendarEvent event,
  }) async {
    final key = _favoriteKey(event);
    final userDoc = _favoritesRef(userId).doc(key);
    final eventDoc = _favoriteUsersRef(event).doc(userId);
    final batch = _firestore.batch();

    batch.delete(userDoc);
    batch.delete(eventDoc);

    await batch.commit();
  }

  Future<void> toggleFavorite({
    required String userId,
    required CalendarEvent event,
    required bool isFavorite,
  }) {
    if (isFavorite) {
      return removeFavorite(userId: userId, event: event);
    }
    return addFavorite(userId: userId, event: event);
  }

  Future<void> addFavoriteForExistingEvent({
    required String userId,
    required ExistingEvent existingEvent,
  }) async {
    final profile = await _fetchUserProfile(userId);
    final key = existingEvent.id;
    final userDoc = _favoritesRef(userId).doc(key);
    final eventDoc = _firestore
        .collection('existing_events')
        .doc(existingEvent.id)
        .collection('favorite_users')
        .doc(userId);
    final batch = _firestore.batch();

    batch.set(userDoc, {
      'targetId': key,
      'existingEventId': existingEvent.id,
      'eventId': existingEvent.id,
      'eventName': existingEvent.name,
      'eventOrganizer': existingEvent.organizer,
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

  Future<void> removeFavoriteForExistingEvent({
    required String userId,
    required ExistingEvent existingEvent,
  }) async {
    final key = existingEvent.id;
    final userDoc = _favoritesRef(userId).doc(key);
    final eventDoc = _firestore
        .collection('existing_events')
        .doc(existingEvent.id)
        .collection('favorite_users')
        .doc(userId);
    final batch = _firestore.batch();

    batch.delete(userDoc);
    batch.delete(eventDoc);

    await batch.commit();
  }

  Future<void> toggleFavoriteForExistingEvent({
    required String userId,
    required ExistingEvent existingEvent,
    required bool isFavorite,
  }) {
    if (isFavorite) {
      return removeFavoriteForExistingEvent(
        userId: userId,
        existingEvent: existingEvent,
      );
    }
    return addFavoriteForExistingEvent(
      userId: userId,
      existingEvent: existingEvent,
    );
  }

  Stream<List<FavoriteEventReference>> watchFavoriteReferences(String userId) {
    return _favoritesRef(userId)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => FavoriteEventReference(
                  targetId: doc.id,
                  eventId: doc.data()['eventId'] as String?,
                  existingEventId: doc.data()['existingEventId'] as String?,
                ),
              )
              .toList(growable: false),
        );
  }
}

class FavoriteEventReference {
  FavoriteEventReference({
    required this.targetId,
    this.eventId,
    this.existingEventId,
  });

  final String targetId;
  final String? eventId;
  final String? existingEventId;
}

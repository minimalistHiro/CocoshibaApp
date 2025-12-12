import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_event.dart';

class EventFavoriteService {
  EventFavoriteService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _favoritesRef(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('favorite_events');

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
  }) {
    final key = _favoriteKey(event);
    return _favoritesRef(userId).doc(key).set({
      'targetId': key,
      'existingEventId': event.existingEventId,
      'eventId': event.id,
      'eventName': event.name,
      'eventOrganizer': event.organizer,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFavorite({
    required String userId,
    required CalendarEvent event,
  }) {
    return _favoritesRef(userId).doc(_favoriteKey(event)).delete();
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

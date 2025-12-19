import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/home_page_reservation_member.dart';

class HomePageReservationService {
  HomePageReservationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _homePagesRef =>
      _firestore.collection('home_pages');

  CollectionReference<Map<String, dynamic>> _userReservationsRef(
          String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('home_page_reservations');

  CollectionReference<Map<String, dynamic>> _contentReservationsRef(
          String contentId) =>
      _homePagesRef.doc(contentId).collection('reservations');

  Future<void> createReservation({
    required String contentId,
    required String contentTitle,
    required DateTime pickupDate,
    required String userId,
    required int quantity,
  }) async {
    final completionDate = DateTime.now();
    final pickupLabel = _formatDate(pickupDate);
    final completionLabel = _formatDate(completionDate);

    final userDocRef = _firestore.collection('users').doc(userId);
    final contentDocRef = _homePagesRef.doc(contentId);
    final contentReservationRef = _contentReservationsRef(contentId).doc();
    final reservationId = contentReservationRef.id;
    final userReservationRef = _userReservationsRef(userId).doc(reservationId);

    await _firestore.runTransaction((transaction) async {
      final contentSnapshot = await transaction.get(contentDocRef);
      if (!contentSnapshot.exists) {
        return;
      }

      final userSnapshot = await transaction.get(userDocRef);
      final userData = userSnapshot.data();

      final reservationPayload = {
        'contentId': contentId,
        'contentTitle': contentTitle,
        'userId': userId,
        'reservationId': reservationId,
        'pickupDate': Timestamp.fromDate(pickupDate),
        'quantity': quantity,
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      transaction.set(userReservationRef, reservationPayload);

      final contentReservationPayload = {
        'userId': userId,
        'userName': (userData?['name'] as String?)?.trim(),
        'userEmail': (userData?['email'] as String?)?.trim(),
        'contentTitle': contentTitle,
        'userReservationId': reservationId,
        'pickupDate': Timestamp.fromDate(pickupDate),
        'quantity': quantity,
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      transaction.set(contentReservationRef, contentReservationPayload);

      final reserverName = (userData?['name'] as String?)?.trim();

      transaction.update(contentDocRef, {
        'reservationCount': FieldValue.increment(1),
        'reservationUserIds': FieldValue.arrayUnion([userId]),
      });
    });
  }

  Stream<List<HomePageReservationMember>> watchContentReservations(
    String contentId,
  ) {
    return _contentReservationsRef(contentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(HomePageReservationMember.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<List<HomePageReservationMember>> watchUserReservations(
    String userId,
  ) {
    return _userReservationsRef(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(HomePageReservationMember.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> markReservationCompleted({
    required String contentId,
    required String reservationId,
    required bool isCompleted,
    String? userId,
    String? userReservationId,
  }) async {
    final contentDocRef = _contentReservationsRef(contentId).doc(reservationId);
    final resolvedUserReservationId =
        (userReservationId != null && userReservationId.isNotEmpty)
            ? userReservationId
            : reservationId;

    final batch = _firestore.batch();
    batch.set(
      contentDocRef,
      {'isCompleted': isCompleted},
      SetOptions(merge: true),
    );
    if (userId != null && userId.isNotEmpty) {
      final userReservationRef =
          _userReservationsRef(userId).doc(resolvedUserReservationId);
      batch.set(
        userReservationRef,
        {'isCompleted': isCompleted},
        SetOptions(merge: true),
      );
    }
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      debugPrint('Firestore error code: ${e.code}');
      debugPrint('message: ${e.message}');
      rethrow;
    }
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

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

  CollectionReference<Map<String, dynamic>> get _ownerNotificationsRef =>
      _firestore.collection('owner_notifications');

  Future<void> createReservation({
    required String contentId,
    required String contentTitle,
    required DateTime reservedDate,
    required String userId,
    DateTime? pickupDate,
    required int quantity,
  }) async {
    final completionDate = DateTime.now();
    final reservedLabel = _formatDate(reservedDate);
    final pickupLabel =
        pickupDate != null ? _formatDate(pickupDate) : reservedLabel;
    final completionLabel = _formatDate(completionDate);

    final userDocRef = _firestore.collection('users').doc(userId);
    final userReservationRef = _userReservationsRef(userId).doc();
    final contentDocRef = _homePagesRef.doc(contentId);
    final contentReservationRef = _contentReservationsRef(contentId).doc();

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
        'reservedDate': Timestamp.fromDate(reservedDate),
        'pickupDate':
            pickupDate != null ? Timestamp.fromDate(pickupDate) : null,
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
        'reservedDate': Timestamp.fromDate(reservedDate),
        'pickupDate':
            pickupDate != null ? Timestamp.fromDate(pickupDate) : null,
        'quantity': quantity,
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      transaction.set(contentReservationRef, contentReservationPayload);

      final reserverName = (userData?['name'] as String?)?.trim();
      final reserverLabel = reserverName != null && reserverName.isNotEmpty
          ? reserverName
          : userId;
      final ownerNotificationBody = '''
$reserverLabel が $contentTitle の予約をしました
受け取り日: $pickupLabel
予約完了日: $completionLabel
個数: $quantity
''';
      final ownerNotificationRef = _ownerNotificationsRef.doc();
      transaction.set(ownerNotificationRef, {
        'title': '予約通知',
        'userId': userId,
        'userName': reserverName,
        'userEmail': (userData?['email'] as String?)?.trim(),
        'contentId': contentId,
        'contentTitle': contentTitle,
        'reservedDate': Timestamp.fromDate(reservedDate),
        'pickupDate':
            pickupDate != null ? Timestamp.fromDate(pickupDate) : null,
        'pickupLabel': pickupLabel,
        'reservedLabel': reservedLabel,
        'quantity': quantity,
        'completionDate': Timestamp.fromDate(completionDate),
        'completionLabel': completionLabel,
        'body': ownerNotificationBody,
        'category': '予約',
        'createdAt': FieldValue.serverTimestamp(),
      });

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

  Future<void> markReservationCompleted({
    required String contentId,
    required String reservationId,
    required bool isCompleted,
  }) {
    final docRef = _contentReservationsRef(contentId).doc(reservationId);
    return docRef.set(
      {'isCompleted': isCompleted},
      SetOptions(merge: true),
    );
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
  }
}

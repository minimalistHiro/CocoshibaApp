import 'package:cloud_firestore/cloud_firestore.dart';

class HomePageReservationService {
  HomePageReservationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reservationsRef =>
      _firestore.collection('home_page_reservations');

  Future<void> createReservation({
    required String contentId,
    required String contentTitle,
    required DateTime reservedDate,
    required String userId,
    DateTime? pickupDate,
  }) {
    return _reservationsRef.add({
      'contentId': contentId,
      'contentTitle': contentTitle,
      'userId': userId,
      'reservedDate': Timestamp.fromDate(reservedDate),
      'pickupDate': pickupDate != null
          ? Timestamp.fromDate(pickupDate)
          : null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<String?> watchReservationId({
    required String contentId,
    required String userId,
  }) {
    return _reservationsRef
        .where('contentId', isEqualTo: contentId)
        .where('userId', isEqualTo: userId)
        .orderBy('reservedDate', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isEmpty ? null : snapshot.docs.first.id);
  }

  Future<void> cancelReservation(String reservationId) {
    return _reservationsRef.doc(reservationId).delete();
  }
}

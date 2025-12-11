import 'package:cloud_firestore/cloud_firestore.dart';

class HomePageOrderService {
  HomePageOrderService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('home_page_orders');

  Future<void> createOrder({
    required String contentId,
    required String contentTitle,
    required String userId,
  }) {
    return _ordersRef.add({
      'contentId': contentId,
      'contentTitle': contentTitle,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<String?> watchOrderId({
    required String contentId,
    required String userId,
  }) {
    return _ordersRef
        .where('contentId', isEqualTo: contentId)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isEmpty ? null : snapshot.docs.first.id);
  }

  Future<void> cancelOrder(String orderId) {
    return _ordersRef.doc(orderId).delete();
  }
}

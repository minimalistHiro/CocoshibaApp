import 'package:cloud_firestore/cloud_firestore.dart';

class NewUserCouponService {
  NewUserCouponService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<bool> watchIsUsed(String uid) {
    return _userRef(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      final used = data?['newUserCouponUsed'] == true;
      final usedAt = data?['newUserCouponUsedAt'];
      return used || usedAt != null;
    });
  }

  Future<void> markUsed(String uid) async {
    await _userRef(uid).set(
      {
        'newUserCouponUsed': true,
        'newUserCouponUsedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}


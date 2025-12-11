import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/point_history.dart';

class PointHistoryService {
  PointHistoryService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userPointHistoryRef(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('pointHistories');
  }

  Stream<List<PointHistory>> watchRecentHistories({
    required String userId,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> query =
        _userPointHistoryRef(userId).orderBy('createdAt', descending: true);

    if (limit > 0) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(PointHistory.fromDocument)
              .toList(growable: false),
        );
  }
}

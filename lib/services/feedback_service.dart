import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackService {
  FeedbackService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _feedbacksRef =>
      _firestore.collection('feedbacks');

  Future<void> submitFeedback({
    required String category,
    required String title,
    required String detail,
    String? contactEmail,
    bool includeDeviceInfo = true,
  }) async {
    final user = _auth.currentUser;
    final now = FieldValue.serverTimestamp();
    final trimmedTitle = title.trim();
    final trimmedDetail = detail.trim();
    final trimmedContact = contactEmail?.trim();
    final userName = user?.displayName?.trim();
    final userEmail = user?.email?.trim();

    final payload = <String, dynamic>{
      'category': category,
      'title': trimmedTitle,
      'detail': trimmedDetail,
      'contactEmail': trimmedContact,
      'includeDeviceInfo': includeDeviceInfo,
      'userId': user?.uid,
      'userEmail': userEmail,
      'userName': userName,
      'createdAt': now,
      'status': 'new',
    };

    await _feedbacksRef.add(payload);
  }
}

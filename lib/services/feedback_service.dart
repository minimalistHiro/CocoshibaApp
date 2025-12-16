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
  CollectionReference<Map<String, dynamic>> get _ownerNotificationsRef =>
      _firestore.collection('owner_notifications');

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

    final reporterLabel = (userName != null && userName.isNotEmpty)
        ? userName
        : (userEmail != null && userEmail.isNotEmpty)
            ? userEmail
            : '不明なユーザー';
    final detailSnippet = trimmedDetail.length > 120
        ? '${trimmedDetail.substring(0, 120)}…'
        : trimmedDetail;
    final ownerBody = '''
$reporterLabel からフィードバックが届きました
カテゴリ: $category
概要: $trimmedTitle
内容: $detailSnippet''';

    final batch = _firestore.batch();
    batch.set(_feedbacksRef.doc(), payload);
    batch.set(_ownerNotificationsRef.doc(), {
      'title': 'フィードバック受信',
      'body': ownerBody,
      'category': 'フィードバック',
      'contactEmail': trimmedContact,
      'includeDeviceInfo': includeDeviceInfo,
      'detail': trimmedDetail,
      'userId': user?.uid,
      'userName': userName,
      'userEmail': userEmail,
      'createdAt': now,
    });
    await batch.commit();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.imageUrl,
    required this.targetUserId,
    required this.createdAt,
  });

  factory AppNotification.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'];
    return AppNotification(
      id: snapshot.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      category: data['category'] as String? ?? '一般',
      imageUrl: data['imageUrl'] as String?,
      targetUserId: data['targetUserId'] as String?,
      createdAt:
          timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }

  final String id;
  final String title;
  final String body;
  final String category;
  final String? imageUrl;
  final String? targetUserId;
  final DateTime? createdAt;
}

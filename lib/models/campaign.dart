import 'package:cloud_firestore/cloud_firestore.dart';

class Campaign {
  Campaign({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.displayStart,
    this.displayEnd,
    this.eventStart,
    this.eventEnd,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final DateTime? displayStart;
  final DateTime? displayEnd;
  final DateTime? eventStart;
  final DateTime? eventEnd;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Campaign.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    DateTime? _parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return Campaign(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      displayStart: _parseDate(data['displayStart']),
      displayEnd: _parseDate(data['displayEnd']),
      eventStart: _parseDate(data['eventStart']),
      eventEnd: _parseDate(data['eventEnd']),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExistingEvent {
  ExistingEvent({
    required this.id,
    required this.name,
    required this.organizer,
    required this.content,
    required this.imageUrls,
    required this.colorValue,
    required this.capacity,
    this.createdAt,
  });

  final String id;
  final String name;
  final String organizer;
  final String content;
  final List<String> imageUrls;
  final int colorValue;
  final int capacity;
  final DateTime? createdAt;

  Color get color => Color(colorValue);

  factory ExistingEvent.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    DateTime? _parse(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return ExistingEvent(
      id: doc.id,
      name: data['name'] as String? ?? '',
      organizer: data['organizer'] as String? ?? '',
      content: data['content'] as String? ?? '',
      imageUrls: (data['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      colorValue: data['colorValue'] as int? ?? Colors.blue.value,
      capacity: data['capacity'] as int? ?? 0,
      createdAt: _parse(data['createdAt']),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.name,
    required this.organizer,
    required this.startDateTime,
    required this.endDateTime,
    required this.content,
    required this.imageUrls,
    required this.colorValue,
    required this.capacity,
    required this.isClosedDay,
    this.existingEventId,
  });

  final String id;
  final String name;
  final String organizer;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String content;
  final List<String> imageUrls;
  final int colorValue;
  final int capacity;
  final bool isClosedDay;
  final String? existingEventId;

  Color get color => Color(colorValue);

  factory CalendarEvent.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    DateTime _parse(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return CalendarEvent(
      id: doc.id,
      name: data['name'] as String? ?? '',
      organizer: data['organizer'] as String? ?? '',
      startDateTime: _parse(data['startDateTime']),
      endDateTime: _parse(data['endDateTime']),
      content: data['content'] as String? ?? '',
      imageUrls: (data['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      colorValue: (data['colorValue'] as int?) ?? Colors.blue.value,
      capacity: (data['capacity'] as int?) ?? 0,
      isClosedDay: data['isClosedDay'] == true,
      existingEventId: data['existingEventId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'organizer': organizer,
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'content': content,
      'imageUrls': imageUrls,
      'colorValue': colorValue,
      'capacity': capacity,
      'isClosedDay': isClosedDay,
      'existingEventId': existingEventId,
    };
  }
}

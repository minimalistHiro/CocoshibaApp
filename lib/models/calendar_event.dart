import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.name,
    required this.organizer,
    required this.startDateTime,
    required this.endDateTime,
    required this.content,
    required this.imageUrls,
  });

  final String id;
  final String name;
  final String organizer;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String content;
  final List<String> imageUrls;

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
    };
  }
}

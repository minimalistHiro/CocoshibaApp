import 'package:cloud_firestore/cloud_firestore.dart';

enum ClosedDayType {
  regular('定休日'),
  temporary('臨時休業');

  const ClosedDayType(this.label);

  final String label;

  static ClosedDayType fromEventName(Object? name) =>
      name == temporary.label ? temporary : regular;
}

class ClosedDaysService {
  ClosedDaysService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('events');

  static const int _closedDayColorValue = 0xFF9E9E9E;

  Future<Map<DateTime, ClosedDayType>> fetchClosedDays({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startTimestamp = Timestamp.fromDate(
      DateTime(startDate.year, startDate.month, startDate.day),
    );
    final endTimestamp = Timestamp.fromDate(
      DateTime(endDate.year, endDate.month, endDate.day + 1),
    );

    final snapshot = await _eventsRef
        .where('startDateTime', isGreaterThanOrEqualTo: startTimestamp)
        .where('startDateTime', isLessThan: endTimestamp)
        .get();

    final result = <DateTime, ClosedDayType>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['isClosedDay'] != true) continue;
      final date = _eventDate(data['startDateTime']);
      if (date != null) {
        result[date] = ClosedDayType.fromEventName(data['name']);
      }
    }
    return result;
  }

  Future<void> saveClosedDayChanges(
      Map<DateTime, ClosedDayType?> changes) async {
    if (changes.isEmpty) return;

    final snapshot =
        await _eventsRef.where('isClosedDay', isEqualTo: true).get();
    final existingByDate =
        <DateTime, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in snapshot.docs) {
      final date = _eventDate(doc.data()['startDateTime']);
      if (date != null && changes.containsKey(date)) {
        existingByDate.putIfAbsent(date, () => []).add(doc);
      }
    }

    final batch = _firestore.batch();
    for (final entry in changes.entries) {
      final date = entry.key;
      final type = entry.value;
      final existing = existingByDate[date] ?? const [];
      if (type == null) {
        for (final doc in existing) {
          batch.delete(doc.reference);
        }
        continue;
      }

      final details = {
        'name': type.label,
        'content': '${type.label}のため休業です。',
        'colorValue': _closedDayColorValue,
      };
      if (existing.isNotEmpty) {
        batch.update(existing.first.reference, details);
        for (final duplicate in existing.skip(1)) {
          batch.delete(duplicate.reference);
        }
        continue;
      }

      final dateKey = DateTime.utc(date.year, date.month, date.day)
          .toIso8601String()
          .split('T')
          .first;
      final endDate = DateTime(date.year, date.month, date.day, 23, 59);
      batch.set(_eventsRef.doc('closed_day_$dateKey'), {
        ...details,
        'organizer': 'システム',
        'startDateTime': Timestamp.fromDate(date),
        'endDateTime': Timestamp.fromDate(endDate),
        'imageUrls': const [],
        'capacity': 0,
        'isClosedDay': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  DateTime? _eventDate(Object? value) {
    final date = value is Timestamp ? value.toDate() : value;
    if (date is! DateTime) return null;
    return DateTime(date.year, date.month, date.day);
  }
}

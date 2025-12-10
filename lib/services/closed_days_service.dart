import 'package:cloud_firestore/cloud_firestore.dart';

class ClosedDaysService {
  ClosedDaysService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('events');

  static const int _closedDayColorValue = 0xFF9E9E9E;

  Future<Set<DateTime>> fetchClosedDays({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startTimestamp = Timestamp.fromDate(
      DateTime(startDate.year, startDate.month, startDate.day),
    );
    final endTimestamp = Timestamp.fromDate(
      DateTime(endDate.year, endDate.month, endDate.day).add(
        const Duration(days: 1),
      ),
    );

    final snapshot = await _eventsRef
        .where('startDateTime', isGreaterThanOrEqualTo: startTimestamp)
        .where('startDateTime', isLessThan: endTimestamp)
        .get();

    final Set<DateTime> result = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final isClosed = data['isClosedDay'] == true;
      if (!isClosed) continue;
      final start = data['startDateTime'];
      if (start is Timestamp) {
        result.add(_normalizeDate(start.toDate()));
      } else if (start is DateTime) {
        result.add(_normalizeDate(start));
      }
    }
    return result;
  }

  Future<void> saveClosedDays(Set<DateTime> dates) async {
    final normalizedDates = dates.map(_normalizeDate).toSet();
    final normalizedKeys = normalizedDates.map(_dateKey).toSet();

    final existingSnapshot =
        await _eventsRef.where('isClosedDay', isEqualTo: true).get();
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> existingByKey =
        {};
    for (final doc in existingSnapshot.docs) {
      final data = doc.data();
      final start = data['startDateTime'];
      DateTime? startDate;
      if (start is Timestamp) {
        startDate = _normalizeDate(start.toDate());
      } else if (start is DateTime) {
        startDate = _normalizeDate(start);
      }
      if (startDate != null) {
        existingByKey[_dateKey(startDate)] = doc;
      }
    }

    final WriteBatch batch = _firestore.batch();

    for (final entry in existingByKey.entries) {
      if (!normalizedKeys.contains(entry.key)) {
        batch.delete(entry.value.reference);
      }
    }

    for (final date in normalizedDates) {
      final key = _dateKey(date);
      if (existingByKey.containsKey(key)) continue;
      final docRef = _eventsRef.doc();
      final endDate = date.add(const Duration(hours: 23, minutes: 59));
      batch.set(docRef, {
        'name': '定休日',
        'organizer': 'システム',
        'startDateTime': Timestamp.fromDate(date),
        'endDateTime': Timestamp.fromDate(endDate),
        'content': '定休日のため休業です。',
        'imageUrls': const [],
        'colorValue': _closedDayColorValue,
        'capacity': 0,
        'isClosedDay': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

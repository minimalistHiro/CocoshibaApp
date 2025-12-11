import 'package:cloud_firestore/cloud_firestore.dart';

class PointHistory {
  const PointHistory({
    required this.id,
    required this.description,
    required this.points,
    required this.createdAt,
  });

  final String id;
  final String description;
  final int points;
  final DateTime? createdAt;

  bool get isPositive => points >= 0;

  factory PointHistory.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final description = _stringFromAny(
          data['description'] ?? data['title'] ?? data['reason'] ?? 'ポイント獲得',
        ) ??
        'ポイント獲得';

    final pointsValue = data['points'] ?? data['value'] ?? 0;
    final createdAtRaw = data['createdAt'] ?? data['timestamp'];

    DateTime? createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else if (createdAtRaw is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw);
    }

    return PointHistory(
      id: document.id,
      description: description,
      points: _parsePoints(pointsValue),
      createdAt: createdAt,
    );
  }

  static int _parsePoints(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  static String? _stringFromAny(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString();
  }
}

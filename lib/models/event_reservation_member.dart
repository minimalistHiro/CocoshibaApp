import 'package:cloud_firestore/cloud_firestore.dart';

class EventReservationMember {
  const EventReservationMember({
    required this.userId,
    required this.name,
    this.email,
    this.area,
    this.ageGroup,
    this.photoUrl,
    this.reservedAt,
  });

  final String userId;
  final String name;
  final String? email;
  final String? area;
  final String? ageGroup;
  final String? photoUrl;
  final DateTime? reservedAt;

  factory EventReservationMember.fromReservationData(
    Map<String, dynamic> data,
  ) {
    final rawName = (data['userName'] as String?)?.trim();
    final userId = (data['userId'] as String?) ?? '';
    DateTime? reservedAt;
    final reservedAtValue = data['reservedAt'];
    if (reservedAtValue is Timestamp) {
      reservedAt = reservedAtValue.toDate();
    } else if (reservedAtValue is DateTime) {
      reservedAt = reservedAtValue;
    }

    final resolvedName =
        (rawName != null && rawName.isNotEmpty) ? rawName : '名称未設定';

    return EventReservationMember(
      userId: userId,
      name: resolvedName,
      email: (data['userEmail'] as String?)?.trim(),
      area: (data['userArea'] as String?)?.trim(),
      ageGroup: (data['userAgeGroup'] as String?)?.trim(),
      photoUrl: (data['userPhotoUrl'] as String?)?.trim(),
      reservedAt: reservedAt,
    );
  }
}

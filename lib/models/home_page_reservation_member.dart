import 'package:cloud_firestore/cloud_firestore.dart';

class HomePageReservationMember {
  HomePageReservationMember({
    required this.id,
    this.userId,
    this.userName,
    this.userEmail,
    this.contentTitle,
    this.userReservationId,
    this.reservedDate,
    this.pickupDate,
    this.quantity = 0,
    this.isCompleted = false,
    this.createdAt,
  });

  final String id;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? contentTitle;
  final String? userReservationId;
  final DateTime? reservedDate;
  final DateTime? pickupDate;
  final int quantity;
  final bool isCompleted;
  final DateTime? createdAt;

  factory HomePageReservationMember.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final reservedTimestamp = data['reservedDate'] ?? data['pickupDate'];
    final pickupTimestamp = data['pickupDate'];
    final createdTimestamp = data['createdAt'];
    return HomePageReservationMember(
      id: snapshot.id,
      userId: data['userId'] as String?,
      userName: data['userName'] as String?,
      userEmail: data['userEmail'] as String?,
      contentTitle: data['contentTitle'] as String?,
      userReservationId: data['userReservationId'] as String?,
      reservedDate:
          reservedTimestamp is Timestamp ? reservedTimestamp.toDate() : null,
      pickupDate:
          pickupTimestamp is Timestamp ? pickupTimestamp.toDate() : null,
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      isCompleted: data['isCompleted'] == true,
      createdAt:
          createdTimestamp is Timestamp ? createdTimestamp.toDate() : null,
    );
  }
}

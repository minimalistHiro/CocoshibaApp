import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/owner_permission_member.dart';

class OwnerPermissionService {
  OwnerPermissionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<OwnerPermissionMember>> watchPrivilegedMembers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final members = snapshot.docs.map((doc) {
        final data = doc.data();
        return OwnerPermissionMember.fromMap(doc.id, data);
      }).where((member) => member.isOwner || member.isSubOwner).toList();
      members.sort((a, b) => a.name.compareTo(b.name));
      return members;
    });
  }

  Future<void> updateRole({
    required String userId,
    required OwnerPermissionRole role,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'isOwner': role == OwnerPermissionRole.owner,
      'isSubOwner': role == OwnerPermissionRole.subOwner,
    });
  }

  Future<List<OwnerPermissionMember>> searchMembersByName(
    String keyword,
  ) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return const [];
    final snapshot = await _firestore
        .collection('users')
        .orderBy('name')
        .startAt([trimmed])
        .endAt(['${trimmed}\uf8ff'])
        .limit(20)
        .get();
    return snapshot.docs
        .map((doc) => OwnerPermissionMember.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }
}

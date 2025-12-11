class OwnerPermissionMember {
  const OwnerPermissionMember({
    required this.id,
    required this.name,
    required this.email,
    required this.isOwner,
    required this.isSubOwner,
  });

  final String id;
  final String name;
  final String email;
  final bool isOwner;
  final bool isSubOwner;

  factory OwnerPermissionMember.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawName = (data['name'] as String?)?.trim();
    final rawEmail = (data['email'] as String?)?.trim();
    return OwnerPermissionMember(
      id: id,
      name: rawName == null || rawName.isEmpty ? '名称未設定' : rawName,
      email: rawEmail ?? '',
      isOwner: data['isOwner'] == true,
      isSubOwner: data['isSubOwner'] == true,
    );
  }

  OwnerPermissionRole get role {
    if (isOwner) return OwnerPermissionRole.owner;
    if (isSubOwner) return OwnerPermissionRole.subOwner;
    return OwnerPermissionRole.none;
  }

  OwnerPermissionMember copyWith({
    String? name,
    String? email,
    bool? isOwner,
    bool? isSubOwner,
  }) {
    return OwnerPermissionMember(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      isOwner: isOwner ?? this.isOwner,
      isSubOwner: isSubOwner ?? this.isSubOwner,
    );
  }
}

enum OwnerPermissionRole {
  owner,
  subOwner,
  none,
}

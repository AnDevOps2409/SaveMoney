import 'package:cloud_firestore/cloud_firestore.dart';

class MemberModel {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String role; // 'admin' | 'member'
  final DateTime joinedAt;

  const MemberModel({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.role,
    required this.joinedAt,
  });

  factory MemberModel.fromMap(Map<String, dynamic> map) {
    return MemberModel(
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? 'Thành viên',
      photoUrl: map['photoUrl'],
      role: map['role'] ?? 'member',
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'role': role,
    'joinedAt': Timestamp.fromDate(joinedAt),
  };
}

class FamilyModel {
  final String id;
  final String name;
  final String createdBy;
  final String inviteCode;
  final List<MemberModel> members;
  final DateTime createdAt;

  const FamilyModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.inviteCode,
    required this.members,
    required this.createdAt,
  });

  factory FamilyModel.fromMap(String id, Map<String, dynamic> map) {
    final membersList = (map['members'] as List<dynamic>? ?? [])
        .map((m) => MemberModel.fromMap(m as Map<String, dynamic>))
        .toList();

    return FamilyModel(
      id: id,
      name: map['name'] ?? 'Gia đình của tôi',
      createdBy: map['createdBy'] ?? '',
      inviteCode: map['inviteCode'] ?? '',
      members: membersList,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

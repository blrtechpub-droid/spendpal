
import 'package:cloud_firestore/cloud_firestore.dart';
class GroupModel {
  final String groupId;
  final String name;
  final String type;
  final String createdBy;
  final DateTime createdAt;
  final List<String> members;
  final String? photo; // ✅ Optional group photo URL

  GroupModel({
    required this.groupId,
    required this.name,
    required this.type,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    this.photo,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'name': name,
      'type': type,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'members': members,
      'photo': photo, // ✅ Save photo if provided
    };
  }

    factory GroupModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupModel(
      groupId: doc.id,
      type: data['type'] ?? '',
      name: data['name'] ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      photo: data['photo'], // ✅ Read photo if available
    );
  }

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      groupId: map['groupId'],
      name: map['name'],
      type: map['type'],
      createdBy: map['createdBy'],
      createdAt: DateTime.parse(map['createdAt']),
      members: List<String>.from(map['members']),
    );
  }
}
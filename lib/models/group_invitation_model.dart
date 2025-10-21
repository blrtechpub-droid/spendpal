import 'package:cloud_firestore/cloud_firestore.dart';

class GroupInvitationModel {
  final String invitationId;
  final String groupId;
  final String invitedBy;
  final String invitedUserId;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;
  final DateTime? respondedAt;

  GroupInvitationModel({
    required this.invitationId,
    required this.groupId,
    required this.invitedBy,
    required this.invitedUserId,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory GroupInvitationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupInvitationModel(
      invitationId: doc.id,
      groupId: data['groupId'] ?? '',
      invitedBy: data['invitedBy'] ?? '',
      invitedUserId: data['invitedUserId'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      respondedAt: data['respondedAt'] != null
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'invitedBy': invitedBy,
      'invitedUserId': invitedUserId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class FriendRequestModel {
  final String requestId;
  final String fromUserId;
  final String toUserId;
  final String status; // 'pending', 'accepted', 'rejected'
  final String? nickname; // Optional nickname from sender
  final DateTime createdAt;
  final DateTime? respondedAt;

  FriendRequestModel({
    required this.requestId,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    this.nickname,
    required this.createdAt,
    this.respondedAt,
  });

  factory FriendRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendRequestModel(
      requestId: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      status: data['status'] ?? 'pending',
      nickname: data['nickname'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      respondedAt: data['respondedAt'] != null
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status,
      'nickname': nickname,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }
}

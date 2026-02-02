import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseCommentModel {
  final String commentId;
  final String expenseId;
  final String userId;
  final String text;
  final DateTime createdAt;

  ExpenseCommentModel({
    required this.commentId,
    required this.expenseId,
    required this.userId,
    required this.text,
    required this.createdAt,
  });

  factory ExpenseCommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseCommentModel(
      commentId: doc.id,
      expenseId: data['expenseId'] ?? '',
      userId: data['userId'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'expenseId': expenseId,
      'userId': userId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

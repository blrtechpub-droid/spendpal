import 'package:cloud_firestore/cloud_firestore.dart';

class SavingsGoalModel {
  final String goalId;
  final String userId;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;
  final String? category;
  final DateTime createdAt;
  final bool isCompleted;

  SavingsGoalModel({
    required this.goalId,
    required this.userId,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    this.category,
    required this.createdAt,
    this.isCompleted = false,
  });

  factory SavingsGoalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavingsGoalModel(
      goalId: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      targetAmount: (data['targetAmount'] ?? 0).toDouble(),
      currentAmount: (data['currentAmount'] ?? 0).toDouble(),
      deadline: (data['deadline'] as Timestamp).toDate(),
      category: data['category'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isCompleted: data['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': Timestamp.fromDate(deadline),
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'isCompleted': isCompleted,
    };
  }

  // Calculate progress percentage (0-100)
  double get progressPercentage {
    if (targetAmount <= 0) return 0;
    final progress = (currentAmount / targetAmount) * 100;
    return progress > 100 ? 100 : progress;
  }

  // Calculate remaining amount to reach goal
  double get remainingAmount {
    final remaining = targetAmount - currentAmount;
    return remaining > 0 ? remaining : 0;
  }

  // Check if deadline has passed
  bool get isOverdue {
    return DateTime.now().isAfter(deadline) && !isCompleted;
  }

  // Calculate days remaining until deadline
  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(deadline)) return 0;
    return deadline.difference(now).inDays;
  }

  // Copy with method for updating fields
  SavingsGoalModel copyWith({
    String? goalId,
    String? userId,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    String? category,
    DateTime? createdAt,
    bool? isCompleted,
  }) {
    return SavingsGoalModel(
      goalId: goalId ?? this.goalId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

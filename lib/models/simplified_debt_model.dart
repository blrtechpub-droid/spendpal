import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a simplified debt between two users
/// This is the result of debt simplification algorithm
class SimplifiedDebt {
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final double amount;
  final String? groupId; // null for friend-to-friend debts
  final String? groupName;

  SimplifiedDebt({
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
    this.groupId,
    this.groupName,
  });

  /// Create a display string for the debt
  String get displayString {
    return '$fromUserName owes $toUserName ₹${amount.toStringAsFixed(2)}';
  }

  /// Create a reverse display string (from creditor's perspective)
  String get reverseDisplayString {
    return '$toUserName gets ₹${amount.toStringAsFixed(2)} from $fromUserName';
  }

  @override
  String toString() => displayString;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimplifiedDebt &&
          runtimeType == other.runtimeType &&
          fromUserId == other.fromUserId &&
          toUserId == other.toUserId &&
          amount == other.amount &&
          groupId == other.groupId;

  @override
  int get hashCode =>
      fromUserId.hashCode ^ toUserId.hashCode ^ amount.hashCode ^ groupId.hashCode;
}

/// Summary of all simplified debts for a user
class DebtSummary {
  final String userId;
  final double totalOwed; // Total amount user owes to others
  final double totalOwedToUser; // Total amount others owe to user
  final List<SimplifiedDebt> debtsOwed; // Debts this user owes
  final List<SimplifiedDebt> debtsOwedToUser; // Debts owed to this user
  final double netBalance; // Positive = owed to user, Negative = user owes

  DebtSummary({
    required this.userId,
    required this.totalOwed,
    required this.totalOwedToUser,
    required this.debtsOwed,
    required this.debtsOwedToUser,
  }) : netBalance = totalOwedToUser - totalOwed;

  /// Is this user settled (no debts)?
  bool get isSettled => netBalance.abs() < 0.01;

  /// Is this user a net creditor (others owe them)?
  bool get isCreditor => netBalance > 0.01;

  /// Is this user a net debtor (they owe others)?
  bool get isDebtor => netBalance < -0.01;

  /// Get a human-readable summary
  String get summary {
    if (isSettled) return 'All settled up! 🎉';
    if (isCreditor) return 'You are owed ₹${netBalance.toStringAsFixed(2)}';
    return 'You owe ₹${netBalance.abs().toStringAsFixed(2)}';
  }

  @override
  String toString() => summary;
}

/// Model for a settlement/payment between users
class SettlementModel {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final double amount;
  final DateTime settledAt;
  final String? groupId;
  final String? groupName;
  final String? paymentMethod; // 'cash', 'upi', 'bank_transfer', 'other'
  final String? transactionId; // UPI transaction ID or reference
  final String? notes;
  final bool isVerified; // Has the receiver confirmed?
  final DateTime? verifiedAt;

  SettlementModel({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.amount,
    required this.settledAt,
    this.groupId,
    this.groupName,
    this.paymentMethod,
    this.transactionId,
    this.notes,
    this.isVerified = false,
    this.verifiedAt,
  });

  /// Display string for the settlement
  String get displayString {
    return '$fromUserName paid $toUserName ₹${amount.toStringAsFixed(2)}';
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'amount': amount,
      'settledAt': Timestamp.fromDate(settledAt),
      'groupId': groupId,
      'groupName': groupName,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'notes': notes,
      'isVerified': isVerified,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
    };
  }

  /// Create from Firestore document
  factory SettlementModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SettlementModel(
      id: doc.id,
      fromUserId: data['fromUserId'] as String,
      fromUserName: data['fromUserName'] as String,
      toUserId: data['toUserId'] as String,
      toUserName: data['toUserName'] as String,
      amount: (data['amount'] as num).toDouble(),
      settledAt: (data['settledAt'] as Timestamp).toDate(),
      groupId: data['groupId'] as String?,
      groupName: data['groupName'] as String?,
      paymentMethod: data['paymentMethod'] as String?,
      transactionId: data['transactionId'] as String?,
      notes: data['notes'] as String?,
      isVerified: data['isVerified'] as bool? ?? false,
      verifiedAt: data['verifiedAt'] != null
          ? (data['verifiedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Create a copy with updated fields
  SettlementModel copyWith({
    String? id,
    String? fromUserId,
    String? fromUserName,
    String? toUserId,
    String? toUserName,
    double? amount,
    DateTime? settledAt,
    String? groupId,
    String? groupName,
    String? paymentMethod,
    String? transactionId,
    String? notes,
    bool? isVerified,
    DateTime? verifiedAt,
  }) {
    return SettlementModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      toUserId: toUserId ?? this.toUserId,
      toUserName: toUserName ?? this.toUserName,
      amount: amount ?? this.amount,
      settledAt: settledAt ?? this.settledAt,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      notes: notes ?? this.notes,
      isVerified: isVerified ?? this.isVerified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }

  @override
  String toString() => displayString;
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a liability (loan, credit card, EMI)
/// Used to track debts and calculate net worth
class Liability {
  final String liabilityId;
  final String userId;
  final String name; // e.g., "Home Loan - HDFC", "Car Loan", "Credit Card - SBI"
  final String type; // 'HOME_LOAN', 'CAR_LOAN', 'PERSONAL_LOAN', 'CREDIT_CARD', 'EMI', 'OTHER'
  final double principal; // Original loan amount
  final double currentOutstanding; // Current outstanding amount
  final double interestRate; // Annual interest rate (percentage)
  final int tenureMonths; // Total tenure in months
  final DateTime startDate; // Loan start date
  final DateTime? nextDueDate; // Next EMI due date
  final double emiAmount; // Monthly EMI amount
  final String currency; // Default: 'INR'
  final List<String> tags; // User-defined tags
  final Map<String, dynamic>? metadata; // Additional info (bank name, account number, etc.)
  final DateTime createdAt;
  final DateTime updatedAt;

  Liability({
    required this.liabilityId,
    required this.userId,
    required this.name,
    required this.type,
    required this.principal,
    required this.currentOutstanding,
    required this.interestRate,
    required this.tenureMonths,
    required this.startDate,
    this.nextDueDate,
    required this.emiAmount,
    this.currency = 'INR',
    this.tags = const [],
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'liabilityId': liabilityId,
      'userId': userId,
      'name': name,
      'type': type,
      'principal': principal,
      'currentOutstanding': currentOutstanding,
      'interestRate': interestRate,
      'tenureMonths': tenureMonths,
      'startDate': Timestamp.fromDate(startDate),
      'nextDueDate': nextDueDate != null ? Timestamp.fromDate(nextDueDate!) : null,
      'emiAmount': emiAmount,
      'currency': currency,
      'tags': tags,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create from Firestore document
  factory Liability.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Liability(
      liabilityId: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? 'OTHER',
      principal: (data['principal'] as num?)?.toDouble() ?? 0.0,
      currentOutstanding: (data['currentOutstanding'] as num?)?.toDouble() ?? 0.0,
      interestRate: (data['interestRate'] as num?)?.toDouble() ?? 0.0,
      tenureMonths: data['tenureMonths'] ?? 0,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nextDueDate: (data['nextDueDate'] as Timestamp?)?.toDate(),
      emiAmount: (data['emiAmount'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] ?? 'INR',
      tags: List<String>.from(data['tags'] ?? []),
      metadata: data['metadata'] as Map<String, dynamic>?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  Liability copyWith({
    String? liabilityId,
    String? userId,
    String? name,
    String? type,
    double? principal,
    double? currentOutstanding,
    double? interestRate,
    int? tenureMonths,
    DateTime? startDate,
    DateTime? nextDueDate,
    double? emiAmount,
    String? currency,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Liability(
      liabilityId: liabilityId ?? this.liabilityId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      principal: principal ?? this.principal,
      currentOutstanding: currentOutstanding ?? this.currentOutstanding,
      interestRate: interestRate ?? this.interestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      emiAmount: emiAmount ?? this.emiAmount,
      currency: currency ?? this.currency,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Helper to get liability type display name
  String get typeDisplay {
    switch (type) {
      case 'HOME_LOAN':
        return 'Home Loan';
      case 'CAR_LOAN':
        return 'Car Loan';
      case 'PERSONAL_LOAN':
        return 'Personal Loan';
      case 'CREDIT_CARD':
        return 'Credit Card';
      case 'EMI':
        return 'EMI';
      case 'OTHER':
        return 'Other';
      default:
        return type;
    }
  }

  /// Calculate remaining months
  int get remainingMonths {
    if (currentOutstanding <= 0) return 0;
    if (emiAmount <= 0) return tenureMonths;

    // Simple calculation: remaining / EMI
    // More accurate calculation would factor in interest
    return (currentOutstanding / emiAmount).ceil();
  }

  /// Calculate total interest paid so far
  double get totalInterestPaid {
    final amountPaid = principal - currentOutstanding;
    final monthsElapsed = tenureMonths - remainingMonths;
    final totalPaid = emiAmount * monthsElapsed;
    return totalPaid - amountPaid;
  }

  /// Calculate percentage of loan paid off
  double get percentagePaid {
    if (principal <= 0) return 0.0;
    final amountPaid = principal - currentOutstanding;
    return (amountPaid / principal) * 100;
  }
}

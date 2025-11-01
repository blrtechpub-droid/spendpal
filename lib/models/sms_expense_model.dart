import 'package:cloud_firestore/cloud_firestore.dart';

class SmsExpenseModel {
  final String id;
  final double amount;
  final String merchant;
  final DateTime date;
  final String category;
  final String? accountInfo;
  final String rawSms;
  final String? transactionId;
  final String userId;
  final String status; // 'pending', 'categorized', 'ignored'
  final DateTime parsedAt;
  final DateTime? categorizedAt;
  final String? linkedExpenseId;
  final String smsSender;

  SmsExpenseModel({
    required this.id,
    required this.amount,
    required this.merchant,
    required this.date,
    required this.category,
    this.accountInfo,
    required this.rawSms,
    this.transactionId,
    required this.userId,
    required this.status,
    required this.parsedAt,
    this.categorizedAt,
    this.linkedExpenseId,
    required this.smsSender,
  });

  /// Create from Firestore document
  factory SmsExpenseModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SmsExpenseModel(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      merchant: data['merchant'] as String,
      date: (data['date'] as Timestamp).toDate(),
      category: data['category'] as String? ?? 'Other',
      accountInfo: data['accountInfo'] as String?,
      rawSms: data['rawSms'] as String,
      transactionId: data['transactionId'] as String?,
      userId: data['userId'] as String,
      status: data['status'] as String? ?? 'pending',
      parsedAt: (data['parsedAt'] as Timestamp).toDate(),
      categorizedAt: data['categorizedAt'] != null
          ? (data['categorizedAt'] as Timestamp).toDate()
          : null,
      linkedExpenseId: data['linkedExpenseId'] as String?,
      smsSender: data['smsSender'] as String? ?? 'Unknown',
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'merchant': merchant,
      'date': Timestamp.fromDate(date),
      'category': category,
      'accountInfo': accountInfo,
      'rawSms': rawSms,
      'transactionId': transactionId,
      'userId': userId,
      'status': status,
      'parsedAt': Timestamp.fromDate(parsedAt),
      'categorizedAt':
          categorizedAt != null ? Timestamp.fromDate(categorizedAt!) : null,
      'linkedExpenseId': linkedExpenseId,
      'smsSender': smsSender,
    };
  }

  /// Create a copy with updated fields
  SmsExpenseModel copyWith({
    String? id,
    double? amount,
    String? merchant,
    DateTime? date,
    String? category,
    String? accountInfo,
    String? rawSms,
    String? transactionId,
    String? userId,
    String? status,
    DateTime? parsedAt,
    DateTime? categorizedAt,
    String? linkedExpenseId,
    String? smsSender,
  }) {
    return SmsExpenseModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      category: category ?? this.category,
      accountInfo: accountInfo ?? this.accountInfo,
      rawSms: rawSms ?? this.rawSms,
      transactionId: transactionId ?? this.transactionId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      parsedAt: parsedAt ?? this.parsedAt,
      categorizedAt: categorizedAt ?? this.categorizedAt,
      linkedExpenseId: linkedExpenseId ?? this.linkedExpenseId,
      smsSender: smsSender ?? this.smsSender,
    );
  }

  /// Check if expense is pending categorization
  bool get isPending => status == 'pending';

  /// Check if expense is categorized
  bool get isCategorized => status == 'categorized';

  /// Check if expense is ignored
  bool get isIgnored => status == 'ignored';
}

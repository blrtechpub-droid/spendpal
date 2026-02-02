import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for tracking user's financial accounts
class MoneyTrackerAccount {
  final String accountId;
  final String userId;
  final String accountType; // 'bank', 'credit_card', 'wallet', 'loan'
  final String accountName;
  final double balance; // Current balance for bank, outstanding principal for loan, spent amount for credit card
  final double? creditLimit; // Only for credit cards (total limit) or loans (original principal)
  final String? trackerId; // Linked Account Tracker for auto-sync from SMS/Email

  // Loan-specific fields
  final String? loanType; // 'personal', 'home', 'car', 'education', 'other'
  final double? interestRate; // Interest rate percentage for loans
  final double? emiAmount; // Monthly EMI for loans
  final DateTime? loanStartDate; // Loan start date
  final int? tenureMonths; // Loan tenure in months

  final DateTime lastUpdated;
  final DateTime createdAt;

  MoneyTrackerAccount({
    required this.accountId,
    required this.userId,
    required this.accountType,
    required this.accountName,
    required this.balance,
    this.creditLimit,
    this.trackerId,
    this.loanType,
    this.interestRate,
    this.emiAmount,
    this.loanStartDate,
    this.tenureMonths,
    required this.lastUpdated,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'userId': userId,
      'accountType': accountType,
      'accountName': accountName,
      'balance': balance,
      'creditLimit': creditLimit,
      'trackerId': trackerId,
      'loanType': loanType,
      'interestRate': interestRate,
      'emiAmount': emiAmount,
      'loanStartDate': loanStartDate != null ? Timestamp.fromDate(loanStartDate!) : null,
      'tenureMonths': tenureMonths,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MoneyTrackerAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MoneyTrackerAccount(
      accountId: doc.id,
      userId: data['userId'] ?? '',
      accountType: data['accountType'] ?? 'bank',
      accountName: data['accountName'] ?? '',
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (data['creditLimit'] as num?)?.toDouble(),
      trackerId: data['trackerId'],
      loanType: data['loanType'],
      interestRate: (data['interestRate'] as num?)?.toDouble(),
      emiAmount: (data['emiAmount'] as num?)?.toDouble(),
      loanStartDate: (data['loanStartDate'] as Timestamp?)?.toDate(),
      tenureMonths: data['tenureMonths'],
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  MoneyTrackerAccount copyWith({
    String? accountId,
    String? userId,
    String? accountType,
    String? accountName,
    double? balance,
    double? creditLimit,
    String? trackerId,
    String? loanType,
    double? interestRate,
    double? emiAmount,
    DateTime? loanStartDate,
    int? tenureMonths,
    DateTime? lastUpdated,
    DateTime? createdAt,
  }) {
    return MoneyTrackerAccount(
      accountId: accountId ?? this.accountId,
      userId: userId ?? this.userId,
      accountType: accountType ?? this.accountType,
      accountName: accountName ?? this.accountName,
      balance: balance ?? this.balance,
      creditLimit: creditLimit ?? this.creditLimit,
      trackerId: trackerId ?? this.trackerId,
      loanType: loanType ?? this.loanType,
      interestRate: interestRate ?? this.interestRate,
      emiAmount: emiAmount ?? this.emiAmount,
      loanStartDate: loanStartDate ?? this.loanStartDate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Model for individual transactions detected from SMS
class MoneyTransaction {
  final String transactionId;
  final String userId;
  final String accountId; // Which account this transaction belongs to
  final String type; // 'credit', 'debit'
  final double amount;
  final String? description;
  final String? category;
  final DateTime transactionDate;
  final String source; // 'sms', 'manual'
  final String? rawSmsText; // Original SMS text for reference
  final DateTime createdAt;

  MoneyTransaction({
    required this.transactionId,
    required this.userId,
    required this.accountId,
    required this.type,
    required this.amount,
    this.description,
    this.category,
    required this.transactionDate,
    required this.source,
    this.rawSmsText,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'userId': userId,
      'accountId': accountId,
      'type': type,
      'amount': amount,
      'description': description,
      'category': category,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'source': source,
      'rawSmsText': rawSmsText,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MoneyTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MoneyTransaction(
      transactionId: doc.id,
      userId: data['userId'] ?? '',
      accountId: data['accountId'] ?? '',
      type: data['type'] ?? 'debit',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      description: data['description'],
      category: data['category'],
      transactionDate: (data['transactionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      source: data['source'] ?? 'manual',
      rawSmsText: data['rawSmsText'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Model for monthly salary tracking
class SalaryRecord {
  final String recordId;
  final String userId;
  final double amount;
  final DateTime creditedDate;
  final String? accountId; // Which account salary was credited to
  final String source; // 'sms', 'manual'
  final String? rawSmsText;
  final DateTime createdAt;

  SalaryRecord({
    required this.recordId,
    required this.userId,
    required this.amount,
    required this.creditedDate,
    this.accountId,
    required this.source,
    this.rawSmsText,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'recordId': recordId,
      'userId': userId,
      'amount': amount,
      'creditedDate': Timestamp.fromDate(creditedDate),
      'accountId': accountId,
      'source': source,
      'rawSmsText': rawSmsText,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SalaryRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SalaryRecord(
      recordId: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      creditedDate: (data['creditedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      accountId: data['accountId'],
      source: data['source'] ?? 'manual',
      rawSmsText: data['rawSmsText'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

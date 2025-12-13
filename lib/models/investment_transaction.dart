import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single investment transaction (BUY, SELL, SIP, DIVIDEND, FEE)
/// Used to track the history of all investment activities
class InvestmentTransaction {
  final String txnId;
  final String userId;
  final String assetId;
  final String? holdingId; // Link to holding (if applicable)
  final String type; // 'BUY', 'SELL', 'SIP', 'DIVIDEND', 'FEE'
  final DateTime date;
  final double? quantity; // Number of units/shares (for BUY/SELL/SIP)
  final double? price; // Price per unit (for BUY/SELL/SIP)
  final double amount; // Total transaction amount
  final double fees; // Brokerage/transaction charges
  final String? notes; // User notes
  final String source; // 'MANUAL', 'CSV', 'CAS', 'EMAIL'
  final DateTime createdAt;

  InvestmentTransaction({
    required this.txnId,
    required this.userId,
    required this.assetId,
    this.holdingId,
    required this.type,
    required this.date,
    this.quantity,
    this.price,
    required this.amount,
    this.fees = 0.0,
    this.notes,
    this.source = 'MANUAL',
    required this.createdAt,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'txnId': txnId,
      'userId': userId,
      'assetId': assetId,
      'holdingId': holdingId,
      'type': type,
      'date': Timestamp.fromDate(date),
      'quantity': quantity,
      'price': price,
      'amount': amount,
      'fees': fees,
      'notes': notes,
      'source': source,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create from Firestore document
  factory InvestmentTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InvestmentTransaction(
      txnId: doc.id,
      userId: data['userId'] ?? '',
      assetId: data['assetId'] ?? '',
      holdingId: data['holdingId'],
      type: data['type'] ?? 'BUY',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      quantity: (data['quantity'] as num?)?.toDouble(),
      price: (data['price'] as num?)?.toDouble(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      fees: (data['fees'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'],
      source: data['source'] ?? 'MANUAL',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  InvestmentTransaction copyWith({
    String? txnId,
    String? userId,
    String? assetId,
    String? holdingId,
    String? type,
    DateTime? date,
    double? quantity,
    double? price,
    double? amount,
    double? fees,
    String? notes,
    String? source,
    DateTime? createdAt,
  }) {
    return InvestmentTransaction(
      txnId: txnId ?? this.txnId,
      userId: userId ?? this.userId,
      assetId: assetId ?? this.assetId,
      holdingId: holdingId ?? this.holdingId,
      type: type ?? this.type,
      date: date ?? this.date,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      amount: amount ?? this.amount,
      fees: fees ?? this.fees,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Whether this transaction increases holdings (BUY, SIP)
  bool get isAcquisition => type == 'BUY' || type == 'SIP';

  /// Whether this transaction decreases holdings (SELL)
  bool get isDisposal => type == 'SELL';

  /// Whether this transaction generates income (DIVIDEND)
  bool get isIncome => type == 'DIVIDEND';

  /// Whether this transaction is a cost (FEE)
  bool get isCost => type == 'FEE';

  /// Helper to get transaction type display name
  String get typeDisplay {
    switch (type) {
      case 'BUY':
        return 'Buy';
      case 'SELL':
        return 'Sell';
      case 'SIP':
        return 'SIP';
      case 'DIVIDEND':
        return 'Dividend';
      case 'FEE':
        return 'Fee';
      default:
        return type;
    }
  }

  /// Helper to get transaction source display name
  String get sourceDisplay {
    switch (source) {
      case 'MANUAL':
        return 'Manual Entry';
      case 'CSV':
        return 'CSV Import';
      case 'CAS':
        return 'CAS Import';
      case 'EMAIL':
        return 'Email Parse';
      default:
        return source;
    }
  }

  /// For XIRR calculation: cashflow amount (negative for investments, positive for returns)
  /// BUY/SIP/FEE: negative (money out)
  /// SELL/DIVIDEND: positive (money in)
  double get xirrCashflow {
    if (isAcquisition || isCost) {
      return -(amount + fees);
    } else if (isDisposal || isIncome) {
      return amount - fees;
    }
    return 0.0;
  }

  /// Format amount with sign for display
  String get amountDisplay {
    final sign = (isAcquisition || isCost) ? '-' : '+';
    return '$sign₹${amount.toStringAsFixed(2)}';
  }
}

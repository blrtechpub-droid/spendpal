import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the current holding/position in an investment asset
/// Tracks quantity, average price, current value, and profit/loss
class InvestmentHolding {
  final String holdingId;
  final String userId;
  final String assetId;
  final double quantity; // Number of units/shares held
  final double avgPrice; // Average purchase price per unit
  final double? currentPrice; // Latest market price (nullable for manual update)
  final DateTime lastUpdatedAt;

  InvestmentHolding({
    required this.holdingId,
    required this.userId,
    required this.assetId,
    required this.quantity,
    required this.avgPrice,
    this.currentPrice,
    required this.lastUpdatedAt,
  });

  /// Current value of the holding (quantity * currentPrice)
  double get currentValue => currentPrice != null ? quantity * currentPrice! : 0.0;

  /// Total invested amount (quantity * avgPrice)
  double get investedAmount => quantity * avgPrice;

  /// Unrealized profit/loss in absolute value
  double get unrealizedPL => currentValue - investedAmount;

  /// Unrealized profit/loss as percentage
  double get unrealizedPLPercent {
    if (investedAmount == 0) return 0.0;
    return (unrealizedPL / investedAmount) * 100;
  }

  /// Whether price data is available
  bool get hasPriceData => currentPrice != null && currentPrice! > 0;

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'holdingId': holdingId,
      'userId': userId,
      'assetId': assetId,
      'quantity': quantity,
      'avgPrice': avgPrice,
      'currentPrice': currentPrice,
      'currentValue': currentValue,
      'investedAmount': investedAmount,
      'unrealizedPL': unrealizedPL,
      'unrealizedPLPercent': unrealizedPLPercent,
      'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
    };
  }

  /// Create from Firestore document
  factory InvestmentHolding.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InvestmentHolding(
      holdingId: doc.id,
      userId: data['userId'] ?? '',
      assetId: data['assetId'] ?? '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      avgPrice: (data['avgPrice'] as num?)?.toDouble() ?? 0.0,
      currentPrice: (data['currentPrice'] as num?)?.toDouble(),
      lastUpdatedAt: (data['lastUpdatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  InvestmentHolding copyWith({
    String? holdingId,
    String? userId,
    String? assetId,
    double? quantity,
    double? avgPrice,
    double? currentPrice,
    DateTime? lastUpdatedAt,
  }) {
    return InvestmentHolding(
      holdingId: holdingId ?? this.holdingId,
      userId: userId ?? this.userId,
      assetId: assetId ?? this.assetId,
      quantity: quantity ?? this.quantity,
      avgPrice: avgPrice ?? this.avgPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  /// Calculate new average price after a BUY transaction
  /// Formula: (existingQty * existingAvg + newQty * newPrice) / (existingQty + newQty)
  static double calculateNewAvgPrice({
    required double existingQty,
    required double existingAvg,
    required double newQty,
    required double newPrice,
  }) {
    if (existingQty + newQty == 0) return 0.0;
    return ((existingQty * existingAvg) + (newQty * newPrice)) / (existingQty + newQty);
  }

  /// Helper to format P/L with sign and color indicator
  String get plDisplay {
    final sign = unrealizedPL >= 0 ? '+' : '';
    return '$sign₹${unrealizedPL.toStringAsFixed(2)}';
  }

  /// Helper to format P/L percentage with sign
  String get plPercentDisplay {
    final sign = unrealizedPLPercent >= 0 ? '+' : '';
    return '$sign${unrealizedPLPercent.toStringAsFixed(2)}%';
  }
}

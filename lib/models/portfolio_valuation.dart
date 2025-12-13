import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a daily snapshot of the entire investment portfolio
/// Used for tracking net worth over time and generating analytics
class PortfolioValuation {
  final String valuationId; // YYYYMMDD format (e.g., "20250109")
  final String userId;
  final DateTime date;
  final Map<String, double> totals; // { netWorth, equity, mutualFund, fd, rd, gold }
  final Map<String, double> assetBreakdown; // Map<assetId, currentValue>
  final double totalInvested; // Total amount invested
  final double totalCurrent; // Total current value
  final double totalPL; // Total profit/loss (absolute)
  final double totalPLPercent; // Total P/L percentage

  PortfolioValuation({
    required this.valuationId,
    required this.userId,
    required this.date,
    required this.totals,
    required this.assetBreakdown,
    required this.totalInvested,
    required this.totalCurrent,
    required this.totalPL,
    required this.totalPLPercent,
  });

  /// Convenience getter for net worth
  double get netWorth => totals['netWorth'] ?? 0.0;

  /// Convenience getter for equity holdings value
  double get equityValue => (totals['equity'] ?? 0.0) + (totals['etf'] ?? 0.0);

  /// Convenience getter for mutual fund holdings value
  double get mutualFundValue => totals['mutualFund'] ?? 0.0;

  /// Convenience getter for debt instruments value (FD, RD)
  double get debtValue => (totals['fd'] ?? 0.0) + (totals['rd'] ?? 0.0);

  /// Convenience getter for gold holdings value
  double get goldValue => totals['gold'] ?? 0.0;

  /// Get asset allocation percentages
  Map<String, double> get allocationPercents {
    if (netWorth == 0) {
      return {
        'equity': 0.0,
        'mutualFund': 0.0,
        'debt': 0.0,
        'gold': 0.0,
      };
    }

    return {
      'equity': (equityValue / netWorth) * 100,
      'mutualFund': (mutualFundValue / netWorth) * 100,
      'debt': (debtValue / netWorth) * 100,
      'gold': (goldValue / netWorth) * 100,
    };
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'valuationId': valuationId,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'totals': totals,
      'assetBreakdown': assetBreakdown,
      'totalInvested': totalInvested,
      'totalCurrent': totalCurrent,
      'totalPL': totalPL,
      'totalPLPercent': totalPLPercent,
    };
  }

  /// Create from Firestore document
  factory PortfolioValuation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Convert totals map
    final totalsData = data['totals'] as Map<String, dynamic>? ?? {};
    final totals = <String, double>{};
    totalsData.forEach((key, value) {
      totals[key] = (value as num?)?.toDouble() ?? 0.0;
    });

    // Convert asset breakdown map
    final breakdownData = data['assetBreakdown'] as Map<String, dynamic>? ?? {};
    final assetBreakdown = <String, double>{};
    breakdownData.forEach((key, value) {
      assetBreakdown[key] = (value as num?)?.toDouble() ?? 0.0;
    });

    return PortfolioValuation(
      valuationId: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totals: totals,
      assetBreakdown: assetBreakdown,
      totalInvested: (data['totalInvested'] as num?)?.toDouble() ?? 0.0,
      totalCurrent: (data['totalCurrent'] as num?)?.toDouble() ?? 0.0,
      totalPL: (data['totalPL'] as num?)?.toDouble() ?? 0.0,
      totalPLPercent: (data['totalPLPercent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Create a copy with updated fields
  PortfolioValuation copyWith({
    String? valuationId,
    String? userId,
    DateTime? date,
    Map<String, double>? totals,
    Map<String, double>? assetBreakdown,
    double? totalInvested,
    double? totalCurrent,
    double? totalPL,
    double? totalPLPercent,
  }) {
    return PortfolioValuation(
      valuationId: valuationId ?? this.valuationId,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      totals: totals ?? this.totals,
      assetBreakdown: assetBreakdown ?? this.assetBreakdown,
      totalInvested: totalInvested ?? this.totalInvested,
      totalCurrent: totalCurrent ?? this.totalCurrent,
      totalPL: totalPL ?? this.totalPL,
      totalPLPercent: totalPLPercent ?? this.totalPLPercent,
    );
  }

  /// Helper to generate valuation ID from date (YYYYMMDD format)
  static String generateId(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// Helper to format P/L with sign
  String get plDisplay {
    final sign = totalPL >= 0 ? '+' : '';
    return '$sign₹${totalPL.toStringAsFixed(2)}';
  }

  /// Helper to format P/L percentage with sign
  String get plPercentDisplay {
    final sign = totalPLPercent >= 0 ? '+' : '';
    return '$sign${totalPLPercent.toStringAsFixed(2)}%';
  }

  /// Helper to format net worth compactly (e.g., "₹1.2L", "₹5.3K")
  String get netWorthCompact {
    if (netWorth >= 10000000) {
      // Crores
      return '₹${(netWorth / 10000000).toStringAsFixed(2)}Cr';
    } else if (netWorth >= 100000) {
      // Lakhs
      return '₹${(netWorth / 100000).toStringAsFixed(2)}L';
    } else if (netWorth >= 1000) {
      // Thousands
      return '₹${(netWorth / 1000).toStringAsFixed(1)}K';
    } else {
      return '₹${netWorth.toStringAsFixed(0)}';
    }
  }
}

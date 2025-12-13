import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/investment_holding.dart';
import 'package:spendpal/models/investment_asset.dart';
import 'package:spendpal/models/portfolio_valuation.dart';

/// Service for calculating and managing portfolio valuations
/// Responsible for creating daily snapshots of portfolio performance
class ValuationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate current portfolio valuation for a user
  /// Aggregates all holdings and computes totals by asset type
  Future<Map<String, dynamic>> calculateCurrentValuation({
    required String userId,
  }) async {
    try {
      // Fetch all holdings for user
      final holdingsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentHoldings')
          .get();

      if (holdingsSnapshot.docs.isEmpty) {
        return _emptyValuation();
      }

      // Fetch all assets to get asset types
      final assetsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentAssets')
          .get();

      final assetsMap = <String, InvestmentAsset>{};
      for (final doc in assetsSnapshot.docs) {
        final asset = InvestmentAsset.fromFirestore(doc);
        assetsMap[asset.assetId] = asset;
      }

      // Calculate totals
      final totals = <String, double>{
        'netWorth': 0.0,
        'equity': 0.0,
        'etf': 0.0,
        'mutualFund': 0.0,
        'fd': 0.0,
        'rd': 0.0,
        'gold': 0.0,
      };

      final assetBreakdown = <String, double>{};
      double totalInvested = 0.0;
      double totalCurrent = 0.0;

      // Process each holding
      for (final doc in holdingsSnapshot.docs) {
        final holding = InvestmentHolding.fromFirestore(doc);
        final asset = assetsMap[holding.assetId];

        if (asset == null) continue;

        final currentValue = holding.currentValue;
        final investedAmount = holding.investedAmount;

        // Add to asset breakdown
        assetBreakdown[holding.assetId] = currentValue;

        // Add to category totals
        final assetType = asset.assetType;
        totals[assetType] = (totals[assetType] ?? 0.0) + currentValue;

        // Add to overall totals
        totalInvested += investedAmount;
        totalCurrent += currentValue;
      }

      // Calculate net worth (sum of all categories)
      totals['netWorth'] = totalCurrent;

      // Calculate total P/L
      final totalPL = totalCurrent - totalInvested;
      final totalPLPercent = totalInvested > 0
          ? (totalPL / totalInvested) * 100
          : 0.0;

      return {
        'totals': totals,
        'assetBreakdown': assetBreakdown,
        'totalInvested': totalInvested,
        'totalCurrent': totalCurrent,
        'totalPL': totalPL,
        'totalPLPercent': totalPLPercent,
      };
    } catch (e) {
      print('Error calculating valuation: $e');
      return _emptyValuation();
    }
  }

  /// Create and save a portfolio valuation snapshot for today
  Future<PortfolioValuation?> createTodayValuation({
    required String userId,
  }) async {
    try {
      final today = DateTime.now();
      final valuationId = PortfolioValuation.generateId(today);

      // Check if valuation already exists for today
      final existingDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolioValuations')
          .doc(valuationId)
          .get();

      if (existingDoc.exists) {
        // Return existing valuation
        return PortfolioValuation.fromFirestore(existingDoc);
      }

      // Calculate current valuation
      final valuation = await calculateCurrentValuation(userId: userId);

      // Create PortfolioValuation object
      final portfolioValuation = PortfolioValuation(
        valuationId: valuationId,
        userId: userId,
        date: today,
        totals: valuation['totals'] as Map<String, double>,
        assetBreakdown: valuation['assetBreakdown'] as Map<String, double>,
        totalInvested: valuation['totalInvested'] as double,
        totalCurrent: valuation['totalCurrent'] as double,
        totalPL: valuation['totalPL'] as double,
        totalPLPercent: valuation['totalPLPercent'] as double,
      );

      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolioValuations')
          .doc(valuationId)
          .set(portfolioValuation.toMap());

      return portfolioValuation;
    } catch (e) {
      print('Error creating valuation: $e');
      return null;
    }
  }

  /// Get the latest portfolio valuation
  Future<PortfolioValuation?> getLatestValuation({
    required String userId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolioValuations')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return PortfolioValuation.fromFirestore(snapshot.docs.first);
    } catch (e) {
      print('Error getting latest valuation: $e');
      return null;
    }
  }

  /// Get portfolio valuations for a date range
  /// Useful for generating charts and analytics
  Future<List<PortfolioValuation>> getValuationsInRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolioValuations')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => PortfolioValuation.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting valuations in range: $e');
      return [];
    }
  }

  /// Get valuations for the last N days
  Future<List<PortfolioValuation>> getRecentValuations({
    required String userId,
    int days = 30,
  }) async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    return getValuationsInRange(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Calculate portfolio performance metrics over time
  /// Returns growth rate, volatility, and other metrics
  Future<Map<String, dynamic>> calculatePerformanceMetrics({
    required String userId,
    int days = 30,
  }) async {
    try {
      final valuations = await getRecentValuations(userId: userId, days: days);

      if (valuations.isEmpty) {
        return {
          'hasData': false,
        };
      }

      // Calculate metrics
      final firstValuation = valuations.first;
      final lastValuation = valuations.last;

      final initialValue = firstValuation.totalCurrent;
      final finalValue = lastValuation.totalCurrent;

      final absoluteGrowth = finalValue - initialValue;
      final percentageGrowth = initialValue > 0
          ? (absoluteGrowth / initialValue) * 100
          : 0.0;

      // Calculate average daily change
      final dailyChanges = <double>[];
      for (int i = 1; i < valuations.length; i++) {
        final prevValue = valuations[i - 1].totalCurrent;
        final currValue = valuations[i].totalCurrent;
        final change = currValue - prevValue;
        dailyChanges.add(change);
      }

      final avgDailyChange = dailyChanges.isNotEmpty
          ? dailyChanges.reduce((a, b) => a + b) / dailyChanges.length
          : 0.0;

      // Calculate volatility (standard deviation of daily changes)
      double volatility = 0.0;
      if (dailyChanges.length > 1) {
        final variance = dailyChanges
            .map((change) => (change - avgDailyChange) * (change - avgDailyChange))
            .reduce((a, b) => a + b) / dailyChanges.length;
        volatility = variance > 0 ? variance : 0.0;
      }

      // Find peak and trough
      final allValues = valuations.map((v) => v.totalCurrent).toList();
      final peakValue = allValues.reduce((a, b) => a > b ? a : b);
      final troughValue = allValues.reduce((a, b) => a < b ? a : b);

      return {
        'hasData': true,
        'period': days,
        'initialValue': initialValue,
        'finalValue': finalValue,
        'absoluteGrowth': absoluteGrowth,
        'percentageGrowth': percentageGrowth,
        'avgDailyChange': avgDailyChange,
        'volatility': volatility,
        'peakValue': peakValue,
        'troughValue': troughValue,
        'dataPoints': valuations.length,
      };
    } catch (e) {
      print('Error calculating performance metrics: $e');
      return {'hasData': false};
    }
  }

  /// Delete old valuations (keep last N days)
  /// Useful for cleaning up historical data
  Future<void> cleanupOldValuations({
    required String userId,
    int keepDays = 365,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolioValuations')
          .where('date', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      print('Cleaned up ${snapshot.docs.length} old valuations');
    } catch (e) {
      print('Error cleaning up valuations: $e');
    }
  }

  /// Stream portfolio valuations in real-time
  Stream<List<PortfolioValuation>> streamRecentValuations({
    required String userId,
    int days = 30,
  }) {
    final startDate = DateTime.now().subtract(Duration(days: days));

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('portfolioValuations')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PortfolioValuation.fromFirestore(doc))
          .toList();
    });
  }

  /// Get asset allocation breakdown
  /// Returns percentage distribution by asset type
  Future<Map<String, double>> getAssetAllocation({
    required String userId,
  }) async {
    try {
      final valuation = await calculateCurrentValuation(userId: userId);
      final totals = valuation['totals'] as Map<String, double>;
      final netWorth = totals['netWorth'] ?? 0.0;

      if (netWorth == 0) {
        return {
          'equity': 0.0,
          'etf': 0.0,
          'mutualFund': 0.0,
          'fd': 0.0,
          'rd': 0.0,
          'gold': 0.0,
        };
      }

      return {
        'equity': ((totals['equity'] ?? 0.0) / netWorth) * 100,
        'etf': ((totals['etf'] ?? 0.0) / netWorth) * 100,
        'mutualFund': ((totals['mutualFund'] ?? 0.0) / netWorth) * 100,
        'fd': ((totals['fd'] ?? 0.0) / netWorth) * 100,
        'rd': ((totals['rd'] ?? 0.0) / netWorth) * 100,
        'gold': ((totals['gold'] ?? 0.0) / netWorth) * 100,
      };
    } catch (e) {
      print('Error calculating asset allocation: $e');
      return {};
    }
  }

  /// Helper to return empty valuation structure
  Map<String, dynamic> _emptyValuation() {
    return {
      'totals': <String, double>{
        'netWorth': 0.0,
        'equity': 0.0,
        'etf': 0.0,
        'mutualFund': 0.0,
        'fd': 0.0,
        'rd': 0.0,
        'gold': 0.0,
      },
      'assetBreakdown': <String, double>{},
      'totalInvested': 0.0,
      'totalCurrent': 0.0,
      'totalPL': 0.0,
      'totalPLPercent': 0.0,
    };
  }
}

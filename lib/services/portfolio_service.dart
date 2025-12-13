import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/investment_asset.dart';
import 'package:spendpal/models/investment_holding.dart';
import 'package:spendpal/models/investment_transaction.dart';
import 'package:spendpal/services/xirr_service.dart';

/// Service for portfolio-level operations
/// Handles asset queries, portfolio summaries, and analytics
class PortfolioService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all investment assets for a user
  Future<List<InvestmentAsset>> getAssets({
    required String userId,
    String? assetType, // Filter by type if specified
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentAssets');

      if (assetType != null) {
        query = query.where('assetType', isEqualTo: assetType);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => InvestmentAsset.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting assets: $e');
      return [];
    }
  }

  /// Get all holdings for a user
  Future<List<InvestmentHolding>> getHoldings({
    required String userId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentHoldings')
          .get();

      return snapshot.docs
          .map((doc) => InvestmentHolding.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting holdings: $e');
      return [];
    }
  }

  /// Get holding for a specific asset
  Future<InvestmentHolding?> getHoldingForAsset({
    required String userId,
    required String assetId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentHoldings')
          .where('assetId', isEqualTo: assetId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return InvestmentHolding.fromFirestore(snapshot.docs.first);
    } catch (e) {
      print('Error getting holding: $e');
      return null;
    }
  }

  /// Get complete portfolio summary with asset details
  /// Combines assets, holdings, and latest prices
  Future<Map<String, dynamic>> getPortfolioSummary({
    required String userId,
  }) async {
    try {
      // Fetch assets and holdings
      final assets = await getAssets(userId: userId);
      final holdings = await getHoldings(userId: userId);

      // Create asset map for quick lookup
      final assetMap = <String, InvestmentAsset>{};
      for (final asset in assets) {
        assetMap[asset.assetId] = asset;
      }

      // Build portfolio items (asset + holding)
      final portfolioItems = <Map<String, dynamic>>[];
      double totalInvested = 0.0;
      double totalCurrent = 0.0;

      for (final holding in holdings) {
        final asset = assetMap[holding.assetId];
        if (asset == null) continue;

        totalInvested += holding.investedAmount;
        totalCurrent += holding.currentValue;

        portfolioItems.add({
          'asset': asset,
          'holding': holding,
          'name': asset.name,
          'assetType': asset.assetType,
          'quantity': holding.quantity,
          'avgPrice': holding.avgPrice,
          'currentPrice': holding.currentPrice,
          'investedAmount': holding.investedAmount,
          'currentValue': holding.currentValue,
          'unrealizedPL': holding.unrealizedPL,
          'unrealizedPLPercent': holding.unrealizedPLPercent,
        });
      }

      // Sort by current value (descending)
      portfolioItems.sort((a, b) =>
          (b['currentValue'] as double).compareTo(a['currentValue'] as double));

      // Calculate overall P/L
      final totalPL = totalCurrent - totalInvested;
      final totalPLPercent = totalInvested > 0
          ? (totalPL / totalInvested) * 100
          : 0.0;

      return {
        'portfolioItems': portfolioItems,
        'totalInvested': totalInvested,
        'totalCurrent': totalCurrent,
        'totalPL': totalPL,
        'totalPLPercent': totalPLPercent,
        'itemCount': portfolioItems.length,
      };
    } catch (e) {
      print('Error getting portfolio summary: $e');
      return {
        'portfolioItems': [],
        'totalInvested': 0.0,
        'totalCurrent': 0.0,
        'totalPL': 0.0,
        'totalPLPercent': 0.0,
        'itemCount': 0,
      };
    }
  }

  /// Get portfolio summary grouped by asset type
  Future<Map<String, dynamic>> getPortfolioByAssetType({
    required String userId,
  }) async {
    try {
      final summary = await getPortfolioSummary(userId: userId);
      final portfolioItems = summary['portfolioItems'] as List<Map<String, dynamic>>;

      // Group by asset type
      final grouped = <String, Map<String, dynamic>>{};

      for (final item in portfolioItems) {
        final assetType = item['assetType'] as String;

        if (!grouped.containsKey(assetType)) {
          grouped[assetType] = {
            'assetType': assetType,
            'items': <Map<String, dynamic>>[],
            'totalInvested': 0.0,
            'totalCurrent': 0.0,
            'totalPL': 0.0,
            'count': 0,
          };
        }

        grouped[assetType]!['items'].add(item);
        grouped[assetType]!['totalInvested'] += item['investedAmount'] as double;
        grouped[assetType]!['totalCurrent'] += item['currentValue'] as double;
        grouped[assetType]!['totalPL'] += item['unrealizedPL'] as double;
        grouped[assetType]!['count'] = (grouped[assetType]!['count'] as int) + 1;
      }

      // Calculate percentages for each group
      for (final group in grouped.values) {
        final invested = group['totalInvested'] as double;
        final pl = group['totalPL'] as double;
        group['totalPLPercent'] = invested > 0 ? (pl / invested) * 100 : 0.0;
      }

      return {
        'groups': grouped,
        'totalInvested': summary['totalInvested'],
        'totalCurrent': summary['totalCurrent'],
        'totalPL': summary['totalPL'],
        'totalPLPercent': summary['totalPLPercent'],
      };
    } catch (e) {
      print('Error grouping portfolio: $e');
      return {
        'groups': {},
        'totalInvested': 0.0,
        'totalCurrent': 0.0,
        'totalPL': 0.0,
        'totalPLPercent': 0.0,
      };
    }
  }

  /// Get detailed asset performance including XIRR
  Future<Map<String, dynamic>> getAssetPerformance({
    required String userId,
    required String assetId,
  }) async {
    try {
      // Get asset
      final assetDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentAssets')
          .doc(assetId)
          .get();

      if (!assetDoc.exists) {
        return {'hasData': false, 'error': 'Asset not found'};
      }

      final asset = InvestmentAsset.fromFirestore(assetDoc);

      // Get holding
      final holding = await getHoldingForAsset(userId: userId, assetId: assetId);

      if (holding == null) {
        return {
          'hasData': false,
          'asset': asset,
          'error': 'No holding found for this asset',
        };
      }

      // Get all transactions for this asset
      final txnSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentTransactions')
          .where('assetId', isEqualTo: assetId)
          .orderBy('date', descending: false)
          .get();

      final transactions = txnSnapshot.docs
          .map((doc) => InvestmentTransaction.fromFirestore(doc))
          .toList();

      // Calculate XIRR
      double? xirr;
      if (transactions.isNotEmpty && holding.currentValue > 0) {
        final cashflows = transactions.map((t) => t.xirrCashflow).toList();
        final dates = transactions.map((t) => t.date).toList();

        // Add current value as final cashflow
        cashflows.add(holding.currentValue);
        dates.add(DateTime.now());

        xirr = XirrService.calculateXirr(
          cashflows: cashflows,
          dates: dates,
        );
      }

      // Get returns summary
      final returnsSummary = XirrService.calculateReturnsSummary(
        totalInvested: holding.investedAmount,
        currentValue: holding.currentValue,
        firstTransactionDate: transactions.isNotEmpty ? transactions.first.date : null,
        currentDate: DateTime.now(),
        xirr: xirr,
      );

      return {
        'hasData': true,
        'asset': asset,
        'holding': holding,
        'transactions': transactions,
        'transactionCount': transactions.length,
        'xirr': xirr,
        'returnsSummary': returnsSummary,
      };
    } catch (e) {
      print('Error getting asset performance: $e');
      return {'hasData': false, 'error': e.toString()};
    }
  }

  /// Get top performing assets
  Future<List<Map<String, dynamic>>> getTopPerformers({
    required String userId,
    int limit = 5,
    bool sortByPercent = true, // true: by %, false: by absolute
  }) async {
    try {
      final summary = await getPortfolioSummary(userId: userId);
      final portfolioItems = summary['portfolioItems'] as List<Map<String, dynamic>>;

      // Filter items with positive returns
      final performers = portfolioItems
          .where((item) => (item['unrealizedPL'] as double) > 0)
          .toList();

      // Sort
      if (sortByPercent) {
        performers.sort((a, b) => (b['unrealizedPLPercent'] as double)
            .compareTo(a['unrealizedPLPercent'] as double));
      } else {
        performers.sort((a, b) => (b['unrealizedPL'] as double)
            .compareTo(a['unrealizedPL'] as double));
      }

      return performers.take(limit).toList();
    } catch (e) {
      print('Error getting top performers: $e');
      return [];
    }
  }

  /// Get worst performing assets
  Future<List<Map<String, dynamic>>> getWorstPerformers({
    required String userId,
    int limit = 5,
  }) async {
    try {
      final summary = await getPortfolioSummary(userId: userId);
      final portfolioItems = summary['portfolioItems'] as List<Map<String, dynamic>>;

      // Filter items with negative returns
      final performers = portfolioItems
          .where((item) => (item['unrealizedPL'] as double) < 0)
          .toList();

      // Sort by P/L percent (ascending, worst first)
      performers.sort((a, b) => (a['unrealizedPLPercent'] as double)
          .compareTo(b['unrealizedPLPercent'] as double));

      return performers.take(limit).toList();
    } catch (e) {
      print('Error getting worst performers: $e');
      return [];
    }
  }

  /// Stream portfolio summary in real-time
  Stream<Map<String, dynamic>> streamPortfolioSummary({
    required String userId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('investmentHoldings')
        .snapshots()
        .asyncMap((_) => getPortfolioSummary(userId: userId));
  }

  /// Search assets by name or symbol
  Future<List<InvestmentAsset>> searchAssets({
    required String userId,
    required String query,
  }) async {
    try {
      // Get all assets (Firestore doesn't support full-text search)
      final assets = await getAssets(userId: userId);

      // Filter locally
      final lowerQuery = query.toLowerCase();
      return assets.where((asset) {
        return asset.name.toLowerCase().contains(lowerQuery) ||
            (asset.symbol?.toLowerCase().contains(lowerQuery) ?? false) ||
            (asset.schemeCode?.contains(query) ?? false);
      }).toList();
    } catch (e) {
      print('Error searching assets: $e');
      return [];
    }
  }

  /// Get portfolio statistics
  Future<Map<String, dynamic>> getPortfolioStats({
    required String userId,
  }) async {
    try {
      final summary = await getPortfolioSummary(userId: userId);
      final portfolioItems = summary['portfolioItems'] as List<Map<String, dynamic>>;

      if (portfolioItems.isEmpty) {
        return {'hasData': false};
      }

      // Count winners and losers
      int winners = 0;
      int losers = 0;
      int neutral = 0;

      for (final item in portfolioItems) {
        final pl = item['unrealizedPL'] as double;
        if (pl > 0) {
          winners++;
        } else if (pl < 0) {
          losers++;
        } else {
          neutral++;
        }
      }

      // Calculate average return
      final avgReturn = portfolioItems.isNotEmpty
          ? portfolioItems
                  .map((item) => item['unrealizedPLPercent'] as double)
                  .reduce((a, b) => a + b) /
              portfolioItems.length
          : 0.0;

      // Find highest and lowest return
      final returns = portfolioItems
          .map((item) => item['unrealizedPLPercent'] as double)
          .toList();
      final highestReturn = returns.isNotEmpty
          ? returns.reduce((a, b) => a > b ? a : b)
          : 0.0;
      final lowestReturn = returns.isNotEmpty
          ? returns.reduce((a, b) => a < b ? a : b)
          : 0.0;

      return {
        'hasData': true,
        'totalAssets': portfolioItems.length,
        'winners': winners,
        'losers': losers,
        'neutral': neutral,
        'winRate': portfolioItems.length > 0
            ? (winners / portfolioItems.length) * 100
            : 0.0,
        'avgReturn': avgReturn,
        'highestReturn': highestReturn,
        'lowestReturn': lowestReturn,
        'totalInvested': summary['totalInvested'],
        'totalCurrent': summary['totalCurrent'],
        'totalPL': summary['totalPL'],
        'totalPLPercent': summary['totalPLPercent'],
      };
    } catch (e) {
      print('Error calculating stats: $e');
      return {'hasData': false};
    }
  }
}

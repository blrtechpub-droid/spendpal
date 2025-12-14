import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/investment_asset.dart';
import 'package:spendpal/models/investment_holding.dart';
import 'package:spendpal/models/investment_transaction.dart';

/// Service for managing investment transactions and holdings
/// Handles transaction creation, holding updates, and price management
class InvestmentTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new investment asset
  Future<InvestmentAsset?> createAsset({
    required String userId,
    required String assetType,
    required String name,
    String? symbol,
    String? schemeCode,
    String? platform,
    List<String> tags = const [],
  }) async {
    try {
      final assetRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentAssets')
          .doc();

      final asset = InvestmentAsset(
        assetId: assetRef.id,
        userId: userId,
        assetType: assetType,
        name: name,
        symbol: symbol,
        schemeCode: schemeCode,
        platform: platform,
        tags: tags,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await assetRef.set(asset.toMap());

      return asset;
    } catch (e) {
      print('Error creating asset: $e');
      return null;
    }
  }

  /// Add a BUY transaction
  /// Creates or updates holding with weighted average price
  Future<InvestmentTransaction?> addBuyTransaction({
    required String userId,
    required String assetId,
    required DateTime date,
    required double quantity,
    required double price,
    double fees = 0.0,
    String? notes,
    String source = 'MANUAL',
  }) async {
    try {
      final amount = quantity * price;

      // Create transaction
      final txnRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentTransactions')
          .doc();

      final transaction = InvestmentTransaction(
        txnId: txnRef.id,
        userId: userId,
        assetId: assetId,
        type: 'BUY',
        date: date,
        quantity: quantity,
        price: price,
        amount: amount,
        fees: fees,
        notes: notes,
        source: source,
        createdAt: DateTime.now(),
      );

      // Update or create holding
      await _updateHoldingForBuy(
        userId: userId,
        assetId: assetId,
        quantity: quantity,
        price: price,
        holdingId: txnRef.id,
      );

      // Save transaction
      await txnRef.set(transaction.toMap());

      return transaction;
    } catch (e) {
      print('Error adding BUY transaction: $e');
      return null;
    }
  }

  /// Add a SELL transaction
  /// Reduces holding quantity (avgPrice remains unchanged)
  Future<InvestmentTransaction?> addSellTransaction({
    required String userId,
    required String assetId,
    required DateTime date,
    required double quantity,
    required double price,
    double fees = 0.0,
    String? notes,
    String source = 'MANUAL',
  }) async {
    try {
      // Check if holding exists and has sufficient quantity
      final holding = await _getHolding(userId: userId, assetId: assetId);

      if (holding == null) {
        print('Error: No holding found for asset');
        return null;
      }

      if (holding.quantity < quantity) {
        print('Error: Insufficient quantity. Have: ${holding.quantity}, trying to sell: $quantity');
        return null;
      }

      final amount = quantity * price;

      // Create transaction
      final txnRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentTransactions')
          .doc();

      final transaction = InvestmentTransaction(
        txnId: txnRef.id,
        userId: userId,
        assetId: assetId,
        holdingId: holding.holdingId,
        type: 'SELL',
        date: date,
        quantity: quantity,
        price: price,
        amount: amount,
        fees: fees,
        notes: notes,
        source: source,
        createdAt: DateTime.now(),
      );

      // Update holding (reduce quantity)
      await _updateHoldingForSell(
        userId: userId,
        assetId: assetId,
        quantity: quantity,
      );

      // Save transaction
      await txnRef.set(transaction.toMap());

      return transaction;
    } catch (e) {
      print('Error adding SELL transaction: $e');
      return null;
    }
  }

  /// Add a SIP transaction (similar to BUY)
  Future<InvestmentTransaction?> addSipTransaction({
    required String userId,
    required String assetId,
    required DateTime date,
    required double quantity,
    required double price,
    double fees = 0.0,
    String? notes,
    String source = 'MANUAL',
  }) async {
    try {
      final amount = quantity * price;

      final txnRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentTransactions')
          .doc();

      final transaction = InvestmentTransaction(
        txnId: txnRef.id,
        userId: userId,
        assetId: assetId,
        type: 'SIP',
        date: date,
        quantity: quantity,
        price: price,
        amount: amount,
        fees: fees,
        notes: notes,
        source: source,
        createdAt: DateTime.now(),
      );

      // Update holding (same as BUY)
      await _updateHoldingForBuy(
        userId: userId,
        assetId: assetId,
        quantity: quantity,
        price: price,
        holdingId: txnRef.id,
      );

      await txnRef.set(transaction.toMap());

      return transaction;
    } catch (e) {
      print('Error adding SIP transaction: $e');
      return null;
    }
  }

  /// Add a DIVIDEND transaction (doesn't affect holdings)
  Future<InvestmentTransaction?> addDividendTransaction({
    required String userId,
    required String assetId,
    required DateTime date,
    required double amount,
    String? notes,
    String source = 'MANUAL',
  }) async {
    try {
      final txnRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentTransactions')
          .doc();

      final transaction = InvestmentTransaction(
        txnId: txnRef.id,
        userId: userId,
        assetId: assetId,
        type: 'DIVIDEND',
        date: date,
        amount: amount,
        fees: 0.0,
        notes: notes,
        source: source,
        createdAt: DateTime.now(),
      );

      await txnRef.set(transaction.toMap());

      return transaction;
    } catch (e) {
      print('Error adding DIVIDEND transaction: $e');
      return null;
    }
  }

  /// Add a FEE transaction (doesn't affect holdings)
  Future<InvestmentTransaction?> addFeeTransaction({
    required String userId,
    required String assetId,
    required DateTime date,
    required double amount,
    String? notes,
    String source = 'MANUAL',
  }) async {
    try {
      final txnRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentTransactions')
          .doc();

      final transaction = InvestmentTransaction(
        txnId: txnRef.id,
        userId: userId,
        assetId: assetId,
        type: 'FEE',
        date: date,
        amount: amount,
        fees: 0.0,
        notes: notes,
        source: source,
        createdAt: DateTime.now(),
      );

      await txnRef.set(transaction.toMap());

      return transaction;
    } catch (e) {
      print('Error adding FEE transaction: $e');
      return null;
    }
  }

  /// Update current price for an asset's holding
  Future<bool> updateCurrentPrice({
    required String userId,
    required String assetId,
    required double currentPrice,
  }) async {
    try {
      final holding = await _getHolding(userId: userId, assetId: assetId);

      if (holding == null) {
        print('Error: No holding found to update price');
        return false;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentHoldings')
          .doc(holding.holdingId)
          .update({
        'currentPrice': currentPrice,
        'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
      });

      return true;
    } catch (e) {
      print('Error updating price: $e');
      return false;
    }
  }

  /// Get all transactions for an asset
  Future<List<InvestmentTransaction>> getTransactionsForAsset({
    required String userId,
    required String assetId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentTransactions')
          .where('assetId', isEqualTo: assetId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => InvestmentTransaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting transactions: $e');
      return [];
    }
  }

  /// Stream transactions for an asset in real-time
  Stream<List<InvestmentTransaction>> streamTransactionsForAsset({
    required String userId,
    required String assetId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('investmentTransactions')
        .where('assetId', isEqualTo: assetId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => InvestmentTransaction.fromFirestore(doc))
          .toList();
    });
  }

  /// Delete a transaction and recalculate holding
  /// WARNING: This will recalculate holdings from scratch
  Future<bool> deleteTransaction({
    required String userId,
    required String txnId,
  }) async {
    try {
      final txnDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentTransactions')
          .doc(txnId)
          .get();

      if (!txnDoc.exists) {
        print('Transaction not found');
        return false;
      }

      final transaction = InvestmentTransaction.fromFirestore(txnDoc);

      // Delete transaction
      await txnDoc.reference.delete();

      // Recalculate holdings for this asset
      await _recalculateHolding(userId: userId, assetId: transaction.assetId);

      return true;
    } catch (e) {
      print('Error deleting transaction: $e');
      return false;
    }
  }

  /// Get holding for an asset (internal helper)
  Future<InvestmentHolding?> _getHolding({
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

  /// Update holding for BUY/SIP transaction (internal helper)
  Future<void> _updateHoldingForBuy({
    required String userId,
    required String assetId,
    required double quantity,
    required double price,
    required String holdingId,
  }) async {
    try {
      final existing = await _getHolding(userId: userId, assetId: assetId);

      if (existing == null) {
        // Create new holding
        final holdingRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('investmentHoldings')
            .doc();

        final holding = InvestmentHolding(
          holdingId: holdingRef.id,
          userId: userId,
          assetId: assetId,
          quantity: quantity,
          avgPrice: price,
          lastUpdatedAt: DateTime.now(),
        );

        await holdingRef.set(holding.toMap());
      } else {
        // Update existing holding with weighted average
        final newAvgPrice = InvestmentHolding.calculateNewAvgPrice(
          existingQty: existing.quantity,
          existingAvg: existing.avgPrice,
          newQty: quantity,
          newPrice: price,
        );

        final newQuantity = existing.quantity + quantity;

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('investmentHoldings')
            .doc(existing.holdingId)
            .update({
          'quantity': newQuantity,
          'avgPrice': newAvgPrice,
          'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      print('Error updating holding for BUY: $e');
      rethrow;
    }
  }

  /// Update holding for SELL transaction (internal helper)
  Future<void> _updateHoldingForSell({
    required String userId,
    required String assetId,
    required double quantity,
  }) async {
    try {
      final holding = await _getHolding(userId: userId, assetId: assetId);

      if (holding == null) {
        throw Exception('No holding found to sell from');
      }

      final newQuantity = holding.quantity - quantity;

      if (newQuantity < 0.001) {
        // If quantity becomes negligible, delete holding
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('investmentHoldings')
            .doc(holding.holdingId)
            .delete();
      } else {
        // Update quantity (avgPrice remains same)
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('investmentHoldings')
            .doc(holding.holdingId)
            .update({
          'quantity': newQuantity,
          'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      print('Error updating holding for SELL: $e');
      rethrow;
    }
  }

  /// Recalculate holding from all transactions (internal helper)
  /// Used after deleting a transaction
  Future<void> _recalculateHolding({
    required String userId,
    required String assetId,
  }) async {
    try {
      // Get all transactions for this asset in chronological order
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentTransactions')
          .where('assetId', isEqualTo: assetId)
          .orderBy('date', descending: false)
          .get();

      final transactions = snapshot.docs
          .map((doc) => InvestmentTransaction.fromFirestore(doc))
          .toList();

      // Delete existing holding
      final existingHolding = await _getHolding(userId: userId, assetId: assetId);
      if (existingHolding != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('investmentHoldings')
            .doc(existingHolding.holdingId)
            .delete();
      }

      // Recalculate from scratch
      double totalQuantity = 0.0;
      double totalInvested = 0.0;

      for (final txn in transactions) {
        if (txn.type == 'BUY' || txn.type == 'SIP') {
          totalQuantity += txn.quantity ?? 0.0;
          totalInvested += (txn.quantity ?? 0.0) * (txn.price ?? 0.0);
        } else if (txn.type == 'SELL') {
          totalQuantity -= txn.quantity ?? 0.0;
        }
      }

      // Create new holding if quantity > 0
      if (totalQuantity > 0.001) {
        final avgPrice = totalInvested / totalQuantity;

        final holdingRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('investmentHoldings')
            .doc();

        final holding = InvestmentHolding(
          holdingId: holdingRef.id,
          userId: userId,
          assetId: assetId,
          quantity: totalQuantity,
          avgPrice: avgPrice,
          currentPrice: existingHolding?.currentPrice,
          lastUpdatedAt: DateTime.now(),
        );

        await holdingRef.set(holding.toMap());
      }
    } catch (e) {
      print('Error recalculating holding: $e');
      rethrow;
    }
  }

  /// Get recent transactions across all assets
  Future<List<InvestmentTransaction>> getRecentTransactions({
    required String userId,
    int limit = 10,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('investmentTransactions')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => InvestmentTransaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting recent transactions: $e');
      return [];
    }
  }
}

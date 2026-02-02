import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../models/local_transaction_model.dart';
import '../../services/local_db_service.dart';

/// Quick test data generator for Sync & Merge feature
class TestSyncData {
  static Future<void> generateTestDuplicates() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('❌ No user logged in');
      return;
    }

    print('🧪 Generating test duplicate transactions...');

    final localDB = LocalDBService.instance;

    // Create pairs of duplicate transactions (SMS + Email)
    final testTransactions = [
      // Duplicate 1: Amazon Pay (high confidence)
      {
        'amount': 1968.00,
        'merchant': 'AMZN',
        'source': TransactionSource.sms,
        'date': DateTime.now().subtract(const Duration(days: 1, hours: 12)),
        'sender': 'JX-HDFCBK',
      },
      {
        'amount': 1968.00,
        'merchant': 'Amazon Pay India',
        'source': TransactionSource.email,
        'date': DateTime.now().subtract(const Duration(days: 1, hours: 12, minutes: 30)),
        'sender': 'alerts@amazon.com',
      },

      // Duplicate 2: Swiggy (high confidence)
      {
        'amount': 450.00,
        'merchant': 'SWIGGY',
        'source': TransactionSource.sms,
        'date': DateTime.now().subtract(const Duration(days: 2, hours: 8)),
        'sender': 'VK-HDFCBK',
      },
      {
        'amount': 450.00,
        'merchant': 'Swiggy Food Delivery',
        'source': TransactionSource.email,
        'date': DateTime.now().subtract(const Duration(days: 2, hours: 8, minutes: 15)),
        'sender': 'noreply@swiggy.com',
      },

      // Duplicate 3: Uber (medium confidence - different times)
      {
        'amount': 285.50,
        'merchant': 'UBER INDIA',
        'source': TransactionSource.sms,
        'date': DateTime.now().subtract(const Duration(days: 3, hours: 5)),
        'sender': 'AX-ICICIB',
      },
      {
        'amount': 285.50,
        'merchant': 'Uber Technologies',
        'source': TransactionSource.email,
        'date': DateTime.now().subtract(const Duration(days: 3, hours: 10)),
        'sender': 'uber.com',
      },

      // SMS-only transaction (no duplicate)
      {
        'amount': 150.00,
        'merchant': 'METRO STATION',
        'source': TransactionSource.sms,
        'date': DateTime.now().subtract(const Duration(days: 4)),
        'sender': 'VK-HDFCBK',
      },

      // Email-only transaction (no duplicate)
      {
        'amount': 2500.00,
        'merchant': 'Netflix Subscription',
        'source': TransactionSource.email,
        'date': DateTime.now().subtract(const Duration(days: 5)),
        'sender': 'info@netflix.com',
      },
    ];

    int created = 0;
    for (final data in testTransactions) {
      final transaction = LocalTransactionModel(
        id: const Uuid().v4(),
        source: data['source'] as TransactionSource,
        sourceIdentifier: data['sender'] as String,
        amount: data['amount'] as double,
        merchant: data['merchant'] as String,
        category: 'Shopping', // Default category
        transactionDate: data['date'] as DateTime,
        rawContent: 'Test transaction for sync feature',
        status: TransactionStatus.pending,
        isDebit: true,
        userId: userId,
        parsedBy: ParseMethod.manual,
        confidence: 1.0,
      );

      final success = await localDB.insertTransaction(transaction);
      if (success) created++;
    }

    print('✅ Created $created test transactions');
    print('   Expected: 3 duplicates, 1 SMS-only, 1 Email-only');
  }

  static Future<void> clearTestData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    print('🧹 Clearing test data...');

    final localDB = LocalDBService.instance;
    final transactions = await localDB.getTransactions(
      userId: userId,
      status: TransactionStatus.pending,
    );

    int deleted = 0;
    for (final transaction in transactions) {
      if (transaction.rawContent == 'Test transaction for sync feature') {
        await localDB.deleteTransaction(transaction.id);
        deleted++;
      }
    }

    print('✅ Deleted $deleted test transactions');
  }
}

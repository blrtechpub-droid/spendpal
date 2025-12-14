import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/widgets/account_selection_dropdown.dart';

/// Service for handling transaction categorization from SMS/Email
class TransactionCategorizationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Categorize transaction as salary
  static Future<String?> categorizeSalary({
    required String transactionId,
    required String transactionSource, // 'sms' or 'email'
    required double amount,
    required DateTime date,
    required String description,
    String? accountId,
    AccountSource? accountSource,
    dynamic account,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final month = date.month;
      final year = date.year;

      final salaryData = {
        'userId': currentUser.uid,
        'amount': amount,
        'month': month,
        'year': year,
        'source': transactionSource,
        'notes': notes ?? description,
        'linkedAccountId': accountId,
        'linkedAccountSource': accountSource?.name,
        'transactionMetadata': {
          ...?metadata,
          'transactionId': transactionId,
          'transactionDate': Timestamp.fromDate(date),
          'description': description,
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      final salaryDoc = await _firestore.collection('salaryRecords').add(salaryData);

      // Update account balance if linked
      if (accountId != null && accountSource == AccountSource.money) {
        await _updateMoneyAccountBalance(accountId, amount, isCredit: true);
      }

      // Mark source transaction as categorized
      await _markTransactionCategorized(
        transactionId,
        transactionSource,
        salaryDoc.id,
        'salary',
      );

      return salaryDoc.id;
    } catch (e) {
      print('Error categorizing as salary: $e');
      return null;
    }
  }

  /// Categorize transaction as investment return
  static Future<String?> categorizeInvestmentReturn({
    required String transactionId,
    required String transactionSource,
    required double amount,
    required DateTime date,
    required String description,
    String? accountId,
    AccountSource? accountSource,
    dynamic account,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create investment transaction record
      final transactionData = {
        'userId': currentUser.uid,
        'assetId': accountId,
        'type': 'return', // dividend, interest, capital gain
        'amount': amount,
        'units': 0.0, // Returns don't affect units
        'pricePerUnit': 0.0,
        'transactionDate': Timestamp.fromDate(date),
        'description': description,
        'notes': notes,
        'source': transactionSource,
        'transactionMetadata': {
          ...?metadata,
          'transactionId': transactionId,
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      final investmentDoc = await _firestore.collection('investmentTransactions').add(transactionData);

      // Mark source transaction as categorized
      await _markTransactionCategorized(
        transactionId,
        transactionSource,
        investmentDoc.id,
        'investment_return',
      );

      return investmentDoc.id;
    } catch (e) {
      print('Error categorizing as investment return: $e');
      return null;
    }
  }

  /// Categorize transaction as cashback
  static Future<String?> categorizeCashback({
    required String transactionId,
    required String transactionSource,
    required double amount,
    required DateTime date,
    required String description,
    String? accountId,
    AccountSource? accountSource,
    dynamic account,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create cashback record (in expenses collection as credit)
      final cashbackData = {
        'title': 'Cashback: $description',
        'amount': -amount, // Negative amount represents credit
        'notes': notes ?? 'Cashback auto-imported from $transactionSource',
        'date': Timestamp.fromDate(date),
        'paidBy': currentUser.uid,
        'splitWith': [currentUser.uid],
        'splitDetails': {currentUser.uid: -amount},
        'splitMethod': 'equal',
        'category': 'cashback',
        'groupId': null,
        'isFromBill': true,
        'billMetadata': {
          'source': transactionSource,
          ...?metadata,
          'transactionId': transactionId,
        },
        'linkedAccountId': accountId,
        'linkedAccountSource': accountSource?.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final cashbackDoc = await _firestore.collection('expenses').add(cashbackData);

      // Update account balance if linked
      if (accountId != null && accountSource == AccountSource.money) {
        await _updateMoneyAccountBalance(accountId, amount, isCredit: true);
      }

      // Mark source transaction as categorized
      await _markTransactionCategorized(
        transactionId,
        transactionSource,
        cashbackDoc.id,
        'cashback',
      );

      return cashbackDoc.id;
    } catch (e) {
      print('Error categorizing as cashback: $e');
      return null;
    }
  }

  /// Categorize transaction as refund
  static Future<String?> categorizeRefund({
    required String transactionId,
    required String transactionSource,
    required double amount,
    required DateTime date,
    required String description,
    String? accountId,
    AccountSource? accountSource,
    dynamic account,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create refund record (in expenses collection as credit)
      final refundData = {
        'title': 'Refund: $description',
        'amount': -amount, // Negative amount represents credit
        'notes': notes ?? 'Refund auto-imported from $transactionSource',
        'date': Timestamp.fromDate(date),
        'paidBy': currentUser.uid,
        'splitWith': [currentUser.uid],
        'splitDetails': {currentUser.uid: -amount},
        'splitMethod': 'equal',
        'category': 'refund',
        'groupId': null,
        'isFromBill': true,
        'billMetadata': {
          'source': transactionSource,
          ...?metadata,
          'transactionId': transactionId,
        },
        'linkedAccountId': accountId,
        'linkedAccountSource': accountSource?.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final refundDoc = await _firestore.collection('expenses').add(refundData);

      // Update account balance if linked
      if (accountId != null && accountSource == AccountSource.money) {
        await _updateMoneyAccountBalance(accountId, amount, isCredit: true);
      }

      // Mark source transaction as categorized
      await _markTransactionCategorized(
        transactionId,
        transactionSource,
        refundDoc.id,
        'refund',
      );

      return refundDoc.id;
    } catch (e) {
      print('Error categorizing as refund: $e');
      return null;
    }
  }

  /// Categorize transaction as other income
  static Future<String?> categorizeOtherIncome({
    required String transactionId,
    required String transactionSource,
    required double amount,
    required DateTime date,
    required String description,
    String? accountId,
    AccountSource? accountSource,
    dynamic account,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create other income record (in expenses collection as credit)
      final incomeData = {
        'title': 'Income: $description',
        'amount': -amount, // Negative amount represents credit
        'notes': notes ?? 'Income auto-imported from $transactionSource',
        'date': Timestamp.fromDate(date),
        'paidBy': currentUser.uid,
        'splitWith': [currentUser.uid],
        'splitDetails': {currentUser.uid: -amount},
        'splitMethod': 'equal',
        'category': 'other_income',
        'groupId': null,
        'isFromBill': true,
        'billMetadata': {
          'source': transactionSource,
          ...?metadata,
          'transactionId': transactionId,
        },
        'linkedAccountId': accountId,
        'linkedAccountSource': accountSource?.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final incomeDoc = await _firestore.collection('expenses').add(incomeData);

      // Update account balance if linked
      if (accountId != null && accountSource == AccountSource.money) {
        await _updateMoneyAccountBalance(accountId, amount, isCredit: true);
      }

      // Mark source transaction as categorized
      await _markTransactionCategorized(
        transactionId,
        transactionSource,
        incomeDoc.id,
        'other_income',
      );

      return incomeDoc.id;
    } catch (e) {
      print('Error categorizing as other income: $e');
      return null;
    }
  }

  /// Categorize transaction as expense
  static Future<String?> categorizeExpense({
    required String transactionId,
    required String transactionSource,
    required double amount,
    required DateTime date,
    required String description,
    String? accountId,
    AccountSource? accountSource,
    dynamic account,
    String? notes,
    String? category,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create expense record
      final expenseData = {
        'title': description,
        'amount': amount,
        'notes': notes ?? 'Auto-imported from $transactionSource',
        'date': Timestamp.fromDate(date),
        'paidBy': currentUser.uid,
        'splitWith': [currentUser.uid],
        'splitDetails': {currentUser.uid: amount},
        'splitMethod': 'equal',
        'category': category ?? 'general',
        'groupId': null,
        'isFromBill': true,
        'billMetadata': {
          'source': transactionSource,
          ...?metadata,
          'transactionId': transactionId,
        },
        'linkedAccountId': accountId,
        'linkedAccountSource': accountSource?.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final expenseDoc = await _firestore.collection('expenses').add(expenseData);

      // Update account balance if linked
      if (accountId != null && accountSource == AccountSource.money) {
        await _updateMoneyAccountBalance(accountId, amount, isCredit: false);
      }

      // Mark source transaction as categorized
      await _markTransactionCategorized(
        transactionId,
        transactionSource,
        expenseDoc.id,
        'expense',
      );

      return expenseDoc.id;
    } catch (e) {
      print('Error categorizing as expense: $e');
      return null;
    }
  }

  /// Categorize transaction as investment purchase
  static Future<String?> categorizeInvestment({
    required String transactionId,
    required String transactionSource,
    required double amount,
    required DateTime date,
    required String description,
    String? accountId,
    AccountSource? accountSource,
    dynamic account,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create investment transaction record
      final transactionData = {
        'userId': currentUser.uid,
        'assetId': accountId,
        'type': 'buy',
        'amount': amount,
        'units': 0.0, // Will need to be updated manually by user
        'pricePerUnit': 0.0,
        'transactionDate': Timestamp.fromDate(date),
        'description': description,
        'notes': notes,
        'source': transactionSource,
        'transactionMetadata': {
          ...?metadata,
          'transactionId': transactionId,
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      final investmentDoc = await _firestore.collection('investmentTransactions').add(transactionData);

      // Mark source transaction as categorized
      await _markTransactionCategorized(
        transactionId,
        transactionSource,
        investmentDoc.id,
        'investment',
      );

      return investmentDoc.id;
    } catch (e) {
      print('Error categorizing as investment: $e');
      return null;
    }
  }

  /// Categorize transaction as loan payment
  static Future<String?> categorizeLoanPayment({
    required String transactionId,
    required String transactionSource,
    required double amount,
    required DateTime date,
    required String description,
    String? accountId,
    AccountSource? accountSource,
    dynamic account,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create loan payment record (in expenses collection)
      final loanData = {
        'title': 'Loan Payment: $description',
        'amount': amount,
        'notes': notes ?? 'Auto-imported from $transactionSource',
        'date': Timestamp.fromDate(date),
        'paidBy': currentUser.uid,
        'splitWith': [currentUser.uid],
        'splitDetails': {currentUser.uid: amount},
        'splitMethod': 'equal',
        'category': 'loan_payment',
        'groupId': null,
        'isFromBill': true,
        'billMetadata': {
          'source': transactionSource,
          ...?metadata,
          'transactionId': transactionId,
        },
        'linkedAccountId': accountId,
        'linkedAccountSource': accountSource?.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final loanDoc = await _firestore.collection('expenses').add(loanData);

      // Update account balance if linked (reduce balance for payment)
      if (accountId != null && accountSource == AccountSource.money) {
        await _updateMoneyAccountBalance(accountId, amount, isCredit: false);
      }

      // Mark source transaction as categorized
      await _markTransactionCategorized(
        transactionId,
        transactionSource,
        loanDoc.id,
        'loan_payment',
      );

      return loanDoc.id;
    } catch (e) {
      print('Error categorizing as loan payment: $e');
      return null;
    }
  }

  /// Categorize transaction as transfer
  static Future<String?> categorizeTransfer({
    required String transactionId,
    required String transactionSource,
    required double amount,
    required DateTime date,
    required String description,
    String? accountId,
    AccountSource? accountSource,
    dynamic account,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create transfer record (in expenses collection)
      final transferData = {
        'title': 'Transfer: $description',
        'amount': amount,
        'notes': notes ?? 'Auto-imported from $transactionSource',
        'date': Timestamp.fromDate(date),
        'paidBy': currentUser.uid,
        'splitWith': [currentUser.uid],
        'splitDetails': {currentUser.uid: amount},
        'splitMethod': 'equal',
        'category': 'transfer',
        'groupId': null,
        'isFromBill': true,
        'billMetadata': {
          'source': transactionSource,
          ...?metadata,
          'transactionId': transactionId,
        },
        'linkedAccountId': accountId,
        'linkedAccountSource': accountSource?.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final transferDoc = await _firestore.collection('expenses').add(transferData);

      // Note: For transfers, balance update should be neutral or handled differently
      // Not updating balance here as it's a transfer, not actual spending

      // Mark source transaction as categorized
      await _markTransactionCategorized(
        transactionId,
        transactionSource,
        transferDoc.id,
        'transfer',
      );

      return transferDoc.id;
    } catch (e) {
      print('Error categorizing as transfer: $e');
      return null;
    }
  }

  /// Update money account balance (bank or credit card)
  static Future<void> _updateMoneyAccountBalance(
    String accountId,
    double amount,
    {required bool isCredit}
  ) async {
    try {
      final accountDoc = await _firestore.collection('moneyAccounts').doc(accountId).get();

      if (!accountDoc.exists) {
        print('Account not found: $accountId');
        return;
      }

      final currentBalance = (accountDoc.data()?['balance'] ?? 0.0) as double;
      final newBalance = isCredit ? currentBalance + amount : currentBalance - amount;

      await _firestore.collection('moneyAccounts').doc(accountId).update({
        'balance': newBalance,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating account balance: $e');
    }
  }

  /// Mark source transaction as categorized
  static Future<void> _markTransactionCategorized(
    String transactionId,
    String transactionSource,
    String linkedRecordId,
    String category,
  ) async {
    try {
      final collection = transactionSource == 'sms'
          ? 'sms_expenses'
          : 'email_transactions';

      await _firestore.collection(collection).doc(transactionId).update({
        'status': 'categorized',
        'categorizedAt': FieldValue.serverTimestamp(),
        'linkedRecordId': linkedRecordId,
        'category': category,
      });
    } catch (e) {
      print('Error marking transaction as categorized: $e');
    }
  }
}

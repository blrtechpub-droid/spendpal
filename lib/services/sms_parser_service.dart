import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/money_tracker_model.dart';

/// Service for parsing SMS messages to detect financial transactions
class SmsParserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Common patterns for Indian bank SMS
  static final Map<String, List<RegExp>> transactionPatterns = {
    'debit': [
      // Pattern: debited by INR/Rs 1234.56
      RegExp(r'debited\s+(?:by\s+)?(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: withdrawn INR/Rs 1234.56
      RegExp(r'withdrawn\s+(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: debited with 1234.56
      RegExp(r'debited\s+with\s+(?:INR|Rs\.?)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: spent Rs 1234.56
      RegExp(r'spent\s+(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
    ],
    'credit': [
      // Pattern: credited with INR/Rs 1234.56
      RegExp(r'credited\s+(?:with\s+)?(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: deposited INR/Rs 1234.56
      RegExp(r'deposited\s+(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: received INR/Rs 1234.56
      RegExp(r'received\s+(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
    ],
    'salary': [
      // Pattern: salary credited
      RegExp(r'(?:salary|sal)\s+credited\s+(?:with\s+)?(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: credited with ... Info: SALARY
      RegExp(r'credited\s+(?:with\s+)?(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+.*?(?:info|ref|utr).*?salary',
          caseSensitive: false),
    ],
    'balance': [
      // Pattern: Available balance: INR/Rs 1234.56
      RegExp(r'(?:available\s+)?balance(?:\s+is)?[:\s]+(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: Avl bal: 1234.56
      RegExp(r'(?:avl|available)\s+(?:bal|balance)[:\s]+(?:INR|Rs\.?)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
    ],
    'creditCardPayment': [
      // Pattern: payment of Rs 1234.56 received
      RegExp(r'payment\s+of\s+(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+(?:is\s+)?received',
          caseSensitive: false),
      // Pattern: bill payment of Rs 1234.56
      RegExp(r'bill\s+payment\s+of\s+(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
    ],
  };

  /// Parse SMS text to detect transaction type and amount
  static Map<String, dynamic>? parseSms(String smsText) {
    // Check for salary
    for (final pattern in transactionPatterns['salary']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          return {
            'type': 'salary',
            'amount': amount,
            'rawText': smsText,
          };
        }
      }
    }

    // Check for credit card payment
    for (final pattern in transactionPatterns['creditCardPayment']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          return {
            'type': 'credit_card_payment',
            'amount': amount,
            'rawText': smsText,
          };
        }
      }
    }

    // Check for debit
    for (final pattern in transactionPatterns['debit']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          // Extract balance if present
          double? balance;
          for (final balPattern in transactionPatterns['balance']!) {
            final balMatch = balPattern.firstMatch(smsText);
            if (balMatch != null) {
              final balStr = balMatch.group(1)!.replaceAll(',', '');
              balance = double.tryParse(balStr);
              break;
            }
          }

          return {
            'type': 'debit',
            'amount': amount,
            'balance': balance,
            'rawText': smsText,
          };
        }
      }
    }

    // Check for credit
    for (final pattern in transactionPatterns['credit']!) {
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          // Extract balance if present
          double? balance;
          for (final balPattern in transactionPatterns['balance']!) {
            final balMatch = balPattern.firstMatch(smsText);
            if (balMatch != null) {
              final balStr = balMatch.group(1)!.replaceAll(',', '');
              balance = double.tryParse(balStr);
              break;
            }
          }

          return {
            'type': 'credit',
            'amount': amount,
            'balance': balance,
            'rawText': smsText,
          };
        }
      }
    }

    return null; // No transaction detected
  }

  /// Save a salary record to Firestore
  static Future<void> saveSalaryRecord({
    required String userId,
    required double amount,
    String? accountId,
    String? rawSmsText,
  }) async {
    final salary = SalaryRecord(
      recordId: '',
      userId: userId,
      amount: amount,
      creditedDate: DateTime.now(),
      accountId: accountId,
      source: rawSmsText != null ? 'sms' : 'manual',
      rawSmsText: rawSmsText,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('salaryRecords').add(salary.toMap());
  }

  /// Save a transaction to Firestore
  static Future<void> saveTransaction({
    required String userId,
    required String accountId,
    required String type,
    required double amount,
    String? description,
    String? category,
    String? rawSmsText,
  }) async {
    final transaction = MoneyTransaction(
      transactionId: '',
      userId: userId,
      accountId: accountId,
      type: type,
      amount: amount,
      description: description,
      category: category,
      transactionDate: DateTime.now(),
      source: rawSmsText != null ? 'sms' : 'manual',
      rawSmsText: rawSmsText,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('moneyTransactions').add(transaction.toMap());
  }

  /// Update account balance based on transaction
  static Future<void> updateAccountBalance({
    required String accountId,
    required double newBalance,
  }) async {
    await _firestore.collection('moneyAccounts').doc(accountId).update({
      'balance': newBalance,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Process SMS and update accounts
  static Future<void> processSmsAndUpdateAccounts({
    required String userId,
    required String smsText,
    required String accountId,
  }) async {
    final parsed = parseSms(smsText);
    if (parsed == null) return;

    final type = parsed['type'] as String;
    final amount = parsed['amount'] as double;
    final balance = parsed['balance'] as double?;

    if (type == 'salary') {
      await saveSalaryRecord(
        userId: userId,
        amount: amount,
        accountId: accountId,
        rawSmsText: smsText,
      );
      await saveTransaction(
        userId: userId,
        accountId: accountId,
        type: 'credit',
        amount: amount,
        description: 'Salary Credit',
        category: 'Salary',
        rawSmsText: smsText,
      );
    } else if (type == 'credit_card_payment') {
      // Reset credit card balance
      await saveTransaction(
        userId: userId,
        accountId: accountId,
        type: 'credit',
        amount: amount,
        description: 'Credit Card Payment',
        category: 'Payment',
        rawSmsText: smsText,
      );
    } else {
      await saveTransaction(
        userId: userId,
        accountId: accountId,
        type: type,
        amount: amount,
        rawSmsText: smsText,
      );
    }

    // Update account balance if available
    if (balance != null) {
      await updateAccountBalance(accountId: accountId, newBalance: balance);
    }
  }
}

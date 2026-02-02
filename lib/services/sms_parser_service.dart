import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/money_tracker_model.dart';
import 'package:spendpal/services/regex_pattern_tracker.dart';

/// Service for parsing SMS messages to detect financial transactions
class SmsParserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Comprehensive patterns for Indian bank SMS (50+ patterns for cost optimization)
  /// Organized by bank and transaction type for better accuracy
  static final Map<String, List<RegExp>> transactionPatterns = {
    'debit': [
      // === HDFC Bank Patterns ===
      // Pattern: Rs 1234.56 debited from A/c XX1234
      RegExp(r'(?:rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+debited\s+from.*?(?:a/c|acct).*?(?:xx)?(\d{4})',
          caseSensitive: false),
      // Pattern: Acct XX1234 debited with Rs 1234.56
      RegExp(r'(?:acct|a/c).*?(?:xx)?(\d{4})\s+debited\s+(?:with\s+)?(?:rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),

      // === ICICI Bank Patterns ===
      // Pattern: INR 1234.56 debited from Card ending 1234
      RegExp(r'(?:rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+debited.*?card\s+ending\s+(\d{4})',
          caseSensitive: false),

      // === SBI Patterns ===
      // Pattern: Rs 1234.56 is debited from SBI A/C XX1234
      RegExp(r'(?:rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+is\s+debited\s+from',
          caseSensitive: false),

      // === UPI Patterns ===
      // Pattern: UPI debited Rs 1234.56
      RegExp(r'upi.*?(?:debited|paid|sent)\s+(?:rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: Paid Rs 1234.56 via UPI
      RegExp(r'paid\s+(?:rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+via\s+upi',
          caseSensitive: false),

      // === Card Payments ===
      // Pattern: card XX1234 used for Rs 1234.56
      RegExp(r'card\s+(?:xx)?(\d{4})\s+used\s+for\s+(?:rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),

      // === Generic Debit Patterns (Fallback) ===
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
      // Pattern: paid Rs 1234.56
      RegExp(r'paid\s+(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: purchase of Rs 1234.56
      RegExp(r'purchase\s+of\s+(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: transferred Rs 1234.56
      RegExp(r'transferred\s+(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
    ],
    'credit': [
      // === Credit Patterns (Multiple Banks) ===
      // Pattern: Rs 1234.56 credited to A/c XX1234
      RegExp(r'(?:rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+credited\s+to.*?(?:a/c|acct)',
          caseSensitive: false),
      // Pattern: A/c XX1234 credited with Rs 1234.56
      RegExp(r'(?:acct|a/c).*?credited\s+(?:with\s+)?(?:rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),

      // === UPI Credit Patterns ===
      // Pattern: Received Rs 1234.56 via UPI
      RegExp(r'received\s+(?:rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{2})?)\s+(?:via\s+)?upi',
          caseSensitive: false),
      // Pattern: UPI credited Rs 1234.56
      RegExp(r'upi.*?credited\s+(?:rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),

      // === Generic Credit Patterns ===
      // Pattern: credited with INR/Rs 1234.56
      RegExp(r'credited\s+(?:with\s+)?(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: deposited INR/Rs 1234.56
      RegExp(r'deposited\s+(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: received INR/Rs 1234.56
      RegExp(r'received\s+(?:INR|Rs\.?)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: added to account Rs 1234.56
      RegExp(r'added\s+to.*?(?:account|a/c).*?(?:rs\.?|inr)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
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
    for (int i = 0; i < transactionPatterns['salary']!.length; i++) {
      final pattern = transactionPatterns['salary']![i];
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          // Track pattern hit
          RegexPatternTracker.recordHit('salary', i);
          return {
            'type': 'salary',
            'amount': amount,
            'rawText': smsText,
          };
        }
      }
    }

    // Check for credit card payment
    for (int i = 0; i < transactionPatterns['creditCardPayment']!.length; i++) {
      final pattern = transactionPatterns['creditCardPayment']![i];
      final match = pattern.firstMatch(smsText);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          // Track pattern hit
          RegexPatternTracker.recordHit('creditCardPayment', i);
          return {
            'type': 'credit_card_payment',
            'amount': amount,
            'rawText': smsText,
          };
        }
      }
    }

    // Check for debit
    for (int i = 0; i < transactionPatterns['debit']!.length; i++) {
      final pattern = transactionPatterns['debit']![i];
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

          // Track pattern hit
          RegexPatternTracker.recordHit('debit', i);

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
    for (int i = 0; i < transactionPatterns['credit']!.length; i++) {
      final pattern = transactionPatterns['credit']![i];
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

          // Track pattern hit
          RegexPatternTracker.recordHit('credit', i);

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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionData {
  final double amount;
  final String merchant;
  final DateTime date;
  final String? category;
  final String? accountInfo;
  final String rawSms;
  final String? transactionId;
  final bool isDebit;

  TransactionData({
    required this.amount,
    required this.merchant,
    required this.date,
    this.category,
    this.accountInfo,
    required this.rawSms,
    this.transactionId,
    this.isDebit = true,
  });
}

class SmsParserService {
  // Generic patterns for Indian banks and payment services
  static final List<RegExp> _debitPatterns = [
    // Pattern: "debited", "spent", "withdrawn", "paid"
    RegExp(r'debited|spent|withdrawn|paid|purchase', caseSensitive: false),
    RegExp(r'debit|deducted|charged', caseSensitive: false),
  ];

  static final List<RegExp> _creditPatterns = [
    RegExp(r'credited|received|refund', caseSensitive: false),
  ];

  // Amount patterns - supports ₹, Rs., INR
  static final List<RegExp> _amountPatterns = [
    RegExp(r'(?:rs\.?|inr|₹)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
    RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\s*(?:rs\.?|inr|₹)', caseSensitive: false),
    RegExp(r'amount[\s:]*(?:rs\.?|inr|₹)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
  ];

  // Merchant name patterns
  static final List<RegExp> _merchantPatterns = [
    RegExp(r'(?:at|to|for)\s+([A-Z][A-Z0-9\s\-]{2,30})', caseSensitive: false),
    RegExp(r'merchant[\s:]+([A-Z][A-Z0-9\s\-]{2,30})', caseSensitive: false),
    RegExp(r'payee[\s:]+([A-Z][A-Z0-9\s\-]{2,30})', caseSensitive: false),
  ];

  // Account/card info patterns
  static final RegExp _accountPattern = RegExp(
    r'(?:a\/c|account|card)[\s:]?(?:ending\s)?(?:no\.?|number)?[\s:]?[xX*]*(\d{4})',
    caseSensitive: false,
  );

  // Transaction ID patterns
  static final RegExp _transactionIdPattern = RegExp(
    r'(?:ref|txn|transaction|utr)[\s:]?(?:id|no\.?|number)?[\s:]?([A-Z0-9]{8,20})',
    caseSensitive: false,
  );

  /// Check if SMS is a transaction message
  static bool isTransactionSms(String smsBody) {
    final lowerBody = smsBody.toLowerCase();

    // Must contain transaction-related keywords
    final hasTransactionKeyword =
        lowerBody.contains('account') ||
        lowerBody.contains('card') ||
        lowerBody.contains('upi') ||
        lowerBody.contains('transaction') ||
        lowerBody.contains('payment');

    // Must contain amount
    final hasAmount = _amountPatterns.any((pattern) => pattern.hasMatch(smsBody));

    // Must contain debit or credit keyword
    final hasTransaction =
        _debitPatterns.any((pattern) => pattern.hasMatch(smsBody)) ||
        _creditPatterns.any((pattern) => pattern.hasMatch(smsBody));

    return hasTransactionKeyword && hasAmount && hasTransaction;
  }

  /// Check if transaction is a debit (expense)
  static bool isDebitTransaction(String smsBody) {
    return _debitPatterns.any((pattern) => pattern.hasMatch(smsBody));
  }

  /// Extract amount from SMS
  static double? extractAmount(String smsBody) {
    for (var pattern in _amountPatterns) {
      final match = pattern.firstMatch(smsBody);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        final amount = double.tryParse(amountStr ?? '');
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }
    return null;
  }

  /// Extract merchant name from SMS
  static String extractMerchant(String smsBody) {
    for (var pattern in _merchantPatterns) {
      final match = pattern.firstMatch(smsBody);
      if (match != null) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.length > 2) {
          // Clean up merchant name
          return _cleanMerchantName(merchant);
        }
      }
    }

    // Fallback: try to extract any capitalized word sequence
    final fallbackPattern = RegExp(r'([A-Z][A-Za-z0-9\s]{3,25})');
    final matches = fallbackPattern.allMatches(smsBody);
    for (var match in matches) {
      final text = match.group(1)?.trim();
      if (text != null && !_isCommonBankingWord(text)) {
        return _cleanMerchantName(text);
      }
    }

    return 'Unknown Merchant';
  }

  /// Clean merchant name by removing extra spaces and common suffixes
  static String _cleanMerchantName(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*-\s*$'), '')
        .trim();
  }

  /// Check if text is a common banking word to avoid false merchant names
  static bool _isCommonBankingWord(String text) {
    final commonWords = [
      'ACCOUNT', 'CARD', 'BANK', 'CREDITED', 'DEBITED', 'TRANSACTION',
      'PAYMENT', 'BALANCE', 'AVAILABLE', 'TOTAL', 'AMOUNT', 'TRANSFER',
      'UPI', 'NEFT', 'RTGS', 'IMPS', 'INFO', 'ALERT', 'MESSAGE'
    ];
    return commonWords.contains(text.toUpperCase());
  }

  /// Extract account/card info
  static String? extractAccountInfo(String smsBody) {
    final match = _accountPattern.firstMatch(smsBody);
    if (match != null) {
      return 'XX${match.group(1)}';
    }
    return null;
  }

  /// Extract transaction ID
  static String? extractTransactionId(String smsBody) {
    final match = _transactionIdPattern.firstMatch(smsBody);
    return match?.group(1);
  }

  /// Auto-categorize based on merchant name and keywords
  static String categorizeTransaction(String merchant, String smsBody) {
    final lowerMerchant = merchant.toLowerCase();
    final lowerBody = smsBody.toLowerCase();

    // Food & Dining
    if (lowerMerchant.contains('swiggy') ||
        lowerMerchant.contains('zomato') ||
        lowerMerchant.contains('restaurant') ||
        lowerMerchant.contains('cafe') ||
        lowerMerchant.contains('food') ||
        lowerMerchant.contains('pizza') ||
        lowerMerchant.contains('mcdonald') ||
        lowerMerchant.contains('kfc') ||
        lowerMerchant.contains('domino')) {
      return 'Food';
    }

    // Groceries
    if (lowerMerchant.contains('dmart') ||
        lowerMerchant.contains('bigbasket') ||
        lowerMerchant.contains('grofer') ||
        lowerMerchant.contains('blinkit') ||
        lowerMerchant.contains('zepto') ||
        lowerMerchant.contains('grocery') ||
        lowerMerchant.contains('supermarket')) {
      return 'Groceries';
    }

    // Shopping
    if (lowerMerchant.contains('amazon') ||
        lowerMerchant.contains('flipkart') ||
        lowerMerchant.contains('myntra') ||
        lowerMerchant.contains('ajio') ||
        lowerMerchant.contains('meesho') ||
        lowerBody.contains('shopping')) {
      return 'Shopping';
    }

    // Travel
    if (lowerMerchant.contains('uber') ||
        lowerMerchant.contains('ola') ||
        lowerMerchant.contains('rapido') ||
        lowerMerchant.contains('makemytrip') ||
        lowerMerchant.contains('goibibo') ||
        lowerMerchant.contains('irctc') ||
        lowerMerchant.contains('fuel') ||
        lowerMerchant.contains('petrol') ||
        lowerBody.contains('travel')) {
      return 'Travel';
    }

    // Entertainment
    if (lowerMerchant.contains('netflix') ||
        lowerMerchant.contains('prime') ||
        lowerMerchant.contains('hotstar') ||
        lowerMerchant.contains('spotify') ||
        lowerMerchant.contains('bookmyshow') ||
        lowerMerchant.contains('pvr') ||
        lowerMerchant.contains('inox')) {
      return 'Entertainment';
    }

    // Utilities
    if (lowerMerchant.contains('electricity') ||
        lowerMerchant.contains('water') ||
        lowerMerchant.contains('gas') ||
        lowerMerchant.contains('broadband') ||
        lowerMerchant.contains('internet') ||
        lowerMerchant.contains('mobile') ||
        lowerMerchant.contains('airtel') ||
        lowerMerchant.contains('jio') ||
        lowerMerchant.contains('vi') ||
        lowerBody.contains('bill payment') ||
        lowerBody.contains('recharge')) {
      return 'Utilities';
    }

    // Healthcare
    if (lowerMerchant.contains('pharma') ||
        lowerMerchant.contains('pharmacy') ||
        lowerMerchant.contains('hospital') ||
        lowerMerchant.contains('clinic') ||
        lowerMerchant.contains('apollo') ||
        lowerMerchant.contains('1mg') ||
        lowerMerchant.contains('netmeds')) {
      return 'Healthcare';
    }

    // Default
    return 'Other';
  }

  /// Parse SMS and extract transaction data
  static TransactionData? parseSms(String smsBody, String sender, DateTime receivedAt) {
    // Check if it's a transaction SMS
    if (!isTransactionSms(smsBody)) {
      return null;
    }

    // Only process debit transactions (expenses)
    if (!isDebitTransaction(smsBody)) {
      return null; // Skip credit transactions
    }

    // Extract amount
    final amount = extractAmount(smsBody);
    if (amount == null) {
      return null; // Invalid transaction without amount
    }

    // Extract merchant
    final merchant = extractMerchant(smsBody);

    // Extract other details
    final accountInfo = extractAccountInfo(smsBody);
    final transactionId = extractTransactionId(smsBody);
    final category = categorizeTransaction(merchant, smsBody);

    return TransactionData(
      amount: amount,
      merchant: merchant,
      date: receivedAt,
      category: category,
      accountInfo: accountInfo,
      rawSms: smsBody,
      transactionId: transactionId,
      isDebit: true,
    );
  }

  /// Save SMS transaction to pending expenses (for user categorization)
  static Future<bool> saveSmsExpenseToPending(TransactionData transaction, String smsSender) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('User not logged in, cannot save SMS expense');
        return false;
      }

      // Check for duplicate based on transaction ID or hash
      final isDuplicate = await _checkDuplicateSmsExpense(transaction);
      if (isDuplicate) {
        print('Duplicate SMS transaction detected, skipping: ${transaction.transactionId}');
        return false;
      }

      // Create sms_expense document
      final smsExpenseData = {
        'amount': transaction.amount,
        'merchant': transaction.merchant,
        'date': Timestamp.fromDate(transaction.date),
        'category': transaction.category ?? 'Other',
        'accountInfo': transaction.accountInfo,
        'rawSms': transaction.rawSms,
        'transactionId': transaction.transactionId,
        'userId': currentUser.uid,
        'status': 'pending',
        'parsedAt': FieldValue.serverTimestamp(),
        'categorizedAt': null,
        'linkedExpenseId': null,
        'smsSender': smsSender,
      };

      await FirebaseFirestore.instance.collection('sms_expenses').add(smsExpenseData);

      print('✅ Saved SMS expense to pending: ${transaction.merchant} - ₹${transaction.amount}');
      return true;
    } catch (e) {
      print('❌ Error saving SMS expense to pending: $e');
      return false;
    }
  }

  /// Create expense from transaction data (DEPRECATED - use saveSmsExpenseToPending instead)
  @Deprecated('Use saveSmsExpenseToPending to save for user categorization')
  static Future<bool> createExpenseFromSms(TransactionData transaction) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('User not logged in, cannot create expense');
        return false;
      }

      // Check for duplicate based on transaction ID or hash
      final isDuplicate = await _checkDuplicate(transaction);
      if (isDuplicate) {
        print('Duplicate transaction detected, skipping: ${transaction.transactionId}');
        return false;
      }

      // Create expense document
      final expenseData = {
        'title': transaction.merchant,
        'amount': transaction.amount,
        'notes': 'Auto-imported from SMS\n${transaction.accountInfo ?? ""}\nTxn: ${transaction.transactionId ?? "N/A"}',
        'date': Timestamp.fromDate(transaction.date),
        'paidBy': currentUser.uid,
        'splitWith': [currentUser.uid], // Personal expense
        'splitDetails': {currentUser.uid: transaction.amount},
        'splitMethod': 'equal',
        'category': transaction.category ?? 'Other',
        'groupId': null, // Personal expense, no group
        'isFromBill': true, // Mark as auto-imported
        'billMetadata': {
          'source': 'sms',
          'sender': 'bank',
          'rawSms': transaction.rawSms,
          'transactionId': transaction.transactionId,
          'accountInfo': transaction.accountInfo,
          'parsedAt': FieldValue.serverTimestamp(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('expenses').add(expenseData);

      print('✅ Created expense from SMS: ${transaction.merchant} - ₹${transaction.amount}');
      return true;
    } catch (e) {
      print('❌ Error creating expense from SMS: $e');
      return false;
    }
  }

  /// Check if SMS transaction already exists in sms_expenses collection
  static Future<bool> _checkDuplicateSmsExpense(TransactionData transaction) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Check by transaction ID if available
      if (transaction.transactionId != null) {
        final query = await FirebaseFirestore.instance
            .collection('sms_expenses')
            .where('userId', isEqualTo: currentUser.uid)
            .where('transactionId', isEqualTo: transaction.transactionId)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          return true; // Duplicate found
        }
      }

      // Fallback: Check by amount, merchant, and date (within same day)
      final startOfDay = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final query = await FirebaseFirestore.instance
          .collection('sms_expenses')
          .where('userId', isEqualTo: currentUser.uid)
          .where('amount', isEqualTo: transaction.amount)
          .where('merchant', isEqualTo: transaction.merchant)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking duplicate SMS expense: $e');
      return false; // Assume not duplicate if check fails
    }
  }

  /// Check if transaction already exists to prevent duplicates
  static Future<bool> _checkDuplicate(TransactionData transaction) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Check by transaction ID if available
      if (transaction.transactionId != null) {
        final query = await FirebaseFirestore.instance
            .collection('expenses')
            .where('paidBy', isEqualTo: currentUser.uid)
            .where('billMetadata.transactionId', isEqualTo: transaction.transactionId)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          return true; // Duplicate found
        }
      }

      // Fallback: Check by amount, merchant, and date (within same day)
      final startOfDay = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final query = await FirebaseFirestore.instance
          .collection('expenses')
          .where('paidBy', isEqualTo: currentUser.uid)
          .where('amount', isEqualTo: transaction.amount)
          .where('title', isEqualTo: transaction.merchant)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking duplicate: $e');
      return false; // Assume not duplicate if check fails
    }
  }
}

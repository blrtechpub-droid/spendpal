import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for parsing email messages to detect financial transactions
/// Handles transaction emails from banks, credit cards, and payment platforms
class EmailTransactionParserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Known bank sender patterns
  static final List<RegExp> bankSenderPatterns = [
    RegExp(r'@hdfcbank\.com', caseSensitive: false),
    RegExp(r'@hdfcbank\.net', caseSensitive: false), // HDFC credit card statements
    RegExp(r'@icicibank\.com', caseSensitive: false),
    RegExp(r'@sbi\.co\.in', caseSensitive: false),
    RegExp(r'@axisbank\.com', caseSensitive: false),
    RegExp(r'@kotak\.com', caseSensitive: false),
    RegExp(r'@yesbank\.in', caseSensitive: false),
    RegExp(r'@indusind\.com', caseSensitive: false),
    RegExp(r'@pnbindia\.in', caseSensitive: false),
    RegExp(r'@sc\.com', caseSensitive: false),
    RegExp(r'@standardchartered\.com', caseSensitive: false),
    RegExp(r'@alerts\.amazon\.', caseSensitive: false),
    RegExp(r'@flipkart\.com', caseSensitive: false),
    RegExp(r'@paytm\.com', caseSensitive: false),
    RegExp(r'@razorpay\.com', caseSensitive: false),
  ];

  /// Transaction patterns for email content
  static final Map<String, List<RegExp>> transactionPatterns = {
    'debit': [
      // Pattern: Debited INR/Rs 1234.56
      RegExp(r'(?:debited|spent|paid|withdrawn|purchase(?:\s+of)?)[:\s]+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: Amount debited: 1234.56
      RegExp(r'amount\s+(?:debited|paid|spent)[:\s]+(?:INR|Rs\.?|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: Transaction Amount: Rs 1234.56
      RegExp(r'transaction\s+amount[:\s]+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: has been debited with Rs 1234.56
      RegExp(r'(?:has\s+been\s+)?debited\s+with\s+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
    ],
    'credit': [
      // Pattern: Credited INR/Rs 1234.56
      RegExp(r'(?:credited|received|refund(?:ed)?|deposited)[:\s]+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: Amount credited: 1234.56
      RegExp(r'amount\s+(?:credited|received|deposited)[:\s]+(?:INR|Rs\.?|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: has been credited with Rs 1234.56
      RegExp(r'(?:has\s+been\s+)?credited\s+with\s+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
    ],
    'creditCard': [
      // Pattern: credit card ... Rs 1234.56
      RegExp(r'credit\s+card.*?(?:charged|paid|spent|billed)[:\s]+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: card ending ... debited Rs 1234.56
      RegExp(r'card\s+(?:ending|no\.|number).*?debited[:\s]+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
    ],
    'upi': [
      // Pattern: UPI transaction ... Rs 1234.56
      RegExp(r'UPI.*?(?:paid|sent|debited)[:\s]+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
      // Pattern: paid ... via UPI Rs 1234.56
      RegExp(r'paid.*?UPI.*?(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
          caseSensitive: false),
    ],
  };

  /// Extract merchant/vendor name from email content
  static String? extractMerchant(String emailContent) {
    // Pattern: at/to MERCHANT_NAME
    final patterns = [
      RegExp(r'(?:at|to|from)\s+([A-Z][A-Za-z\s&]{2,30})', caseSensitive: true),
      RegExp(r'merchant[:\s]+([A-Za-z\s&]{3,30})', caseSensitive: false),
      RegExp(r'(?:store|shop|vendor)[:\s]+([A-Za-z\s&]{3,30})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(emailContent);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }

  /// Extract transaction date from email content
  static DateTime? extractTransactionDate(String emailContent) {
    // Pattern: Date: DD/MM/YYYY or DD-MM-YYYY
    final datePatterns = [
      RegExp(r'(?:date|on)[:\s]+(\d{1,2})[/-](\d{1,2})[/-](\d{4})', caseSensitive: false),
      RegExp(r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{4})', caseSensitive: false),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(emailContent);
      if (match != null) {
        try {
          if (pattern == datePatterns[0]) {
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final year = int.parse(match.group(3)!);
            return DateTime(year, month, day);
          } else {
            final day = int.parse(match.group(1)!);
            final monthStr = match.group(2)!;
            final year = int.parse(match.group(3)!);
            final monthMap = {
              'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
              'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
            };
            final month = monthMap[monthStr.substring(0, 3)];
            if (month != null) {
              return DateTime(year, month, day);
            }
          }
        } catch (e) {
          // Invalid date, continue
        }
      }
    }
    return null;
  }

  /// Check if sender is from a known bank/financial institution
  static bool isFromBank(String senderEmail) {
    return bankSenderPatterns.any((pattern) => pattern.hasMatch(senderEmail));
  }

  /// Parse email content to detect transaction type and amount
  static Map<String, dynamic>? parseEmail({
    required String senderEmail,
    required String subject,
    required String body,
    required DateTime receivedAt,
  }) {
    // Check if from known bank
    if (!isFromBank(senderEmail)) {
      return null;
    }

    // Combine subject and body for parsing
    final content = '$subject\n$body';

    // Try to detect UPI transactions first
    for (final pattern in transactionPatterns['upi']!) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          return {
            'type': 'upi',
            'amount': amount,
            'merchant': extractMerchant(content),
            'transactionDate': extractTransactionDate(content) ?? receivedAt,
            'rawText': content,
            'senderEmail': senderEmail,
            'subject': subject,
          };
        }
      }
    }

    // Check for credit card transactions
    for (final pattern in transactionPatterns['creditCard']!) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          return {
            'type': 'credit_card',
            'amount': amount,
            'merchant': extractMerchant(content),
            'transactionDate': extractTransactionDate(content) ?? receivedAt,
            'rawText': content,
            'senderEmail': senderEmail,
            'subject': subject,
          };
        }
      }
    }

    // Check for debit transactions
    for (final pattern in transactionPatterns['debit']!) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          return {
            'type': 'debit',
            'amount': amount,
            'merchant': extractMerchant(content),
            'transactionDate': extractTransactionDate(content) ?? receivedAt,
            'rawText': content,
            'senderEmail': senderEmail,
            'subject': subject,
          };
        }
      }
    }

    // Check for credit transactions
    for (final pattern in transactionPatterns['credit']!) {
      final match = pattern.firstMatch(content);
      if (match != null) {
        final amountStr = match.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          return {
            'type': 'credit',
            'amount': amount,
            'merchant': extractMerchant(content),
            'transactionDate': extractTransactionDate(content) ?? receivedAt,
            'rawText': content,
            'senderEmail': senderEmail,
            'subject': subject,
          };
        }
      }
    }

    return null;
  }

  /// Add parsed email to queue for user review
  static Future<bool> addToQueue({
    required String userId,
    required Map<String, dynamic> parsedData,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emailTransactionQueue')
          .add({
        ...parsedData,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error adding email to queue: $e');
      return false;
    }
  }

  /// Get pending emails from queue
  static Stream<List<Map<String, dynamic>>> getPendingEmails({
    required String userId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('emailTransactionQueue')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Update email status (approved/rejected)
  static Future<bool> updateEmailStatus({
    required String userId,
    required String queueId,
    required String status,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emailTransactionQueue')
          .doc(queueId)
          .update({
        'status': status,
        'processedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating email status: $e');
      return false;
    }
  }

  /// Import approved email to expenses
  static Future<bool> importToExpense({
    required String userId,
    required String queueId,
    required Map<String, dynamic> parsedData,
  }) async {
    try {
      // Convert transactionDate if it's a Timestamp, otherwise use as DateTime
      final transactionDate = parsedData['transactionDate'];
      final DateTime dateTime;
      if (transactionDate is Timestamp) {
        dateTime = transactionDate.toDate();
      } else if (transactionDate is DateTime) {
        dateTime = transactionDate;
      } else {
        dateTime = DateTime.now();
      }

      // Add to expenses collection
      await _firestore.collection('expenses').add({
        'userId': userId,
        'title': parsedData['merchant'] ?? 'Email Transaction',
        'amount': parsedData['amount'],
        'date': Timestamp.fromDate(dateTime),
        'category': _suggestCategory(parsedData['type'], parsedData['merchant']),
        'notes': 'Imported from email: ${parsedData['subject']}',
        'paidBy': userId,
        'splitWith': [userId],
        'source': 'email',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update queue status
      await updateEmailStatus(
        userId: userId,
        queueId: queueId,
        status: 'approved',
      );

      return true;
    } catch (e) {
      print('Error importing email to expense: $e');
      return false;
    }
  }

  /// Suggest category based on transaction type and merchant
  static String _suggestCategory(String? type, String? merchant) {
    if (merchant != null) {
      final merchantLower = merchant.toLowerCase();
      if (merchantLower.contains('food') ||
          merchantLower.contains('restaurant') ||
          merchantLower.contains('cafe') ||
          merchantLower.contains('zomato') ||
          merchantLower.contains('swiggy')) {
        return 'Food & Dining';
      }
      if (merchantLower.contains('fuel') ||
          merchantLower.contains('petrol') ||
          merchantLower.contains('gas')) {
        return 'Transportation';
      }
      if (merchantLower.contains('amazon') ||
          merchantLower.contains('flipkart') ||
          merchantLower.contains('shop')) {
        return 'Shopping';
      }
      if (merchantLower.contains('movie') ||
          merchantLower.contains('cinema') ||
          merchantLower.contains('netflix') ||
          merchantLower.contains('spotify')) {
        return 'Entertainment';
      }
    }

    return type == 'credit' ? 'Income' : 'Other';
  }
}

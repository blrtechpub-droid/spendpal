import '../models/local_transaction_model.dart';
import 'local_db_service.dart';

/// Service for syncing and merging SMS and Email transactions
///
/// Finds duplicates between SMS and Email sources
/// Identifies exclusive transactions (SMS-only or Email-only)
/// Helps user decide which to keep
class TransactionSyncService {
  static final LocalDBService _localDB = LocalDBService.instance;

  /// Result of comparing transactions
  static Future<SyncResult> compareTransactions({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    print('🔄 Comparing SMS and Email transactions...');

    // Get SMS transactions
    final smsTransactions = await _localDB.getTransactions(
      userId: userId,
      source: TransactionSource.sms,
      startDate: startDate,
      endDate: endDate,
      status: TransactionStatus.pending, // Only unconfirmed
    );

    // Get Email transactions
    final emailTransactions = await _localDB.getTransactions(
      userId: userId,
      source: TransactionSource.email,
      startDate: startDate,
      endDate: endDate,
      status: TransactionStatus.pending, // Only unconfirmed
    );

    print('📊 Found ${smsTransactions.length} SMS + ${emailTransactions.length} Email transactions');

    final duplicates = <DuplicateTransaction>[];
    final smsOnly = <LocalTransactionModel>[];
    final emailOnly = <LocalTransactionModel>[];

    final matchedEmailIds = <String>{};

    // Find duplicates
    for (final sms in smsTransactions) {
      bool foundMatch = false;

      for (final email in emailTransactions) {
        if (matchedEmailIds.contains(email.id)) continue;

        if (_isLikelyDuplicate(sms, email)) {
          duplicates.add(DuplicateTransaction(
            smsTransaction: sms,
            emailTransaction: email,
            confidence: _calculateMatchConfidence(sms, email),
          ));
          matchedEmailIds.add(email.id);
          foundMatch = true;
          break;
        }
      }

      if (!foundMatch) {
        smsOnly.add(sms);
      }
    }

    // Find email-only transactions
    for (final email in emailTransactions) {
      if (!matchedEmailIds.contains(email.id)) {
        emailOnly.add(email);
      }
    }

    print('✅ Comparison complete:');
    print('   Duplicates: ${duplicates.length}');
    print('   SMS-only: ${smsOnly.length}');
    print('   Email-only: ${emailOnly.length}');

    return SyncResult(
      duplicates: duplicates,
      smsOnly: smsOnly,
      emailOnly: emailOnly,
    );
  }

  /// Check if two transactions are likely duplicates
  static bool _isLikelyDuplicate(
    LocalTransactionModel t1,
    LocalTransactionModel t2,
  ) {
    // 1. Amount must match exactly
    if (t1.amount != t2.amount) return false;

    // 2. Date must be within 24 hours
    final timeDiff = t1.transactionDate.difference(t2.transactionDate).abs();
    if (timeDiff.inHours > 24) return false;

    // 3. Merchant should be similar
    if (_isMerchantSimilar(t1.merchant, t2.merchant)) return true;

    // 4. Transaction ID match (if both have it)
    if (t1.transactionId != null &&
        t2.transactionId != null &&
        t1.transactionId == t2.transactionId) {
      return true;
    }

    return false;
  }

  /// Check if merchant names are similar (fuzzy match)
  static bool _isMerchantSimilar(String m1, String m2) {
    final clean1 = m1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final clean2 = m2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    // Exact match after cleaning
    if (clean1 == clean2) return true;

    // One contains the other
    if (clean1.contains(clean2) || clean2.contains(clean1)) return true;

    // Levenshtein distance < 3
    final distance = _levenshteinDistance(clean1, clean2);
    return distance <= 2;
  }

  /// Calculate match confidence (0-100%)
  static double _calculateMatchConfidence(
    LocalTransactionModel t1,
    LocalTransactionModel t2,
  ) {
    double confidence = 0;

    // Amount match: 40%
    if (t1.amount == t2.amount) confidence += 40;

    // Date proximity: 30%
    final hoursDiff = t1.transactionDate.difference(t2.transactionDate).abs().inHours;
    if (hoursDiff == 0) {
      confidence += 30;
    } else if (hoursDiff <= 6) {
      confidence += 20;
    } else if (hoursDiff <= 24) {
      confidence += 10;
    }

    // Merchant similarity: 30%
    final clean1 = t1.merchant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final clean2 = t2.merchant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (clean1 == clean2) {
      confidence += 30;
    } else if (clean1.contains(clean2) || clean2.contains(clean1)) {
      confidence += 20;
    }

    return confidence;
  }

  /// Levenshtein distance for fuzzy string matching
  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;
    final matrix = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[len1][len2];
  }

  /// Merge action: Keep SMS version
  static Future<bool> keepSms(DuplicateTransaction duplicate) async {
    // Delete email version
    await _localDB.deleteTransaction(duplicate.emailTransaction.id);
    // Confirm SMS version
    final updated = duplicate.smsTransaction.copyWith(
      status: TransactionStatus.confirmed,
    );
    return await _localDB.updateTransaction(updated);
  }

  /// Merge action: Keep Email version
  static Future<bool> keepEmail(DuplicateTransaction duplicate) async {
    // Delete SMS version
    await _localDB.deleteTransaction(duplicate.smsTransaction.id);
    // Confirm email version
    final updated = duplicate.emailTransaction.copyWith(
      status: TransactionStatus.confirmed,
    );
    return await _localDB.updateTransaction(updated);
  }

  /// Merge action: Keep both
  static Future<bool> keepBoth(DuplicateTransaction duplicate) async {
    // Confirm both
    final sms = duplicate.smsTransaction.copyWith(
      status: TransactionStatus.confirmed,
    );
    final email = duplicate.emailTransaction.copyWith(
      status: TransactionStatus.confirmed,
    );
    final r1 = await _localDB.updateTransaction(sms);
    final r2 = await _localDB.updateTransaction(email);
    return r1 && r2;
  }

  /// Merge action: Merge details (combine best of both)
  static Future<bool> mergeDetails(DuplicateTransaction duplicate) async {
    final sms = duplicate.smsTransaction;
    final email = duplicate.emailTransaction;

    // Create merged transaction with best data from both
    final merged = sms.copyWith(
      // Use email's merchant if it's longer/more detailed
      merchant: email.merchant.length > sms.merchant.length
          ? email.merchant
          : sms.merchant,
      // Use email's transaction date if available
      transactionDate: email.transactionDate,
      // Use email's transaction ID if SMS doesn't have it
      transactionId: sms.transactionId ?? email.transactionId,
      // Use email's account info if SMS doesn't have it
      accountInfo: sms.accountInfo ?? email.accountInfo,
      // Combine notes
      notes: [sms.notes, email.notes]
          .where((n) => n != null && n.isNotEmpty)
          .join(' | '),
      // Mark as confirmed
      status: TransactionStatus.confirmed,
    );

    // Delete email version
    await _localDB.deleteTransaction(email.id);
    // Update SMS version with merged data
    return await _localDB.updateTransaction(merged);
  }
}

/// Result of syncing SMS and Email transactions
class SyncResult {
  final List<DuplicateTransaction> duplicates;
  final List<LocalTransactionModel> smsOnly;
  final List<LocalTransactionModel> emailOnly;

  SyncResult({
    required this.duplicates,
    required this.smsOnly,
    required this.emailOnly,
  });

  int get totalDuplicates => duplicates.length;
  int get totalSmsOnly => smsOnly.length;
  int get totalEmailOnly => emailOnly.length;
  int get totalUnique => smsOnly.length + emailOnly.length;
}

/// Represents a potential duplicate transaction
class DuplicateTransaction {
  final LocalTransactionModel smsTransaction;
  final LocalTransactionModel emailTransaction;
  final double confidence; // 0-100%

  DuplicateTransaction({
    required this.smsTransaction,
    required this.emailTransaction,
    required this.confidence,
  });

  bool get isHighConfidence => confidence >= 80;
  bool get isMediumConfidence => confidence >= 60 && confidence < 80;
  bool get isLowConfidence => confidence < 60;
}

import 'package:spendpal/models/local_transaction_model.dart';

/// Service to handle transaction display logic including deduplication
class TransactionDisplayService {
  /// Mark duplicate transactions without removing them
  /// Returns ALL transactions with merge info indicating duplicates
  static List<TransactionWithMergeInfo> filterAndMergeDuplicates(
    List<LocalTransactionModel> transactions,
  ) {
    final result = <TransactionWithMergeInfo>[];

    for (int i = 0; i < transactions.length; i++) {
      final transaction = transactions[i];

      // Look for duplicates (but don't remove them!)
      final duplicates = <LocalTransactionModel>[];

      for (int j = 0; j < transactions.length; j++) {
        if (i == j) continue; // Skip self

        final other = transactions[j];

        if (_isDuplicate(transaction, other)) {
          duplicates.add(other);
        }
      }

      // Add ALL transactions with merge info
      result.add(TransactionWithMergeInfo(
        transaction: transaction,
        hasDuplicates: duplicates.isNotEmpty,
        duplicateSources: duplicates.map((d) => d.source).toSet().toList(),
        duplicateCount: duplicates.length,
      ));
    }

    return result;
  }

  /// Check if two transactions are duplicates
  static bool _isDuplicate(
    LocalTransactionModel t1,
    LocalTransactionModel t2,
  ) {
    // Same source - not duplicate
    if (t1.source == t2.source) return false;

    // Check by transaction ID (exact match)
    if (t1.transactionId != null &&
        t2.transactionId != null &&
        t1.transactionId!.isNotEmpty &&
        t2.transactionId!.isNotEmpty &&
        t1.transactionId == t2.transactionId) {
      return true;
    }

    // Check by amount + date + merchant (fuzzy match)
    final amountMatch = (t1.amount - t2.amount).abs() < 0.01; // Within 1 paisa

    final dateMatch = t1.transactionDate
            .difference(t2.transactionDate)
            .abs()
            .inHours <
        24; // Within 24 hours

    final merchantMatch = _isMerchantSimilar(t1.merchant, t2.merchant);

    return amountMatch && dateMatch && merchantMatch;
  }

  /// Check if two merchant names are similar
  static bool _isMerchantSimilar(String merchant1, String merchant2) {
    final clean1 = _cleanMerchantName(merchant1);
    final clean2 = _cleanMerchantName(merchant2);

    // Exact match
    if (clean1 == clean2) return true;

    // Contains match
    if (clean1.contains(clean2) || clean2.contains(clean1)) return true;

    // Word similarity
    final words1 = clean1.split(' ').where((w) => w.isNotEmpty).toSet();
    final words2 = clean2.split(' ').where((w) => w.isNotEmpty).toSet();

    if (words1.isEmpty || words2.isEmpty) return false;

    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    final similarity = intersection / union;

    return similarity >= 0.6; // 60% similarity threshold
  }

  /// Clean merchant name for comparison
  static String _cleanMerchantName(String merchant) {
    return merchant
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Filter out transactions that are already shared/categorized
  static List<T> filterPendingOnly<T extends LocalTransactionModel>(
    List<T> transactions,
  ) {
    return transactions
        .where((t) => t.status == TransactionStatus.pending)
        .toList();
  }
}

/// Transaction with merge information
class TransactionWithMergeInfo {
  final LocalTransactionModel transaction;
  final bool hasDuplicates;
  final List<TransactionSource> duplicateSources;
  final int duplicateCount;

  TransactionWithMergeInfo({
    required this.transaction,
    required this.hasDuplicates,
    required this.duplicateSources,
    required this.duplicateCount,
  });

  /// Get merge badge text
  String get mergeBadgeText {
    if (!hasDuplicates) return '';

    final sources = <String>[];
    if (duplicateSources.contains(TransactionSource.sms)) sources.add('SMS');
    if (duplicateSources.contains(TransactionSource.email)) sources.add('Email');

    return 'Also in ${sources.join(' & ')}';
  }

  /// Get merge icon
  String get mergeIcon {
    if (!hasDuplicates) return '';

    final hasSms = duplicateSources.contains(TransactionSource.sms);
    final hasEmail = duplicateSources.contains(TransactionSource.email);

    if (hasSms && hasEmail) return '📧💬';
    if (hasSms) return '💬';
    if (hasEmail) return '📧';

    return '';
  }
}

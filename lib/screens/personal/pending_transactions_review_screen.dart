import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/models/local_transaction_model.dart';
import 'package:spendpal/services/local_db_service.dart';
import 'package:spendpal/services/transaction_display_service.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/widgets/transaction_categorization_dialog.dart';
import 'package:spendpal/widgets/tracker_badge_widget.dart';

/// Unified pending transactions screen with deduplication
/// Shows combined SMS + Email transactions with smart merge badges
class PendingTransactionsReviewScreen extends StatefulWidget {
  const PendingTransactionsReviewScreen({super.key});

  @override
  State<PendingTransactionsReviewScreen> createState() =>
      _PendingTransactionsReviewScreenState();
}

class _PendingTransactionsReviewScreenState
    extends State<PendingTransactionsReviewScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _refreshKey = 0;

  void _refreshTransactions() {
    if (mounted) {
      setState(() {
        _refreshKey++;
      });
    }
  }

  Future<List<TransactionWithMergeInfo>> _loadDeduplicatedTransactions() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return [];
    }

    // Load both SMS and Email transactions
    final smsTransactions = await LocalDBService.instance.getTransactions(
      userId: currentUser.uid,
      source: TransactionSource.sms,
      status: TransactionStatus.pending,
    );

    final emailTransactions = await LocalDBService.instance.getTransactions(
      userId: currentUser.uid,
      source: TransactionSource.email,
      status: TransactionStatus.pending,
    );

    // Combine both sources
    final allTransactions = [...smsTransactions, ...emailTransactions];

    // Sort by date (newest first)
    allTransactions.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    // Apply deduplication and merge
    return TransactionDisplayService.filterAndMergeDuplicates(allTransactions);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Queue')),
        body: const Center(child: Text('Please login first')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review Queue'),
            Text(
              'Smart deduplication enabled',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: FutureBuilder<List<TransactionWithMergeInfo>>(
        key: ValueKey(_refreshKey),
        future: _loadDeduplicatedTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.tealAccent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading transactions',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final mergedTransactions = snapshot.data ?? [];

          if (mergedTransactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox,
                      size: 80,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Pending Transactions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan SMS or sync emails to see transactions here',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Header with stats
              Container(
                padding: const EdgeInsets.all(16),
                color: theme.cardTheme.color,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total',
                        '${mergedTransactions.length}',
                        Icons.list,
                        Colors.blue,
                        theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Merged',
                        '${mergedTransactions.where((t) => t.hasDuplicates).length}',
                        Icons.merge_type,
                        Colors.orange,
                        theme,
                      ),
                    ),
                  ],
                ),
              ),

              // Info banner
              if (mergedTransactions.any((t) => t.hasDuplicates))
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Duplicates automatically merged. Categorizing one updates both.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Transaction list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: mergedTransactions.length,
                  itemBuilder: (context, index) {
                    final mergeInfo = mergedTransactions[index];
                    return _buildTransactionCard(
                      context,
                      theme,
                      mergeInfo,
                      userId,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    ThemeData theme,
    TransactionWithMergeInfo mergeInfo,
    String userId,
  ) {
    final transaction = mergeInfo.transaction;
    final amount = transaction.amount;
    final merchant = transaction.merchant;
    final transactionDate = transaction.transactionDate;
    final source = transaction.source;

    // Source icon and color
    final sourceIcon = source == TransactionSource.sms
        ? Icons.message
        : Icons.email_outlined;
    final sourceColor = source == TransactionSource.sms
        ? AppTheme.tealAccent
        : Colors.blue;

    return Card(
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: mergeInfo.hasDuplicates ? 3 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: mergeInfo.hasDuplicates
            ? BorderSide(color: Colors.orange.withValues(alpha: 0.5), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _showTransactionDetail(context, theme, mergeInfo, userId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Merchant + Amount
              Row(
                children: [
                  // Source icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      sourceIcon,
                      color: sourceColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Merchant and date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchant,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(transactionDate),
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Amount
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: sourceColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Badges row (Merge badge + Tracker badge)
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Merge badge (if duplicate)
                  if (mergeInfo.hasDuplicates)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mergeInfo.mergeIcon,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            mergeInfo.mergeBadgeText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Tracker badge
                  TrackerBadge(
                    trackerId: transaction.trackerId,
                    confidence: transaction.trackerConfidence,
                    userId: userId,
                    compact: true,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _categorizeTransaction(mergeInfo, userId),
                      icon: const Icon(Icons.category_outlined, size: 16),
                      label: const Text('Categorize', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.tealAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareTransaction(mergeInfo),
                      icon: const Icon(Icons.group, size: 16),
                      label: const Text('Share', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.tealAccent,
                        side: const BorderSide(color: AppTheme.tealAccent),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _ignoreTransaction(mergeInfo, userId),
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text('Ignore', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.textTheme.bodyMedium?.color,
                        side: BorderSide(color: theme.dividerTheme.color ?? Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionDetail(
    BuildContext context,
    ThemeData theme,
    TransactionWithMergeInfo mergeInfo,
    String userId,
  ) {
    final transaction = mergeInfo.transaction;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 16),

            if (mergeInfo.hasDuplicates) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.merge_type, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This transaction appears in ${mergeInfo.duplicateCount + 1} sources. Categorizing here will update all copies.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerTheme.color ?? Colors.grey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Merchant', transaction.merchant, theme),
                  _buildDetailRow('Amount', '₹${transaction.amount.toStringAsFixed(2)}', theme),
                  _buildDetailRow(
                    'Date',
                    DateFormat('dd MMM yyyy, hh:mm a').format(transaction.transactionDate),
                    theme,
                  ),
                  _buildDetailRow('Source', transaction.source.name.toUpperCase(), theme),
                  _buildDetailRow('Category', transaction.category, theme),
                  const SizedBox(height: 8),
                  Text(
                    'Raw Content:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.rawContent ?? 'No content',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodyMedium?.color,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _categorizeTransaction(mergeInfo, userId);
                    },
                    icon: const Icon(Icons.category),
                    label: const Text('Categorize'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tealAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _ignoreTransaction(mergeInfo, userId);
                  },
                  icon: const Icon(Icons.block),
                  color: theme.textTheme.bodyMedium?.color,
                  tooltip: 'Ignore',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _categorizeTransaction(
    TransactionWithMergeInfo mergeInfo,
    String userId,
  ) async {
    final transaction = mergeInfo.transaction;

    final result = await showDialog<TransactionCategorizationResult>(
      context: context,
      builder: (context) => TransactionCategorizationDialog(
        title: transaction.merchant,
        amount: transaction.amount,
        transactionType: transaction.isDebit ? TransactionType.debit : TransactionType.credit,
        description: 'From ${transaction.source.name}: ${transaction.sourceIdentifier ?? 'Unknown'}',
        trackerId: null, // TODO: Add tracker matching logic
      ),
    );

    if (result == null) return; // User cancelled

    // Show loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Categorizing...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      // Update transaction status to confirmed
      final updatedTransaction = transaction.copyWith(
        status: TransactionStatus.confirmed,
        notes: result.notes,
      );
      await LocalDBService.instance.updateTransaction(updatedTransaction);

      // If this transaction has duplicates, update all copies
      if (mergeInfo.hasDuplicates) {
        await _updateDuplicateTransactions(transaction, userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction categorized successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      _refreshTransactions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error categorizing transaction: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Update all duplicate copies of a transaction when one is categorized
  Future<void> _updateDuplicateTransactions(
    LocalTransactionModel primaryTransaction,
    String userId,
  ) async {
    try {
      // Load all pending transactions from both sources
      final smsTransactions = await LocalDBService.instance.getTransactions(
        userId: userId,
        source: TransactionSource.sms,
        status: TransactionStatus.pending,
      );

      final emailTransactions = await LocalDBService.instance.getTransactions(
        userId: userId,
        source: TransactionSource.email,
        status: TransactionStatus.pending,
      );

      final allTransactions = [...smsTransactions, ...emailTransactions];

      // Find all duplicates of the primary transaction
      for (final other in allTransactions) {
        // Skip the primary transaction itself
        if (other.id == primaryTransaction.id) continue;

        // Check if this is a duplicate
        if (_isDuplicate(primaryTransaction, other)) {
          // Update the duplicate to confirmed status
          final updatedTransaction = LocalTransactionModel(
            id: other.id,
            source: other.source,
            sourceIdentifier: other.sourceIdentifier,
            amount: other.amount,
            merchant: other.merchant,
            category: other.category,
            transactionDate: other.transactionDate,
            rawContent: other.rawContent,
            status: TransactionStatus.confirmed,
            isDebit: other.isDebit,
            userId: other.userId,
            createdAt: other.createdAt,
            transactionId: other.transactionId,
            accountInfo: other.accountInfo,
            notes: other.notes,
            parsedAt: other.parsedAt,
            updatedAt: DateTime.now(),
            deviceId: other.deviceId,
            parsedBy: other.parsedBy,
            patternId: other.patternId,
            confidence: other.confidence,
          );

          await LocalDBService.instance.updateTransaction(updatedTransaction);
        }
      }
    } catch (e) {
      print('Error updating duplicate transactions: $e');
      // Don't throw - partial success is okay
    }
  }

  /// Check if two transactions are duplicates (same logic as TransactionDisplayService)
  bool _isDuplicate(LocalTransactionModel t1, LocalTransactionModel t2) {
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

    // Fuzzy match: amount + date + merchant
    final amountMatch = (t1.amount - t2.amount).abs() < 0.01;
    final dateMatch = t1.transactionDate
            .difference(t2.transactionDate)
            .abs()
            .inHours < 24;
    final merchantMatch = _isMerchantSimilar(t1.merchant, t2.merchant);

    return amountMatch && dateMatch && merchantMatch;
  }

  /// Check if two merchant names are similar (same logic as TransactionDisplayService)
  bool _isMerchantSimilar(String merchant1, String merchant2) {
    final clean1 = _cleanMerchantName(merchant1);
    final clean2 = _cleanMerchantName(merchant2);

    if (clean1 == clean2) return true;
    if (clean1.contains(clean2) || clean2.contains(clean1)) return true;

    final words1 = clean1.split(' ').where((w) => w.isNotEmpty).toSet();
    final words2 = clean2.split(' ').where((w) => w.isNotEmpty).toSet();
    if (words1.isEmpty || words2.isEmpty) return false;

    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    final similarity = intersection / union;

    return similarity >= 0.6;
  }

  /// Clean merchant name for comparison
  String _cleanMerchantName(String merchant) {
    return merchant
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _shareTransaction(TransactionWithMergeInfo mergeInfo) async {
    final transaction = mergeInfo.transaction;
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final result = await Navigator.pushNamed(
      context,
      '/add_expense',
      arguments: {
        'prefill': true,
        'title': transaction.merchant,
        'amount': transaction.amount.toString(),
        'category': transaction.category,
        'notes': 'From ${transaction.source.name}: ${transaction.sourceIdentifier ?? 'Unknown'}${transaction.notes != null ? '\n${transaction.notes}' : ''}',
        'date': transaction.transactionDate,
      },
    );

    if (result == true && mounted) {
      // Mark transaction as confirmed
      try {
        final updatedTransaction = LocalTransactionModel(
          id: transaction.id,
          source: transaction.source,
          sourceIdentifier: transaction.sourceIdentifier,
          amount: transaction.amount,
          merchant: transaction.merchant,
          category: transaction.category,
          transactionDate: transaction.transactionDate,
          rawContent: transaction.rawContent,
          status: TransactionStatus.confirmed,
          isDebit: transaction.isDebit,
          userId: transaction.userId,
          createdAt: transaction.createdAt,
          transactionId: transaction.transactionId,
          accountInfo: transaction.accountInfo,
          notes: transaction.notes,
          parsedAt: transaction.parsedAt,
          updatedAt: DateTime.now(),
          deviceId: transaction.deviceId,
          parsedBy: transaction.parsedBy,
          patternId: transaction.patternId,
          confidence: transaction.confidence,
        );
        await LocalDBService.instance.updateTransaction(updatedTransaction);

        // If this transaction has duplicates, update all copies
        if (mergeInfo.hasDuplicates) {
          await _updateDuplicateTransactions(transaction, userId);
        }

        _refreshTransactions();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shared successfully but failed to update status: $e'),
              backgroundColor: AppTheme.orangeAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _ignoreTransaction(
    TransactionWithMergeInfo mergeInfo,
    String userId,
  ) async {
    final transaction = mergeInfo.transaction;

    try {
      final updatedTransaction = LocalTransactionModel(
        id: transaction.id,
        source: transaction.source,
        sourceIdentifier: transaction.sourceIdentifier,
        amount: transaction.amount,
        merchant: transaction.merchant,
        category: transaction.category,
        transactionDate: transaction.transactionDate,
        rawContent: transaction.rawContent,
        status: TransactionStatus.ignored,
        isDebit: transaction.isDebit,
        userId: transaction.userId,
        createdAt: transaction.createdAt,
        transactionId: transaction.transactionId,
        accountInfo: transaction.accountInfo,
        notes: transaction.notes,
        parsedAt: transaction.parsedAt,
        updatedAt: DateTime.now(),
        deviceId: transaction.deviceId,
        parsedBy: transaction.parsedBy,
        patternId: transaction.patternId,
        confidence: transaction.confidence,
      );

      await LocalDBService.instance.updateTransaction(updatedTransaction);

      // If this transaction has duplicates, update all copies to ignored status
      if (mergeInfo.hasDuplicates) {
        await _updateDuplicateTransactionsToStatus(transaction, userId, TransactionStatus.ignored);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction ignored'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        _refreshTransactions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Update duplicate transactions to a specific status (for ignore action)
  Future<void> _updateDuplicateTransactionsToStatus(
    LocalTransactionModel primaryTransaction,
    String userId,
    TransactionStatus newStatus,
  ) async {
    try {
      final smsTransactions = await LocalDBService.instance.getTransactions(
        userId: userId,
        source: TransactionSource.sms,
        status: TransactionStatus.pending,
      );

      final emailTransactions = await LocalDBService.instance.getTransactions(
        userId: userId,
        source: TransactionSource.email,
        status: TransactionStatus.pending,
      );

      final allTransactions = [...smsTransactions, ...emailTransactions];

      for (final other in allTransactions) {
        if (other.id == primaryTransaction.id) continue;

        if (_isDuplicate(primaryTransaction, other)) {
          final updatedTransaction = LocalTransactionModel(
            id: other.id,
            source: other.source,
            sourceIdentifier: other.sourceIdentifier,
            amount: other.amount,
            merchant: other.merchant,
            category: other.category,
            transactionDate: other.transactionDate,
            rawContent: other.rawContent,
            status: newStatus,
            isDebit: other.isDebit,
            userId: other.userId,
            createdAt: other.createdAt,
            transactionId: other.transactionId,
            accountInfo: other.accountInfo,
            notes: other.notes,
            parsedAt: other.parsedAt,
            updatedAt: DateTime.now(),
            deviceId: other.deviceId,
            parsedBy: other.parsedBy,
            patternId: other.patternId,
            confidence: other.confidence,
          );

          await LocalDBService.instance.updateTransaction(updatedTransaction);
        }
      }
    } catch (e) {
      print('Error updating duplicate transactions to $newStatus: $e');
    }
  }
}

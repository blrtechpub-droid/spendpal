import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../models/local_transaction_model.dart';
import '../../services/transaction_sync_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';
import 'test_sync_data.dart';

class TransactionSyncScreen extends StatefulWidget {
  const TransactionSyncScreen({super.key});

  @override
  State<TransactionSyncScreen> createState() => _TransactionSyncScreenState();
}

class _TransactionSyncScreenState extends State<TransactionSyncScreen> {
  bool _isLoading = false;
  SyncResult? _syncResult;
  final _resolvedDuplicates = <String>{};

  @override
  void initState() {
    super.initState();
    _runSync();
  }

  Future<void> _runSync() async {
    setState(() => _isLoading = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final result = await TransactionSyncService.compareTransactions(
      userId: userId,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
    );

    setState(() {
      _syncResult = result;
      _isLoading = false;
    });
  }

  Future<void> _handleMergeAction(
    DuplicateTransaction duplicate,
    String action,
  ) async {
    bool success = false;

    switch (action) {
      case 'sms':
        success = await TransactionSyncService.keepSms(duplicate);
        break;
      case 'email':
        success = await TransactionSyncService.keepEmail(duplicate);
        break;
      case 'both':
        success = await TransactionSyncService.keepBoth(duplicate);
        break;
      case 'merge':
        success = await TransactionSyncService.mergeDetails(duplicate);
        break;
    }

    if (success) {
      setState(() {
        _resolvedDuplicates.add(duplicate.smsTransaction.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction ${action == 'both' ? 'kept both' : 'merged'}'),
            backgroundColor: AppTheme.tealAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync & Merge Transactions'),
        actions: [
          if (_syncResult != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _runSync,
              tooltip: 'Refresh',
            ),
          // Debug: Clear test data
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                await TestSyncData.clearTestData();
                _runSync();
              },
              tooltip: 'Clear Test Data',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSyncResults(),
      // Debug: Generate test data button
      floatingActionButton: kDebugMode
          ? FloatingActionButton.extended(
              onPressed: () async {
                await TestSyncData.generateTestDuplicates();
                _runSync();
              },
              icon: const Icon(Icons.science),
              label: const Text('Generate Test Data'),
              backgroundColor: Colors.purple,
            )
          : null,
    );
  }

  Widget _buildSyncResults() {
    if (_syncResult == null) {
      return const Center(child: Text('No sync results'));
    }

    final unresolved = _syncResult!.duplicates
        .where((d) => !_resolvedDuplicates.contains(d.smsTransaction.id))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          _buildSummaryCard(),
          const SizedBox(height: 24),

          // Duplicates Section
          if (unresolved.isNotEmpty) ...[
            Text(
              'Potential Duplicates (${unresolved.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...unresolved.map((duplicate) => _buildDuplicateCard(duplicate)),
          ],

          // SMS-Only Section
          if (_syncResult!.smsOnly.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'SMS Only (${_syncResult!.smsOnly.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...(_syncResult!.smsOnly.take(5).map((t) => _buildTransactionItem(t, 'SMS'))),
            if (_syncResult!.smsOnly.length > 5)
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text('View all ${_syncResult!.smsOnly.length} →'),
                ),
              ),
          ],

          // Email-Only Section
          if (_syncResult!.emailOnly.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Email Only (${_syncResult!.emailOnly.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...(_syncResult!.emailOnly.take(5).map((t) => _buildTransactionItem(t, 'Email'))),
            if (_syncResult!.emailOnly.length > 5)
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text('View all ${_syncResult!.emailOnly.length} →'),
                ),
              ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final unresolved = _syncResult!.duplicates.length - _resolvedDuplicates.length;

    return Card(
      color: AppTheme.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sync Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  '🔄',
                  unresolved.toString(),
                  'Duplicates',
                  Colors.orange,
                ),
                _buildSummaryItem(
                  '💬',
                  _syncResult!.smsOnly.length.toString(),
                  'SMS Only',
                  AppTheme.tealAccent,
                ),
                _buildSummaryItem(
                  '📧',
                  _syncResult!.emailOnly.length.toString(),
                  'Email Only',
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String icon, String count, String label, Color color) {
    return Column(
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 32),
        ),
        const SizedBox(height: 4),
        Text(
          count,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDuplicateCard(DuplicateTransaction duplicate) {
    return Card(
      color: AppTheme.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Header with confidence
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getConfidenceColor(duplicate.confidence).withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.formatCurrency(duplicate.smsTransaction.amount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(duplicate.confidence),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${duplicate.confidence.toStringAsFixed(0)}% match',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SMS Transaction
          _buildTransactionComparison(
            duplicate.smsTransaction,
            'SMS',
            Icons.sms,
            AppTheme.tealAccent,
          ),

          const Divider(height: 1),

          // Email Transaction
          _buildTransactionComparison(
            duplicate.emailTransaction,
            'Email',
            Icons.email,
            Colors.blue,
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleMergeAction(duplicate, 'sms'),
                    icon: const Icon(Icons.sms, size: 16),
                    label: const Text('Keep SMS', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleMergeAction(duplicate, 'email'),
                    icon: const Icon(Icons.email, size: 16),
                    label: const Text('Keep Email', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleMergeAction(duplicate, 'merge'),
                    icon: const Icon(Icons.merge_type, size: 16),
                    label: const Text('Merge Details', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tealAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleMergeAction(duplicate, 'both'),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Keep Both', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionComparison(
    LocalTransactionModel transaction,
    String source,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.merchant,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy, HH:mm').format(transaction.transactionDate),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                if (transaction.sourceIdentifier != null)
                  Text(
                    transaction.sourceIdentifier!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(LocalTransactionModel transaction, String source) {
    return Card(
      color: AppTheme.cardBackground,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          source == 'SMS' ? Icons.sms : Icons.email,
          color: source == 'SMS' ? AppTheme.tealAccent : Colors.blue,
        ),
        title: Text(transaction.merchant),
        subtitle: Text(
          DateFormat('dd MMM yyyy').format(transaction.transactionDate),
        ),
        trailing: Text(
          context.formatCurrency(transaction.amount),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }
}

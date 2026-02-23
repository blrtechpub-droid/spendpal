import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/scan_history_model.dart';
import '../../models/local_transaction_model.dart';
import '../../services/local_db_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';

/// Screen displaying scan history with cost tracking
class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  final LocalDBService _localDB = LocalDBService.instance;
  List<ScanHistoryModel> _history = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  TransactionSource? _filterSource;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final history = await _localDB.getScanHistory(
        userId: userId,
        source: _filterSource,
      );
      final stats = await _localDB.getScanStatistics(userId: userId);

      setState(() {
        _history = history;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading scan history: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          // Filter dropdown
          PopupMenuButton<TransactionSource?>(
            icon: Icon(
              Icons.filter_list,
              color: _filterSource != null ? AppTheme.tealAccent : null,
            ),
            tooltip: 'Filter by source',
            onSelected: (source) {
              setState(() => _filterSource = source);
              _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Sources'),
              ),
              const PopupMenuItem(
                value: TransactionSource.sms,
                child: Text('SMS Only'),
              ),
              const PopupMenuItem(
                value: TransactionSource.email,
                child: Text('Email Only'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Summary card
                  SliverToBoxAdapter(
                    child: _buildSummaryCard(theme),
                  ),

                  // History list header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Scan Records',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_history.length} scans',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // History table
                  if (_history.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: theme.disabledColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No scan history yet',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Scan SMS or Email to see history here',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildHistoryCard(theme, _history[index]),
                        childCount: _history.length,
                      ),
                    ),

                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final totalScans = _stats['totalScans'] ?? 0;
    final totalCost = (_stats['totalCost'] as double?) ?? 0.0;
    final totalSaved = (_stats['totalSaved'] as double?) ?? 0.0;
    final totalTransactions = _stats['totalTransactions'] ?? 0;
    final totalAI = _stats['totalAIProcessed'] ?? 0;
    final totalPattern = _stats['totalPatternMatched'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[400]!, Colors.indigo[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'All-Time Statistics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats row 1
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Total Scans', totalScans.toString(), Colors.white),
              _buildStatItem('Transactions', totalTransactions.toString(), Colors.white),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row 2
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Pattern Matched', totalPattern.toString(), Colors.greenAccent),
              _buildStatItem('AI Processed', totalAI.toString(), Colors.orangeAccent),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),

          // Cost summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total AI Cost',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.formatCurrency(totalCost),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Cost Saved',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.formatCurrency(totalSaved),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(ThemeData theme, ScanHistoryModel scan) {
    final isSms = scan.source == TransactionSource.sms;
    final isAiMode = scan.mode == ScanMode.ai;
    final cost = scan.cost;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _showScanDetails(theme, scan),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Source icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isSms ? AppTheme.tealAccent : Colors.blue).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSms ? Icons.message : Icons.email,
                      color: isSms ? AppTheme.tealAccent : Colors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Date and mode
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMM dd, yyyy  h:mm a').format(scan.scanDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isAiMode ? Colors.orange : AppTheme.tealAccent).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isAiMode ? 'AI Mode' : 'Fast Mode',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isAiMode ? Colors.orange : AppTheme.tealAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Last ${scan.daysScanned} days',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Cost
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        context.formatCurrency(cost),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cost > 0 ? Colors.orange : Colors.green,
                        ),
                      ),
                      Text(
                        '${scan.aiProcessed} AI calls',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: theme.dividerColor),
              const SizedBox(height: 12),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(theme, 'Scanned', scan.filteredMessages.toString()),
                  _buildMiniStat(theme, 'Pattern', scan.patternMatched.toString(), Colors.green),
                  _buildMiniStat(theme, 'AI', scan.aiProcessed.toString(), Colors.orange),
                  _buildMiniStat(theme, 'Found', scan.transactionsFound.toString(), AppTheme.tealAccent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(ThemeData theme, String label, String value, [Color? valueColor]) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? theme.textTheme.bodyLarge?.color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  void _showScanDetails(ThemeData theme, ScanHistoryModel scan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Scan Details',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Details
              _buildDetailRow(theme, 'Source', scan.source == TransactionSource.sms ? 'SMS' : 'Email'),
              _buildDetailRow(theme, 'Mode', scan.mode == ScanMode.ai ? 'AI Mode (Accurate)' : 'Fast Mode (Regex)'),
              _buildDetailRow(theme, 'Scan Date', DateFormat('MMM dd, yyyy h:mm a').format(scan.scanDate)),
              _buildDetailRow(theme, 'Date Range', '${DateFormat('MMM dd').format(scan.rangeStart)} - ${DateFormat('MMM dd, yyyy').format(scan.rangeEnd)}'),
              _buildDetailRow(theme, 'Days Scanned', '${scan.daysScanned} days'),

              const SizedBox(height: 16),
              Divider(color: theme.dividerColor),
              const SizedBox(height: 16),

              Text(
                'Processing Statistics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              _buildDetailRow(theme, 'Total Messages', scan.totalMessages.toString()),
              _buildDetailRow(theme, 'Filtered (Bank)', scan.filteredMessages.toString()),
              _buildDetailRow(theme, 'Already Processed', scan.alreadyProcessed.toString()),
              _buildDetailRow(theme, 'Pattern Matched', scan.patternMatched.toString(), Colors.green),
              _buildDetailRow(theme, 'AI Processed', scan.aiProcessed.toString(), Colors.orange),
              _buildDetailRow(theme, 'Transactions Found', scan.transactionsFound.toString(), AppTheme.tealAccent),
              _buildDetailRow(theme, 'New Patterns Learned', scan.newPatternsLearned.toString()),

              const SizedBox(height: 16),
              Divider(color: theme.dividerColor),
              const SizedBox(height: 16),

              Text(
                'Cost Analysis',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              _buildDetailRow(theme, 'AI Cost', context.formatCurrency(scan.cost), Colors.orange),
              _buildDetailRow(theme, 'Potential Cost', context.formatCurrency(scan.potentialCost)),
              _buildDetailRow(theme, 'Cost Saved', context.formatCurrency(scan.savedCost), Colors.green),
              _buildDetailRow(theme, 'Savings', '${scan.savingsPercent.toStringAsFixed(1)}%', Colors.green),

              const SizedBox(height: 24),

              // Delete button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDelete(scan),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Delete Record', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(ScanHistoryModel scan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text('This will remove this scan record from history. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _localDB.deleteScanHistory(scan.id);
      Navigator.pop(context); // Close bottom sheet
      _loadData(); // Refresh list
    }
  }
}

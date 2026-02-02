import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/services/local_db_service.dart';
import 'package:spendpal/models/local_transaction_model.dart';
import 'package:spendpal/utils/currency_utils.dart';

/// SMS Processing Statistics Screen
///
/// Shows detailed statistics about SMS processing:
/// - Total SMS scanned
/// - Pattern matches vs AI processing
/// - Cost savings from incremental learning
/// - Processing speed and efficiency
/// - Pattern library stats
class SmsProcessingStatsScreen extends StatefulWidget {
  const SmsProcessingStatsScreen({super.key});

  @override
  State<SmsProcessingStatsScreen> createState() => _SmsProcessingStatsScreenState();
}

class _SmsProcessingStatsScreenState extends State<SmsProcessingStatsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Load all SMS transactions
      final smsTransactions = await LocalDBService.instance.getTransactions(
        userId: currentUser.uid,
        source: TransactionSource.sms,
      );

      // Load all patterns
      final patterns = await LocalDBService.instance.getPatterns(userId: currentUser.uid);
      final activePatterns = patterns.where((p) => p.isActive).toList();

      // Calculate statistics
      final patternMatched = smsTransactions.where((t) => t.parsedBy == ParseMethod.regex).length;
      final aiProcessed = smsTransactions.where((t) => t.parsedBy == ParseMethod.ai).length;
      final totalProcessed = smsTransactions.length;

      // Cost calculation (₹0.13 per AI call)
      final aiCost = aiProcessed * 0.13;
      final potentialCost = totalProcessed * 0.13;
      final savedCost = potentialCost - aiCost;
      final savingsPercent = totalProcessed > 0 ? (savedCost / potentialCost * 100) : 0;

      // Pattern efficiency
      final patternAccuracy = patterns.fold<double>(0, (sum, p) => sum + p.accuracy) /
                              (patterns.isEmpty ? 1 : patterns.length);

      final totalMatches = patterns.fold<int>(0, (sum, p) => sum + p.matchCount);
      final totalFails = patterns.fold<int>(0, (sum, p) => sum + p.failCount);

      // Top performing patterns
      final topPatterns = List<Map<String, dynamic>>.from(patterns.map((p) => {
        'category': p.category,
        'accuracy': p.accuracy,
        'matchCount': p.matchCount,
        'description': p.description,
      }))..sort((a, b) => (b['matchCount'] as int).compareTo(a['matchCount'] as int));

      setState(() {
        _stats = {
          'totalProcessed': totalProcessed,
          'patternMatched': patternMatched,
          'aiProcessed': aiProcessed,
          'aiCost': aiCost,
          'savedCost': savedCost,
          'savingsPercent': savingsPercent,
          'totalPatterns': patterns.length,
          'activePatterns': activePatterns.length,
          'patternAccuracy': patternAccuracy,
          'totalMatches': totalMatches,
          'totalFails': totalFails,
          'topPatterns': topPatterns.take(5).toList(),
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('SMS Processing Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Overview Card
                  _buildOverviewCard(theme),
                  const SizedBox(height: 16),

                  // Cost Savings Card
                  _buildCostSavingsCard(theme),
                  const SizedBox(height: 16),

                  // Pattern Library Card
                  _buildPatternLibraryCard(theme),
                  const SizedBox(height: 16),

                  // Top Patterns Card
                  _buildTopPatternsCard(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard(ThemeData theme) {
    final totalProcessed = _stats['totalProcessed'] ?? 0;
    final patternMatched = _stats['patternMatched'] ?? 0;
    final aiProcessed = _stats['aiProcessed'] ?? 0;

    final patternPercent = totalProcessed > 0 ? (patternMatched / totalProcessed * 100) : 0;
    final aiPercent = totalProcessed > 0 ? (aiProcessed / totalProcessed * 100) : 0;

    return Card(
      color: theme.cardTheme.color,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.analytics, color: Colors.blue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Processing Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last 90 days',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Total Processed
            _buildStatRow(
              theme,
              'Total SMS Processed',
              NumberFormat('#,##0').format(totalProcessed),
              Colors.blue,
              Icons.sms,
            ),
            const SizedBox(height: 16),

            // Pattern Matched
            Row(
              children: [
                Expanded(
                  child: _buildStatRow(
                    theme,
                    'Pattern Matched',
                    NumberFormat('#,##0').format(patternMatched),
                    Colors.green,
                    Icons.pattern,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${patternPercent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // AI Processed
            Row(
              children: [
                Expanded(
                  child: _buildStatRow(
                    theme,
                    'AI Processed',
                    NumberFormat('#,##0').format(aiProcessed),
                    Colors.purple,
                    Icons.auto_awesome,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${aiPercent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostSavingsCard(ThemeData theme) {
    final savedCost = _stats['savedCost'] ?? 0.0;
    final aiCost = _stats['aiCost'] ?? 0.0;
    final savingsPercent = _stats['savingsPercent'] ?? 0.0;

    return Card(
      color: theme.cardTheme.color,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.savings, color: Colors.amber, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cost Savings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Incremental learning optimization',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Cost Saved
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    context.formatCurrency(savedCost),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saved with pattern matching',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${savingsPercent.toStringAsFixed(1)}% savings',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // AI Cost Spent
            _buildStatRow(
              theme,
              'AI Processing Cost',
              context.formatCurrency(aiCost),
              Colors.purple,
              Icons.attach_money,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternLibraryCard(ThemeData theme) {
    final totalPatterns = _stats['totalPatterns'] ?? 0;
    final activePatterns = _stats['activePatterns'] ?? 0;
    final patternAccuracy = _stats['patternAccuracy'] ?? 0.0;
    final totalMatches = _stats['totalMatches'] ?? 0;
    final totalFails = _stats['totalFails'] ?? 0;

    final successRate = (totalMatches + totalFails) > 0
        ? (totalMatches / (totalMatches + totalFails) * 100)
        : 0.0;

    return Card(
      color: theme.cardTheme.color,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.library_books, color: Colors.orange, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pattern Library',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI-learned patterns',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Total Patterns
            _buildStatRow(
              theme,
              'Total Patterns',
              '$totalPatterns',
              Colors.orange,
              Icons.pattern,
            ),
            const SizedBox(height: 16),

            // Active Patterns
            _buildStatRow(
              theme,
              'Active Patterns',
              '$activePatterns',
              Colors.green,
              Icons.check_circle,
            ),
            const SizedBox(height: 16),

            // Average Accuracy
            Row(
              children: [
                Expanded(
                  child: _buildStatRow(
                    theme,
                    'Average Accuracy',
                    '${patternAccuracy.toStringAsFixed(1)}%',
                    Colors.blue,
                    Icons.verified,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Success Rate
            Row(
              children: [
                Expanded(
                  child: _buildStatRow(
                    theme,
                    'Success Rate',
                    '${successRate.toStringAsFixed(1)}%',
                    Colors.teal,
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Total Matches
            _buildStatRow(
              theme,
              'Total Matches',
              NumberFormat('#,##0').format(totalMatches),
              Colors.green,
              Icons.done_all,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPatternsCard(ThemeData theme) {
    final topPatterns = _stats['topPatterns'] as List<Map<String, dynamic>>? ?? [];

    if (topPatterns.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: theme.cardTheme.color,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.stars, color: Colors.indigo, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Top Performing Patterns',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...topPatterns.asMap().entries.map((entry) {
              final index = entry.key;
              final pattern = entry.value;
              final isLast = index == topPatterns.length - 1;

              return Column(
                children: [
                  _buildPatternItem(
                    theme,
                    pattern['category'] as String,
                    pattern['description'] as String,
                    pattern['matchCount'] as int,
                    pattern['accuracy'] as double,
                  ),
                  if (!isLast) const SizedBox(height: 12),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternItem(
    ThemeData theme,
    String category,
    String description,
    int matchCount,
    double accuracy,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${accuracy.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$matchCount matches',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    ThemeData theme,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}

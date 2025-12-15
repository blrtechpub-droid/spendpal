import 'package:flutter/material.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/screens/sms_expenses/sms_expenses_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/screens/expense/expense_detail_screen.dart';

/// Auto-Import tab combines:
/// 1. Pending SMS expenses (queue)
/// 2. Pending email transactions (queue)
/// 3. Already-categorized auto-imported expenses
class AutoImportTab extends StatefulWidget {
  const AutoImportTab({super.key});

  @override
  State<AutoImportTab> createState() => _AutoImportTabState();
}

class _AutoImportTabState extends State<AutoImportTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = _auth.currentUser?.uid ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick access cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildQuickAccessCard(
                  context,
                  title: 'SMS Transactions',
                  subtitle: 'Review and categorize transactions from SMS',
                  icon: Icons.message,
                  color: AppTheme.tealAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SmsExpensesScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildQuickAccessCard(
                  context,
                  title: 'Email Transactions',
                  subtitle: 'Review and categorize transactions from email',
                  icon: Icons.email,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pushNamed(context, '/email_transactions');
                  },
                ),
              ],
            ),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Divider(color: theme.dividerTheme.color)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Already Imported',
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: theme.dividerTheme.color)),
              ],
            ),
          ),

          // Already-categorized auto-imported expenses
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('expenses')
                .where('paidBy', isEqualTo: currentUserId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppTheme.tealAccent),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Error loading expenses',
                      style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                    ),
                  ),
                );
              }

              // Filter auto-imported expenses
              final allExpenses = snapshot.data?.docs ?? [];
              final autoImportedExpenses = allExpenses.where((expense) {
                final data = expense.data() as Map<String, dynamic>;
                final groupId = data['groupId'] ?? '';
                final splitWith = List<String>.from(data['splitWith'] ?? []);
                final source = data['source'] ?? 'manual';
                final tags = List<String>.from(data['tags'] ?? []);

                // Filter out group and friend expenses
                if (groupId.isNotEmpty || splitWith.length > 1) {
                  return false;
                }

                // Only show auto-imported expenses
                return source == 'sms' ||
                    source == 'statement' ||
                    source == 'receipt' ||
                    tags.contains('sms') ||
                    tags.contains('SMS') ||
                    tags.contains('statement') ||
                    tags.contains('bank') ||
                    tags.contains('receipt');
              }).toList();

              // Sort by date
              autoImportedExpenses.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['createdAt'] as Timestamp?;
                final bTime = bData['createdAt'] as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime);
              });

              if (autoImportedExpenses.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No imported expenses yet',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan SMS or review pending transactions above',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: autoImportedExpenses.length,
                itemBuilder: (context, index) {
                  final expenseDoc = autoImportedExpenses[index];
                  final data = expenseDoc.data() as Map<String, dynamic>;
                  return _buildExpenseCard(context, expenseDoc.id, data);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(BuildContext context, String expenseId, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final title = data['title'] ?? 'Untitled';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final timestamp = data['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final source = data['source'] ?? 'manual';

    // Get source icon and label
    IconData sourceIcon;
    String sourceLabel;
    Color sourceColor;

    if (source == 'sms') {
      sourceIcon = Icons.message;
      sourceLabel = 'SMS';
      sourceColor = AppTheme.tealAccent;
    } else if (source == 'statement') {
      sourceIcon = Icons.description;
      sourceLabel = 'Statement';
      sourceColor = Colors.blue;
    } else if (source == 'receipt') {
      sourceIcon = Icons.receipt;
      sourceLabel = 'Receipt';
      sourceColor = Colors.orange;
    } else {
      sourceIcon = Icons.cloud_download;
      sourceLabel = 'Imported';
      sourceColor = Colors.purple;
    }

    return Card(
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseDetailScreen(expenseId: expenseId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Category icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sourceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(sourceIcon, color: sourceColor, size: 24),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: sourceColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sourceLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: sourceColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (date != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd, yyyy').format(date),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.orangeAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

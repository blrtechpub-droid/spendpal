import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/budget_model.dart';
import '../../services/budget_service.dart';
import '../../utils/currency_utils.dart';
import 'budget_setup_dialog.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Budget')),
        body: const Center(child: Text('Please login to view budgets')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showBudgetSetupDialog(null),
            tooltip: 'Setup Budget',
          ),
        ],
      ),
      body: StreamBuilder<BudgetModel?>(
        stream: BudgetService.getActiveBudget(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return _buildNoBudgetState();
          }

          final budget = snapshot.data!;
          return _buildBudgetOverview(budget, currentUser.uid);
        },
      ),
    );
  }

  Widget _buildNoBudgetState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Budget Set',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Set a monthly budget to track your spending and get alerts when approaching limits',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showBudgetSetupDialog(null),
              icon: const Icon(Icons.add),
              label: const Text('Create Budget'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetOverview(BudgetModel budget, String userId) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {}); // Trigger rebuild
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Budget Period Card
          _buildPeriodCard(budget),
          const SizedBox(height: 16),

          // Overall Budget Card (if set)
          if (budget.overallMonthlyLimit != null) ...[
            FutureBuilder<BudgetAnalysis?>(
              future: BudgetService.analyzeOverallBudget(
                userId: userId,
                budget: budget,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (!snapshot.hasData) return const SizedBox();

                return _buildOverallBudgetCard(snapshot.data!);
              },
            ),
            const SizedBox(height: 16),
          ],

          // Category Budgets Section
          if (budget.categoryLimits.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Category Budgets',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton.icon(
                  onPressed: () => _showBudgetSetupDialog(budget),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, BudgetAnalysis>>(
              future: BudgetService.analyzeCategoryBudgets(
                userId: userId,
                budget: budget,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox();
                }

                return _buildCategoryBudgetList(snapshot.data!);
              },
            ),
          ],

          if (budget.overallMonthlyLimit == null &&
              budget.categoryLimits.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('No budget limits set'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => _showBudgetSetupDialog(budget),
                      child: const Text('Set Budget Limits'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(BudgetModel budget) {
    final period = BudgetPeriod.current(cycleStartDay: budget.cycleStartDay);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                Text(
                  'Current Budget Cycle',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(period.startDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_forward, color: Colors.grey[400]),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'End Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(period.endDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Resets on day ${budget.cycleStartDay} of each month',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${period.daysRemaining} days remaining in this cycle',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallBudgetCard(BudgetAnalysis analysis) {
    final statusColor = _getStatusColor(analysis.status);
    final progressColor = _getProgressColor(analysis.status);

    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet,
                        color: statusColor, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Overall Budget',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                _buildStatusIcon(analysis.status),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.formatCurrency(analysis.spent),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Spent',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      context.formatCurrency(analysis.limit),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Limit',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (analysis.percentageUsed / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[300],
                color: progressColor,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${analysis.percentageUsed.toStringAsFixed(1)}% used',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
                ),
                Text(
                  analysis.remaining >= 0
                      ? '${context.formatCurrency(analysis.remaining)} left'
                      : '${context.formatCurrency(analysis.excessAmount)} over budget',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBudgetList(Map<String, BudgetAnalysis> analyses) {
    // Sort categories by percentage used (highest first)
    final sortedCategories = analyses.entries.toList()
      ..sort((a, b) => b.value.percentageUsed.compareTo(a.value.percentageUsed));

    return Column(
      children: sortedCategories.map((entry) {
        return _buildCategoryBudgetCard(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildCategoryBudgetCard(String category, BudgetAnalysis analysis) {
    final progressColor = _getProgressColor(analysis.status);
    final categoryIcon = _getCategoryIcon(category);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(categoryIcon, size: 24, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                _buildStatusIcon(analysis.status),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (analysis.percentageUsed / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[300],
                color: progressColor,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${context.formatCurrency(analysis.spent)} / ${context.formatCurrency(analysis.limit)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '${analysis.percentageUsed.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.safe:
        return Colors.green;
      case BudgetStatus.warning:
        return Colors.yellow[700]!;
      case BudgetStatus.danger:
        return Colors.orange;
      case BudgetStatus.exceeded:
        return Colors.red;
    }
  }

  Color _getProgressColor(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.safe:
        return Colors.green;
      case BudgetStatus.warning:
        return Colors.yellow[700]!;
      case BudgetStatus.danger:
        return Colors.orange;
      case BudgetStatus.exceeded:
        return Colors.red;
    }
  }

  Widget _buildStatusIcon(BudgetStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case BudgetStatus.safe:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case BudgetStatus.warning:
        icon = Icons.warning_amber;
        color = Colors.yellow[700]!;
        break;
      case BudgetStatus.danger:
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case BudgetStatus.exceeded:
        icon = Icons.error;
        color = Colors.red;
        break;
    }

    return Icon(icon, color: color, size: 28);
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'groceries':
        return Icons.shopping_cart;
      case 'travel':
        return Icons.flight;
      case 'shopping':
        return Icons.shopping_bag;
      case 'maid':
      case 'cook':
        return Icons.person;
      case 'utilities':
        return Icons.power;
      case 'entertainment':
        return Icons.movie;
      case 'healthcare':
        return Icons.local_hospital;
      case 'education':
        return Icons.school;
      case 'personal care':
        return Icons.spa;
      case 'taxes':
        return Icons.account_balance;
      default:
        return Icons.category;
    }
  }

  void _showBudgetSetupDialog(BudgetModel? existingBudget) {
    showDialog(
      context: context,
      builder: (context) => BudgetSetupDialog(existingBudget: existingBudget),
    );
  }
}

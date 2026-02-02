import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';

/// Screen for visualizing friend-to-friend expenses with charts
class FriendChartsScreen extends StatefulWidget {
  final String friendId;
  final String friendName;

  const FriendChartsScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<FriendChartsScreen> createState() => _FriendChartsScreenState();
}

enum TimePeriod { week, month, threeMonths, all }

class _FriendChartsScreenState extends State<FriendChartsScreen> {
  TimePeriod _selectedPeriod = TimePeriod.month;
  List<ExpenseModel> _expenses = [];
  Map<String, double> _categoryTotals = {};
  double _userPaidTotal = 0;
  double _friendPaidTotal = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case TimePeriod.week:
          startDate = now.subtract(const Duration(days: 7));
          break;
        case TimePeriod.month:
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case TimePeriod.threeMonths:
          startDate = DateTime(now.year, now.month - 3, now.day);
          break;
        case TimePeriod.all:
          startDate = DateTime(2000, 1, 1);
          break;
      }

      // Query all non-group expenses involving current user
      final snapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('groupId', isEqualTo: null)
          .where('splitWith', arrayContains: currentUserId)
          .get();

      // Filter for friend expenses and filter by date
      final expenses = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ExpenseModel.fromMap(data);
          })
          .where((expense) =>
              expense.sharedWith.contains(widget.friendId) &&
              expense.date.isAfter(startDate))
          .toList();

      // Calculate totals
      _categoryTotals.clear();
      _userPaidTotal = 0;
      _friendPaidTotal = 0;

      for (var expense in expenses) {
        // Category totals
        _categoryTotals[expense.category] =
            (_categoryTotals[expense.category] ?? 0) + expense.amount;

        // Who paid totals
        if (expense.paidBy == currentUserId) {
          _userPaidTotal += expense.amount;
        } else if (expense.paidBy == widget.friendId) {
          _friendPaidTotal += expense.amount;
        }
      }

      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading expenses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${widget.friendName} - Charts'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildPeriodSelector(),
                    const SizedBox(height: 24),
                    _buildSummaryStats(),
                    const SizedBox(height: 24),
                    _buildWhoPaidWhatChart(),
                    const SizedBox(height: 32),
                    _buildCategoryPieChart(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Time Period',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPeriodChip(TimePeriod.week, 'Week'),
                _buildPeriodChip(TimePeriod.month, 'Month'),
                _buildPeriodChip(TimePeriod.threeMonths, '3 Months'),
                _buildPeriodChip(TimePeriod.all, 'All Time'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(TimePeriod period, String label) {
    final isSelected = _selectedPeriod == period;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPeriod = period;
          _loadExpenses();
        });
      },
      selectedColor: AppTheme.tealAccent,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }

  Widget _buildSummaryStats() {
    if (_expenses.isEmpty) {
      return _buildEmptyState('No expenses in this period');
    }

    final totalExpenses = _userPaidTotal + _friendPaidTotal;
    final avgExpense = totalExpenses / _expenses.length;
    final userPercentage = totalExpenses > 0 ? (_userPaidTotal / totalExpenses * 100) : 50;
    final friendPercentage = 100 - userPercentage;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Total Expenses', context.formatCurrency(totalExpenses)),
            _buildStatRow('Number of Transactions', '${_expenses.length}'),
            _buildStatRow('Average per Expense', context.formatCurrency(avgExpense)),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'You paid',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${userPercentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        context.formatCurrency(_userPaidTotal),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey[300],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${widget.friendName} paid',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${friendPercentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        context.formatCurrency(_friendPaidTotal),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildWhoPaidWhatChart() {
    if (_expenses.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final maxValue = _userPaidTotal > _friendPaidTotal ? _userPaidTotal : _friendPaidTotal;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Who Paid What',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue * 1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('You');
                          if (value == 1) return Text(widget.friendName);
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${context.currencySymbol}${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: _userPaidTotal,
                          color: Colors.green,
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: _friendPaidTotal,
                          color: Colors.orange,
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPieChart() {
    if (_categoryTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedCategories = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = _categoryTotals.values.reduce((a, b) => a + b);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expenses by Category',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: sortedCategories.asMap().entries.map((entry) {
                          final index = entry.key;
                          final category = entry.value.key;
                          final amount = entry.value.value;
                          final percentage = (amount / total * 100);

                          return PieChartSectionData(
                            value: amount,
                            title: '${percentage.toStringAsFixed(1)}%',
                            color: _getCategoryColor(index),
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: sortedCategories.asMap().entries.map((entry) {
                        final index = entry.key;
                        final category = entry.value.key;
                        final amount = entry.value.value;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(index),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  category,
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...sortedCategories.map((entry) {
              final category = entry.key;
              final amount = entry.value;
              final percentage = (amount / total * 100);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(category, style: const TextStyle(fontSize: 13)),
                    Text(
                      '${context.formatCurrency(amount)} (${percentage.toStringAsFixed(1)}%)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(int index) {
    final colors = [
      AppTheme.foodCategory,
      AppTheme.travelCategory,
      AppTheme.shoppingCategory,
      AppTheme.maidCategory,
      AppTheme.cookCategory,
      Colors.purple,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[index % colors.length];
  }

  Widget _buildEmptyState(String message) {
    return Card(
      elevation: 2,
      child: Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

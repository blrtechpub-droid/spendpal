import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/expense_model.dart';
import '../../utils/currency_utils.dart';

/// Screen for visualizing group expenses with charts
class GroupChartsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChartsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChartsScreen> createState() => _GroupChartsScreenState();
}

enum TimePeriod { week, month, threeMonths, sixMonths, year, all }

class _GroupChartsScreenState extends State<GroupChartsScreen> {
  TimePeriod _selectedPeriod = TimePeriod.month;
  List<ExpenseModel> _expenses = [];
  Map<String, double> _categoryTotals = {};
  Map<String, double> _memberTotals = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    try {
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
        case TimePeriod.sixMonths:
          startDate = DateTime(now.year, now.month - 6, now.day);
          break;
        case TimePeriod.year:
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        case TimePeriod.all:
          startDate = DateTime(2000, 1, 1); // Far past
          break;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('groupId', isEqualTo: widget.groupId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('date', descending: true)
          .get();

      final expenses = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ExpenseModel.fromMap(data);
          })
          .toList();

      // Calculate category totals
      final categoryTotals = <String, double>{};
      for (final expense in expenses) {
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0) + expense.amount;
      }

      // Calculate member totals (total paid by each member)
      final memberTotals = <String, double>{};
      for (final expense in expenses) {
        memberTotals[expense.paidBy] =
            (memberTotals[expense.paidBy] ?? 0) + expense.amount;
      }

      setState(() {
        _expenses = expenses;
        _categoryTotals = categoryTotals;
        _memberTotals = memberTotals;
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
        title: Text('${widget.groupName} - Charts'),
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
                    _buildCategoryPieChart(),
                    const SizedBox(height: 32),
                    _buildMemberBarChart(),
                    const SizedBox(height: 32),
                    _buildExpenseTrendChart(),
                    const SizedBox(height: 16),
                    _buildSummaryStats(),
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
      selectedColor: Colors.teal[400],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }

  Widget _buildCategoryPieChart() {
    if (_categoryTotals.isEmpty) {
      return _buildEmptyState('No expenses in this period');
    }

    final total = _categoryTotals.values.reduce((a, b) => a + b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expenses by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.3,
              child: PieChart(
                PieChartData(
                  sections: _categoryTotals.entries.map((entry) {
                    final percentage = (entry.value / total) * 100;
                    return PieChartSectionData(
                      value: entry.value,
                      title: '${percentage.toStringAsFixed(1)}%',
                      color: _getCategoryColor(entry.key),
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 14,
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
            const SizedBox(height: 16),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _categoryTotals.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(entry.key),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.key}: ${context.formatCurrency(entry.value)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Food': Colors.orange,
      'Groceries': Colors.green,
      'Travel': Colors.blue,
      'Shopping': Colors.purple,
      'Utilities': Colors.brown,
      'Entertainment': Colors.pink,
      'Healthcare': Colors.red,
      'Education': Colors.indigo,
      'Maid': Colors.cyan,
      'Cook': Colors.lime,
      'Personal Care': Colors.amber,
      'Taxes': Colors.deepOrange,
      'Other': Colors.grey,
    };
    return colors[category] ?? Colors.teal;
  }

  Widget _buildMemberBarChart() {
    if (_memberTotals.isEmpty) {
      return _buildEmptyState('No expenses in this period');
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Paid by Member',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.5,
              child: FutureBuilder<Map<String, String>>(
                future: _fetchMemberNames(_memberTotals.keys.toList()),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final memberNames = snapshot.data!;

                  return BarChart(
                    BarChartData(
                      barGroups: _memberTotals.entries.toList().asMap().entries.map((entry) {
                        final index = entry.key;
                        final memberEntry = entry.value;

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: memberEntry.value,
                              color: Colors.teal,
                              width: 40,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < _memberTotals.length) {
                                final userId = _memberTotals.keys.elementAt(value.toInt());
                                final name = memberNames[userId] ?? 'Unknown';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    name.split(' ').first, // First name only
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }
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
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[300],
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, String>> _fetchMemberNames(List<String> userIds) async {
    final names = <String, String>{};
    for (final userId in userIds) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      names[userId] = doc.data()?['name'] ?? 'Unknown';
    }
    return names;
  }

  Widget _buildExpenseTrendChart() {
    if (_expenses.isEmpty) {
      return _buildEmptyState('No expenses in this period');
    }

    // Group expenses by date (daily aggregation)
    final dailyTotals = <DateTime, double>{};
    for (final expense in _expenses) {
      final date = DateTime(
        expense.date.year,
        expense.date.month,
        expense.date.day,
      );
      dailyTotals[date] = (dailyTotals[date] ?? 0) + expense.amount;
    }

    final sortedDates = dailyTotals.keys.toList()..sort();

    // Limit to max 30 data points for better visualization
    final displayDates = sortedDates.length > 30
        ? sortedDates.sublist(sortedDates.length - 30)
        : sortedDates;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expense Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.5,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: displayDates.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          dailyTotals[entry.value]!,
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.teal,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.teal.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (displayDates.length / 5).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < displayDates.length) {
                            final date = displayDates[index];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${date.day}/${date.month}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
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
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300],
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStats() {
    final totalExpenses = _expenses.length;
    final totalAmount = _expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final avgExpense = totalExpenses > 0 ? totalAmount / totalExpenses : 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatRow('Total Expenses', totalExpenses.toString()),
            _buildStatRow('Total Amount', context.formatCurrency(totalAmount.toDouble())),
            _buildStatRow('Average Expense', context.formatCurrency(avgExpense.toDouble())),
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
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

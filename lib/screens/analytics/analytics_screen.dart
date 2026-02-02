import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/services/analytics_service.dart';
import 'package:spendpal/utils/currency_utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;

  // Data
  Map<String, double> _categoryBreakdown = {};
  Map<String, double> _monthlyTotals = {};
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _topCategories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userId = currentUser.uid;
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

    try {
      final results = await Future.wait([
        AnalyticsService.getCategoryBreakdown(
          userId: userId,
          startDate: startOfMonth,
          endDate: endOfMonth,
        ),
        AnalyticsService.getMonthlyTotals(userId: userId, monthsCount: 6),
        AnalyticsService.getSpendingSummary(
          userId: userId,
          startDate: startOfMonth,
          endDate: endOfMonth,
        ),
        AnalyticsService.getTopCategories(
          userId: userId,
          startDate: startOfMonth,
          endDate: endOfMonth,
          limit: 5,
        ),
      ]);

      setState(() {
        _categoryBreakdown = results[0] as Map<String, double>;
        _monthlyTotals = results[1] as Map<String, double>;
        _summary = results[2] as Map<String, dynamic>;
        _topCategories = results[3] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Categories'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Month Selector
                Container(
                  padding: const EdgeInsets.all(16),
                  color: theme.cardColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _changeMonth(-1),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                        style: theme.textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _selectedMonth.month >= DateTime.now().month &&
                                _selectedMonth.year >= DateTime.now().year
                            ? null
                            : () => _changeMonth(1),
                      ),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(theme),
                      _buildCategoriesTab(theme),
                      _buildTrendsTab(theme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme) {
    final total = (_summary['total'] as double?) ?? 0.0;
    final average = (_summary['average'] as double?) ?? 0.0;
    final count = (_summary['count'] as int?) ?? 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  theme,
                  'Total Spent',
                  context.formatCurrency(total),
                  Icons.account_balance_wallet,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  theme,
                  'Avg/Day',
                  context.formatCurrency(average),
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            theme,
            'Transactions',
            count.toString(),
            Icons.receipt,
            Colors.orange,
          ),

          const SizedBox(height: 24),

          // Top Categories
          if (_topCategories.isNotEmpty) ...[
            Text(
              'Top Spending Categories',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._topCategories.map((category) {
              final name = category['category'] as String;
              final amount = category['amount'] as double;
              final color = Color(AnalyticsService.getCategoryColors()[name] ?? 0xFF9E9E9E);
              final percentage = total > 0 ? (amount / total * 100) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(name, style: theme.textTheme.bodyLarge),
                          ],
                        ),
                        Text(
                          '${context.formatCurrency(amount)} (${percentage.toStringAsFixed(1)}%)',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: color.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoriesTab(ThemeData theme) {
    if (_categoryBreakdown.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              'No expenses for this month',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    final total = _categoryBreakdown.values.fold<double>(0.0, (sum, val) => sum + val);
    final categoryColors = AnalyticsService.getCategoryColors();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pie Chart
        SizedBox(
          height: 300,
          child: PieChart(
            PieChartData(
              sections: _categoryBreakdown.entries.map((entry) {
                final percentage = (entry.value / total * 100);
                final color = Color(categoryColors[entry.key] ?? 0xFF9E9E9E);

                return PieChartSectionData(
                  value: entry.value,
                  title: '${percentage.toStringAsFixed(1)}%',
                  color: color,
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

        const SizedBox(height: 24),

        // Category Legend
        ..._categoryBreakdown.entries.map((entry) {
          final color = Color(categoryColors[entry.key] ?? 0xFF9E9E9E);
          final percentage = (entry.value / total * 100);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(entry.key, style: theme.textTheme.bodyLarge),
                  ],
                ),
                Text(
                  '${context.formatCurrency(entry.value)} (${percentage.toStringAsFixed(1)}%)',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTrendsTab(ThemeData theme) {
    if (_monthlyTotals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              'No data available',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    final sortedMonths = _monthlyTotals.entries.toList().reversed.toList();
    final maxAmount = _monthlyTotals.values.reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Line Chart
        SizedBox(
          height: 300,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxAmount / 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: theme.dividerColor,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${context.currencySymbol}${(value / 1000).toStringAsFixed(0)}k',
                        style: theme.textTheme.bodySmall,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < sortedMonths.length) {
                        final monthLabel = sortedMonths[index].key.split(' ')[0];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            monthLabel,
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: sortedMonths.asMap().entries.map((entry) {
                    return FlSpot(entry.key.toDouble(), entry.value.value);
                  }).toList(),
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withValues(alpha: 0.2),
                  ),
                ),
              ],
              minY: 0,
              maxY: maxAmount * 1.1,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Monthly Breakdown
        Text(
          'Monthly Breakdown',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...sortedMonths.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key, style: theme.textTheme.bodyLarge),
                Text(
                  context.formatCurrency(entry.value),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

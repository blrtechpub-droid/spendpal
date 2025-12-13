import 'package:flutter/material.dart';
import 'package:spendpal/models/simplified_debt_model.dart';
import 'package:spendpal/services/debt_simplification_service.dart';
import 'package:spendpal/widgets/upi_settle_dialog.dart';

/// Screen showing simplified debts with Splitwise-style UX
/// Shows who owes whom and how much in a clear, actionable format
class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  final DebtSimplificationService _debtService = DebtSimplificationService();
  late TabController _tabController;

  DebtSummary? _debtSummary;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDebts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDebts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final summary = await _debtService.getUserDebtSummary();

      // Enrich with user names
      final enrichedDebtsOwed = await _debtService.enrichWithUserNames(summary.debtsOwed);
      final enrichedDebtsOwedToUser = await _debtService.enrichWithUserNames(summary.debtsOwedToUser);

      setState(() {
        _debtSummary = DebtSummary(
          userId: summary.userId,
          totalOwed: summary.totalOwed,
          totalOwedToUser: summary.totalOwedToUser,
          debtsOwed: enrichedDebtsOwed,
          debtsOwedToUser: enrichedDebtsOwedToUser,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Balances'),
        automaticallyImplyLeading: false,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'You Owe'),
            Tab(text: 'Owed to You'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _debtSummary == null
                  ? const Center(child: Text('No debt data available'))
                  : Column(
                      children: [
                        _buildSummaryCard(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildDebtsOwedTab(),
                              _buildDebtsOwedToUserTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _debtSummary!;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: summary.isSettled
              ? [Colors.green[400]!, Colors.green[600]!]
              : summary.isDebtor
                  ? [Colors.orange[400]!, Colors.deepOrange[600]!]
                  : [Colors.blue[400]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            summary.summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (!summary.isSettled) ...[
            const SizedBox(height: 8),
            Text(
              summary.isDebtor
                  ? 'You owe ₹${summary.totalOwed.toStringAsFixed(2)}'
                  : 'You are owed ₹${summary.totalOwedToUser.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebtsOwedTab() {
    final debts = _debtSummary!.debtsOwed;

    if (debts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.celebration,
        title: 'All settled up!',
        subtitle: 'You don\'t owe anyone money',
        color: Colors.green,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDebts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: debts.length,
        itemBuilder: (context, index) {
          final debt = debts[index];
          return _buildDebtCard(
            debt: debt,
            isOwed: false,
            onSettle: () => _showSettleDialog(debt),
          );
        },
      ),
    );
  }

  Widget _buildDebtsOwedToUserTab() {
    final debts = _debtSummary!.debtsOwedToUser;

    if (debts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox,
        title: 'No pending dues',
        subtitle: 'Nobody owes you money right now',
        color: Colors.grey,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDebts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: debts.length,
        itemBuilder: (context, index) {
          final debt = debts[index];
          return _buildDebtCard(
            debt: debt,
            isOwed: true,
            onSettle: null, // Can't settle debts owed to you
          );
        },
      ),
    );
  }

  Widget _buildDebtCard({
    required SimplifiedDebt debt,
    required bool isOwed,
    VoidCallback? onSettle,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.cardTheme.color,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSettle,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: isOwed ? Colors.blue[100] : Colors.orange[100],
                child: Icon(
                  Icons.person,
                  color: isOwed ? Colors.blue[700] : Colors.orange[700],
                ),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOwed ? debt.fromUserName : debt.toUserName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      debt.groupName ?? 'Personal expense',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${debt.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isOwed ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                  if (onSettle != null) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: onSettle,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Settle Up'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final bool isSettled = icon == Icons.celebration;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isSettled
              ? [
                  Colors.green[50]!,
                  Colors.green[100]!,
                  Colors.white,
                ]
              : [
                  Colors.blue[50]!,
                  Colors.grey[100]!,
                  Colors.white,
                ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon with shadow
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 100,
                color: isSettled ? Colors.green[600] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isSettled ? Colors.green[700] : theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error loading debts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadDebts,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showSettleDialog(SimplifiedDebt debt) {
    showDialog(
      context: context,
      builder: (context) => UpiSettleDialog(
        debt: debt,
        onSettled: _loadDebts,
      ),
    );
  }
}

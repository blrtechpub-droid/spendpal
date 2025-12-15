import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/models/money_tracker_model.dart';
import 'package:spendpal/services/portfolio_service.dart';
import 'package:spendpal/theme/app_theme.dart';

class MoneyTrackerScreen extends StatefulWidget {
  const MoneyTrackerScreen({Key? key}) : super(key: key);

  @override
  State<MoneyTrackerScreen> createState() => _MoneyTrackerScreenState();
}

class _MoneyTrackerScreenState extends State<MoneyTrackerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _bankExpanded = false;
  bool _creditCardExpanded = false;

  Future<Map<String, dynamic>> _getMoneyTrackerData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return {};

    final userId = currentUser.uid;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // Get salary for current month
    final salarySnapshot = await _firestore
        .collection('salaryRecords')
        .where('userId', isEqualTo: userId)
        .where('creditedDate', isGreaterThanOrEqualTo: startOfMonth)
        .get();

    double monthlySalary = 0.0;
    for (var doc in salarySnapshot.docs) {
      final salary = SalaryRecord.fromFirestore(doc);
      monthlySalary += salary.amount;
    }

    // Get total expenses for current month from expenses collection
    final expensesSnapshot = await _firestore
        .collection('expenses')
        .where('paidBy', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
        .get();

    double monthlyExpenses = 0.0;
    for (var doc in expensesSnapshot.docs) {
      final data = doc.data();
      monthlyExpenses += (data['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // Get bank accounts (Savings)
    final bankAccountsSnapshot = await _firestore
        .collection('moneyAccounts')
        .where('userId', isEqualTo: userId)
        .where('accountType', isEqualTo: 'bank')
        .get();

    double totalBankBalance = 0.0;
    for (var doc in bankAccountsSnapshot.docs) {
      final account = MoneyTrackerAccount.fromFirestore(doc);
      totalBankBalance += account.balance;
    }

    // Get investment portfolio value
    final portfolioService = PortfolioService();
    final portfolioSummary = await portfolioService.getPortfolioSummary(userId: userId);
    final totalInvestments = (portfolioSummary['totalCurrent'] as double?) ?? 0.0;

    // Get credit card accounts (Liabilities)
    final creditCardSnapshot = await _firestore
        .collection('moneyAccounts')
        .where('userId', isEqualTo: userId)
        .where('accountType', isEqualTo: 'credit_card')
        .get();

    double creditCardBalance = 0.0;
    double creditCardLimit = 0.0;
    for (var doc in creditCardSnapshot.docs) {
      final account = MoneyTrackerAccount.fromFirestore(doc);
      creditCardBalance += account.balance;
      creditCardLimit += (account.creditLimit ?? 0.0);
    }

    // Calculate Net Worth = (Savings + Investments) - Liabilities
    final totalAssets = totalBankBalance + totalInvestments;
    final totalLiabilities = creditCardBalance; // Can add more liabilities here
    final netWorth = totalAssets - totalLiabilities;

    return {
      'monthlySalary': monthlySalary,
      'monthlyExpenses': monthlyExpenses,
      'remainingBalance': monthlySalary - monthlyExpenses,
      'savings': totalBankBalance,
      'investments': totalInvestments,
      'liabilities': totalLiabilities,
      'netWorth': netWorth,
      'bankBalance': totalBankBalance,
      'creditCardSpent': creditCardBalance,
      'creditCardLimit': creditCardLimit,
      'creditCardAvailable': creditCardLimit - creditCardBalance,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Money Tracker'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showInfoDialog();
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getMoneyTrackerData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {};
          final monthlySalary = (data['monthlySalary'] as double?) ?? 0.0;
          final monthlyExpenses = (data['monthlyExpenses'] as double?) ?? 0.0;
          final remainingBalance = (data['remainingBalance'] as double?) ?? 0.0;
          final savings = (data['savings'] as double?) ?? 0.0;
          final investments = (data['investments'] as double?) ?? 0.0;
          final liabilities = (data['liabilities'] as double?) ?? 0.0;
          final netWorth = (data['netWorth'] as double?) ?? 0.0;
          final bankBalance = (data['bankBalance'] as double?) ?? 0.0;
          final creditCardSpent = (data['creditCardSpent'] as double?) ?? 0.0;
          final creditCardLimit = (data['creditCardLimit'] as double?) ?? 0.0;
          final creditCardAvailable = (data['creditCardAvailable'] as double?) ?? 0.0;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Net Worth Card
                _buildNetWorthCard(
                  theme,
                  savings,
                  investments,
                  liabilities,
                  netWorth,
                ),
                const SizedBox(height: 16),

                // Monthly Salary Card
                _buildSalaryCard(
                  theme,
                  monthlySalary,
                  monthlyExpenses,
                  remainingBalance,
                ),
                const SizedBox(height: 16),

                // Bank Balance Card
                _buildBankBalanceCard(theme, bankBalance),
                const SizedBox(height: 16),

                // Credit Card Card
                _buildCreditCardCard(
                  theme,
                  creditCardSpent,
                  creditCardLimit,
                  creditCardAvailable,
                ),
                const SizedBox(height: 16),

                // Investments Card (Navigation)
                _buildInvestmentsCard(theme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNetWorthCard(
    ThemeData theme,
    double savings,
    double investments,
    double liabilities,
    double netWorth,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: netWorth >= 0
              ? [Colors.blue[400]!, Colors.blue[700]!]
              : [Colors.red[400]!, Colors.red[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (netWorth >= 0 ? Colors.blue : Colors.red)
                .withValues(alpha: 0.3),
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
                child: const Icon(Icons.account_balance_wallet, color: Color(0xFFF8F8F8), size: 28),
              ),
              const SizedBox(width: 12),
              const Text(
                'Net Worth',
                style: TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Net Worth Total
          Center(
            child: Column(
              children: [
                Text(
                  'Total Net Worth',
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8).withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${netWorth.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.3), thickness: 1),
          const SizedBox(height: 16),
          // Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    'Savings',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${savings.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Investments',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${investments.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'Liabilities',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${liabilities.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 16,
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

  Widget _buildSalaryCard(
    ThemeData theme,
    double salary,
    double expenses,
    double remaining,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: remaining >= 0
              ? [Colors.green[400]!, Colors.green[700]!]
              : [Colors.orange[400]!, Colors.deepOrange[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (remaining >= 0 ? Colors.green : Colors.orange)
                .withValues(alpha: 0.3),
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
                child: const Icon(Icons.account_balance, color: Color(0xFFF8F8F8), size: 28),
              ),
              const SizedBox(width: 12),
              const Text(
                'Monthly Finances',
                style: TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                    'Salary',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${salary.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Expenses',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${expenses.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining Balance',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8).withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '₹${remaining.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankBalanceCard(ThemeData theme, double balance) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox();

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _bankExpanded = !_bankExpanded);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.blue[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
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
                      child: const Icon(Icons.account_balance_wallet, color: Color(0xFFF8F8F8), size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Bank Accounts',
                        style: TextStyle(
                          color: Color(0xFFF8F8F8),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      _bankExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFFF8F8F8),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Total Balance',
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_bankExpanded)
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('moneyAccounts')
                .where('userId', isEqualTo: currentUser.uid)
                .where('accountType', isEqualTo: 'bank')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final accounts = snapshot.data!.docs
                  .map((doc) => MoneyTrackerAccount.fromFirestore(doc))
                  .toList();

              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (accounts.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No bank accounts yet',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    if (accounts.isNotEmpty)
                      ...accounts.map((account) => _buildAccountTile(account, theme, 'bank')),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddBankAccountDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Bank Account'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.blue.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCreditCardCard(
    ThemeData theme,
    double spent,
    double limit,
    double available,
  ) {
    final usagePercent = limit > 0 ? (spent / limit * 100) : 0.0;
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox();

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _creditCardExpanded = !_creditCardExpanded);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[400]!, Colors.purple[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.3),
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
                      child: const Icon(Icons.credit_card, color: Color(0xFFF8F8F8), size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Credit Cards',
                        style: TextStyle(
                          color: Color(0xFFF8F8F8),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      _creditCardExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFFF8F8F8),
                    ),
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
                          'Spent',
                          style: TextStyle(
                            color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${spent.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFFF8F8F8),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Available',
                          style: TextStyle(
                            color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${available.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFFF8F8F8),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: usagePercent / 100,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      usagePercent > 80 ? Colors.red : const Color(0xFFF8F8F8),
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${usagePercent.toStringAsFixed(1)}% of limit used',
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8).withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_creditCardExpanded)
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('moneyAccounts')
                .where('userId', isEqualTo: currentUser.uid)
                .where('accountType', isEqualTo: 'credit_card')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final accounts = snapshot.data!.docs
                  .map((doc) => MoneyTrackerAccount.fromFirestore(doc))
                  .toList();

              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (accounts.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No credit cards yet',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    if (accounts.isNotEmpty)
                      ...accounts.map((account) => _buildAccountTile(account, theme, 'credit_card')),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddCreditCardDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Credit Card'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.purple.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildInvestmentsCard(ThemeData theme) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/investments');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[400]!, Colors.teal[700]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.trending_up, color: Color(0xFFF8F8F8), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Investments',
                    style: TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track MF, stocks, FD & gold',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text(
          'Money Tracker',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        content: Text(
          'This feature tracks your:\n\n'
          '• Monthly salary\n'
          '• Bank account balance\n'
          '• Credit card spending\n\n'
          'Tap on cards to expand and manage accounts.',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(MoneyTrackerAccount account, ThemeData theme, String type) {
    final isCreditCard = type == 'credit_card';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isCreditCard ? Icons.credit_card : Icons.account_balance,
          color: isCreditCard ? Colors.purple : Colors.blue,
        ),
        title: Text(
          account.accountName,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: isCreditCard && account.creditLimit != null
            ? Text(
                '₹${account.balance.toStringAsFixed(0)} / ₹${account.creditLimit!.toStringAsFixed(0)}',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              )
            : null,
        trailing: Text(
          '₹${account.balance.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        onTap: () {
          if (isCreditCard) {
            _showAddCreditCardDialog(account: account, accountId: account.accountId);
          } else {
            _showAddBankAccountDialog(account: account, accountId: account.accountId);
          }
        },
      ),
    );
  }

  void _showAddBankAccountDialog({MoneyTrackerAccount? account, String? accountId}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: account?.accountName ?? '');
    final balanceController = TextEditingController(
      text: account != null ? account.balance.toStringAsFixed(2) : '',
    );
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance, color: Colors.blue, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            account == null ? 'Add Bank Account' : 'Edit Bank Account',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        if (account != null)
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Theme.of(context).cardTheme.color,
                                  title: const Text('Delete Account'),
                                  content: const Text('Are you sure you want to delete this account?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && accountId != null) {
                                await _firestore.collection('moneyAccounts').doc(accountId).delete();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Account deleted')),
                                  );
                                }
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Account Name',
                        hintText: 'e.g., HDFC Savings',
                        prefixIcon: const Icon(Icons.account_balance),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Theme.of(context).cardTheme.color,
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: balanceController,
                      decoration: InputDecoration(
                        labelText: 'Current Balance',
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Theme.of(context).cardTheme.color,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;

                                setModalState(() => isLoading = true);

                                try {
                                  final data = {
                                    'userId': _auth.currentUser!.uid,
                                    'accountType': 'bank',
                                    'accountName': nameController.text.trim(),
                                    'balance': double.parse(balanceController.text.trim()),
                                    'lastUpdated': FieldValue.serverTimestamp(),
                                  };

                                  if (account == null) {
                                    data['createdAt'] = FieldValue.serverTimestamp();
                                    await _firestore.collection('moneyAccounts').add(data);
                                  } else {
                                    await _firestore.collection('moneyAccounts').doc(accountId).update(data);
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(account == null ? 'Account added' : 'Account updated'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
                                    );
                                  }
                                } finally {
                                  setModalState(() => isLoading = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(account == null ? 'Add Account' : 'Update Account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddCreditCardDialog({MoneyTrackerAccount? account, String? accountId}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: account?.accountName ?? '');
    final limitController = TextEditingController(
      text: account?.creditLimit != null ? account!.creditLimit!.toStringAsFixed(2) : '',
    );
    final spentController = TextEditingController(
      text: account != null ? account.balance.toStringAsFixed(2) : '',
    );
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.credit_card, color: Colors.purple, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            account == null ? 'Add Credit Card' : 'Edit Credit Card',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        if (account != null)
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Theme.of(context).cardTheme.color,
                                  title: const Text('Delete Card'),
                                  content: const Text('Are you sure you want to delete this credit card?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && accountId != null) {
                                await _firestore.collection('moneyAccounts').doc(accountId).delete();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Card deleted')),
                                  );
                                }
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Card Name',
                        hintText: 'e.g., HDFC Credit Card',
                        prefixIcon: const Icon(Icons.credit_card),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Theme.of(context).cardTheme.color,
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: limitController,
                      decoration: InputDecoration(
                        labelText: 'Credit Limit',
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.account_balance_wallet),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Theme.of(context).cardTheme.color,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        final limit = double.tryParse(v!);
                        if (limit == null || limit <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: spentController,
                      decoration: InputDecoration(
                        labelText: 'Current Spending',
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Theme.of(context).cardTheme.color,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;

                                final limit = double.parse(limitController.text.trim());
                                final spent = double.parse(spentController.text.trim());

                                if (spent > limit) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Spending cannot exceed credit limit'),
                                      backgroundColor: AppTheme.errorColor,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isLoading = true);

                                try {
                                  final data = {
                                    'userId': _auth.currentUser!.uid,
                                    'accountType': 'credit_card',
                                    'accountName': nameController.text.trim(),
                                    'balance': spent,
                                    'creditLimit': limit,
                                    'lastUpdated': FieldValue.serverTimestamp(),
                                  };

                                  if (account == null) {
                                    data['createdAt'] = FieldValue.serverTimestamp();
                                    await _firestore.collection('moneyAccounts').add(data);
                                  } else {
                                    await _firestore.collection('moneyAccounts').doc(accountId).update(data);
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(account == null ? 'Card added' : 'Card updated'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
                                    );
                                  }
                                } finally {
                                  setModalState(() => isLoading = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(account == null ? 'Add Card' : 'Update Card'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

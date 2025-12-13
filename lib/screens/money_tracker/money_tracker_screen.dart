import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/models/money_tracker_model.dart';
import 'package:spendpal/theme/app_theme.dart';

class MoneyTrackerScreen extends StatefulWidget {
  const MoneyTrackerScreen({Key? key}) : super(key: key);

  @override
  State<MoneyTrackerScreen> createState() => _MoneyTrackerScreenState();
}

class _MoneyTrackerScreenState extends State<MoneyTrackerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    // Get bank accounts
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

    // Get credit card accounts
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

    return {
      'monthlySalary': monthlySalary,
      'monthlyExpenses': monthlyExpenses,
      'remainingBalance': monthlySalary - monthlyExpenses,
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
                // Salary Card
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
    return Container(
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
              const Text(
                'Bank Account',
                style: TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
    );
  }

  Widget _buildCreditCardCard(
    ThemeData theme,
    double spent,
    double limit,
    double available,
  ) {
    final usagePercent = limit > 0 ? (spent / limit * 100) : 0.0;

    return Container(
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
              const Text(
                'Credit Card',
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
          'SMS auto-detection will be enabled in a future update.',
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
}

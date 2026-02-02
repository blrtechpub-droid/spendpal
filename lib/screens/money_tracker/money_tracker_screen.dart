import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/models/money_tracker_model.dart';
import 'package:spendpal/services/portfolio_service.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/services/account_tracker_service.dart';
import 'package:spendpal/models/account_tracker_model.dart';
import 'package:spendpal/config/tracker_registry.dart';
import 'package:spendpal/screens/trackers/account_tracker_screen.dart';
import 'package:spendpal/models/budget_model.dart';
import 'package:spendpal/services/budget_service.dart';
import 'package:spendpal/utils/currency_utils.dart';

class MoneyTrackerScreen extends StatefulWidget {
  const MoneyTrackerScreen({Key? key}) : super(key: key);

  @override
  State<MoneyTrackerScreen> createState() => _MoneyTrackerScreenState();
}

class _MoneyTrackerScreenState extends State<MoneyTrackerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _getMoneyTrackerData();
  }

  void _refreshData() {
    setState(() {
      _dataFuture = _getMoneyTrackerData();
    });
  }

  Future<Map<String, dynamic>> _getMoneyTrackerData() async {
    try {
      print('💰 DEBUG: Starting _getMoneyTrackerData()');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('💰 DEBUG: No current user, returning empty map');
        return {};
      }

      final userId = currentUser.uid;
      print('💰 DEBUG: User ID: $userId');
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

    // Get salary for current month
    double monthlySalary = 0.0;
    try {
      final salarySnapshot = await _firestore
          .collection('salaryRecords')
          .where('userId', isEqualTo: userId)
          .where('creditedDate', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      for (var doc in salarySnapshot.docs) {
        final salary = SalaryRecord.fromFirestore(doc);
        monthlySalary += salary.amount;
      }
    } catch (e) {
      print('💰 WARNING: Could not load salary records (index may be missing): $e');
      // Continue with monthlySalary = 0.0
    }

    // Get total expenses for current month from expenses collection
    double monthlyExpenses = 0.0;
    try {
      final expensesSnapshot = await _firestore
          .collection('expenses')
          .where('paidBy', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      for (var doc in expensesSnapshot.docs) {
        final data = doc.data();
        monthlyExpenses += (data['amount'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      print('💰 WARNING: Could not load expenses (index may be missing): $e');
      // Continue with monthlyExpenses = 0.0
    }

    // Get bank accounts (Savings)
    final bankAccountsSnapshot = await _firestore
        .collection('moneyAccounts')
        .where('userId', isEqualTo: userId)
        .where('accountType', isEqualTo: 'bank')
        .get();

    print('💰 DEBUG Money Tracker: Found ${bankAccountsSnapshot.docs.length} bank accounts');

    double totalBankBalance = 0.0;
    for (var doc in bankAccountsSnapshot.docs) {
      final account = MoneyTrackerAccount.fromFirestore(doc);
      print('💰 DEBUG: Bank account "${account.accountName}" balance: ${account.balance}');
      totalBankBalance += account.balance;
    }

    print('💰 DEBUG: Total bank balance: $totalBankBalance');

    // Get wallet accounts (Paytm, PhonePe, etc.)
    final walletAccountsSnapshot = await _firestore
        .collection('moneyAccounts')
        .where('userId', isEqualTo: userId)
        .where('accountType', isEqualTo: 'wallet')
        .get();

    double totalWalletBalance = 0.0;
    for (var doc in walletAccountsSnapshot.docs) {
      final account = MoneyTrackerAccount.fromFirestore(doc);
      totalWalletBalance += account.balance;
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

    // Get loan accounts (Liabilities)
    final loanSnapshot = await _firestore
        .collection('moneyAccounts')
        .where('userId', isEqualTo: userId)
        .where('accountType', isEqualTo: 'loan')
        .get();

    double totalLoans = 0.0;
    for (var doc in loanSnapshot.docs) {
      final account = MoneyTrackerAccount.fromFirestore(doc);
      totalLoans += account.balance;
    }

    // Calculate Net Worth = (Savings + Wallets + Investments) - Liabilities
    final totalAssets = totalBankBalance + totalWalletBalance + totalInvestments;
    final totalLiabilities = creditCardBalance + totalLoans; // Credit cards + Loans
    final netWorth = totalAssets - totalLiabilities;

    print('💰 DEBUG: Returning data - bankBalance: $totalBankBalance');
      return {
        'monthlySalary': monthlySalary,
        'monthlyExpenses': monthlyExpenses,
        'remainingBalance': monthlySalary - monthlyExpenses,
        'savings': totalBankBalance,
        'wallets': totalWalletBalance,
        'investments': totalInvestments,
        'liabilities': totalLiabilities,
        'netWorth': netWorth,
        'bankBalance': totalBankBalance,
        'walletBalance': totalWalletBalance,
        'creditCardSpent': creditCardBalance,
        'creditCardLimit': creditCardLimit,
        'creditCardAvailable': creditCardLimit - creditCardBalance,
      };
    } catch (e, stackTrace) {
      print('💰 ERROR in _getMoneyTrackerData: $e');
      print('💰 ERROR Stack trace: $stackTrace');
      return {};
    }
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
            icon: const Icon(Icons.sync_alt),
            tooltip: 'Manage Trackers',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountTrackerScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showInfoDialog();
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {};
          print('💰 WIDGET DEBUG: Full data map: $data');
          final savings = (data['savings'] as double?) ?? 0.0;
          final wallets = (data['wallets'] as double?) ?? 0.0;
          final investments = (data['investments'] as double?) ?? 0.0;
          final liabilities = (data['liabilities'] as double?) ?? 0.0;
          final netWorth = (data['netWorth'] as double?) ?? 0.0;
          final bankBalance = (data['bankBalance'] as double?) ?? 0.0;
          final walletBalance = (data['walletBalance'] as double?) ?? 0.0;
          final creditCardSpent = (data['creditCardSpent'] as double?) ?? 0.0;
          final creditCardLimit = (data['creditCardLimit'] as double?) ?? 0.0;
          final creditCardAvailable = (data['creditCardAvailable'] as double?) ?? 0.0;
          print('💰 WIDGET DEBUG: bankBalance extracted: $bankBalance');

          return RefreshIndicator(
            onRefresh: () async {
              _refreshData();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Net Worth Card
                NetWorthCard(
                  savings: savings,
                  wallets: wallets,
                  investments: investments,
                  liabilities: liabilities,
                  netWorth: netWorth,
                ),
                const SizedBox(height: 16),

                // Bank Balance Card
                BankBalanceCard(balance: bankBalance),
                const SizedBox(height: 16),

                // Wallets Card
                WalletsCard(balance: walletBalance),
                const SizedBox(height: 16),

                // Credit Card Card
                CreditCardCard(
                  spent: creditCardSpent,
                  limit: creditCardLimit,
                  available: creditCardAvailable,
                ),
                const SizedBox(height: 16),

                // Investments Card
                const InvestmentsCard(),
                const SizedBox(height: 16),

                // Debts/Loans Card
                const DebtsCard(),
                const SizedBox(height: 16),

                // Budget Summary Card
                const BudgetSummaryCard(),
              ],
            ),
          );
        },
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
    final isWallet = type == 'wallet';

    IconData icon;
    Color color;

    if (isCreditCard) {
      icon = Icons.credit_card;
      color = Colors.purple;
    } else if (isWallet) {
      icon = Icons.wallet;
      color = Colors.orange;
    } else {
      icon = Icons.account_balance;
      color = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          account.accountName,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: isCreditCard && account.creditLimit != null
            ? Text(
                '${context.formatCurrency(account.balance, showSymbol: true)} / ${context.formatCurrency(account.creditLimit!, showSymbol: true)}',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              )
            : null,
        trailing: Text(
          context.formatCurrency(account.balance, showSymbol: true),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        onTap: () {
          if (isCreditCard) {
            _showAddCreditCardDialog(account: account, accountId: account.accountId);
          } else if (isWallet) {
            _showAddWalletDialog(account: account, accountId: account.accountId);
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
    String? selectedTrackerId = account?.trackerId;
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
                    const SizedBox(height: 16),
                    FutureBuilder<List<AccountTrackerModel>>(
                      future: AccountTrackerService.getTrackersByType(
                        _auth.currentUser!.uid,
                        TrackerType.banking,
                      ),
                      builder: (context, snapshot) {
                        final trackers = snapshot.data ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              value: selectedTrackerId,
                              decoration: InputDecoration(
                                labelText: 'Link Tracker (Optional)',
                                hintText: 'Enable auto-sync from SMS/Email',
                                prefixIcon: const Icon(Icons.sync),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Theme.of(context).cardTheme.color,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('No tracker (manual updates only)'),
                                ),
                                ...trackers.map((tracker) {
                                  final color = Color(int.parse('0xFF${tracker.colorHex}'));
                                  return DropdownMenuItem<String>(
                                    value: tracker.id,
                                    child: Row(
                                      children: [
                                        Icon(Icons.account_balance_wallet, color: color, size: 20),
                                        const SizedBox(width: 8),
                                        Text(tracker.name),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(${tracker.emailsFetched} txns)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setModalState(() => selectedTrackerId = value);
                              },
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final newTracker = await _showQuickTrackerCreationDialog(
                                  context,
                                  TrackerType.banking,
                                  nameController.text.trim(),
                                );
                                if (newTracker != null) {
                                  setModalState(() {
                                    selectedTrackerId = newTracker.id;
                                  });
                                }
                              },
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              label: const Text('Create New Tracker'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.tealAccent,
                              ),
                            ),
                          ],
                        );
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
                                    'trackerId': selectedTrackerId,
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

  void _showAddWalletDialog({MoneyTrackerAccount? account, String? accountId}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: account?.accountName ?? '');
    final balanceController = TextEditingController(
      text: account != null ? account.balance.toStringAsFixed(2) : '',
    );
    String? selectedTrackerId = account?.trackerId;
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
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.wallet, color: Colors.orange, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            account == null ? 'Add Wallet' : 'Edit Wallet',
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
                                  title: const Text('Delete Wallet'),
                                  content: const Text('Are you sure you want to delete this wallet?'),
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
                                    const SnackBar(content: Text('Wallet deleted')),
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
                        labelText: 'Wallet Name',
                        hintText: 'e.g., Paytm, PhonePe',
                        prefixIcon: const Icon(Icons.wallet),
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
                    const SizedBox(height: 16),
                    FutureBuilder<List<AccountTrackerModel>>(
                      future: AccountTrackerService.getTrackersByType(
                        _auth.currentUser!.uid,
                        TrackerType.digitalWallet,
                      ),
                      builder: (context, snapshot) {
                        final trackers = snapshot.data ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              value: selectedTrackerId,
                              decoration: InputDecoration(
                                labelText: 'Link Tracker (Optional)',
                                hintText: 'Enable auto-sync from SMS/Email',
                                prefixIcon: const Icon(Icons.sync),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Theme.of(context).cardTheme.color,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('No tracker (manual updates only)'),
                                ),
                                ...trackers.map((tracker) {
                                  final color = Color(int.parse('0xFF${tracker.colorHex}'));
                                  return DropdownMenuItem<String>(
                                    value: tracker.id,
                                    child: Row(
                                      children: [
                                        Icon(Icons.wallet, color: color, size: 20),
                                        const SizedBox(width: 8),
                                        Text(tracker.name),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(${tracker.emailsFetched} txns)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setModalState(() => selectedTrackerId = value);
                              },
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final newTracker = await _showQuickTrackerCreationDialog(
                                  context,
                                  TrackerType.digitalWallet,
                                  nameController.text.trim(),
                                );
                                if (newTracker != null) {
                                  setModalState(() {
                                    selectedTrackerId = newTracker.id;
                                  });
                                }
                              },
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              label: const Text('Create New Tracker'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.tealAccent,
                              ),
                            ),
                          ],
                        );
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
                                    'accountType': 'wallet',
                                    'accountName': nameController.text.trim(),
                                    'balance': double.parse(balanceController.text.trim()),
                                    'trackerId': selectedTrackerId,
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
                                        content: Text(account == null ? 'Wallet added' : 'Wallet updated'),
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
                          backgroundColor: Colors.orange,
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
                            : Text(account == null ? 'Add Wallet' : 'Update Wallet'),
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
    String? selectedTrackerId = account?.trackerId;
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
                    const SizedBox(height: 16),
                    FutureBuilder<List<AccountTrackerModel>>(
                      future: AccountTrackerService.getTrackersByType(
                        _auth.currentUser!.uid,
                        TrackerType.creditCard,
                      ),
                      builder: (context, snapshot) {
                        final trackers = snapshot.data ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              value: selectedTrackerId,
                              decoration: InputDecoration(
                                labelText: 'Link Tracker (Optional)',
                                hintText: 'Enable auto-sync from SMS/Email',
                                prefixIcon: const Icon(Icons.sync),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Theme.of(context).cardTheme.color,
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('No tracker (manual updates only)'),
                                ),
                                ...trackers.map((tracker) {
                                  final color = Color(int.parse('0xFF${tracker.colorHex}'));
                                  return DropdownMenuItem<String>(
                                    value: tracker.id,
                                    child: Row(
                                      children: [
                                        Icon(Icons.credit_card, color: color, size: 20),
                                        const SizedBox(width: 8),
                                        Text(tracker.name),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(${tracker.emailsFetched} txns)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setModalState(() => selectedTrackerId = value);
                              },
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final newTracker = await _showQuickTrackerCreationDialog(
                                  context,
                                  TrackerType.creditCard,
                                  nameController.text.trim(),
                                );
                                if (newTracker != null) {
                                  setModalState(() {
                                    selectedTrackerId = newTracker.id;
                                  });
                                }
                              },
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              label: const Text('Create New Tracker'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.tealAccent,
                              ),
                            ),
                          ],
                        );
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
                                    'trackerId': selectedTrackerId,
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

  /// Quick tracker creation dialog
  Future<AccountTrackerModel?> _showQuickTrackerCreationDialog(
    BuildContext context,
    TrackerType type,
    String suggestedName,
  ) async {
    final nameController = TextEditingController(text: suggestedName);
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    return showDialog<AccountTrackerModel>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.cardTheme.color,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.tealAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sync, color: AppTheme.tealAccent, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Create Tracker', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a tracker to auto-sync transactions from email',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Tracker Name',
                      hintText: 'e.g., HDFC Bank',
                      prefixIcon: const Icon(Icons.label),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: theme.cardTheme.color,
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Domains (Optional)',
                      hintText: 'e.g., hdfcbank.net, alerts.hdfcbank.com',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: theme.cardTheme.color,
                      helperText: 'Comma-separated email domains to track',
                      helperMaxLines: 2,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setState(() => isLoading = true);

                        try {
                          // Parse email domains
                          final emailText = emailController.text.trim();
                          final emailDomains = emailText.isEmpty
                              ? <String>[]
                              : emailText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

                          // Create tracker
                          final tracker = await AccountTrackerService.addCustomTracker(
                            userId: _auth.currentUser!.uid,
                            name: nameController.text.trim(),
                            type: type,
                            emailDomains: emailDomains,
                          );

                          if (tracker != null && context.mounted) {
                            Navigator.pop(context, tracker);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Tracker "${tracker.name}" created'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to create tracker'),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// Expandable Card Widgets (separate state to prevent scroll jump)
// ============================================================================

class NetWorthCard extends StatefulWidget {
  final double savings;
  final double wallets;
  final double investments;
  final double liabilities;
  final double netWorth;

  const NetWorthCard({
    super.key,
    required this.savings,
    required this.wallets,
    required this.investments,
    required this.liabilities,
    required this.netWorth,
  });

  @override
  State<NetWorthCard> createState() => _NetWorthCardState();
}

class _NetWorthCardState extends State<NetWorthCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _expanded = !_expanded);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.netWorth >= 0
                    ? [Colors.blue[400]!, Colors.blue[700]!]
                    : [Colors.red[400]!, Colors.red[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (widget.netWorth >= 0 ? Colors.blue : Colors.red)
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
                      child: const Icon(Icons.account_balance_wallet,
                          color: Color(0xFFF8F8F8), size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Net Worth',
                        style: TextStyle(
                          color: Color(0xFFF8F8F8),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFFF8F8F8),
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
                          color:
                              const Color(0xFFF8F8F8).withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CurrencyText(
                        widget.netWorth,
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
                Divider(
                    color: Colors.white.withValues(alpha: 0.3), thickness: 1),
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
                            color:
                                const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        CurrencyText(
                          widget.savings,
                          style: const TextStyle(
                            color: Color(0xFFF8F8F8),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Wallets',
                          style: TextStyle(
                            color:
                                const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        CurrencyText(
                          widget.wallets,
                          style: const TextStyle(
                            color: Color(0xFFF8F8F8),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Invest',
                          style: TextStyle(
                            color:
                                const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        CurrencyText(
                          widget.investments,
                          style: const TextStyle(
                            color: Color(0xFFF8F8F8),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Debt',
                          style: TextStyle(
                            color:
                                const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        CurrencyText(
                          widget.liabilities,
                          style: const TextStyle(
                            color: Color(0xFFF8F8F8),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
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
                Text(
                  'Assets',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBreakdownRow(
                  context,
                  'Bank Accounts',
                  widget.savings,
                  Icons.account_balance,
                  Colors.blue,
                ),
                const SizedBox(height: 8),
                _buildBreakdownRow(
                  context,
                  'Digital Wallets',
                  widget.wallets,
                  Icons.wallet,
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildBreakdownRow(
                  context,
                  'Investments',
                  widget.investments,
                  Icons.trending_up,
                  Colors.teal,
                ),
                const Divider(height: 24),
                Text(
                  'Liabilities',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBreakdownRow(
                  context,
                  'Total Debt',
                  widget.liabilities,
                  Icons.trending_down,
                  Colors.red,
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net Worth',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    CurrencyText(
                      widget.netWorth,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: widget.netWorth >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBreakdownRow(
    BuildContext context,
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
        CurrencyText(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}

class BankBalanceCard extends StatefulWidget {
  final double balance;

  const BankBalanceCard({super.key, required this.balance});

  @override
  State<BankBalanceCard> createState() => _BankBalanceCardState();
}

class _BankBalanceCardState extends State<BankBalanceCard> {
  bool _expanded = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox();

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _expanded = !_expanded);
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
                      _expanded ? Icons.expand_less : Icons.expand_more,
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
                CurrencyText(
                  widget.balance,
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
        if (_expanded)
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
                      ...accounts.map((account) {
                        // Get reference to parent state to call _buildAccountTile
                        final parentContext = context.findAncestorStateOfType<_MoneyTrackerScreenState>();
                        return parentContext?._buildAccountTile(account, theme, 'bank') ?? const SizedBox();
                      }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final parentContext = context.findAncestorStateOfType<_MoneyTrackerScreenState>();
                          parentContext?._showAddBankAccountDialog();
                        },
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
}

class WalletsCard extends StatefulWidget {
  final double balance;

  const WalletsCard({super.key, required this.balance});

  @override
  State<WalletsCard> createState() => _WalletsCardState();
}

class _WalletsCardState extends State<WalletsCard> {
  bool _expanded = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox();

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _expanded = !_expanded);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber[400]!, Colors.orange[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
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
                      child: const Icon(Icons.wallet, color: Color(0xFFF8F8F8), size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Wallets',
                        style: TextStyle(
                          color: Color(0xFFF8F8F8),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
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
                CurrencyText(
                  widget.balance,
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
        if (_expanded)
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('moneyAccounts')
                .where('userId', isEqualTo: currentUser.uid)
                .where('accountType', isEqualTo: 'wallet')
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
                    color: Colors.orange.withValues(alpha: 0.3),
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
                            'No wallets yet',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    if (accounts.isNotEmpty)
                      ...accounts.map((account) {
                        final parentContext = context.findAncestorStateOfType<_MoneyTrackerScreenState>();
                        return parentContext?._buildAccountTile(account, theme, 'wallet') ?? const SizedBox();
                      }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final parentContext = context.findAncestorStateOfType<_MoneyTrackerScreenState>();
                          parentContext?._showAddWalletDialog();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Wallet'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
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
}

class CreditCardCard extends StatefulWidget {
  final double spent;
  final double limit;
  final double available;

  const CreditCardCard({
    super.key,
    required this.spent,
    required this.limit,
    required this.available,
  });

  @override
  State<CreditCardCard> createState() => _CreditCardCardState();
}

class _CreditCardCardState extends State<CreditCardCard> {
  bool _expanded = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usagePercent = widget.limit > 0 ? (widget.spent / widget.limit * 100) : 0.0;
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox();

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _expanded = !_expanded);
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
                      _expanded ? Icons.expand_less : Icons.expand_more,
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
                        CurrencyText(
                          widget.spent,
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
                        CurrencyText(
                          widget.available,
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
        if (_expanded)
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
                      ...accounts.map((account) {
                        final parentContext = context.findAncestorStateOfType<_MoneyTrackerScreenState>();
                        return parentContext?._buildAccountTile(account, theme, 'credit_card') ?? const SizedBox();
                      }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final parentContext = context.findAncestorStateOfType<_MoneyTrackerScreenState>();
                          parentContext?._showAddCreditCardDialog();
                        },
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
}

class InvestmentsCard extends StatefulWidget {
  const InvestmentsCard({super.key});

  @override
  State<InvestmentsCard> createState() => _InvestmentsCardState();
}

class _InvestmentsCardState extends State<InvestmentsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        InkWell(
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
            child: FutureBuilder<Map<String, dynamic>>(
              future: PortfolioService().getPortfolioSummary(
                userId: FirebaseAuth.instance.currentUser!.uid,
              ),
              builder: (context, snapshot) {
                final data = snapshot.data ?? {};
                final currentValue = (data['totalCurrent'] as double?) ?? 0.0;
                final invested = (data['totalInvested'] as double?) ?? 0.0;
                final pl = (data['totalPL'] as double?) ?? 0.0;
                final plPercent = (data['totalPLPercent'] as double?) ?? 0.0;
                final hasData = invested > 0;

                return Column(
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
                          child: const Icon(Icons.trending_up, color: Color(0xFFF8F8F8), size: 28),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Investments',
                            style: TextStyle(
                              color: Color(0xFFF8F8F8),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            color: const Color(0xFFF8F8F8),
                          ),
                          onPressed: () {
                            setState(() => _expanded = !_expanded);
                          },
                        ),
                      ],
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF8F8F8)),
                            ),
                          ),
                        ),
                      )
                    else if (hasData) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Current Value',
                        style: TextStyle(
                          color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      CurrencyText(
                        currentValue,
                        style: const TextStyle(
                          color: Color(0xFFF8F8F8),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '${pl >= 0 ? '+' : '-'}${context.formatCurrency(pl.abs())}',
                            style: TextStyle(
                              color: pl >= 0
                                ? Colors.green[200]
                                : Colors.red[200],
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${plPercent >= 0 ? '+' : ''}${plPercent.toStringAsFixed(2)}%)',
                            style: TextStyle(
                              color: plPercent >= 0
                                ? Colors.green[200]
                                : Colors.red[200],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      Text(
                        'No investments yet',
                        style: TextStyle(
                          color: const Color(0xFFF8F8F8).withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        if (_expanded)
          FutureBuilder<Map<String, dynamic>>(
            future: PortfolioService().getPortfolioSummary(
              userId: FirebaseAuth.instance.currentUser!.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final data = snapshot.data ?? {};
              final portfolioItems = (data['portfolioItems'] as List<dynamic>?) ?? [];
              final topHoldings = portfolioItems.take(3).toList();

              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.teal.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (portfolioItems.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No investments yet',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    if (portfolioItems.isNotEmpty) ...[
                      // Top 3 holdings
                      ...topHoldings.map((item) {
                        final itemMap = item as Map<String, dynamic>;
                        final name = itemMap['name'] as String? ?? 'Unknown';
                        final currentValue = (itemMap['currentValue'] as num?)?.toDouble() ?? 0.0;
                        final pl = (itemMap['unrealizedPL'] as num?)?.toDouble() ?? 0.0;
                        final plPercent = (itemMap['unrealizedPLPercent'] as num?)?.toDouble() ?? 0.0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              Icons.show_chart,
                              color: Colors.teal,
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${pl >= 0 ? '+' : ''}${context.formatCurrency(pl)} (${plPercent >= 0 ? '+' : ''}${plPercent.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                color: pl >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            trailing: CurrencyText(
                              currentValue,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        );
                      }),

                      // "View all" button if more than 3 holdings
                      if (portfolioItems.length > 3)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/investments');
                              },
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: Text('View all ${portfolioItems.length} holdings'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.teal,
                              ),
                            ),
                          ),
                        ),

                      // "Manage Investments" button
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/investments');
                          },
                          icon: const Icon(Icons.account_balance_wallet),
                          label: const Text('Manage Investments'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                            side: BorderSide(color: Colors.teal.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class DebtsCard extends StatefulWidget {
  const DebtsCard({super.key});

  @override
  State<DebtsCard> createState() => _DebtsCardState();
}

class _DebtsCardState extends State<DebtsCard> {
  bool _expanded = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox();

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _expanded = !_expanded);
          },
          borderRadius: BorderRadius.circular(16),
          child: FutureBuilder<QuerySnapshot>(
            future: _firestore
                .collection('moneyAccounts')
                .where('userId', isEqualTo: currentUser.uid)
                .where('accountType', isEqualTo: 'loan')
                .get(),
            builder: (context, snapshot) {
              // Calculate total debt from loans
              double totalDebt = 0.0;
              if (snapshot.hasData) {
                final loans = snapshot.data!.docs
                    .map((doc) => MoneyTrackerAccount.fromFirestore(doc))
                    .toList();
                totalDebt = loans.fold(0.0, (total, loan) => total + loan.balance);
              }

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[400]!, Colors.red[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
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
                          child: const Icon(Icons.trending_down, color: Color(0xFFF8F8F8), size: 28),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Debts & Loans',
                            style: TextStyle(
                              color: Color(0xFFF8F8F8),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          color: const Color(0xFFF8F8F8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Total Outstanding',
                      style: TextStyle(
                        color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    CurrencyText(
                      totalDebt,
                      style: const TextStyle(
                        color: Color(0xFFF8F8F8),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_expanded)
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('moneyAccounts')
                .where('userId', isEqualTo: currentUser.uid)
                .where('accountType', isEqualTo: 'loan')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final loans = snapshot.data!.docs
                  .map((doc) => MoneyTrackerAccount.fromFirestore(doc))
                  .toList();

              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loans.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No loans tracked yet',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    if (loans.isNotEmpty)
                      ...loans.map((loan) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              _getLoanIcon(loan.loanType),
                              color: Colors.red,
                            ),
                            title: Text(
                              loan.accountName,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            subtitle: Text(
                              _getLoanSubtitle(loan),
                              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                            ),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CurrencyText(
                                  loan.balance,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                if (loan.emiAmount != null)
                                  Text(
                                    'EMI: ${context.formatCurrency(loan.emiAmount!)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () => _showLoanDetailsDialog(loan),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showAddLoanDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Loan/Debt'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
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

  IconData _getLoanIcon(String? loanType) {
    switch (loanType) {
      case 'home':
        return Icons.home;
      case 'car':
        return Icons.directions_car;
      case 'education':
        return Icons.school;
      case 'personal':
        return Icons.person;
      default:
        return Icons.attach_money;
    }
  }

  String _getLoanSubtitle(MoneyTrackerAccount loan) {
    final parts = <String>[];
    if (loan.loanType != null) {
      parts.add(_getLoanTypeName(loan.loanType!));
    }
    if (loan.interestRate != null) {
      parts.add('${loan.interestRate}% p.a.');
    }
    if (loan.tenureMonths != null) {
      final years = loan.tenureMonths! ~/ 12;
      final months = loan.tenureMonths! % 12;
      if (years > 0) {
        parts.add('$years yr${years > 1 ? 's' : ''}${months > 0 ? ' $months mo' : ''}');
      } else {
        parts.add('$months months');
      }
    }
    return parts.isNotEmpty ? parts.join(' • ') : 'Loan';
  }

  String _getLoanTypeName(String loanType) {
    switch (loanType) {
      case 'home':
        return 'Home Loan';
      case 'car':
        return 'Car Loan';
      case 'education':
        return 'Education Loan';
      case 'personal':
        return 'Personal Loan';
      default:
        return 'Other';
    }
  }

  void _showLoanDetailsDialog(MoneyTrackerAccount loan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loan.accountName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', _getLoanTypeName(loan.loanType ?? 'other')),
            _buildDetailRow('Outstanding', context.formatCurrency(loan.balance)),
            if (loan.creditLimit != null)
              _buildDetailRow('Original Amount', context.formatCurrency(loan.creditLimit!)),
            if (loan.interestRate != null)
              _buildDetailRow('Interest Rate', '${loan.interestRate}% p.a.'),
            if (loan.emiAmount != null)
              _buildDetailRow('Monthly EMI', context.formatCurrency(loan.emiAmount!)),
            if (loan.tenureMonths != null)
              _buildDetailRow('Tenure', '${loan.tenureMonths} months'),
            if (loan.loanStartDate != null)
              _buildDetailRow('Start Date', '${loan.loanStartDate!.day}/${loan.loanStartDate!.month}/${loan.loanStartDate!.year}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditLoanDialog(loan);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddLoanDialog() {
    _showLoanFormDialog(null);
  }

  void _showEditLoanDialog(MoneyTrackerAccount loan) {
    _showLoanFormDialog(loan);
  }

  void _showLoanFormDialog(MoneyTrackerAccount? existingLoan) {
    final nameController = TextEditingController(text: existingLoan?.accountName);
    final balanceController = TextEditingController(
      text: existingLoan?.balance.toString() ?? '',
    );
    final originalAmountController = TextEditingController(
      text: existingLoan?.creditLimit?.toString() ?? '',
    );
    final interestRateController = TextEditingController(
      text: existingLoan?.interestRate?.toString() ?? '',
    );
    final emiController = TextEditingController(
      text: existingLoan?.emiAmount?.toString() ?? '',
    );
    final tenureController = TextEditingController(
      text: existingLoan?.tenureMonths?.toString() ?? '',
    );

    String selectedLoanType = existingLoan?.loanType ?? 'personal';
    DateTime? selectedStartDate = existingLoan?.loanStartDate;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existingLoan == null ? 'Add Loan/Debt' : 'Edit Loan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedLoanType,
                  decoration: const InputDecoration(
                    labelText: 'Loan Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'personal', child: Text('Personal Loan')),
                    DropdownMenuItem(value: 'home', child: Text('Home Loan')),
                    DropdownMenuItem(value: 'car', child: Text('Car Loan')),
                    DropdownMenuItem(value: 'education', child: Text('Education Loan')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedLoanType = value!);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Loan Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  decoration: InputDecoration(
                    labelText: 'Outstanding Balance',
                    border: OutlineInputBorder(),
                    prefixText: context.currencySymbol,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: originalAmountController,
                  decoration: InputDecoration(
                    labelText: 'Original Amount (Optional)',
                    border: OutlineInputBorder(),
                    prefixText: context.currencySymbol,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: interestRateController,
                  decoration: const InputDecoration(
                    labelText: 'Interest Rate % (Optional)',
                    border: OutlineInputBorder(),
                    suffixText: '% p.a.',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emiController,
                  decoration: InputDecoration(
                    labelText: 'Monthly EMI (Optional)',
                    border: OutlineInputBorder(),
                    prefixText: context.currencySymbol,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tenureController,
                  decoration: const InputDecoration(
                    labelText: 'Tenure in Months (Optional)',
                    border: OutlineInputBorder(),
                    suffixText: 'months',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            if (existingLoan != null)
              TextButton(
                onPressed: () async {
                  await _firestore
                      .collection('moneyAccounts')
                      .doc(existingLoan.accountId)
                      .delete();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final balance = double.tryParse(balanceController.text.trim());

                if (name.isEmpty || balance == null) {
                  return;
                }

                final currentUser = _auth.currentUser;
                if (currentUser == null) return;

                final accountId = existingLoan?.accountId ??
                    _firestore.collection('moneyAccounts').doc().id;

                final account = MoneyTrackerAccount(
                  accountId: accountId,
                  userId: currentUser.uid,
                  accountType: 'loan',
                  accountName: name,
                  balance: balance,
                  creditLimit: double.tryParse(originalAmountController.text.trim()),
                  loanType: selectedLoanType,
                  interestRate: double.tryParse(interestRateController.text.trim()),
                  emiAmount: double.tryParse(emiController.text.trim()),
                  tenureMonths: int.tryParse(tenureController.text.trim()),
                  loanStartDate: selectedStartDate,
                  lastUpdated: DateTime.now(),
                  createdAt: existingLoan?.createdAt ?? DateTime.now(),
                );

                await _firestore
                    .collection('moneyAccounts')
                    .doc(accountId)
                    .set(account.toMap());

                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: Text(existingLoan == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// Budget Summary Card widget
class BudgetSummaryCard extends StatefulWidget {
  const BudgetSummaryCard({super.key});

  @override
  State<BudgetSummaryCard> createState() => _BudgetSummaryCardState();
}

class _BudgetSummaryCardState extends State<BudgetSummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    return StreamBuilder<BudgetModel?>(
      stream: BudgetService.getActiveBudget(currentUser.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return _buildNoBudgetCard(theme);
        }

        final budget = snapshot.data!;
        return _buildBudgetCard(budget, theme, currentUser.uid);
      },
    );
  }

  Widget _buildNoBudgetCard(ThemeData theme) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/budget'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.add_chart, size: 40, color: Colors.grey[400]),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set a Budget',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Track spending limits and get warnings',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetCard(BudgetModel budget, ThemeData theme, String userId) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            if (_expanded) {
              Navigator.pushNamed(context, '/budget');
            } else {
              setState(() => _expanded = true);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: FutureBuilder<BudgetAnalysis?>(
            future: BudgetService.analyzeOverallBudget(
              userId: userId,
              budget: budget,
            ),
            builder: (context, snapshot) {
              final analysis = snapshot.data;
              final hasOverallBudget =
                  budget.overallMonthlyLimit != null && analysis != null;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasOverallBudget
                        ? _getGradientColors(analysis.status)
                        : [Colors.blue[400]!, Colors.blue[700]!],
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
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Budget',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    if (hasOverallBudget) ...[
                      const SizedBox(height: 16),
                      Text(
                        '${context.formatCurrency(analysis.spent)} / ${context.formatCurrency(analysis.limit)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (analysis.percentageUsed / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        color: Colors.white,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${analysis.percentageUsed.toStringAsFixed(1)}% used',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Text(
                        '${budget.categoryLimits.length} category budgets set',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          _buildExpandedContent(budget, userId, theme),
        ],
      ],
    );
  }

  Widget _buildExpandedContent(
      BudgetModel budget, String userId, ThemeData theme) {
    return FutureBuilder<Map<String, BudgetAnalysis>>(
      future:
          BudgetService.analyzeCategoryBudgets(userId: userId, budget: budget),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final analyses = snapshot.data!;
        final sortedCategories = analyses.entries.toList()
          ..sort((a, b) => b.value.percentageUsed.compareTo(a.value.percentageUsed));

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Category Budgets',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/budget'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...sortedCategories.take(3).map((entry) {
                  final category = entry.key;
                  final analysis = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            category,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: LinearProgressIndicator(
                            value: (analysis.percentageUsed / 100).clamp(0.0, 1.0),
                            color: _getProgressColor(analysis.status),
                            backgroundColor: Colors.grey[300],
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${analysis.percentageUsed.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Color> _getGradientColors(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.safe:
        return [Colors.green[400]!, Colors.green[700]!];
      case BudgetStatus.warning:
        return [Colors.yellow[600]!, Colors.yellow[800]!];
      case BudgetStatus.danger:
        return [Colors.orange[400]!, Colors.orange[700]!];
      case BudgetStatus.exceeded:
        return [Colors.red[400]!, Colors.red[700]!];
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
}

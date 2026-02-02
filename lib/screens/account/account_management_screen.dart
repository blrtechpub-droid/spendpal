import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/models/money_tracker_model.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/utils/currency_utils.dart';
import 'package:spendpal/screens/account/add_bank_account_screen.dart';
import 'package:spendpal/screens/account/add_credit_card_screen.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Account Management'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.textTheme.bodyLarge?.color,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          tabs: const [
            Tab(
              icon: Icon(Icons.account_balance),
              text: 'Bank Accounts',
            ),
            Tab(
              icon: Icon(Icons.credit_card),
              text: 'Credit Cards',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBankAccountsTab(theme),
          _buildCreditCardsTab(theme),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAccount(context),
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Add Bank Account' : 'Add Credit Card'),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildBankAccountsTab(ThemeData theme) {
    final currentUserId = _auth.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('moneyAccounts')
          .where('userId', isEqualTo: currentUserId)
          .where('accountType', isEqualTo: 'bank')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: AppTheme.errorColor, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading accounts',
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
              ],
            ),
          );
        }

        final accounts = snapshot.data?.docs ?? [];

        if (accounts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance,
                  size: 80,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Bank Accounts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first bank account to start tracking',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final accountDoc = accounts[index];
            final account = MoneyTrackerAccount.fromFirestore(accountDoc);
            return _buildAccountCard(context, account, theme, accountDoc.id);
          },
        );
      },
    );
  }

  Widget _buildCreditCardsTab(ThemeData theme) {
    final currentUserId = _auth.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('moneyAccounts')
          .where('userId', isEqualTo: currentUserId)
          .where('accountType', isEqualTo: 'credit_card')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: AppTheme.errorColor, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading cards',
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
              ],
            ),
          );
        }

        final cards = snapshot.data?.docs ?? [];

        if (cards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.credit_card,
                  size: 80,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Credit Cards',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first credit card to start tracking',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final cardDoc = cards[index];
            final card = MoneyTrackerAccount.fromFirestore(cardDoc);
            return _buildAccountCard(context, card, theme, cardDoc.id);
          },
        );
      },
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    MoneyTrackerAccount account,
    ThemeData theme,
    String docId,
  ) {
    final isCreditCard = account.accountType == 'credit_card';
    final iconData = isCreditCard ? Icons.credit_card : Icons.account_balance;
    final color = isCreditCard ? Colors.purple : Colors.blue;

    return Card(
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _editAccount(context, account, docId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.accountName,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCreditCard ? 'Credit Card' : 'Bank Account',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    if (isCreditCard && account.creditLimit != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Limit: ${context.formatCurrency(account.creditLimit!)}',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    context.formatCurrency(account.balance),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: account.balance >= 0 ? Colors.green : AppTheme.errorColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCreditCard ? 'Spent' : 'Balance',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addAccount(BuildContext context) {
    if (_tabController.index == 0) {
      // Bank Account
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AddBankAccountScreen(),
        ),
      );
    } else {
      // Credit Card
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AddCreditCardScreen(),
        ),
      );
    }
  }

  void _editAccount(BuildContext context, MoneyTrackerAccount account, String docId) {
    if (account.accountType == 'bank') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddBankAccountScreen(
            account: account,
            accountId: docId,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddCreditCardScreen(
            account: account,
            accountId: docId,
          ),
        ),
      );
    }
  }
}

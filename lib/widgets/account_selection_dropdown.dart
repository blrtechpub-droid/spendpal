import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/models/money_tracker_model.dart';
import 'package:spendpal/models/investment_asset.dart';
import 'package:spendpal/theme/app_theme.dart';

/// Account source type for categorization
enum AccountSource {
  money,       // Bank or Credit Card
  investment,  // Investment Asset
}

/// Unified account item for dropdown
class AccountItem {
  final String id;
  final String name;
  final String displayInfo;
  final IconData icon;
  final Color color;
  final AccountSource source;
  final dynamic account; // MoneyTrackerAccount or InvestmentAsset

  AccountItem({
    required this.id,
    required this.name,
    required this.displayInfo,
    required this.icon,
    required this.color,
    required this.source,
    required this.account,
  });
}

/// Enhanced dropdown widget for selecting bank accounts, credit cards, or investments
class AccountSelectionDropdown extends StatefulWidget {
  final String? selectedAccountId;
  final Function(String? accountId, AccountSource? source, dynamic account) onAccountSelected;
  final String? accountType; // 'bank', 'credit_card', or null for all money accounts
  final bool includeInvestments; // Include investment assets
  final String? trackerId; // Filter accounts by linked tracker ID
  final String label;
  final IconData icon;
  final bool required;

  const AccountSelectionDropdown({
    super.key,
    this.selectedAccountId,
    required this.onAccountSelected,
    this.accountType,
    this.includeInvestments = false,
    this.trackerId,
    this.label = 'Select Account',
    this.icon = Icons.account_balance_wallet,
    this.required = false,
  });

  @override
  State<AccountSelectionDropdown> createState() => _AccountSelectionDropdownState();
}

class _AccountSelectionDropdownState extends State<AccountSelectionDropdown> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedAccountId;
  List<AccountItem> _accountItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.selectedAccountId;
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final items = <AccountItem>[];

      // Load money accounts (banks and credit cards)
      await _loadMoneyAccounts(currentUser.uid, items);

      // Load investment assets if enabled
      if (widget.includeInvestments) {
        await _loadInvestmentAssets(currentUser.uid, items);
      }

      if (mounted) {
        setState(() {
          _accountItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading accounts: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _loadMoneyAccounts(String userId, List<AccountItem> items) async {
    Query query = _firestore
        .collection('moneyAccounts')
        .where('userId', isEqualTo: userId);

    // Filter by account type if specified
    if (widget.accountType != null) {
      query = query.where('accountType', isEqualTo: widget.accountType);
    }

    // Filter by tracker ID if specified
    if (widget.trackerId != null) {
      query = query.where('trackerId', isEqualTo: widget.trackerId);
    }

    final snapshot = await query.get();

    for (final doc in snapshot.docs) {
      final account = MoneyTrackerAccount.fromFirestore(doc);
      final isCreditCard = account.accountType == 'credit_card';
      final isWallet = account.accountType == 'wallet';

      IconData accountIcon;
      Color accountColor;

      if (isCreditCard) {
        accountIcon = Icons.credit_card;
        accountColor = Colors.purple;
      } else if (isWallet) {
        accountIcon = Icons.wallet;
        accountColor = Colors.orange;
      } else {
        accountIcon = Icons.account_balance;
        accountColor = Colors.blue;
      }

      items.add(AccountItem(
        id: account.accountId,
        name: account.accountName,
        displayInfo: '₹${account.balance.toStringAsFixed(0)}',
        icon: accountIcon,
        color: accountColor,
        source: AccountSource.money,
        account: account,
      ));
    }

    // Auto-select if only one account matches the tracker
    if (widget.trackerId != null && items.length == 1 && _selectedAccountId == null) {
      _selectedAccountId = items[0].id;
      // Notify parent of auto-selection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onAccountSelected(items[0].id, items[0].source, items[0].account);
      });
    }
  }

  Future<void> _loadInvestmentAssets(String userId, List<AccountItem> items) async {
    final snapshot = await _firestore
        .collection('investmentAssets')
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in snapshot.docs) {
      final asset = InvestmentAsset.fromFirestore(doc);

      // Show platform if available
      final displayInfo = asset.platform != null
          ? '${asset.assetTypeDisplay} (${asset.platformDisplay})'
          : asset.assetTypeDisplay;

      items.add(AccountItem(
        id: asset.assetId,
        name: asset.name,
        displayInfo: displayInfo,
        icon: _getInvestmentIcon(asset.assetType),
        color: _getInvestmentColor(asset.assetType),
        source: AccountSource.investment,
        account: asset,
      ));
    }
  }

  IconData _getInvestmentIcon(String assetType) {
    switch (assetType) {
      case 'mutual_fund':
        return Icons.trending_up;
      case 'equity':
      case 'etf':
        return Icons.show_chart;
      case 'fd':
      case 'rd':
        return Icons.savings;
      case 'gold':
        return Icons.diamond;
      case 'ppf':
      case 'epf':
      case 'nps':
        return Icons.account_balance_wallet;
      case 'crypto':
        return Icons.currency_bitcoin;
      case 'property':
        return Icons.home;
      default:
        return Icons.pie_chart;
    }
  }

  Color _getInvestmentColor(String assetType) {
    switch (assetType) {
      case 'mutual_fund':
        return Colors.green;
      case 'equity':
      case 'etf':
        return Colors.teal;
      case 'fd':
      case 'rd':
        return Colors.orange;
      case 'gold':
        return Colors.amber;
      case 'ppf':
      case 'epf':
      case 'nps':
        return Colors.indigo;
      case 'crypto':
        return Colors.deepOrange;
      case 'property':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  AccountItem? _getSelectedItem() {
    if (_selectedAccountId == null) return null;
    try {
      return _accountItems.firstWhere((item) => item.id == _selectedAccountId);
    } catch (e) {
      return null;
    }
  }

  List<Widget> _buildGroupedDropdownItems() {
    final items = <Widget>[];

    // Add "None" option if not required
    if (!widget.required) {
      items.add(
        const DropdownMenuItem<String>(
          value: null,
          child: Text('None (Optional)'),
        ),
      );
    }

    // Group items by source
    final moneyAccounts = _accountItems.where((item) => item.source == AccountSource.money).toList();
    final investments = _accountItems.where((item) => item.source == AccountSource.investment).toList();

    // Add money accounts section
    if (moneyAccounts.isNotEmpty) {
      // Group header for banks/cards
      if (widget.includeInvestments) {
        items.add(
          const DropdownMenuItem<String>(
            enabled: false,
            value: '__header_money__',
            child: Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'BANK ACCOUNTS & CREDIT CARDS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        );
      }

      // Add money account items
      for (final item in moneyAccounts) {
        items.add(_buildDropdownItem(item));
      }
    }

    // Add investments section
    if (investments.isNotEmpty) {
      // Group header for investments
      items.add(
        const DropdownMenuItem<String>(
          enabled: false,
          value: '__header_investments__',
          child: Padding(
            padding: EdgeInsets.only(left: 8, top: 8),
            child: Text(
              'INVESTMENTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );

      // Add investment items
      for (final item in investments) {
        items.add(_buildDropdownItem(item));
      }
    }

    return items;
  }

  DropdownMenuItem<String> _buildDropdownItem(AccountItem item) {
    return DropdownMenuItem<String>(
      value: item.id,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          children: [
            Icon(item.icon, color: item.color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    item.displayInfo,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_accountItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.orangeAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.orangeAccent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning,
              color: AppTheme.orangeAccent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.includeInvestments
                    ? 'No accounts or investments found. Add them in Account Management or Investments.'
                    : 'No accounts found. Add an account in Account Management.',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedAccountId,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: theme.cardTheme.color,
      ),
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      dropdownColor: theme.cardTheme.color,
      isExpanded: true,
      items: _buildGroupedDropdownItems().cast<DropdownMenuItem<String>>(),
      onChanged: (value) {
        // Ignore header selections
        if (value?.startsWith('__header_') ?? false) {
          return;
        }

        setState(() => _selectedAccountId = value);
        final item = _getSelectedItem();
        widget.onAccountSelected(value, item?.source, item?.account);
      },
      validator: widget.required
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please select an account';
              }
              return null;
            }
          : null,
    );
  }
}

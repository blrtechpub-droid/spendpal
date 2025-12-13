import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/models/money_tracker_model.dart';
import 'package:spendpal/theme/app_theme.dart';

/// Reusable dropdown widget for selecting bank accounts or credit cards
class AccountSelectionDropdown extends StatefulWidget {
  final String? selectedAccountId;
  final Function(String? accountId, MoneyTrackerAccount? account) onAccountSelected;
  final String? accountType; // 'bank', 'credit_card', or null for both
  final String label;
  final IconData icon;

  const AccountSelectionDropdown({
    super.key,
    this.selectedAccountId,
    required this.onAccountSelected,
    this.accountType,
    this.label = 'Select Account',
    this.icon = Icons.account_balance_wallet,
  });

  @override
  State<AccountSelectionDropdown> createState() => _AccountSelectionDropdownState();
}

class _AccountSelectionDropdownState extends State<AccountSelectionDropdown> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedAccountId;
  List<MoneyTrackerAccount> _accounts = [];
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

      Query query = _firestore
          .collection('moneyAccounts')
          .where('userId', isEqualTo: currentUser.uid);

      // Filter by account type if specified
      if (widget.accountType != null) {
        query = query.where('accountType', isEqualTo: widget.accountType);
      }

      final snapshot = await query.get();
      final accounts = snapshot.docs
          .map((doc) => MoneyTrackerAccount.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _accounts = accounts;
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

  MoneyTrackerAccount? _getSelectedAccount() {
    if (_selectedAccountId == null) return null;
    try {
      return _accounts.firstWhere((account) => account.accountId == _selectedAccountId);
    } catch (e) {
      return null;
    }
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

    if (_accounts.isEmpty) {
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
            Icon(
              Icons.warning,
              color: AppTheme.orangeAccent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No accounts found. Add an account in Account Management.',
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
      value: _selectedAccountId,
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
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('None (Optional)'),
        ),
        ..._accounts.map((account) {
          final icon = account.accountType == 'credit_card'
              ? Icons.credit_card
              : Icons.account_balance;
          final color = account.accountType == 'credit_card'
              ? Colors.purple
              : Colors.blue;

          return DropdownMenuItem<String>(
            value: account.accountId,
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    account.accountName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '₹${account.balance.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() => _selectedAccountId = value);
        final account = _getSelectedAccount();
        widget.onAccountSelected(value, account);
      },
      validator: (value) {
        // Optional field by default
        return null;
      },
    );
  }
}

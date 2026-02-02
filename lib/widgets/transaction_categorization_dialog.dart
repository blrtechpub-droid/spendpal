import 'package:flutter/material.dart';
import 'package:spendpal/widgets/account_selection_dropdown.dart';
import 'package:spendpal/theme/app_theme.dart';

/// Transaction type for categorization
enum TransactionType {
  credit, // Money received
  debit, // Money spent
}

/// Category for credit transactions
enum CreditCategory {
  salary,
  investmentReturn,
  cashback,
  refund,
  otherIncome,
}

/// Category for debit transactions
enum DebitCategory {
  expense,
  investment,
  loanPayment,
  transfer,
  other,
}

/// Result of transaction categorization
class TransactionCategorizationResult {
  final String category;
  final String? accountId;
  final AccountSource? accountSource;
  final dynamic account;
  final String? notes;

  TransactionCategorizationResult({
    required this.category,
    this.accountId,
    this.accountSource,
    this.account,
    this.notes,
  });
}

/// Comprehensive dialog for categorizing SMS/Email transactions
class TransactionCategorizationDialog extends StatefulWidget {
  final String title;
  final double amount;
  final TransactionType transactionType;
  final String? description;
  final String? trackerId; // Tracker that matched this transaction

  const TransactionCategorizationDialog({
    super.key,
    required this.title,
    required this.amount,
    required this.transactionType,
    this.description,
    this.trackerId,
  });

  @override
  State<TransactionCategorizationDialog> createState() =>
      _TransactionCategorizationDialogState();
}

class _TransactionCategorizationDialogState
    extends State<TransactionCategorizationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  // Selected values
  String? _selectedCategory;
  String? _selectedAccountId;
  AccountSource? _selectedAccountSource;
  dynamic _selectedAccount;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getCategoryOptions() {
    if (widget.transactionType == TransactionType.credit) {
      return [
        {
          'value': 'salary',
          'label': 'Salary',
          'icon': Icons.account_balance_wallet,
          'color': Colors.green,
          'description': 'Regular salary or wages',
        },
        {
          'value': 'investment_return',
          'label': 'Investment Return',
          'icon': Icons.trending_up,
          'color': Colors.blue,
          'description': 'Returns, dividends, or capital gains',
        },
        {
          'value': 'cashback',
          'label': 'Cashback',
          'icon': Icons.card_giftcard,
          'color': Colors.orange,
          'description': 'Cashback or rewards',
        },
        {
          'value': 'refund',
          'label': 'Refund',
          'icon': Icons.refresh,
          'color': Colors.purple,
          'description': 'Refunds from purchases',
        },
        {
          'value': 'other_income',
          'label': 'Other Income',
          'icon': Icons.attach_money,
          'color': Colors.teal,
          'description': 'Other sources of income',
        },
      ];
    } else {
      return [
        {
          'value': 'expense',
          'label': 'Expense',
          'icon': Icons.shopping_bag,
          'color': Colors.red,
          'description': 'Regular spending or purchases',
        },
        {
          'value': 'investment',
          'label': 'Investment',
          'icon': Icons.show_chart,
          'color': Colors.green,
          'description': 'Investment purchases (stocks, MF, etc.)',
        },
        {
          'value': 'loan_payment',
          'label': 'Loan Payment',
          'icon': Icons.payment,
          'color': Colors.orange,
          'description': 'Loan or credit card payments',
        },
        {
          'value': 'transfer',
          'label': 'Transfer',
          'icon': Icons.swap_horiz,
          'color': Colors.blue,
          'description': 'Transfer between accounts',
        },
        {
          'value': 'other',
          'label': 'Other',
          'icon': Icons.more_horiz,
          'color': Colors.grey,
          'description': 'Other debits',
        },
      ];
    }
  }

  String _getCategoryLabel(String category) {
    final options = _getCategoryOptions();
    final option = options.firstWhere((opt) => opt['value'] == category);
    return option['label'] as String;
  }

  bool _shouldShowAccountDropdown() {
    if (_selectedCategory == null) return false;

    // Show dropdown for categories that need account linking
    return [
      'salary',
      'investment_return',
      'cashback',
      'refund',
      'expense',
      'investment',
      'loan_payment',
      'transfer',
    ].contains(_selectedCategory);
  }

  bool _shouldIncludeInvestments() {
    // Only show investments for investment-related categories
    return _selectedCategory == 'investment' ||
        _selectedCategory == 'investment_return';
  }

  void _handleCategorize() {
    if (!_formKey.currentState!.validate()) return;

    // Validate account selection for categories that require it
    if (_shouldShowAccountDropdown() && _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an account'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final result = TransactionCategorizationResult(
      category: _selectedCategory!,
      accountId: _selectedAccountId,
      accountSource: _selectedAccountSource,
      account: _selectedAccount,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    Navigator.pop(context, result);
  }

  // Build category option card
  Widget _buildCategoryOption(Map<String, dynamic> option, ThemeData theme) {
    final isSelected = _selectedCategory == option['value'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = option['value'] as String;
            // Reset account selection when category changes
            _selectedAccountId = null;
            _selectedAccountSource = null;
            _selectedAccount = null;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? (option['color'] as Color).withValues(alpha: 0.15)
                : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (option['color'] as Color)
                  : theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                option['icon'] as IconData,
                color: option['color'] as Color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option['label'] as String,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      option['description'] as String,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: option['color'] as Color,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Build category selection section
  Widget _buildCategorySelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Select Category',
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._getCategoryOptions().map((option) => _buildCategoryOption(option, theme)),
      ],
    );
  }

  // Build account selection section
  Widget _buildAccountSelection() {
    if (!_shouldShowAccountDropdown()) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        AccountSelectionDropdown(
          selectedAccountId: _selectedAccountId,
          onAccountSelected: (accountId, source, account) {
            setState(() {
              _selectedAccountId = accountId;
              _selectedAccountSource = source;
              _selectedAccount = account;
            });
          },
          includeInvestments: _shouldIncludeInvestments(),
          trackerId: widget.trackerId, // Filter by matched tracker
          label: 'Select Account',
          icon: Icons.account_balance_wallet,
          required: true,
        ),
      ],
    );
  }

  // Build notes field section
  Widget _buildNotesField(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'Notes (Optional)',
            hintText: 'Add any additional notes',
            prefixIcon: const Icon(Icons.notes),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: theme.cardTheme.color,
          ),
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          maxLines: 2,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = widget.transactionType == TransactionType.credit;

    return AlertDialog(
      backgroundColor: theme.cardTheme.color,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                color: isCredit ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '₹${widget.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isCredit ? Colors.green : Colors.red,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (widget.description != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.description!,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategorySelection(theme),
                  _buildAccountSelection(),
                  _buildNotesField(theme),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedCategory == null ? null : _handleCategorize,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: Text('Categorize as ${_selectedCategory != null ? _getCategoryLabel(_selectedCategory!) : '...'}'),
        ),
      ],
    );
  }
}

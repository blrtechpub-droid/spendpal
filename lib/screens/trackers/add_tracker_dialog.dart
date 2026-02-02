import 'package:flutter/material.dart';
import '../../models/account_tracker_model.dart';
import '../../services/account_tracker_service.dart';
import '../../config/tracker_registry.dart';
import '../../theme/app_theme.dart';

class AddTrackerDialog extends StatefulWidget {
  final String userId;
  final TrackerType? preselectedType;

  const AddTrackerDialog({
    super.key,
    required this.userId,
    this.preselectedType,
  });

  @override
  State<AddTrackerDialog> createState() => _AddTrackerDialogState();
}

class _AddTrackerDialogState extends State<AddTrackerDialog> {
  TrackerType? _selectedType;
  TrackerCategory? _selectedCategory;
  final TextEditingController _accountNumberController = TextEditingController();
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.preselectedType;
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.tealAccent.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle, color: AppTheme.tealAccent),
                  const SizedBox(width: 12),
                  const Text(
                    'Add Account Tracker',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _selectedType == null
                  ? _buildTypeSelection(theme)
                  : _buildCategorySelection(theme),
            ),

            // Footer
            if (_selectedCategory != null) _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelection(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Select Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        ...TrackerType.values.map((type) => _buildTypeCard(type, theme)),
      ],
    );
  }

  Widget _buildTypeCard(TrackerType type, ThemeData theme) {
    String emoji = '🏦';
    String title = 'Banking';
    String description = 'Savings & Current accounts';

    switch (type) {
      case TrackerType.banking:
        emoji = '🏦';
        title = 'Banking';
        description = 'Savings & Current accounts';
        break;
      case TrackerType.creditCard:
        emoji = '💳';
        title = 'Credit Card';
        description = 'Credit card transactions';
        break;
      case TrackerType.investment:
        emoji = '📈';
        title = 'Investments';
        description = 'Stocks, Mutual Funds, etc.';
        break;
      case TrackerType.governmentScheme:
        emoji = '💰';
        title = 'Government Schemes';
        description = 'PPF, NPS, EPF, etc.';
        break;
      case TrackerType.digitalWallet:
        emoji = '📱';
        title = 'Digital Wallets';
        description = 'Paytm, PhonePe, Google Pay';
        break;
      case TrackerType.insurance:
        emoji = '🏥';
        title = 'Insurance';
        description = 'Life, Health, Vehicle';
        break;
      case TrackerType.loan:
        emoji = '🏠';
        title = 'Loans';
        description = 'Home, Car, Personal';
        break;
    }

    return Card(
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.tealAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelection(ThemeData theme) {
    final templates = TrackerRegistry.getTemplatesByType(_selectedType!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedType = null;
                  _selectedCategory = null;
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Choose Provider',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Provider list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: templates.map((template) {
              return _buildProviderCard(template, theme);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderCard(TrackerTemplate template, ThemeData theme) {
    final isSelected = _selectedCategory == template.category;
    final color = template.color;

    return Card(
      color: isSelected
          ? color.withValues(alpha: 0.1)
          : theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = template.category),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(template.emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.emailDomains.join(', '),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.tealAccent,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Optional account number input
          TextField(
            controller: _accountNumberController,
            decoration: InputDecoration(
              labelText: 'Account Number (Optional)',
              hintText: 'Last 4 digits',
              prefixIcon: const Icon(Icons.account_balance),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: 'For display purposes only',
              helperStyle: TextStyle(fontSize: 11),
            ),
            maxLength: 4,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // Add button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isAdding ? null : _addTracker,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.tealAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isAdding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Add Tracker',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addTracker() async {
    if (_selectedCategory == null) return;

    setState(() => _isAdding = true);

    final accountNumber = _accountNumberController.text.trim();

    final tracker = await AccountTrackerService.addTrackerFromTemplate(
      userId: widget.userId,
      category: _selectedCategory!,
      accountNumber: accountNumber.isNotEmpty ? accountNumber : null,
    );

    setState(() => _isAdding = false);

    if (mounted) {
      if (tracker != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tracker.name} added successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This tracker already exists or failed to add'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

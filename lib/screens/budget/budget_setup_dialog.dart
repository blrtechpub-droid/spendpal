import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/budget_model.dart';
import '../../services/budget_service.dart';
import '../../utils/currency_utils.dart';

class BudgetSetupDialog extends StatefulWidget {
  final BudgetModel? existingBudget;

  const BudgetSetupDialog({super.key, this.existingBudget});

  @override
  State<BudgetSetupDialog> createState() => _BudgetSetupDialogState();
}

class _BudgetSetupDialogState extends State<BudgetSetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cycleStartDayController = TextEditingController();
  final _overallLimitController = TextEditingController();

  final Map<String, TextEditingController> _categoryControllers = {};

  final List<String> categories = [
    'Food',
    'Groceries',
    'Travel',
    'Shopping',
    'Maid',
    'Cook',
    'Utilities',
    'Entertainment',
    'Healthcare',
    'Education',
    'Personal Care',
    'Taxes',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    if (widget.existingBudget != null) {
      _cycleStartDayController.text =
          widget.existingBudget!.cycleStartDay.toString();
      _overallLimitController.text =
          widget.existingBudget!.overallMonthlyLimit?.toString() ?? '';
    } else {
      _cycleStartDayController.text = '1'; // Default to 1st of month
    }

    // Initialize category controllers
    for (final category in categories) {
      final controller = TextEditingController();
      if (widget.existingBudget != null &&
          widget.existingBudget!.categoryLimits.containsKey(category)) {
        controller.text =
            widget.existingBudget!.categoryLimits[category]!.toString();
      }
      _categoryControllers[category] = controller;
    }
  }

  @override
  void dispose() {
    _cycleStartDayController.dispose();
    _overallLimitController.dispose();
    _categoryControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingBudget == null
          ? 'Setup Budget'
          : 'Edit Budget'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cycle Start Day
                TextFormField(
                  controller: _cycleStartDayController,
                  decoration: const InputDecoration(
                    labelText: 'Budget Cycle Start Day',
                    helperText: 'Day of month when your salary is credited (1-31)',
                    hintText: '1',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a day';
                    }
                    final day = int.tryParse(value);
                    if (day == null || day < 1 || day > 31) {
                      return 'Enter a day between 1 and 31';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Overall Monthly Limit
                TextFormField(
                  controller: _overallLimitController,
                  decoration: InputDecoration(
                    labelText: 'Overall Monthly Limit (Optional)',
                    helperText: 'Leave empty to set only category budgets',
                    hintText: '30000',
                    prefixText: context.currencySymbol,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid positive amount';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Category Budgets Section
                Text(
                  'Category Budgets (Optional)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Set spending limits for individual categories',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 12),

                // Category limit fields
                ...categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _categoryControllers[category],
                      decoration: InputDecoration(
                        labelText: category,
                        hintText: '0',
                        prefixText: context.currencySymbol,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Enter a valid positive amount';
                          }
                        }
                        return null;
                      },
                    ),
                  );
                }).toList(),
              ],
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
          onPressed: _saveBudget,
          child: Text(widget.existingBudget == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    // Parse values
    final cycleStartDay = int.parse(_cycleStartDayController.text);
    final overallLimit = _overallLimitController.text.isNotEmpty
        ? double.parse(_overallLimitController.text)
        : null;

    // Parse category limits
    final categoryLimits = <String, double>{};
    for (final entry in _categoryControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        categoryLimits[entry.key] = double.parse(entry.value.text);
      }
    }

    // Validate that at least one limit is set
    if (overallLimit == null && categoryLimits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please set either an overall budget or at least one category budget'),
        ),
      );
      return;
    }

    try {
      if (widget.existingBudget == null) {
        // Create new budget
        await BudgetService.createBudget(
          userId: userId,
          cycleStartDay: cycleStartDay,
          overallMonthlyLimit: overallLimit,
          categoryLimits: categoryLimits,
        );
      } else {
        // Update existing budget
        await BudgetService.updateBudget(
          budgetId: widget.existingBudget!.budgetId,
          cycleStartDay: cycleStartDay,
          overallMonthlyLimit: overallLimit,
          categoryLimits: categoryLimits,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingBudget == null
              ? 'Budget created successfully!'
              : 'Budget updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving budget: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

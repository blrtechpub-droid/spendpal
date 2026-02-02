import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/savings_goal_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';

class AddEditSavingsGoalScreen extends StatefulWidget {
  final SavingsGoalModel? goal;

  const AddEditSavingsGoalScreen({super.key, this.goal});

  @override
  State<AddEditSavingsGoalScreen> createState() =>
      _AddEditSavingsGoalScreenState();
}

class _AddEditSavingsGoalScreenState extends State<AddEditSavingsGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _contributionController = TextEditingController();

  DateTime _deadline = DateTime.now().add(const Duration(days: 30));
  String? _category;
  bool _isLoading = false;
  bool _showContributionField = false;

  final List<String> _categories = [
    'Emergency Fund',
    'Vacation',
    'Car',
    'Home',
    'Education',
    'Wedding',
    'Gadget',
    'Investment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.goal != null) {
      _titleController.text = widget.goal!.title;
      _targetAmountController.text = widget.goal!.targetAmount.toString();
      _deadline = widget.goal!.deadline;
      _category = widget.goal!.category;
      _showContributionField = true; // Show contribution field for existing goals
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _contributionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.goal != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Goal' : 'New Savings Goal'),
        actions: [
          if (isEditing && !widget.goal!.isCompleted)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteGoal(),
              tooltip: 'Delete Goal',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Goal progress card (only for existing goals)
                    if (isEditing) ...[
                      _buildProgressCard(theme),
                      const SizedBox(height: 24),
                    ],

                    // Title field
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Goal Title',
                        hintText: 'e.g., Holiday to Goa, New Car',
                        prefixIcon: const Icon(Icons.flag_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a goal title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Target amount field
                    TextFormField(
                      controller: _targetAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Target Amount',
                        hintText: '${context.currencySymbol} 0',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter target amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                      enabled: !isEditing, // Can't change target after creation
                    ),
                    const SizedBox(height: 16),

                    // Category selector
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: InputDecoration(
                        labelText: 'Category (Optional)',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _category = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Deadline picker
                    InkWell(
                      onTap: () => _selectDeadline(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Deadline: ${DateFormat('MMM dd, yyyy').format(_deadline)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),

                    // Contribution section (for existing goals)
                    if (_showContributionField) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Add Contribution',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _contributionController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                hintText: '${context.currencySymbol} 0',
                                prefixIcon: const Icon(Icons.add_circle_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => _addContribution(),
                            style: AppTheme.successButtonStyle,
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current: ${context.formatCurrency(widget.goal?.currentAmount ?? 0)} / ${context.formatCurrency(widget.goal?.targetAmount ?? 0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _saveGoal(),
                        style: AppTheme.primaryButtonStyle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            isEditing ? 'Update Goal' : 'Create Goal',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),

                    // Mark as complete button (for existing goals)
                    if (isEditing && !widget.goal!.isCompleted) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _markAsComplete(),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('Mark as Complete'),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProgressCard(ThemeData theme) {
    final goal = widget.goal!;
    final progressPercentage = goal.progressPercentage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${progressPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.tealAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressPercentage / 100,
                minHeight: 10,
                backgroundColor: theme.dividerColor.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.tealAccent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      context.formatCurrency(goal.currentAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Remaining',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      context.formatCurrency(goal.remainingAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!goal.isCompleted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: goal.isOverdue
                      ? Colors.red.withOpacity(0.1)
                      : AppTheme.tealAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      goal.isOverdue
                          ? Icons.error_outline
                          : Icons.calendar_today,
                      size: 14,
                      color: goal.isOverdue ? Colors.red : AppTheme.tealAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      goal.isOverdue
                          ? 'Deadline passed'
                          : '${goal.daysRemaining} days remaining',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            goal.isOverdue ? Colors.red : AppTheme.tealAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
    );

    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _addContribution() async {
    final amountStr = _contributionController.text.trim();
    if (amountStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newAmount = widget.goal!.currentAmount + amount;
      final isCompleted = newAmount >= widget.goal!.targetAmount;

      await FirebaseFirestore.instance
          .collection('savingsGoals')
          .doc(widget.goal!.goalId)
          .update({
        'currentAmount': newAmount,
        'isCompleted': isCompleted,
      });

      _contributionController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCompleted
                ? '🎉 Goal completed! Contribution of ${context.formatCurrency(amount)} added.'
                : 'Contribution of ${context.formatCurrency(amount)} added successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      if (isCompleted) {
        // Navigate back after a delay to show the success message
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding contribution: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final title = _titleController.text.trim();
      final targetAmount = double.parse(_targetAmountController.text.trim());

      if (widget.goal != null) {
        // Update existing goal
        await FirebaseFirestore.instance
            .collection('savingsGoals')
            .doc(widget.goal!.goalId)
            .update({
          'title': title,
          'deadline': Timestamp.fromDate(_deadline),
          'category': _category,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Create new goal
        final newGoal = SavingsGoalModel(
          goalId: '', // Firestore will generate
          userId: currentUserId,
          title: title,
          targetAmount: targetAmount,
          currentAmount: 0,
          deadline: _deadline,
          category: _category,
          createdAt: DateTime.now(),
          isCompleted: false,
        );

        await FirebaseFirestore.instance
            .collection('savingsGoals')
            .add(newGoal.toMap());

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving goal: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Complete'),
        content: const Text(
          'Are you sure you want to mark this goal as complete?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.successButtonStyle,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('savingsGoals')
          .doc(widget.goal!.goalId)
          .update({
        'isCompleted': true,
        'currentAmount': widget.goal!.targetAmount, // Set to target amount
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Goal marked as complete!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking goal as complete: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteGoal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text(
          'Are you sure you want to delete this goal? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('savingsGoals')
          .doc(widget.goal!.goalId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goal deleted successfully'),
          backgroundColor: Colors.orange,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting goal: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

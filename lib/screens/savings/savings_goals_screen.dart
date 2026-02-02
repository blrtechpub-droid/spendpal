import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/savings_goal_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';
import 'add_edit_savings_goal_screen.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToAddGoal(),
            tooltip: 'Add Goal',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('savingsGoals')
            .where('userId', isEqualTo: _currentUserId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final goals = snapshot.data?.docs
                  .map((doc) => SavingsGoalModel.fromFirestore(doc))
                  .toList() ??
              [];

          if (goals.isEmpty) {
            return _buildEmptyState();
          }

          // Separate active and completed goals
          final activeGoals = goals.where((g) => !g.isCompleted).toList();
          final completedGoals = goals.where((g) => g.isCompleted).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (activeGoals.isNotEmpty) ...[
                Text(
                  'Active Goals',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...activeGoals.map((goal) => _buildGoalCard(goal, theme)),
                const SizedBox(height: 24),
              ],
              if (completedGoals.isNotEmpty) ...[
                Text(
                  'Completed Goals',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...completedGoals.map((goal) => _buildGoalCard(goal, theme)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddGoal(),
        backgroundColor: AppTheme.tealAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.savings_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Savings Goals Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first goal to start saving!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddGoal(),
            style: AppTheme.primaryButtonStyle,
            icon: const Icon(Icons.add),
            label: const Text('Create Goal'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(SavingsGoalModel goal, ThemeData theme) {
    final isOverdue = goal.isOverdue;
    final progressPercentage = goal.progressPercentage;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToGoalDetail(goal),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and amount row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: goal.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (goal.isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Progress amount
              Row(
                children: [
                  Text(
                    context.formatCurrency(goal.currentAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.tealAccent,
                    ),
                  ),
                  Text(
                    ' / ${context.formatCurrency(goal.targetAmount)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressPercentage / 100,
                  minHeight: 8,
                  backgroundColor: theme.dividerColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    goal.isCompleted
                        ? Colors.green
                        : isOverdue
                            ? Colors.red
                            : AppTheme.tealAccent,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bottom info row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Progress percentage
                  Text(
                    '${progressPercentage.toStringAsFixed(1)}% Complete',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),

                  // Deadline info
                  if (!goal.isCompleted) ...[
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 12, color: Colors.red),
                            const SizedBox(width: 4),
                            Text(
                              'Overdue',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${goal.daysRemaining} days left',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),

              // Category chip (if present)
              if (goal.category != null && goal.category!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.tealAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    goal.category!,
                    style: const TextStyle(
                      color: AppTheme.tealAccent,
                      fontSize: 11,
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

  void _navigateToAddGoal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditSavingsGoalScreen(),
      ),
    );
  }

  void _navigateToGoalDetail(SavingsGoalModel goal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditSavingsGoalScreen(goal: goal),
      ),
    );
  }
}

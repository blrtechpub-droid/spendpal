import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/savings_goal_model.dart';
import '../theme/app_theme.dart';
import '../screens/savings/savings_goals_screen.dart';
import '../screens/savings/add_edit_savings_goal_screen.dart';

class SavingsGoalsWidget extends StatelessWidget {
  const SavingsGoalsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('savingsGoals')
          .where('userId', isEqualTo: currentUserId)
          .where('isCompleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(context, theme);
        }

        final goals = snapshot.data!.docs
            .map((doc) => SavingsGoalModel.fromFirestore(doc))
            .toList();

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.savings,
                        size: 20,
                        color: AppTheme.tealAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Savings Goals',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SavingsGoalsScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'View All',
                      style: TextStyle(
                        color: AppTheme.tealAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Horizontal scrollable goals
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    return _buildGoalCard(context, goals[index], theme);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.savings,
                size: 20,
                color: AppTheme.tealAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'Savings Goals',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.tealAccent.withValues(alpha: 0.1),
                  AppTheme.tealAccent.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.tealAccent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start saving for your goals',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track your progress towards financial goals',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEditSavingsGoalScreen(),
                      ),
                    );
                  },
                  style: AppTheme.primaryButtonStyle.copyWith(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  child: const Text(
                    'Create Goal',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, SavingsGoalModel goal, ThemeData theme) {
    final progressPercentage = goal.progressPercentage;
    final isOverdue = goal.isOverdue;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditSavingsGoalScreen(goal: goal),
          ),
        );
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.tealAccent.withValues(alpha: 0.15),
              AppTheme.tealAccent.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.tealAccent.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Title
            Text(
              goal.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Progress
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '₹${goal.currentAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.tealAccent,
                      ),
                    ),
                    Text(
                      ' / ₹${goal.targetAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercentage / 100,
                    minHeight: 6,
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOverdue ? Colors.red : AppTheme.tealAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Status row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${progressPercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Overdue',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Text(
                        '${goal.daysRemaining}d left',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/screens/expense/expense_screen.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:spendpal/screens/groups/group_charts_screen.dart';
import 'package:spendpal/models/expense_comment_model.dart';
import 'package:spendpal/utils/currency_utils.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final String expenseId;

  const ExpenseDetailScreen({Key? key, required this.expenseId}) : super(key: key);

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('expenses')
          .doc(widget.expenseId)
          .collection('comments')
          .add({
        'expenseId': widget.expenseId,
        'userId': currentUserId,
        'text': commentText,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'travel':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_cart;
      case 'maid':
        return Icons.cleaning_services;
      case 'cook':
        return Icons.soup_kitchen;
      default:
        return Icons.receipt;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Colors.orange;
      case 'travel':
        return Colors.blue;
      case 'shopping':
        return Colors.purple;
      case 'maid':
        return Colors.teal;
      case 'cook':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSpendingTrends(BuildContext context, ThemeData theme, String category, String? groupId) {
    // Calculate date 6 months ago
    final now = DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('expenses')
          .where('category', isEqualTo: category)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(sixMonthsAgo))
          .orderBy('date', descending: false)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // Group expenses by month
        final monthlyTotals = <String, double>{};
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = data['date'] as Timestamp;
          final date = timestamp.toDate();
          final monthKey = DateFormat('MMM yyyy').format(date);
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

          monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0.0) + amount;
        }

        if (monthlyTotals.isEmpty) {
          return const SizedBox.shrink();
        }

        // Sort months chronologically
        final sortedMonths = monthlyTotals.keys.toList()
          ..sort((a, b) {
            final dateA = DateFormat('MMM yyyy').parse(a);
            final dateB = DateFormat('MMM yyyy').parse(b);
            return dateA.compareTo(dateB);
          });

        // Take last 6 months only
        final displayMonths = sortedMonths.length > 6
            ? sortedMonths.sublist(sortedMonths.length - 6)
            : sortedMonths;

        final maxAmount = monthlyTotals.values.reduce((a, b) => a > b ? a : b);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spending trends',
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your $category spending over time',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              // Bar chart
              AspectRatio(
                aspectRatio: 1.7,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxAmount * 1.2,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final month = displayMonths[group.x.toInt()];
                          return BarTooltipItem(
                            '$month\n${context.formatCurrency(rod.toY)}',
                            TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < displayMonths.length) {
                              final month = displayMonths[index];
                              // Show only month abbreviation (first 3 chars)
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  month.split(' ').first,
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${context.currencySymbol}${(value / 1000).toStringAsFixed(0)}k',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxAmount / 4,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    barGroups: displayMonths.asMap().entries.map((entry) {
                      final index = entry.key;
                      final month = entry.value;
                      final amount = monthlyTotals[month] ?? 0.0;

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: amount,
                            color: _getCategoryColor(category),
                            width: 20,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // View more charts button (only for group expenses)
              if (groupId != null)
                Center(
                  child: TextButton.icon(
                    icon: Icon(Icons.bar_chart, color: theme.colorScheme.primary),
                    label: Text(
                      'View more charts',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                    onPressed: () async {
                      // Navigate to group charts screen
                      final groupDoc = await FirebaseFirestore.instance
                          .collection('groups')
                          .doc(groupId)
                          .get();

                      if (!context.mounted) return;

                      if (groupDoc.exists) {
                        final groupData = groupDoc.data() as Map<String, dynamic>;
                        final groupName = groupData['name'] ?? 'Group';

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupChartsScreen(
                              groupId: groupId,
                              groupName: groupName,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentsSection(BuildContext context, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('expenses')
          .doc(widget.expenseId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final comments = snapshot.data!.docs;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.comment,
                    size: 20,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Comments',
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.tealAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${comments.length}',
                      style: const TextStyle(
                        color: AppTheme.tealAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...comments.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final userId = data['userId'] ?? '';
                final text = data['text'] ?? '';
                final createdAt = data['createdAt'] as Timestamp?;

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get(),
                  builder: (context, userSnapshot) {
                    String userName = 'Unknown';
                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                      userName = userData?['name'] ?? 'Unknown';
                    }

                    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                    final isCurrentUser = userId == currentUserId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.tealAccent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: AppTheme.tealAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isCurrentUser ? 'You' : userName,
                                      style: TextStyle(
                                        color: theme.textTheme.bodyLarge?.color,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (createdAt != null)
                                      Text(
                                        _formatCommentTime(createdAt.toDate()),
                                        style: TextStyle(
                                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  style: TextStyle(
                                    color: theme.textTheme.bodyLarge?.color,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _formatCommentTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.camera_alt, color: theme.textTheme.bodyLarge?.color),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add receipt photo')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete, color: theme.textTheme.bodyLarge?.color),
            onPressed: () async {
              final dialogTheme = Theme.of(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: dialogTheme.cardTheme.color,
                  title: Text(
                    'Delete Expense',
                    style: TextStyle(color: dialogTheme.textTheme.bodyLarge?.color),
                  ),
                  content: Text(
                    'Are you sure you want to delete this expense?',
                    style: TextStyle(color: dialogTheme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                // Show loading dialog
                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                try {
                  // Delete the expense
                  await FirebaseFirestore.instance
                      .collection('expenses')
                      .doc(widget.expenseId)
                      .delete();

                  if (context.mounted) {
                    // Close loading dialog
                    Navigator.pop(context);
                    // Close detail screen
                    Navigator.pop(context);
                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Expense deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    // Close loading dialog
                    Navigator.pop(context);
                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting expense: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.edit, color: theme.textTheme.bodyLarge?.color),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddExpenseScreen(expenseId: widget.expenseId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('expenses')
            .doc(widget.expenseId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Expense not found',
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final title = data['title'] ?? 'Untitled';
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final category = data['category'] ?? 'Other';
          final paidBy = data['paidBy'] ?? '';
          final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});
          final createdAt = data['createdAt'] as Timestamp?;
          final date = createdAt?.toDate();
          final notes = data['notes'] ?? '';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expense Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Category Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(category).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getCategoryIcon(category),
                          size: 40,
                          color: _getCategoryColor(category),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      Text(
                        title,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Amount
                      Text(
                        context.formatCurrency(amount),
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Date
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(paidBy)
                            .get(),
                        builder: (context, userSnapshot) {
                          String addedBy = 'Unknown';
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                            addedBy = userData?['name'] ?? 'Unknown';
                            if (paidBy == currentUserId) {
                              addedBy = 'you';
                            }
                          }

                          return Text(
                            date != null
                                ? 'Added by $addedBy on ${DateFormat('dd MMM yyyy').format(date)}'
                                : 'Added by $addedBy',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Payment Details
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Who paid
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(paidBy)
                            .get(),
                        builder: (context, userSnapshot) {
                          String paidByName = 'Unknown';
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                            paidByName = userData?['name'] ?? 'Unknown';
                          }

                          final isPaidByCurrentUser = paidBy == currentUserId;
                          final displayName = isPaidByCurrentUser ? 'You' : paidByName;

                          return Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.tealAccent.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: AppTheme.tealAccent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$displayName paid ${context.formatCurrency(amount)}',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyLarge?.color,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Divider(color: theme.dividerTheme.color),
                      const SizedBox(height: 16),
                      // Split details
                      ...splitDetails.entries.map((entry) {
                        final uid = entry.key;
                        final shareAmount = (entry.value as num).toDouble();

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .get(),
                          builder: (context, userSnapshot) {
                            String userName = 'Unknown';
                            if (userSnapshot.hasData && userSnapshot.data!.exists) {
                              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                              userName = userData?['name'] ?? 'Unknown';
                            }

                            final isCurrentUser = uid == currentUserId;
                            final isPaidByCurrentUser = paidBy == currentUserId;

                            String statusText;
                            Color statusColor;

                            if (isCurrentUser && isPaidByCurrentUser) {
                              statusText = 'You lent';
                              statusColor = Colors.green;
                            } else if (isCurrentUser && !isPaidByCurrentUser) {
                              statusText = 'You owe';
                              statusColor = Colors.orange;
                            } else if (!isCurrentUser && isPaidByCurrentUser) {
                              statusText = '$userName owes you';
                              statusColor = Colors.green;
                            } else {
                              statusText = 'owes';
                              statusColor = Colors.grey;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      isCurrentUser ? 'You' : userName,
                                      style: TextStyle(
                                        color: theme.textTheme.bodyLarge?.color,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        context.formatCurrency(shareAmount),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),

                // Notes section
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notes,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Spending trends chart
                _buildSpendingTrends(context, theme, category, data['groupId'] as String?),

                const SizedBox(height: 24),

                // Comments section
                _buildCommentsSection(context, theme),

                const SizedBox(height: 100), // Space for comment input
              ],
            ),
          );
        },
      ),
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          border: Border(
            top: BorderSide(
              color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: 'Add a comment',
                  hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: AppTheme.tealAccent,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (value) => _postComment(),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.send,
                color: AppTheme.tealAccent,
              ),
              onPressed: _postComment,
            ),
          ],
        ),
      ),
    );
  }
}

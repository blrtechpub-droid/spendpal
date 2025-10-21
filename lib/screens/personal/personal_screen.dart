import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/screens/expense/expense_detail_screen.dart';
import 'package:spendpal/screens/expense/expense_screen.dart';

class PersonalExpensesScreen extends StatefulWidget {
  const PersonalExpensesScreen({super.key});

  @override
  State<PersonalExpensesScreen> createState() => _PersonalExpensesScreenState();
}

class _PersonalExpensesScreenState extends State<PersonalExpensesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get category icon based on category name
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
      case 'utilities':
        return Icons.bolt;
      case 'entertainment':
        return Icons.movie;
      case 'healthcare':
        return Icons.medical_services;
      case 'education':
        return Icons.school;
      case 'personal care':
        return Icons.spa;
      default:
        return Icons.receipt;
    }
  }

  // Helper function to get category background color
  Color _getCategoryBackgroundColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return AppTheme.foodCategory;
      case 'travel':
        return AppTheme.travelCategory;
      case 'shopping':
        return AppTheme.shoppingCategory;
      case 'maid':
        return AppTheme.maidCategory;
      case 'cook':
        return AppTheme.cookCategory;
      case 'utilities':
        return Colors.amber.shade100;
      case 'entertainment':
        return Colors.pink.shade100;
      case 'healthcare':
        return Colors.red.shade100;
      case 'education':
        return Colors.indigo.shade100;
      case 'personal care':
        return Colors.cyan.shade100;
      default:
        return AppTheme.defaultCategory;
    }
  }

  // Calculate total expenses for current month
  Future<double> _calculateMonthlyTotal(List<QueryDocumentSnapshot> expenses) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    double total = 0.0;
    for (var expense in expenses) {
      final data = expense.data() as Map<String, dynamic>;
      final timestamp = data['createdAt'] as Timestamp?;
      if (timestamp != null) {
        final date = timestamp.toDate();
        if (date.year == currentMonth.year && date.month == currentMonth.month) {
          total += (data['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }
    return total;
  }

  // Calculate category breakdown
  Map<String, double> _calculateCategoryBreakdown(List<QueryDocumentSnapshot> expenses) {
    Map<String, double> categoryTotals = {};

    for (var expense in expenses) {
      final data = expense.data() as Map<String, dynamic>;
      final category = data['category'] ?? 'Other';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

      categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
    }

    return categoryTotals;
  }

  // Helper function to determine expense type
  String _getExpenseType(Map<String, dynamic> data) {
    final groupId = data['groupId'] ?? '';
    final splitWith = List<String>.from(data['splitWith'] ?? []);

    if (groupId.isNotEmpty) {
      return 'group';
    } else if (splitWith.length > 1) {
      return 'friend';
    } else {
      return 'personal';
    }
  }

  // Helper function to get expense type icon
  IconData _getExpenseTypeIcon(String type) {
    switch (type) {
      case 'group':
        return Icons.groups;
      case 'friend':
        return Icons.people;
      case 'personal':
      default:
        return Icons.person;
    }
  }

  // Helper function to get expense type color
  Color _getExpenseTypeColor(String type) {
    switch (type) {
      case 'group':
        return Colors.blue;
      case 'friend':
        return Colors.purple;
      case 'personal':
      default:
        return AppTheme.tealAccent;
    }
  }

  // Helper function to get expense type label
  String _getExpenseTypeLabel(String type) {
    switch (type) {
      case 'group':
        return 'Group';
      case 'friend':
        return 'Split';
      case 'personal':
      default:
        return 'Personal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground,
        title: const Text(
          'My Expenses',
          style: TextStyle(color: AppTheme.primaryText),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppTheme.primaryText),
            onPressed: () {
              // TODO: Implement filter dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filter feature coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, color: AppTheme.primaryText),
            onPressed: () {
              // TODO: Implement export to PDF
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('expenses')
            .where('paidBy', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.tealAccent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading expenses',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.tealAccent),
            );
          }

          // Filter to show ONLY personal expenses (not group or friend expenses)
          var allExpenses = snapshot.data!.docs;
          var personalExpenses = allExpenses.where((expense) {
            final data = expense.data() as Map<String, dynamic>;
            final groupId = data['groupId'] ?? '';
            final splitWith = List<String>.from(data['splitWith'] ?? []);

            // Only include expenses that are NOT part of a group AND NOT split with friends
            return groupId.isEmpty && splitWith.length <= 1;
          }).toList();

          // Sort by date (most recent first)
          personalExpenses.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          if (personalExpenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.tealAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      size: 64,
                      color: AppTheme.tealAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No expenses yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your personal expenses here',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Expense'),
                    style: AppTheme.primaryButtonStyle,
                    onPressed: () => Navigator.pushNamed(context, '/add_expense'),
                  ),
                ],
              ),
            );
          }

          // Calculate statistics
          final categoryBreakdown = _calculateCategoryBreakdown(personalExpenses);

          return FutureBuilder<double>(
            future: _calculateMonthlyTotal(personalExpenses),
            builder: (context, monthlySnapshot) {
              final monthlyTotal = monthlySnapshot.data ?? 0.0;

              return Column(
                children: [
                  // Statistics Summary
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.tealAccent.withValues(alpha: 0.2),
                          AppTheme.tealAccent.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatCard(
                              'This Month',
                              '₹${monthlyTotal.toStringAsFixed(2)}',
                              Icons.calendar_month,
                              AppTheme.tealAccent,
                            ),
                            _buildStatCard(
                              'Total Expenses',
                              personalExpenses.length.toString(),
                              Icons.receipt,
                              AppTheme.orangeAccent,
                            ),
                          ],
                        ),
                        if (categoryBreakdown.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(color: AppTheme.dividerColor),
                          const SizedBox(height: 8),
                          const Text(
                            'Top Categories',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildCategoryChips(categoryBreakdown),
                        ],
                      ],
                    ),
                  ),

                  // Expenses List
                  Expanded(
                    child: _buildExpensesList(personalExpenses),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(Map<String, double> categoryBreakdown) {
    // Sort categories by amount (descending) and take top 3
    var sortedCategories = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    var topCategories = sortedCategories.take(3).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: topCategories.map((entry) {
        final color = _getCategoryBackgroundColor(entry.key);
        return Chip(
          avatar: Icon(
            _getCategoryIcon(entry.key),
            size: 16,
            color: Colors.grey[800],
          ),
          label: Text(
            '${entry.key}: ₹${entry.value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: color,
        );
      }).toList(),
    );
  }

  Widget _buildExpensesList(List<QueryDocumentSnapshot> expenses) {
    // Group expenses by month
    Map<String, List<QueryDocumentSnapshot>> groupedExpenses = {};
    for (var expense in expenses) {
      final data = expense.data() as Map<String, dynamic>;
      final timestamp = data['createdAt'] as Timestamp?;
      if (timestamp != null) {
        final date = timestamp.toDate();
        final monthKey = DateFormat('MMMM yyyy').format(date);
        groupedExpenses.putIfAbsent(monthKey, () => []);
        groupedExpenses[monthKey]!.add(expense);
      }
    }

    return ListView(
      children: groupedExpenses.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.secondaryBackground,
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryText,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '₹${entry.value.fold<double>(0.0, (total, doc) {
                      final amount = ((doc.data() as Map<String, dynamic>)['amount'] as num?)?.toDouble() ?? 0.0;
                      return total + amount;
                    }).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.tealAccent,
                    ),
                  ),
                ],
              ),
            ),
            // Expenses for this month
            ...entry.value.map((expenseDoc) {
              final data = expenseDoc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Untitled';
              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final category = data['category'] ?? 'Other';
              final timestamp = data['createdAt'] as Timestamp?;
              final date = timestamp?.toDate();
              final notes = data['notes'] ?? '';
              final tags = List<String>.from(data['tags'] ?? []);

              // Get expense type info
              final expenseType = _getExpenseType(data);
              final typeColor = _getExpenseTypeColor(expenseType);
              final typeLabel = _getExpenseTypeLabel(expenseType);
              final typeIcon = _getExpenseTypeIcon(expenseType);

              return Slidable(
                key: ValueKey(expenseDoc.id),
                startActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => _splitWithFriends(context, expenseDoc.id, data),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      icon: Icons.people,
                      label: 'Friends',
                    ),
                  ],
                ),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => _splitWithGroup(context, expenseDoc.id, data),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      icon: Icons.groups,
                      label: 'Group',
                    ),
                  ],
                ),
                child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpenseDetailScreen(
                        expenseId: expenseDoc.id,
                      ),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _getCategoryBackgroundColor(category),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: Colors.grey[800],
                    size: 26,
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryText,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Expense type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.5),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                typeIcon,
                                size: 10,
                                color: typeColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: typeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (date != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('MMM dd, yyyy • h:mm a').format(date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.tertiaryText,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          children: tags.take(2).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.tealAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.tealAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
                trailing: Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.orangeAccent,
                  ),
                ),
              ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  // Method to split expense with friends
  Future<void> _splitWithFriends(BuildContext context, String expenseId, Map<String, dynamic> expenseData) async {
    final currentUserId = _auth.currentUser?.uid ?? '';

    // Fetch user's friends
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final friendsData = userDoc.data()?['friends'];

    List<Map<String, dynamic>> friends = [];
    if (friendsData is Map) {
      for (var entry in (friendsData as Map).entries) {
        final friendId = entry.key as String;
        final nickname = entry.value as String?;

        final friendDoc = await _firestore.collection('users').doc(friendId).get();
        if (friendDoc.exists) {
          final friendInfo = friendDoc.data()!;
          friends.add({
            'uid': friendId,
            'name': friendInfo['name'] ?? 'Unknown',
            'nickname': nickname ?? '',
            'photoURL': friendInfo['photoURL'] ?? '',
          });
        }
      }
    }

    if (!context.mounted) return;

    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No friends found. Add friends first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show friend selector bottom sheet
    _showFriendSelector(context, expenseId, expenseData, friends);
  }

  // Method to split expense with group
  Future<void> _splitWithGroup(BuildContext context, String expenseId, Map<String, dynamic> expenseData) async {
    final currentUserId = _auth.currentUser?.uid ?? '';

    // Fetch user's groups
    final groupsSnapshot = await _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .get();

    if (!context.mounted) return;

    if (groupsSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No groups found. Create a group first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    List<Map<String, dynamic>> groups = groupsSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'groupId': doc.id,
        'name': data['name'] ?? 'Unnamed Group',
        'photo': data['photo'] ?? '',
        'members': List<String>.from(data['members'] ?? []),
      };
    }).toList();

    // Show group selector bottom sheet
    _showGroupSelector(context, expenseId, expenseData, groups);
  }

  // Friend selector - navigate to full expense editor for Splitwise-style options
  void _showFriendSelector(
    BuildContext context,
    String expenseId,
    Map<String, dynamic> expenseData,
    List<Map<String, dynamic>> friends,
  ) {
    // Navigate directly to expense editor with friend split mode pre-selected
    // This gives users full Splitwise-style options:
    // - You're owed the full amount
    // - Split equally
    // - Exact amounts (unequal)
    // - Percentages
    // - Shares
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          expenseId: expenseId,
          preSelectedSplitType: 'friends', // Pre-select friends mode from swipe
        ),
      ),
    );
  }

  // Group selector bottom sheet
  void _showGroupSelector(
    BuildContext context,
    String expenseId,
    Map<String, dynamic> expenseData,
    List<Map<String, dynamic>> groups,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Split with Group',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.primaryText),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.tealAccent,
                        backgroundImage: group['photo']?.isNotEmpty == true
                            ? NetworkImage(group['photo'])
                            : null,
                        child: group['photo']?.isEmpty != false
                            ? const Icon(Icons.groups, color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        group['name'],
                        style: const TextStyle(color: AppTheme.primaryText),
                      ),
                      subtitle: Text(
                        '${(group['members'] as List).length} members',
                        style: const TextStyle(color: AppTheme.secondaryText),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        // Navigate to expense editor with pre-filled data and selected group
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddExpenseScreen(
                              expenseId: expenseId,
                              preSelectedGroupId: group['groupId'],
                              preSelectedGroupName: group['name'],
                              preSelectedSplitType: 'group', // Pre-select group mode from swipe
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

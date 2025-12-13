import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/screens/expense/expense_detail_screen.dart';
import 'package:spendpal/screens/expense/expense_screen.dart';
import 'package:spendpal/screens/money_tracker/money_tracker_screen.dart';
import 'package:spendpal/screens/personal/auto_import_tab.dart';

class PersonalExpensesScreen extends StatefulWidget {
  const PersonalExpensesScreen({super.key});

  @override
  State<PersonalExpensesScreen> createState() => _PersonalExpensesScreenState();
}

class _PersonalExpensesScreenState extends State<PersonalExpensesScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Expenses'),
        automaticallyImplyLeading: false,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.textTheme.bodyLarge?.color,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Auto-Import'),
            Tab(text: 'Tracker'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Implement filter dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filter feature coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // TODO: Implement export to PDF
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExpensesTab(currentUserId, theme, 'all'),
          const AutoImportTab(), // Pending SMS + Investment SMS + Already imported expenses
          const MoneyTrackerScreen(), // Financial tracker (salary, bank, credit card)
        ],
      ),
    );
  }

  // Build expenses tab for different source types
  Widget _buildExpensesTab(String currentUserId, ThemeData theme, String sourceType) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('expenses')
          .where('paidBy', isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
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

          // Filter expenses based on source type and tab
          var allExpenses = snapshot.data!.docs;
          var filteredExpenses = allExpenses.where((expense) {
            final data = expense.data() as Map<String, dynamic>;
            final groupId = data['groupId'] ?? '';
            final splitWith = List<String>.from(data['splitWith'] ?? []);
            final source = data['source'] ?? 'manual'; // Default to manual if no source field
            final tags = List<String>.from(data['tags'] ?? []);

            // Filter out group and friend expenses for all tabs
            if (groupId.isNotEmpty || splitWith.length > 1) {
              return false;
            }

            // Filter by tab type
            switch (sourceType) {
              case 'all':
                // All personal expenses regardless of source
                return true;
              case 'auto_import':
                // Combine SMS and Statements (auto-imported expenses)
                return source == 'sms' ||
                       source == 'statement' ||
                       source == 'receipt' ||
                       tags.contains('sms') ||
                       tags.contains('SMS') ||
                       tags.contains('statement') ||
                       tags.contains('bank') ||
                       tags.contains('receipt');
              default:
                return false;
            }
          }).toList();

          // Use filteredExpenses instead of personalExpenses
          var personalExpenses = filteredExpenses;

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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.tealAccent.withValues(alpha: 0.2),
                            AppTheme.tealAccent.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.tealAccent.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        size: 80,
                        color: AppTheme.tealAccent,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'No expenses yet',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Track your personal expenses here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.tealAccent,
                            AppTheme.tealAccent.withValues(
                              red: (AppTheme.tealAccent.r * 0.8).clamp(0, 1),
                              green: (AppTheme.tealAccent.g * 0.8).clamp(0, 1),
                              blue: (AppTheme.tealAccent.b * 0.8).clamp(0, 1),
                            ),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.tealAccent.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle_outline, size: 24),
                        label: const Text(
                          'Add First Expense',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pushNamed(context, '/add_expense'),
                      ),
                    ),
                  ],
                ),
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
                          color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
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
                          Divider(color: theme.dividerTheme.color),
                          const SizedBox(height: 8),
                          Text(
                            'Top Categories',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
      );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
    final theme = Theme.of(context);

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
                color: theme.cardTheme.color?.withValues(alpha: 0.5) ?? theme.scaffoldBackgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
                    gradient: LinearGradient(
                      colors: [
                        _getCategoryBackgroundColor(category),
                        _getCategoryBackgroundColor(category).withValues(
                          red: (_getCategoryBackgroundColor(category).r * 0.7).clamp(0, 1),
                          green: (_getCategoryBackgroundColor(category).g * 0.7).clamp(0, 1),
                          blue: (_getCategoryBackgroundColor(category).b * 0.7).clamp(0, 1),
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _getCategoryBackgroundColor(category).withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: Colors.grey[800],
                    size: 26,
                  ),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
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
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
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
      for (var entry in friendsData.entries) {
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
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color,
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
                  Text(
                    'Split with Group',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
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
                        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      ),
                      subtitle: Text(
                        '${(group['members'] as List).length} members',
                        style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
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

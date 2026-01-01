import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/group_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/screens/groups/add_group_members_screen.dart';
import 'package:spendpal/screens/groups/group_settings_screen.dart';
import 'package:spendpal/screens/expense/expense_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/widgets/FloatingButtons.dart';
import '../../services/debt_simplification_service.dart';
import '../../services/group_export_service.dart';
import '../../models/simplified_debt_model.dart';
import '../../widgets/upi_settle_dialog.dart';
import 'group_balances_screen.dart';
import 'group_charts_screen.dart';
import 'group_whiteboard_screen.dart';
import '../expense/expense_screen.dart';

class GroupHomeScreen extends StatelessWidget {
  final GroupModel group;

  const GroupHomeScreen({Key? key, required this.group}) : super(key: key);

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
      default:
        return Icons.receipt;
    }
  }

  // Calculate balance for current user in this group
  Future<Map<String, double>> _calculateBalances(String groupId, String currentUserId, List<String> members) async {
    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('expenses')
        .where('groupId', isEqualTo: groupId)
        .get();

    Map<String, double> balances = {};
    for (var member in members) {
      balances[member] = 0.0;
    }

    for (var expenseDoc in expensesSnapshot.docs) {
      final data = expenseDoc.data();
      final paidBy = data['paidBy'] as String;
      final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});
      final amount = (data['amount'] as num).toDouble();

      // Add the amount paid by the payer
      balances[paidBy] = (balances[paidBy] ?? 0.0) + amount;

      // Subtract each person's share
      splitDetails.forEach((uid, share) {
        balances[uid] = (balances[uid] ?? 0.0) - (share as num).toDouble();
      });
    }

    return balances;
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
      default:
        return AppTheme.defaultCategory;
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
        title: Text(
          group.name,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.download, color: theme.textTheme.bodyLarge?.color),
            tooltip: 'Export',
            onSelected: (value) => _handleExport(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart),
                    SizedBox(width: 8),
                    Text('Export as CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf),
                    SizedBox(width: 8),
                    Text('Export as PDF'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.settings, color: theme.textTheme.bodyLarge?.color),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupSettingsScreen(group: group),
                ),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(group.groupId)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (!groupSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupData = groupSnapshot.data!.data() as Map<String, dynamic>?;
          final members = List<String>.from(groupData?['members'] ?? []);
          final isEmptyGroup = members.length <= 1;

          if (isEmptyGroup) {
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
                      Icons.group_add,
                      size: 64,
                      color: AppTheme.tealAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "No members yet",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Add members to start splitting expenses",
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text("Add Group Members"),
                    style: AppTheme.primaryButtonStyle,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddGroupMembersScreen(groupId: group.groupId),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Balance Summary Section
              FutureBuilder<Map<String, double>>(
                future: _calculateBalances(group.groupId, currentUserId, members),
                builder: (context, balanceSnapshot) {
                  if (!balanceSnapshot.hasData) {
                    return const LinearProgressIndicator();
                  }

                  final balances = balanceSnapshot.data!;
                  final currentUserBalance = balances[currentUserId] ?? 0.0;
                  final isSettledUp = currentUserBalance.abs() < 0.01;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSettledUp
                            ? [
                                AppTheme.tealAccent.withValues(alpha: 0.2),
                                AppTheme.tealAccent.withValues(alpha: 0.1),
                              ]
                            : currentUserBalance > 0
                                ? [
                                    AppTheme.greenAccent.withValues(alpha: 0.2),
                                    AppTheme.greenAccent.withValues(alpha: 0.1),
                                  ]
                                : [
                                    AppTheme.orangeAccent.withValues(alpha: 0.2),
                                    AppTheme.orangeAccent.withValues(alpha: 0.1),
                                  ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerTheme.color ?? Colors.grey,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          group.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _getBalanceMessages(balances, currentUserId),
                          builder: (context, messageSnapshot) {
                            if (!messageSnapshot.hasData) {
                              return const SizedBox.shrink();
                            }

                            final messages = messageSnapshot.data!;
                            if (messages.isEmpty) {
                              return const Text(
                                "You're all settled up!",
                                style: TextStyle(fontSize: 16, color: Colors.green),
                              );
                            }

                            return Column(
                              children: messages.map((msg) {
                                return Text(
                                  msg['text'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: msg['isOwe'] as bool ? Colors.orange.shade700 : Colors.green.shade700,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Action Buttons (Horizontal Scrollable - Splitwise Style)
              Container(
                height: 110,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildActionButton(
                      context: context,
                      icon: Icons.paid,
                      label: 'Settle up',
                      color: AppTheme.warningColor,
                      onTap: () => _showSettleUpDialog(context, group.groupId, group.name),
                    ),
                    _buildActionButton(
                      context: context,
                      icon: Icons.bar_chart,
                      label: 'Charts',
                      color: AppTheme.tealAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupChartsScreen(
                              groupId: group.groupId,
                              groupName: group.name,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildActionButton(
                      context: context,
                      icon: Icons.account_balance_wallet,
                      label: 'Balances',
                      color: AppTheme.tealAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupBalancesScreen(
                              groupId: group.groupId,
                              groupName: group.name,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildActionButton(
                      context: context,
                      icon: Icons.notes,
                      label: 'Whiteboard',
                      color: AppTheme.tealAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupWhiteboardScreen(
                              groupId: group.groupId,
                              groupName: group.name,
                              initialNotes: groupData?['notes'],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Expenses Section with Month Grouping
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('expenses')
                      .where('groupId', isEqualTo: group.groupId)
                      .snapshots(),
                  builder: (context, expenseSnapshot) {
                    if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (expenseSnapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text('Error: ${expenseSnapshot.error}'),
                            const SizedBox(height: 8),
                            const Text('Try creating a Firestore index'),
                          ],
                        ),
                      );
                    }

                    if (!expenseSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var expenses = expenseSnapshot.data!.docs;

                    // Fetch settlements for this group
                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('settlements')
                          .where('groupId', isEqualTo: group.groupId)
                          .get(),
                      builder: (context, settlementSnapshot) {
                        // Combine expenses and settlements
                        List<Map<String, dynamic>> allItems = [];

                        // Add expenses
                        for (var expense in expenses) {
                          final data = expense.data() as Map<String, dynamic>;
                          data['_id'] = expense.id;
                          data['_type'] = 'expense';
                          data['_doc'] = expense;
                          allItems.add(data);
                        }

                        // Add settlements if loaded
                        if (settlementSnapshot.hasData) {
                          for (var settlement in settlementSnapshot.data!.docs) {
                            final data = settlement.data() as Map<String, dynamic>;
                            data['_id'] = settlement.id;
                            data['_type'] = 'settlement';
                            data['_doc'] = settlement;
                            // Use settledAt as createdAt for sorting
                            data['createdAt'] = data['settledAt'];
                            allItems.add(data);
                          }
                        }

                        // Sort by createdAt/settledAt
                        allItems.sort((a, b) {
                          final aTime = a['createdAt'] as Timestamp?;
                          final bTime = b['createdAt'] as Timestamp?;
                          if (aTime == null || bTime == null) return 0;
                          return bTime.compareTo(aTime); // Descending
                        });

                        if (allItems.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text("No expenses added yet", style: TextStyle(fontSize: 18)),
                              ],
                            ),
                          );
                        }

                        // Group items by month
                        Map<String, List<Map<String, dynamic>>> groupedItems = {};
                        for (var item in allItems) {
                          final timestamp = item['createdAt'] as Timestamp?;
                          if (timestamp != null) {
                            final date = timestamp.toDate();
                            final monthKey = DateFormat('MMMM yyyy').format(date);
                            groupedItems.putIfAbsent(monthKey, () => []);
                            groupedItems[monthKey]!.add(item);
                          }
                        }

                        return ListView(
                          children: groupedItems.entries.map((entry) {
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
                                    color: theme.dividerTheme.color ?? Colors.grey,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            // Expenses and Settlements for this month
                            ...entry.value.map((item) {
                              final itemType = item['_type'] as String;
                              final itemId = item['_id'] as String;

                              // Handle settlement items
                              if (itemType == 'settlement') {
                                return _buildSettlementItem(item, currentUserId, theme);
                              }

                              // Handle expense items
                              final title = item['title'] ?? '';
                              final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
                              final paidByUid = item['paidBy'] ?? '';
                              final category = item['category'] ?? 'Other';
                              final splitDetails = Map<String, dynamic>.from(item['splitDetails'] ?? {});
                              final timestamp = item['createdAt'] as Timestamp?;
                              final userShare = splitDetails[currentUserId] as num? ?? 0.0;
                              final date = timestamp?.toDate();

                              return FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(paidByUid)
                                    .get(),
                                builder: (context, userSnapshot) {
                                  String paidByName = 'Unknown';
                                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                    final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                                    paidByName = userData?['name'] ?? 'Unknown';
                                  }

                                  final isPaidByCurrentUser = paidByUid == currentUserId;
                                  final statusText = isPaidByCurrentUser
                                      ? 'you lent'
                                      : 'you borrowed';
                                  final statusColor = isPaidByCurrentUser
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700;

                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ExpenseDetailScreen(
                                            expenseId: itemId,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          // Date Column
                                          if (date != null)
                                            SizedBox(
                                              width: 35,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    DateFormat('MMM').format(date),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat('dd').format(date),
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: theme.textTheme.bodyLarge?.color,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(width: 12),

                                          // Category Icon
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: _getCategoryBackgroundColor(category).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              _getCategoryIcon(category),
                                              color: _getCategoryBackgroundColor(category),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // Details Column
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.textTheme.bodyLarge?.color,
                                                    fontSize: 15,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '$paidByName paid ₹${amount.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // Amount Column
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                statusText,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: statusColor.withValues(alpha: 0.8),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '₹${userShare.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ],
                        );
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingButtons(
        onAddExpense: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(
                preSelectedGroupId: group.groupId,
                preSelectedGroupName: group.name,
              ),
            ),
          );
        },
        onScan: () {
          Navigator.pushNamed(context, '/scan_qr');
        },
      ),
    );
  }

  Widget _buildSettlementItem(Map<String, dynamic> settlement, String currentUserId, ThemeData theme) {
    final fromUserId = settlement['fromUserId'] as String? ?? '';
    final fromUserName = settlement['fromUserName'] as String? ?? 'Unknown';
    final toUserId = settlement['toUserId'] as String? ?? '';
    final toUserName = settlement['toUserName'] as String? ?? 'Unknown';
    final amount = (settlement['amount'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = settlement['paymentMethod'] as String? ?? 'other';
    final timestamp = settlement['settledAt'] as Timestamp?;
    final date = timestamp?.toDate();

    final isPayer = fromUserId == currentUserId;
    final displayText = isPayer
        ? 'You paid $toUserName'
        : '$fromUserName paid you';
    final statusColor = isPayer ? Colors.orange.shade700 : Colors.green.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Date Column
          if (date != null)
            SizedBox(
              width: 35,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM').format(date),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    DateFormat('dd').format(date),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),

          // Payment Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.payment,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      'Payment',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Amount Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isPayer ? 'you paid' : 'received',
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getBalanceMessages(Map<String, double> balances, String currentUserId) async {
    List<Map<String, dynamic>> messages = [];

    for (var entry in balances.entries) {
      final uid = entry.key;
      final balance = entry.value;

      if (uid == currentUserId || balance.abs() < 0.01) continue;

      // Get user name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userName = (userDoc.data()?['name'] ?? 'Unknown') as String;

      final currentUserBalance = balances[currentUserId] ?? 0.0;

      // Calculate who owes whom
      if (currentUserBalance < 0 && balance > 0) {
        // Current user owes this person
        final amount = currentUserBalance.abs().clamp(0.0, balance);
        if (amount > 0.01) {
          messages.add({
            'text': 'You owe $userName ₹${amount.toStringAsFixed(2)}',
            'isOwe': true,
          });
        }
      } else if (currentUserBalance > 0 && balance < 0) {
        // This person owes current user
        final amount = currentUserBalance.clamp(0.0, balance.abs());
        if (amount > 0.01) {
          messages.add({
            'text': '$userName owes you ₹${amount.toStringAsFixed(2)}',
            'isOwe': false,
          });
        }
      }
    }

    return messages;
  }

  // Export Handler Method
  Future<void> _handleExport(BuildContext context, String exportType) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final exportService = GroupExportService();
      String filePath;

      if (exportType == 'csv') {
        filePath = await exportService.exportToCSV(
          groupId: group.groupId,
          groupName: group.name,
        );
      } else if (exportType == 'pdf') {
        filePath = await exportService.exportToPDF(
          groupId: group.groupId,
          groupName: group.name,
        );
      } else {
        throw Exception('Unknown export type');
      }

      // Close loading indicator
      if (context.mounted) Navigator.pop(context);

      // Share the file
      final fileName = filePath.split('/').last;
      await exportService.shareFile(filePath, fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported successfully as ${exportType.toUpperCase()}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading indicator
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Build Action Button (Splitwise Style)
  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 95,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Settle Up Dialog Method
  Future<void> _showSettleUpDialog(BuildContext context, String groupId, String groupName) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // DEBUG: Check if there are any expenses in this group
      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('groupId', isEqualTo: groupId)
          .get();

      print('DEBUG: Found ${expensesSnapshot.docs.length} expenses in group $groupId');
      for (var doc in expensesSnapshot.docs) {
        final data = doc.data();
        print('  Expense: ${data['title']}, Amount: ${data['amount']}, PaidBy: ${data['paidBy']}, SharedWith: ${data['sharedWith']}');
      }

      // Fetch group-specific simplified debts
      final allDebts = await DebtSimplificationService().simplifyGroupDebts(groupId);

      print('DEBUG: Simplified debts count: ${allDebts.length}');
      for (var debt in allDebts) {
        print('  Debt: ${debt.fromUserId} owes ${debt.toUserId} ₹${debt.amount}');
      }

      // Enrich debts with user names
      final enrichedDebts = await DebtSimplificationService().enrichWithUserNames(allDebts);

      // Filter debts involving current user
      final userDebts = enrichedDebts.where((debt) =>
        debt.fromUserId == currentUserId || debt.toUserId == currentUserId
      ).toList();

      print('DEBUG: User debts for $currentUserId: ${userDebts.length}');

      // Close loading indicator
      if (context.mounted) Navigator.pop(context);

      if (userDebts.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have no pending debts in this group!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // Show bottom sheet with debt selection
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => _SettleUpSheet(
            debts: userDebts,
            groupName: groupName,
          ),
        );
      }
    } catch (e) {
      // Close loading indicator
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading debts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Bottom sheet for selecting which debt to settle
class _SettleUpSheet extends StatelessWidget {
  final List<SimplifiedDebt> debts;
  final String groupName;

  const _SettleUpSheet({required this.debts, required this.groupName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settle Up - $groupName',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a debt to settle:',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ...debts.map((debt) => _buildDebtTile(context, debt)),
        ],
      ),
    );
  }

  Widget _buildDebtTile(BuildContext context, SimplifiedDebt debt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.account_balance_wallet, color: Colors.teal),
        title: Text('${debt.fromUserName} → ${debt.toUserName}'),
        subtitle: Text('₹${debt.amount.toStringAsFixed(2)}'),
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Close sheet
            _openUpiSettlement(context, debt);
          },
          style: AppTheme.primaryButtonStyle,
          child: const Text('Settle'),
        ),
      ),
    );
  }

  void _openUpiSettlement(BuildContext context, SimplifiedDebt debt) {
    showDialog(
      context: context,
      builder: (context) => UpiSettleDialog(
        debt: debt,
        onSettled: () {
          // Refresh parent screen
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

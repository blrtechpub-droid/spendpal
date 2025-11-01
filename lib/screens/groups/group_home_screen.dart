import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/group_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/screens/groups/add_group_members_screen.dart';
import 'package:spendpal/screens/expense/expense_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/widgets/FloatingButtons.dart';

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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          group.name,
          style: const TextStyle(color: AppTheme.primaryText),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.primaryText),
            onPressed: () {
              // TODO: Group settings
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
                  const Text(
                    "No members yet",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Add members to start splitting expenses",
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.secondaryText,
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
                    padding: const EdgeInsets.all(20),
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
                          color: AppTheme.dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Group icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.tealAccent,
                                AppTheme.tealAccent.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.tealAccent.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.groups, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryText,
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
              // Action Buttons (Settle up, Charts, Balances)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: AppTheme.warningButtonStyle,
                        onPressed: () {
                          // TODO: Implement settle up
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settle up feature coming soon!')),
                          );
                        },
                        child: const Text('Settle up'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.bar_chart),
                        label: const Text('Charts'),
                        onPressed: () {
                          // TODO: Implement charts
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Charts feature coming soon!')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO: Implement balances view
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Balances feature coming soon!')),
                          );
                        },
                        child: const Text('Balances'),
                      ),
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

                    // Sort manually by createdAt
                    expenses.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime = aData['createdAt'] as Timestamp?;
                      final bTime = bData['createdAt'] as Timestamp?;
                      if (aTime == null || bTime == null) return 0;
                      return bTime.compareTo(aTime); // Descending
                    });

                    if (expenses.isEmpty) {
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
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            // Expenses for this month
                            ...entry.value.map((expenseDoc) {
                              final data = expenseDoc.data() as Map<String, dynamic>;
                              final title = data['title'] ?? '';
                              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                              final paidByUid = data['paidBy'] ?? '';
                              final category = data['category'] ?? 'Other';
                              final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});
                              final timestamp = data['createdAt'] as Timestamp?;
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
                                      ? 'you borrowed'
                                      : 'you lent';
                                  final statusColor = isPaidByCurrentUser
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700;

                                  return ListTile(
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
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (date != null)
                                          Text(
                                            '${DateFormat('MMM dd').format(date)} • $paidByName paid ₹${amount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.secondaryText,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        if (splitDetails.length > 1)
                                          Text(
                                            '${splitDetails.length} people paid ₹${amount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.secondaryText,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          statusText,
                                          style: TextStyle(fontSize: 12, color: statusColor),
                                        ),
                                        Text(
                                          '₹${userShare.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
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
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingButtons(
        onAddExpense: () {
          Navigator.pushNamed(context, '/add_expense');
        },
        onScan: () {
          Navigator.pushNamed(context, '/scan_qr');
        },
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
}

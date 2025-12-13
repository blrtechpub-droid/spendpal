import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/screens/expense/expense_detail_screen.dart';
import 'package:spendpal/screens/expense/expense_screen.dart';
import 'package:spendpal/theme/app_theme.dart';

class FriendHomeScreen extends StatelessWidget {
  final String friendId;
  final String friendName;

  const FriendHomeScreen({
    Key? key,
    required this.friendId,
    required this.friendName,
  }) : super(key: key);

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

  // Calculate balance between current user and friend
  Future<double> _calculateBalance(String currentUserId) async {
    double balance = 0.0;

    // Get all expenses where both users are involved
    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('expenses')
        .where('splitWith', arrayContains: currentUserId)
        .get();

    for (var expenseDoc in expensesSnapshot.docs) {
      final data = expenseDoc.data();
      final paidBy = data['paidBy'] as String;
      final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});
      final splitWith = List<String>.from(data['splitWith'] ?? []);

      // Only consider expenses involving both users
      if (!splitWith.contains(friendId)) continue;

      if (paidBy == currentUserId && splitDetails.containsKey(friendId)) {
        // Current user paid, friend owes their share
        balance += (splitDetails[friendId] as num).toDouble();
      } else if (paidBy == friendId && splitDetails.containsKey(currentUserId)) {
        // Friend paid, current user owes their share
        balance -= (splitDetails[currentUserId] as num).toDouble();
      }
    }

    return balance;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(friendName, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              // TODO: Friend settings
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance Summary Section
          FutureBuilder<double>(
            future: _calculateBalance(currentUserId),
            builder: (context, balanceSnapshot) {
              if (!balanceSnapshot.hasData) {
                return const LinearProgressIndicator();
              }

              final balance = balanceSnapshot.data!;
              final isSettled = balance.abs() < 0.01;
              final owesYou = balance > 0;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSettled
                      ? Colors.grey.shade900
                      : owesYou
                          ? Colors.green.shade900.withOpacity(0.3)
                          : Colors.orange.shade900.withOpacity(0.3),
                ),
                child: Column(
                  children: [
                    // Friend Avatar
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(friendId)
                          .get(),
                      builder: (context, userSnapshot) {
                        String photoURL = '';
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                          photoURL = userData?['photoURL'] ?? '';
                        }

                        return CircleAvatar(
                          radius: AppTheme.avatarRadiusLarge,
                          backgroundColor: AppTheme.orangeAccent,
                          backgroundImage: photoURL.isNotEmpty
                              ? NetworkImage(photoURL)
                              : null,
                          child: photoURL.isEmpty
                              ? Text(
                                  friendName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      friendName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isSettled)
                      const Text(
                        "You're settled up!",
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      )
                    else
                      Column(
                        children: [
                          Text(
                            owesYou ? '$friendName owes you' : 'You owe $friendName',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${balance.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: owesYou ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          // Action Buttons
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
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textTheme.bodyLarge?.color,
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddExpenseScreen(),
                        ),
                      );
                    },
                    child: const Text('Add expense'),
                  ),
                ),
              ],
            ),
          ),
          // Expenses List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('expenses')
                  .where('splitWith', arrayContains: currentUserId)
                  .snapshots(),
              builder: (context, expenseSnapshot) {
                if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (expenseSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${expenseSnapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                if (!expenseSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter expenses to only show those involving this friend
                var allExpenses = expenseSnapshot.data!.docs;
                var expenses = allExpenses.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final splitWith = List<String>.from(data['splitWith'] ?? []);
                  return splitWith.contains(friendId);
                }).toList();

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
                        Text(
                          "No expenses with this friend yet",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.grey[900],
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
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
                              final isPaidByFriend = paidByUid == friendId;

                              String statusText;
                              Color statusColor;

                              if (isPaidByCurrentUser) {
                                final friendShare = splitDetails[friendId] as num? ?? 0.0;
                                statusText = '$friendName owes';
                                statusColor = Colors.green.shade700;
                              } else if (isPaidByFriend) {
                                statusText = 'you owe';
                                statusColor = Colors.orange.shade700;
                              } else {
                                statusText = 'split';
                                statusColor = Colors.grey;
                              }

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
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(category),
                                    color: Colors.white70,
                                  ),
                                ),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
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
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
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
                        }),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

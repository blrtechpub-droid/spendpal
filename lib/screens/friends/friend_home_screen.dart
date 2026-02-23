import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/screens/expense/expense_detail_screen.dart';
import 'package:spendpal/screens/expense/expense_screen.dart';
import 'package:spendpal/screens/groups/group_home_screen.dart';
import 'package:spendpal/models/group_model.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/services/debt_simplification_service.dart';
import 'package:spendpal/models/simplified_debt_model.dart';
import 'package:spendpal/widgets/upi_settle_dialog.dart';
import 'package:spendpal/screens/friends/friend_charts_screen.dart';
import 'package:spendpal/screens/friends/friend_whiteboard_screen.dart';
import 'package:spendpal/services/group_export_service.dart';
import 'package:spendpal/utils/currency_utils.dart';

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

  // Build a group aggregate item
  Widget _buildGroupItem(
    BuildContext context,
    Map<String, dynamic> groupData,
    String currentUserId,
    String friendName,
  ) {
    final groupId = groupData['groupId'] as String;
    final totalOwed = groupData['totalOwed'] as double;
    final expenseCount = groupData['expenseCount'] as int;
    final lastDate = (groupData['lastDate'] as Timestamp?)?.toDate();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('groups').doc(groupId).get(),
      builder: (context, snapshot) {
        String groupName = 'Unknown Group';
        if (snapshot.hasData && snapshot.data!.exists) {
          final group = GroupModel.fromDocument(snapshot.data!);
          groupName = group.name;
        }

        final isSettled = totalOwed.abs() < 0.01;
        final friendOwes = totalOwed > 0;

        String statusText;
        Color statusColor;

        if (isSettled) {
          statusText = 'settled';
          statusColor = Colors.grey;
        } else if (friendOwes) {
          statusText = '$friendName owes';
          statusColor = Colors.green.shade700;
        } else {
          statusText = 'you owe';
          statusColor = Colors.orange.shade700;
        }

        return InkWell(
          onTap: () {
            if (snapshot.hasData && snapshot.data!.exists) {
              final group = GroupModel.fromDocument(snapshot.data!);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupHomeScreen(group: group),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Date Column
                if (lastDate != null)
                  SizedBox(
                    width: 35,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMM').format(lastDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          DateFormat('dd').format(lastDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 12),

                // Group Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[800]?.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.group,
                    color: Colors.grey[400],
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
                        groupName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$expenseCount expense${expenseCount > 1 ? "s" : ""}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
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
                    if (!isSettled)
                      CurrencyText(
                        totalOwed.abs(),
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
  }

  // Build settlement item widget
  Widget _buildSettlementItem(
    BuildContext context,
    Map<String, dynamic> settlement,
    String currentUserId,
    String friendId,
  ) {
    final settlementId = settlement['_id'] as String? ?? '';
    final fromUserId = settlement['fromUserId'] as String? ?? '';
    final fromUserName = settlement['fromUserName'] as String? ?? 'Unknown';
    final toUserName = settlement['toUserName'] as String? ?? 'Unknown';
    final amount = (settlement['amount'] as num?)?.toDouble() ?? 0.0;
    final timestamp = settlement['settledAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final isVerified = settlement['isVerified'] as bool? ?? false;

    final isPayer = fromUserId == currentUserId;
    final displayText = isPayer ? 'You paid $toUserName' : '$fromUserName paid you';
    final statusText = isPayer ? 'you paid' : 'received';
    final statusColor = isPayer ? Colors.orange.shade700 : Colors.green.shade700;

    // Can delete if: not verified AND current user is the payer
    final canDelete = !isVerified && isPayer;

    return Dismissible(
      key: Key(settlementId),
      direction: canDelete ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Settlement?'),
              content: Text('Delete payment of ${context.formatCurrency(amount)} to $toUserName?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) async {
        try {
          await FirebaseFirestore.instance
              .collection('settlements')
              .doc(settlementId)
              .delete();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Settlement of ${context.formatCurrency(amount)} deleted'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting settlement: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
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
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    DateFormat('dd').format(date),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),

          // Payment Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.payment,
              color: Colors.teal,
              size: 24,
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
                    Icon(
                      isVerified ? Icons.check_circle : Icons.schedule,
                      color: isVerified ? Colors.green : Colors.orange,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVerified ? 'Payment' : 'Payment (Pending)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
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
              CurrencyText(
                amount,
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
  }

  // Build action button widget
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

    // Account for settlements (both verified and unverified)
    try {
      // Query settlements where current user is involved
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('settlements')
            .where('fromUserId', isEqualTo: currentUserId)
            .get(),
        FirebaseFirestore.instance
            .collection('settlements')
            .where('toUserId', isEqualTo: currentUserId)
            .get(),
      ]);

      final allSettlements = [...results[0].docs, ...results[1].docs];

      for (var settlementDoc in allSettlements) {
        final data = settlementDoc.data();
        final fromUserId = data['fromUserId'] as String?;
        final toUserId = data['toUserId'] as String?;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

        // Check if settlement involves both users
        if (fromUserId == currentUserId && toUserId == friendId) {
          // Current user paid friend - reduces what friend owes (or increases what you owe)
          balance -= amount;
        } else if (fromUserId == friendId && toUserId == currentUserId) {
          // Friend paid current user - reduces what you owe (or increases what friend owes)
          balance += amount;
        }
      }
    } catch (e) {
      print('Error loading settlements: $e');
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isSettled
                      ? Colors.grey.shade900
                      : owesYou
                          ? Colors.green.shade900.withOpacity(0.3)
                          : Colors.orange.shade900.withOpacity(0.3),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade800,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
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
                          CurrencyText(
                            balance.abs(),
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
          // Action Buttons (Horizontal Scrollable)
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
                  onTap: () => _showSettleUpDialog(context, friendId, friendName),
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
                        builder: (_) => FriendChartsScreen(
                          friendId: friendId,
                          friendName: friendName,
                        ),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context: context,
                  icon: Icons.file_download,
                  label: 'Export',
                  color: AppTheme.tealAccent,
                  onTap: () => _showExportDialog(context, friendId, friendName),
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
                        builder: (_) => FriendWhiteboardScreen(
                          friendId: friendId,
                          friendName: friendName,
                        ),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context: context,
                  icon: Icons.add_circle_outline,
                  label: 'Add expense',
                  color: AppTheme.tealAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddExpenseScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Expenses List (now includes settlements)
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

                // Fetch settlements involving this friend (both verified and unverified)
                // Query settlements where current user is sender OR receiver
                return FutureBuilder<List<QueryDocumentSnapshot>>(
                  future: Future.wait([
                    // Settlements where current user is sender
                    FirebaseFirestore.instance
                        .collection('settlements')
                        .where('fromUserId', isEqualTo: currentUserId)
                        .get(),
                    // Settlements where current user is receiver
                    FirebaseFirestore.instance
                        .collection('settlements')
                        .where('toUserId', isEqualTo: currentUserId)
                        .get(),
                  ]).then((results) {
                    // Combine both query results
                    return [...results[0].docs, ...results[1].docs];
                  }),
                  builder: (context, settlementSnapshot) {
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

                    // Filter settlements to only those involving this friend
                    List<QueryDocumentSnapshot> settlements = [];
                    if (settlementSnapshot.hasData) {
                      final allSettlements = settlementSnapshot.data!;
                      print('DEBUG: Total settlements for current user: ${allSettlements.length}');
                      print('DEBUG: Current user ID: $currentUserId');
                      print('DEBUG: Friend ID: $friendId');

                      settlements = allSettlements.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final fromUserId = data['fromUserId'] as String?;
                        final toUserId = data['toUserId'] as String?;

                        print('DEBUG: Settlement - from: $fromUserId, to: $toUserId');

                        // Only include settlements between current user and this friend
                        final matches = (fromUserId == currentUserId && toUserId == friendId) ||
                               (fromUserId == friendId && toUserId == currentUserId);

                        if (matches) {
                          print('DEBUG: ✓ Settlement matches!');
                        }

                        return matches;
                      }).toList();

                      print('DEBUG: Filtered settlements for this friend: ${settlements.length}');
                    }

                    if (expenses.isEmpty && settlements.isEmpty) {
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

                    // Separate group expenses from individual expenses
                    // For groups: aggregate by groupId
                    Map<String, Map<String, dynamic>> groupAggregates = {};
                    List<QueryDocumentSnapshot> individualExpenses = [];

                for (var expense in expenses) {
                  final data = expense.data() as Map<String, dynamic>;
                  final groupId = data['groupId'] as String?;
                  final timestamp = data['createdAt'] as Timestamp?;
                  final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});
                  final paidByUid = data['paidBy'] ?? '';

                  if (groupId != null && groupId.isNotEmpty) {
                    // Group expense - aggregate
                    if (!groupAggregates.containsKey(groupId)) {
                      groupAggregates[groupId] = {
                        'groupId': groupId,
                        'totalOwed': 0.0,
                        'expenseCount': 0,
                        'lastDate': timestamp,
                      };
                    }

                    // Calculate how much is owed in this expense
                    double expenseOwed = 0.0;
                    if (paidByUid == currentUserId && splitDetails.containsKey(friendId)) {
                      // Current user paid, friend owes their share
                      expenseOwed = (splitDetails[friendId] as num).toDouble();
                    } else if (paidByUid == friendId && splitDetails.containsKey(currentUserId)) {
                      // Friend paid, current user owes their share (negative)
                      expenseOwed = -(splitDetails[currentUserId] as num).toDouble();
                    }

                    groupAggregates[groupId]!['totalOwed'] =
                        (groupAggregates[groupId]!['totalOwed'] as double) + expenseOwed;
                    groupAggregates[groupId]!['expenseCount'] =
                        (groupAggregates[groupId]!['expenseCount'] as int) + 1;

                    // Keep the latest date
                    if (timestamp != null) {
                      final currentLatest = groupAggregates[groupId]!['lastDate'] as Timestamp?;
                      if (currentLatest == null || timestamp.compareTo(currentLatest) > 0) {
                        groupAggregates[groupId]!['lastDate'] = timestamp;
                      }
                    }
                  } else {
                    // Individual expense - keep as-is
                    individualExpenses.add(expense);
                  }
                }

                    // Create a combined list: groups, individual expenses, and settlements
                    List<Map<String, dynamic>> displayItems = [];

                    // Add group items
                    for (var groupData in groupAggregates.values) {
                      displayItems.add({
                        'type': 'group',
                        'data': groupData,
                      });
                    }

                    // Add individual expense items
                    for (var expense in individualExpenses) {
                      displayItems.add({
                        'type': 'individual',
                        'data': expense,
                      });
                    }

                    // Add settlement items
                    for (var settlement in settlements) {
                      final settlementData = settlement.data() as Map<String, dynamic>;
                      settlementData['_id'] = settlement.id; // Add document ID
                      displayItems.add({
                        'type': 'settlement',
                        'data': settlementData,
                      });
                    }

                    // Sort by date (newest first)
                    displayItems.sort((a, b) {
                      Timestamp? aTime;
                      Timestamp? bTime;

                      if (a['type'] == 'group') {
                        aTime = a['data']['lastDate'] as Timestamp?;
                      } else if (a['type'] == 'settlement') {
                        final settlementData = a['data'] as Map<String, dynamic>;
                        aTime = settlementData['settledAt'] as Timestamp?;
                      } else {
                        final expenseData = (a['data'] as QueryDocumentSnapshot).data() as Map<String, dynamic>;
                        aTime = expenseData['createdAt'] as Timestamp?;
                      }

                      if (b['type'] == 'group') {
                        bTime = b['data']['lastDate'] as Timestamp?;
                      } else if (b['type'] == 'settlement') {
                        final settlementData = b['data'] as Map<String, dynamic>;
                        bTime = settlementData['settledAt'] as Timestamp?;
                      } else {
                        final expenseData = (b['data'] as QueryDocumentSnapshot).data() as Map<String, dynamic>;
                        bTime = expenseData['createdAt'] as Timestamp?;
                      }

                      if (aTime == null || bTime == null) return 0;
                      return bTime.compareTo(aTime); // Descending
                    });

                    // Group items by month for display
                    Map<String, List<Map<String, dynamic>>> groupedByMonth = {};
                    for (var item in displayItems) {
                      Timestamp? timestamp;

                      if (item['type'] == 'group') {
                        timestamp = item['data']['lastDate'] as Timestamp?;
                      } else if (item['type'] == 'settlement') {
                        final settlementData = item['data'] as Map<String, dynamic>;
                        timestamp = settlementData['settledAt'] as Timestamp?;
                      } else {
                        final expenseData = (item['data'] as QueryDocumentSnapshot).data() as Map<String, dynamic>;
                        timestamp = expenseData['createdAt'] as Timestamp?;
                      }

                      if (timestamp != null) {
                        final date = timestamp.toDate();
                        final monthKey = DateFormat('MMMM yyyy').format(date);
                        groupedByMonth.putIfAbsent(monthKey, () => []);
                        groupedByMonth[monthKey]!.add(item);
                      }
                    }

                    return ListView(
                      children: groupedByMonth.entries.map((entry) {
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
                            // Items for this month (groups, individual expenses, and settlements)
                            ...entry.value.map((item) {
                              if (item['type'] == 'group') {
                                // Render group aggregate
                                return _buildGroupItem(
                                  context,
                                  item['data'] as Map<String, dynamic>,
                                  currentUserId,
                                  friendName,
                                );
                              } else if (item['type'] == 'settlement') {
                                // Render settlement
                                final settlementData = item['data'] as Map<String, dynamic>;
                                return _buildSettlementItem(
                                  context,
                                  settlementData,
                                  currentUserId,
                                  friendId,
                                );
                              } else {
                                // Render individual expense
                                final expenseDoc = item['data'] as QueryDocumentSnapshot;
                          final data = expenseDoc.data() as Map<String, dynamic>;
                          final title = data['title'] ?? '';
                          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                          final paidByUid = data['paidBy'] ?? '';
                          final category = data['category'] ?? 'Other';
                          final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});
                          final timestamp = data['createdAt'] as Timestamp?;
                          final userShare = (splitDetails[currentUserId] as num?)?.toDouble() ?? 0.0;
                          final date = timestamp?.toDate();
                          final groupId = data['groupId'] as String?;

                          // Fetch both user and group data if groupId exists
                          Future<Map<String, dynamic>> fetchData() async {
                            final Map<String, dynamic> result = {};

                            // Fetch payer name
                            final userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(paidByUid)
                                .get();
                            if (userDoc.exists) {
                              final userData = userDoc.data() as Map<String, dynamic>?;
                              result['paidByName'] = userData?['name'] ?? 'Unknown';
                            } else {
                              result['paidByName'] = 'Unknown';
                            }

                            // Fetch group data if groupId exists
                            if (groupId != null && groupId.isNotEmpty) {
                              final groupDoc = await FirebaseFirestore.instance
                                  .collection('groups')
                                  .doc(groupId)
                                  .get();
                              if (groupDoc.exists) {
                                result['group'] = GroupModel.fromDocument(groupDoc);
                              }
                            }

                            return result;
                          }

                          return FutureBuilder<Map<String, dynamic>>(
                            future: fetchData(),
                            builder: (context, snapshot) {
                              String paidByName = 'Unknown';
                              GroupModel? group;

                              if (snapshot.hasData) {
                                paidByName = snapshot.data!['paidByName'] ?? 'Unknown';
                                group = snapshot.data!['group'] as GroupModel?;
                              }

                              final isPaidByCurrentUser = paidByUid == currentUserId;
                              final isPaidByFriend = paidByUid == friendId;

                              String statusText;
                              Color statusColor;

                              if (isPaidByCurrentUser) {
                                statusText = 'you lent';
                                statusColor = Colors.green.shade700;
                              } else if (isPaidByFriend) {
                                statusText = 'you borrowed';
                                statusColor = Colors.orange.shade700;
                              } else {
                                statusText = 'split';
                                statusColor = Colors.grey;
                              }

                              return InkWell(
                                onTap: () {
                                  if (group != null) {
                                    // Navigate to group screen if expense is from a group
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => GroupHomeScreen(group: group!),
                                      ),
                                    );
                                  } else {
                                    // Navigate to expense detail for non-group expenses
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ExpenseDetailScreen(
                                          expenseId: expenseDoc.id,
                                        ),
                                      ),
                                    );
                                  }
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
                                                  color: Colors.grey[500],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('dd').format(date),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
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
                                          color: Colors.grey[800]?.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(category),
                                          color: Colors.grey[400],
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
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              group != null
                                                  ? group.name
                                                  : '$paidByName paid ${context.formatCurrency(amount)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[500],
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
                                          CurrencyText(
                                            userShare,
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
                          }
                            }),
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
      ),
    );
  }

  // Settle Up Dialog Method
  Future<void> _showSettleUpDialog(BuildContext context, String friendId, String friendName) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch all friend debts using debt simplification service
      final allDebts = await DebtSimplificationService().simplifyFriendDebts();

      // Filter debts for this specific friend only
      final friendDebts = allDebts.where((debt) =>
        (debt.fromUserId == currentUserId && debt.toUserId == friendId) ||
        (debt.fromUserId == friendId && debt.toUserId == currentUserId)
      ).toList();

      // Enrich debts with user names
      final enrichedDebts = await DebtSimplificationService().enrichWithUserNames(friendDebts);

      // Close loading indicator
      if (context.mounted) Navigator.pop(context);

      if (enrichedDebts.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have no pending debts with this friend!'),
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
            debts: enrichedDebts,
            friendName: friendName,
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

  // Export Dialog Method
  Future<void> _showExportDialog(BuildContext context, String friendId, String friendName) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Expenses'),
        content: const Text('Choose export format:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleExport(context, 'csv', currentUserId, friendId, friendName);
            },
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleExport(context, 'pdf', currentUserId, friendId, friendName);
            },
            child: const Text('PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Handle Export Method
  Future<void> _handleExport(
    BuildContext context,
    String exportType,
    String currentUserId,
    String friendId,
    String friendName,
  ) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final exportService = GroupExportService();
      String filePath;
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final fileName = '${friendName}_expenses_$dateStr.${exportType}';

      if (exportType == 'csv') {
        filePath = await exportService.exportFriendExpensesToCSV(
          currentUserId: currentUserId,
          friendId: friendId,
          friendName: friendName,
        );
      } else {
        filePath = await exportService.exportFriendExpensesToPDF(
          currentUserId: currentUserId,
          friendId: friendId,
          friendName: friendName,
        );
      }

      // Close loading indicator
      if (context.mounted) Navigator.pop(context);

      // Share the file
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
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Settle Up Bottom Sheet Widget
class _SettleUpSheet extends StatelessWidget {
  final List<SimplifiedDebt> debts;
  final String friendName;

  const _SettleUpSheet({
    required this.debts,
    required this.friendName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settle up with $friendName',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...debts.map((debt) {
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final isOwing = debt.fromUserId == currentUserId;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  isOwing ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isOwing ? Colors.orange : Colors.green,
                ),
                title: Text(
                  isOwing
                      ? 'You owe ${debt.toUserName}'
                      : '${debt.fromUserName} owes you',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: CurrencyText(
                  debt.amount,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isOwing ? Colors.orange : Colors.green,
                  ),
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => UpiSettleDialog(
                        debt: debt,
                        onSettled: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment initiated!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('Settle'),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

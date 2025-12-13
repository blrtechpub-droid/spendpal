import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/screens/expense/expense_detail_screen.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/widgets/empty_state_widget.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({Key? key}) : super(key: key);

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

  Color _getCategoryBackgroundColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return AppTheme.foodCategory.withValues(alpha: 0.2);
      case 'travel':
        return AppTheme.travelCategory.withValues(alpha: 0.2);
      case 'shopping':
        return AppTheme.shoppingCategory.withValues(alpha: 0.2);
      case 'maid':
        return AppTheme.maidCategory.withValues(alpha: 0.2);
      case 'cook':
        return AppTheme.cookCategory.withValues(alpha: 0.2);
      default:
        return AppTheme.defaultCategory.withValues(alpha: 0.2);
    }
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      }
      return 'Today, ${DateFormat('h:mm a').format(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago, ${DateFormat('h:mm a').format(dateTime)}';
    } else {
      return DateFormat('MMM dd, h:mm a').format(dateTime);
    }
  }

  Future<Map<String, String>> _getUserNames(List<String> userIds) async {
    Map<String, String> names = {};
    for (String userId in userIds) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        names[userId] = userData?['name'] ?? 'Unknown';
      }
    }
    return names;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Recent Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('expenses')
            .where('splitWith', arrayContains: currentUserId)
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
                  Icon(Icons.error, color: theme.colorScheme.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading activities',
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.receipt_long,
              title: 'No activity yet',
              subtitle: 'Start adding expenses to see activity',
            );
          }

          var expenses = snapshot.data!.docs;

          // Sort manually by createdAt in descending order
          expenses.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // Most recent first
          });

          // Limit to 50 items
          if (expenses.length > 50) {
            expenses = expenses.sublist(0, 50);
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expenseDoc = expenses[index];
              final data = expenseDoc.data() as Map<String, dynamic>;

              final title = data['title'] ?? 'Untitled';
              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final category = data['category'] ?? 'Other';
              final paidBy = data['paidBy'] ?? '';
              final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});
              final groupId = data['groupId'] is String && (data['groupId'] as String).isNotEmpty
                  ? data['groupId'] as String
                  : null;
              final createdAt = data['createdAt'] as Timestamp?;
              final updatedAt = data['updatedAt'] as Timestamp?;

              final currentUserShare = (splitDetails[currentUserId] as num?)?.toDouble() ?? 0.0;
              final isPaidByCurrentUser = paidBy == currentUserId;

              // Determine if it's "you get back" or "you owe"
              final isGetBack = isPaidByCurrentUser && currentUserShare < amount;
              final getBackAmount = isPaidByCurrentUser ? (amount - currentUserShare) : 0.0;

              final timestamp = updatedAt ?? createdAt;
              final dateTime = timestamp?.toDate() ?? DateTime.now();
              final relativeTime = _getRelativeTime(dateTime);

              return FutureBuilder<Map<String, dynamic>>(
                future: Future.wait([
                  if (paidBy.isNotEmpty)
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(paidBy)
                        .get()
                  else
                    Future.value(null),
                  if (groupId != null)
                    FirebaseFirestore.instance
                        .collection('groups')
                        .doc(groupId)
                        .get()
                  else
                    Future.value(null),
                ]).then((results) {
                  final userDoc = results[0] as DocumentSnapshot?;
                  final groupDoc = results[1] as DocumentSnapshot?;

                  String paidByName = 'Unknown';
                  if (userDoc != null && userDoc.exists) {
                    final userData = userDoc.data() as Map<String, dynamic>?;
                    paidByName = userData?['name'] ?? 'Unknown';
                  }

                  String groupName = '';
                  if (groupDoc != null && groupDoc.exists) {
                    final groupData = groupDoc.data() as Map<String, dynamic>?;
                    groupName = groupData?['name'] ?? '';
                  }

                  return {
                    'paidByName': paidByName,
                    'groupName': groupName,
                  };
                }),
                builder: (context, futureSnapshot) {
                  final paidByName = futureSnapshot.data?['paidByName'] ?? 'Unknown';
                  final groupName = futureSnapshot.data?['groupName'] ?? '';

                  // Build activity text
                  String activityText;
                  String activitySubtext;
                  bool wasUpdated = updatedAt != null;

                  if (isPaidByCurrentUser) {
                    activityText = 'You ${wasUpdated ? 'updated' : 'added'} "$title"';
                  } else {
                    activityText = '$paidByName ${wasUpdated ? 'updated' : 'added'} "$title"';
                  }

                  if (groupName.isNotEmpty) {
                    activitySubtext = 'in "$groupName"';
                  } else {
                    // Get friend name
                    final friendIds = splitDetails.keys.where((id) => id != currentUserId).toList();
                    if (friendIds.isNotEmpty) {
                      activitySubtext = 'with ${isPaidByCurrentUser ? '' : paidByName}';
                    } else {
                      activitySubtext = '';
                    }
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
                      vertical: 12,
                    ),
                    leading: Stack(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getCategoryBackgroundColor(category).withValues(alpha: 0.8),
                                _getCategoryBackgroundColor(category).withValues(alpha: 0.4),
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
                            color: theme.textTheme.bodyLarge?.color,
                            size: 28,
                          ),
                        ),
                        // Indicator for owe/get back
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isGetBack ? Colors.green : Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 15,
                        ),
                        children: [
                          TextSpan(text: activityText),
                          if (activitySubtext.isNotEmpty) ...[
                            TextSpan(
                              text: ' ',
                              style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                            ),
                            TextSpan(
                              text: activitySubtext,
                              style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                            ),
                          ],
                          const TextSpan(text: '.'),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        if (isGetBack)
                          Text(
                            'You get back ₹${getBackAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          )
                        else if (!isPaidByCurrentUser)
                          Text(
                            'You owe ₹${currentUserShare.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                            ),
                          )
                        else
                          Text(
                            'You paid ₹${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          relativeTime,
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

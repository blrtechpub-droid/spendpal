import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/screens/expense/expense_screen.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final String expenseId;

  const ExpenseDetailScreen({Key? key, required this.expenseId}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add receipt photo')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Expense'),
                  content: const Text('Are you sure you want to delete this expense?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await FirebaseFirestore.instance
                    .collection('expenses')
                    .doc(expenseId)
                    .delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Expense deleted')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddExpenseScreen(expenseId: expenseId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('expenses')
            .doc(expenseId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Expense not found',
                style: TextStyle(color: Colors.white),
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
                          color: _getCategoryColor(category).withOpacity(0.2),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Amount
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
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
                              color: Colors.grey[400],
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
                    color: Colors.grey[900],
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
                                  color: Colors.teal.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.teal,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$displayName paid ₹${amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
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
                      const Divider(color: Colors.grey),
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
                                      style: const TextStyle(
                                        color: Colors.white,
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
                                        '₹${shareAmount.toStringAsFixed(2)}',
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
                      }).toList(),
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
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notes,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Spending trends placeholder
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Spending trends',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.bar_chart, color: Colors.purple),
                          label: const Text(
                            'View more charts',
                            style: TextStyle(color: Colors.purple),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Charts feature coming soon')),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 100), // Space for comment input
              ],
            ),
          );
        },
      ),
      bottomSheet: Container(
        color: Colors.grey[900],
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add a comment',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Comments feature coming soon')),
                    );
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.grey),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comments feature coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

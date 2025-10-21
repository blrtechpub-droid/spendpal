import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/models/bill_parsing_response.dart';
import 'package:spendpal/models/transaction_model.dart';
import 'package:spendpal/models/expense_model.dart';
import 'package:spendpal/models/group_model.dart';
import 'package:spendpal/models/user_model.dart';
import 'package:intl/intl.dart';

class TransactionReviewScreen extends StatefulWidget {
  final BillParsingResponse parsingResponse;
  final String? billImageUrl;

  const TransactionReviewScreen({
    super.key,
    required this.parsingResponse,
    this.billImageUrl,
  });

  @override
  State<TransactionReviewScreen> createState() => _TransactionReviewScreenState();
}

class _TransactionReviewScreenState extends State<TransactionReviewScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late List<TransactionModel> _transactions;
  bool _isCreatingExpenses = false;

  List<GroupModel> _userGroups = [];
  Map<String, String> _userFriends = {}; // uid -> name

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.parsingResponse.transactions);
    _loadUserGroupsAndFriends();
  }

  Future<void> _loadUserGroupsAndFriends() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Load groups
    try {
      final groupsSnapshot = await _firestore
          .collection('groups')
          .where('members', arrayContains: userId)
          .get();

      setState(() {
        _userGroups = groupsSnapshot.docs
            .map((doc) => GroupModel.fromDocument(doc))
            .toList();
      });
    } catch (e) {
      // Handle error
    }

    // Load friends from user document
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userFriends = Map<String, String>.from(userData['friends'] ?? {});
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _createExpenses() async {
    final selectedTransactions = _transactions.where((t) => t.isSelected).toList();

    if (selectedTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one transaction'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCreatingExpenses = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      int successCount = 0;
      for (final transaction in selectedTransactions) {
        final assignmentInfo = transaction.assignmentInfo;

        // Determine groupId and sharedWith based on assignment
        String groupId = '';
        List<String> sharedWith = [];

        if (assignmentInfo.type == AssignmentType.group && assignmentInfo.id != null) {
          groupId = assignmentInfo.id!;
          // Get group members
          final groupDoc = await _firestore.collection('groups').doc(groupId).get();
          if (groupDoc.exists) {
            final groupData = groupDoc.data() as Map<String, dynamic>;
            sharedWith = List<String>.from(groupData['members'] ?? []);
          }
        } else if (assignmentInfo.type == AssignmentType.friend && assignmentInfo.id != null) {
          sharedWith = [userId, assignmentInfo.id!];
        } else {
          // Self - personal expense
          sharedWith = [userId];
        }

        // Create expense
        final expenseData = {
          'title': transaction.merchant,
          'amount': transaction.amount,
          'paidBy': userId,
          'groupId': groupId,
          'sharedWith': sharedWith,
          'date': Timestamp.fromDate(transaction.parsedDate ?? DateTime.now()),
          'notes': transaction.notes ?? '',
          'category': transaction.category,
          'tags': [],
          'billImageUrl': widget.billImageUrl,
          'isFromBill': true,
          'billMetadata': {
            'parsedBy': widget.parsingResponse.parsedBy,
            'bankName': widget.parsingResponse.bankName,
            'month': widget.parsingResponse.month,
            'year': widget.parsingResponse.year,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('expenses').add(expenseData);
        successCount++;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully created $successCount expense(s)!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to personal expenses screen
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating expenses: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingExpenses = false;
        });
      }
    }
  }

  void _toggleTransaction(int index) {
    setState(() {
      _transactions[index] = _transactions[index].copyWith(
        isSelected: !_transactions[index].isSelected,
      );
    });
  }

  void _showAssignmentDialog(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildAssignmentBottomSheet(index),
    );
  }

  Widget _buildAssignmentBottomSheet(int index) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assign Transaction To',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 20),

          // Self option
          _buildAssignmentOption(
            icon: Icons.person,
            title: 'Myself (Personal)',
            subtitle: 'Track as personal expense',
            isSelected: _transactions[index].assignedTo == 'self',
            onTap: () {
              setState(() {
                _transactions[index] = _transactions[index].copyWith(
                  assignedTo: 'self',
                  assignedToName: 'Personal',
                );
              });
              Navigator.pop(context);
            },
          ),

          const SizedBox(height: 12),

          // Friends
          if (_userFriends.isNotEmpty) ...[
            const Divider(),
            const Text(
              'Friends',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            ..._userFriends.entries.map((friend) {
              final friendId = friend.key;
              final friendName = friend.value;
              final assignedTo = 'friend:$friendId';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildAssignmentOption(
                  icon: Icons.person_outline,
                  title: friendName,
                  subtitle: 'Split with friend',
                  isSelected: _transactions[index].assignedTo == assignedTo,
                  onTap: () {
                    setState(() {
                      _transactions[index] = _transactions[index].copyWith(
                        assignedTo: assignedTo,
                        assignedToName: friendName,
                      );
                    });
                    Navigator.pop(context);
                  },
                ),
              );
            }),
          ],

          // Groups
          if (_userGroups.isNotEmpty) ...[
            const Divider(),
            const Text(
              'Groups',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 8),
            ..._userGroups.map((group) {
              final assignedTo = 'group:${group.groupId}';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildAssignmentOption(
                  icon: Icons.groups,
                  title: group.name,
                  subtitle: '${group.members.length} members',
                  isSelected: _transactions[index].assignedTo == assignedTo,
                  onTap: () {
                    setState(() {
                      _transactions[index] = _transactions[index].copyWith(
                        assignedTo: assignedTo,
                        assignedToName: group.name,
                      );
                    });
                    Navigator.pop(context);
                  },
                ),
              );
            }),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAssignmentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.tealAccent.withValues(alpha: 0.1)
              : AppTheme.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.tealAccent
                : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.tealAccent
                    : AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.secondaryText,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.tealAccent
                          : AppTheme.primaryText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppTheme.tealAccent,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _transactions.where((t) => t.isSelected).length;
    final totalAmount = _transactions
        .where((t) => t.isSelected)
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground,
        title: const Text(
          'Review Transactions',
          style: TextStyle(color: AppTheme.primaryText),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (int i = 0; i < _transactions.length; i++) {
                  _transactions[i] = _transactions[i].copyWith(isSelected: true);
                }
              });
            },
            child: const Text(
              'Select All',
              style: TextStyle(color: AppTheme.tealAccent),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Bill info header
          _buildBillInfoHeader(),

          // Transactions list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _transactions.length,
              itemBuilder: (context, index) => _buildTransactionCard(index),
            ),
          ),

          // Bottom action bar
          _buildBottomActionBar(selectedCount, totalAmount),
        ],
      ),
    );
  }

  Widget _buildBillInfoHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.tealAccent.withValues(alpha: 0.2),
            AppTheme.tealAccent.withValues(alpha: 0.1),
          ],
        ),
        border: const Border(
          bottom: BorderSide(color: AppTheme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.tealAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.parsingResponse.bankName} Bill',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryText,
                  ),
                ),
                Text(
                  '${widget.parsingResponse.month} ${widget.parsingResponse.year} • ${_transactions.length} transactions',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.tealAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.parsingResponse.parsedBy.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.tealAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(int index) {
    final transaction = _transactions[index];
    final date = transaction.parsedDate;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: transaction.isSelected
            ? AppTheme.cardBackground
            : AppTheme.cardBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: transaction.isSelected
              ? AppTheme.tealAccent.withValues(alpha: 0.3)
              : AppTheme.dividerColor,
          width: transaction.isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Checkbox(
          value: transaction.isSelected,
          onChanged: (value) => _toggleTransaction(index),
          activeColor: AppTheme.tealAccent,
        ),
        title: Text(
          transaction.merchant,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: transaction.isSelected
                ? AppTheme.primaryText
                : AppTheme.secondaryText,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (date != null)
              Text(
                DateFormat('MMM dd, yyyy').format(date),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryText,
                ),
              ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _showAssignmentDialog(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.tealAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.label,
                      size: 12,
                      color: AppTheme.tealAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      transaction.assignedToName ?? 'Personal',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.tealAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.edit,
                      size: 10,
                      color: AppTheme.tealAccent,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        trailing: Text(
          '₹${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: transaction.isSelected
                ? AppTheme.orangeAccent
                : AppTheme.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(int selectedCount, double totalAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$selectedCount selected',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  Text(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.tealAccent,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isCreatingExpenses ? null : _createExpenses,
              style: AppTheme.primaryButtonStyle.copyWith(
                minimumSize: MaterialStateProperty.all(const Size(160, 50)),
              ),
              child: _isCreatingExpenses
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle),
                        SizedBox(width: 8),
                        Text('Create Expenses'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

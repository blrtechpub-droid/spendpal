import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/services/budget_service.dart';
import 'package:spendpal/utils/currency_utils.dart';

class AddExpenseScreen extends StatefulWidget {
  final String? preSelectedGroupId;
  final String? preSelectedGroupName;
  final String? expenseId; // For edit mode
  final String? preSelectedSplitType; // 'friends' or 'group' - for swipe actions

  const AddExpenseScreen({
    super.key,
    this.preSelectedGroupId,
    this.preSelectedGroupName,
    this.expenseId,
    this.preSelectedSplitType,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _paidBy;
  String? _category;
  final List<String> _selectedFriends = [];

  // New variables for group/friends selection
  String _splitType = 'personal'; // 'personal', 'friends', or 'group'
  String? _selectedGroupId;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  // Splitwise-style split options
  String _splitMethod = 'equal'; // 'equal', 'unequal', 'percentage', 'shares'
  Map<String, double> _customSplits = {}; // uid -> amount/percentage/shares
  List<String> _groupMembers = []; // Current group members for display
  Map<String, String> _groupMemberDetails = {}; // uid -> name mapping

  // SMS expense tracking
  String? _smsExpenseId; // Track which SMS expense this came from
  bool _argumentsProcessed = false; // Flag to prevent duplicate processing

  // Budget warnings
  List<String> _budgetWarnings = [];

  final List<String> categories = [
    'Food',
    'Groceries',
    'Travel',
    'Shopping',
    'Maid',
    'Cook',
    'Utilities',
    'Entertainment',
    'Healthcare',
    'Education',
    'Personal Care',
    'Taxes',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Don't hardcode paidBy - let user select or default to current user
    _paidBy = FirebaseAuth.instance.currentUser?.uid;

    // If split type is pre-selected (from swipe action), use it
    if (widget.preSelectedSplitType != null) {
      _splitType = widget.preSelectedSplitType!;
    }

    // If a group is pre-selected, set the split type to 'group'
    if (widget.preSelectedGroupId != null) {
      _splitType = 'group';
      _selectedGroupId = widget.preSelectedGroupId;
    }

    _loadFriendsAndGroups();

    // If editing an existing expense, load its data
    if (widget.expenseId != null) {
      _loadExpenseData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Process route arguments only once
    if (!_argumentsProcessed) {
      _argumentsProcessed = true;

      final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (arguments != null && arguments['prefill'] == true) {
        // Pre-fill form with data from SMS expense
        setState(() {
          _titleController.text = arguments['title']?.toString() ?? '';

          // Convert amount to string (might be double from SMS)
          final amount = arguments['amount'];
          if (amount != null) {
            _amountController.text = amount is double
                ? amount.toString()
                : amount.toString();
          }

          _notesController.text = arguments['notes']?.toString() ?? '';

          if (arguments['date'] != null) {
            _selectedDate = arguments['date'] as DateTime;
          }

          // Set category if valid
          final category = arguments['category'] as String?;
          if (category != null && categories.contains(category)) {
            _category = category;
          }

          // Store SMS expense ID for later
          _smsExpenseId = arguments['smsExpenseId'] as String?;
        });
      }
    }
  }

  Future<void> _loadExpenseData() async {
    try {
      final expenseDoc = await FirebaseFirestore.instance
          .collection('expenses')
          .doc(widget.expenseId)
          .get();

      if (!expenseDoc.exists) return;

      final data = expenseDoc.data()!;

      setState(() {
        _titleController.text = data['title'] ?? '';
        _amountController.text = (data['amount'] as num?)?.toString() ?? '';
        _notesController.text = data['notes'] ?? '';

        // Validate category exists in the list
        final categoryFromDb = data['category'] as String?;
        if (categoryFromDb != null && categories.contains(categoryFromDb)) {
          _category = categoryFromDb;
        } else if (categoryFromDb != null) {
          // Try to find a case-insensitive match
          final matchedCategory = categories.firstWhere(
            (c) => c.toLowerCase() == categoryFromDb.toLowerCase(),
            orElse: () => 'Other',
          );
          _category = matchedCategory;
        }

        _paidBy = data['paidBy'];
        _splitMethod = data['splitMethod'] ?? 'equal';

        // Handle date
        final timestamp = data['date'] as Timestamp?;
        if (timestamp != null) {
          _selectedDate = timestamp.toDate();
        }

        // Handle split type
        // Priority: preSelectedSplitType > preSelectedGroupId > existing data
        if (widget.preSelectedSplitType != null) {
          // If split type was pre-selected (from swipe action), use it
          _splitType = widget.preSelectedSplitType!;

          if (_splitType == 'friends') {
            // Load existing friends if any
            _selectedFriends.clear();
            final splitWith = List<String>.from(data['splitWith'] ?? []);
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            _selectedFriends.addAll(splitWith.where((uid) => uid != currentUserId));
          } else if (_splitType == 'group') {
            // Use preselected group if available, otherwise load from data
            _selectedGroupId = widget.preSelectedGroupId ?? data['groupId'];
          }
        } else if (widget.preSelectedGroupId != null) {
          // If a group is preselected (e.g., categorizing personal expense to group), use that
          _splitType = 'group';
          _selectedGroupId = widget.preSelectedGroupId;
        } else if (data['groupId'] != null && (data['groupId'] as String).isNotEmpty) {
          // Load from existing data - has a group
          _splitType = 'group';
          _selectedGroupId = data['groupId'];
        } else {
          // Check if it's a personal expense or friends expense
          final splitWith = List<String>.from(data['splitWith'] ?? []);
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          if (splitWith.length == 1 && splitWith.first == currentUserId) {
            // Personal expense (only user in splitWith)
            _splitType = 'personal';
          } else {
            // Friends expense
            _splitType = 'friends';
            _selectedFriends.clear();
            _selectedFriends.addAll(splitWith.where((uid) => uid != currentUserId));
          }
        }

        // Load custom splits if not equal
        if (_splitMethod != 'equal' && data['splitDetails'] != null) {
          final splitDetails = Map<String, dynamic>.from(data['splitDetails']);

          if (_splitMethod == 'percentage') {
            // Convert amounts back to percentages
            final totalAmount = (data['amount'] as num).toDouble();
            splitDetails.forEach((uid, amount) {
              _customSplits[uid] = ((amount as num).toDouble() / totalAmount) * 100;
            });
          } else {
            // For unequal and shares, use the values directly
            splitDetails.forEach((uid, value) {
              _customSplits[uid] = (value as num).toDouble();
            });
          }
        }
      });

      // Load group members if in group mode
      if (_selectedGroupId != null) {
        await _loadGroupMembers(_selectedGroupId!);
      }
    } catch (e) {
      print('Error loading expense data: $e');
    }
  }

  Future<void> _loadFriendsAndGroups() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load friends
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final friendsData = userDoc.data()?['friends'];
      List<String> friendIds = [];

      if (friendsData is Map) {
        friendIds = (friendsData as Map).keys.cast<String>().toList();
      } else if (friendsData is List) {
        friendIds = List<String>.from(friendsData);
      }

      List<Map<String, dynamic>> friendsList = [];
      for (String friendId in friendIds) {
        final friendDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(friendId)
            .get();
        if (friendDoc.exists) {
          final friendData = Map<String, dynamic>.from(friendDoc.data()!);
          friendData['uid'] = friendId;
          if (friendsData is Map) {
            friendData['nickname'] = friendsData[friendId] ?? '';
          }
          friendsList.add(friendData);
        }
      }

      // Load groups
      final groupsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: currentUser.uid)
          .get();

      List<Map<String, dynamic>> groupsList = groupsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['groupId'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _friends = friendsList;
        _groups = groupsList;
        _isLoading = false;
      });

      // If a group is pre-selected, load its members
      if (_selectedGroupId != null) {
        await _loadGroupMembers(_selectedGroupId!);
      }
    } catch (e) {
      print('Error loading friends and groups: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Get participant count for header
  int _getParticipantCount() {
    if (_splitType == 'personal') return 1;
    if (_splitType == 'friends') return _selectedFriends.length + 1; // +1 for current user
    if (_splitType == 'group') return _groupMembers.length;
    return 1;
  }

  // Get split method text for compact display
  String _getSplitMethodText() {
    final payers = _getPossiblePayers();
    final payer = payers.firstWhere(
      (p) => p['uid'] == _paidBy,
      orElse: () => {'name': 'You'},
    );
    final payerName = payer['name'] as String;

    if (_splitType == 'personal') {
      return 'Personal expense';
    }

    String splitText = '';
    if (_splitMethod == 'equal') {
      splitText = 'split equally';
    } else if (_splitMethod == 'unequal') {
      splitText = 'split by exact amounts';
    } else if (_splitMethod == 'percentage') {
      splitText = 'split by percentages';
    } else if (_splitMethod == 'shares') {
      splitText = 'split by shares';
    }

    return 'Paid by $payerName and $splitText';
  }

  // Get list of possible payers based on split type
  List<Map<String, dynamic>> _getPossiblePayers() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    List<Map<String, dynamic>> payers = [];

    // Always include current user
    payers.add({
      'uid': currentUserId,
      'name': 'You',
      'isCurrentUser': true,
    });

    if (_splitType == 'friends' && _selectedFriends.isNotEmpty) {
      // Add selected friends
      for (final friend in _friends) {
        final friendId = friend['uid'] as String;
        if (_selectedFriends.contains(friendId)) {
          final nickname = friend['nickname'] as String?;
          final name = friend['name'] as String? ?? 'Unknown';
          final displayName = nickname != null && nickname.isNotEmpty ? nickname : name;
          payers.add({
            'uid': friendId,
            'name': displayName,
            'isCurrentUser': false,
          });
        }
      }
    } else if (_splitType == 'group' && _groupMembers.isNotEmpty) {
      // Add group members with actual names from _groupMemberDetails
      for (final memberId in _groupMembers) {
        if (memberId != currentUserId) {
          payers.add({
            'uid': memberId,
            'name': _groupMemberDetails[memberId] ?? 'Unknown',
            'isCurrentUser': false,
          });
        }
      }
    }

    return payers;
  }

  Future<void> _loadGroupMembers(String groupId) async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();
      if (groupDoc.exists) {
        final memberIds = List<String>.from(groupDoc.data()?['members'] ?? []);

        // Fetch user details for each member
        _groupMemberDetails.clear();
        for (String uid in memberIds) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              _groupMemberDetails[uid] = userData?['name'] ?? 'Unknown';
            } else {
              _groupMemberDetails[uid] = 'Unknown';
            }
          } catch (e) {
            _groupMemberDetails[uid] = 'Unknown';
          }
        }

        setState(() {
          _groupMembers = memberIds;
          // Reset custom splits when group changes
          _customSplits.clear();
        });
      }
    } catch (e) {
      print('Error loading group members: $e');
    }
  }

  Future<void> _checkBudgetWarnings() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty || _category == null) {
      setState(() => _budgetWarnings = []);
      return;
    }

    final expenseAmount = double.tryParse(amountText);
    if (expenseAmount == null || expenseAmount <= 0) {
      setState(() => _budgetWarnings = []);
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _budgetWarnings = []);
      return;
    }

    // Only check budget for personal expenses (not shared expenses)
    if (_splitType != 'personal') {
      setState(() => _budgetWarnings = []);
      return;
    }

    try {
      final warnings = await BudgetService.checkBudgetImpact(
        userId: userId,
        expenseAmount: expenseAmount,
        category: _category!,
      );

      setState(() {
        _budgetWarnings = warnings['warnings'] as List<String>;
      });
    } catch (e) {
      // Silently fail - budget warnings are not critical
      setState(() => _budgetWarnings = []);
    }
  }

  Future<void> _saveExpense() async {
    final String title = _titleController.text.trim();
    final String amount = _amountController.text.trim();
    final String notes = _notesController.text.trim();

    // Validation
    if (title.isEmpty || amount.isEmpty || _paidBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill title, amount, and payer')),
      );
      return;
    }

    if (_splitType == 'friends' && _selectedFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one friend')),
      );
      return;
    }

    if (_splitType == 'group' && _selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a group')),
      );
      return;
    }

    // Validate custom splits
    final totalAmount = double.tryParse(amount);
    if (totalAmount == null || totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Validate custom splits for both groups and friends
    if (_splitMethod != 'equal') {
      final expectedParticipants = _splitType == 'group'
          ? _groupMembers.length
          : _selectedFriends.length + 1; // +1 for current user

      if (_customSplits.isEmpty || _customSplits.length != expectedParticipants) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter split values for all participants')),
        );
        return;
      }

      if (_splitMethod == 'unequal') {
        // Validate that sum of amounts equals total
        final sum = _customSplits.values.fold(0.0, (sum, val) => sum + val);
        if ((sum - totalAmount).abs() > 0.01) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Split amounts must total ${context.formatCurrency(totalAmount)} (current: ${context.formatCurrency(sum)})')),
          );
          return;
        }
      } else if (_splitMethod == 'percentage') {
        // Validate that percentages sum to 100
        final sum = _customSplits.values.fold(0.0, (sum, val) => sum + val);
        if ((sum - 100).abs() > 0.01) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Percentages must total 100% (current: ${sum.toStringAsFixed(1)}%)')),
          );
          return;
        }
      } else if (_splitMethod == 'shares') {
        // Validate that all shares are positive
        if (_customSplits.values.any((val) => val <= 0)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All shares must be greater than 0')),
          );
          return;
        }
      }
    }

    try {
      // Get split members based on type
      List<String> splitWith = [];
      String? groupId;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (_splitType == 'personal') {
        // Personal expense - no splitting
        groupId = '';
        splitWith = [currentUserId];
      } else if (_splitType == 'group') {
        groupId = _selectedGroupId;
        // Get group members
        final groupDoc = await FirebaseFirestore.instance
            .collection('groups')
            .doc(_selectedGroupId)
            .get();
        if (groupDoc.exists) {
          splitWith = List<String>.from(groupDoc.data()?['members'] ?? []);
        }
      } else {
        // For friends, include current user + selected friends
        groupId = '';
        splitWith = [currentUserId, ..._selectedFriends];
      }

      // Calculate split details based on split method
      Map<String, double> splitDetails = {};
      final totalAmount = double.parse(amount);

      if (_splitMethod == 'equal') {
        // Equal split
        final perPerson = totalAmount / splitWith.length;
        for (var uid in splitWith) {
          splitDetails[uid] = perPerson;
        }
      } else if (_splitMethod == 'unequal') {
        // Use custom amounts
        splitDetails = Map.from(_customSplits);
      } else if (_splitMethod == 'percentage') {
        // Convert percentages to amounts
        for (var entry in _customSplits.entries) {
          splitDetails[entry.key] = (totalAmount * entry.value) / 100;
        }
      } else if (_splitMethod == 'shares') {
        // Convert shares to amounts
        final totalShares = _customSplits.values.fold(0.0, (sum, shares) => sum + shares);
        for (var entry in _customSplits.entries) {
          splitDetails[entry.key] = (totalAmount * entry.value) / totalShares;
        }
      }

      final expenseData = {
        'title': title,
        'amount': totalAmount,
        'notes': notes,
        'date': Timestamp.fromDate(_selectedDate),
        'paidBy': _paidBy,
        'splitWith': splitWith,
        'splitDetails': splitDetails, // Store who owes how much
        'splitMethod': _splitMethod,
        'category': _category ?? '',
        'groupId': groupId,
      };

      String? createdExpenseId;

      if (widget.expenseId != null) {
        // Update existing expense
        expenseData['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('expenses')
            .doc(widget.expenseId)
            .update(expenseData);
        createdExpenseId = widget.expenseId;
      } else {
        // Create new expense
        expenseData['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await FirebaseFirestore.instance.collection('expenses').add(expenseData);
        createdExpenseId = docRef.id;
      }

      if (!mounted) return;
      // Return the expense ID so SMS expense can be marked as categorized
      Navigator.pop(context, createdExpenseId);
    } catch (e) {
      print('Error saving expense: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving expense: $e')),
      );
    }
  }

  List<Widget> _buildCustomSplitInputs() {
    List<Widget> widgets = [];

    for (var memberId in _groupMembers) {
      widgets.add(
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(memberId)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final name = userData?['name'] ?? 'Unknown';

            String label = '';
            if (_splitMethod == 'unequal') {
              label = 'Amount for $name';
            } else if (_splitMethod == 'percentage') {
              label = 'Percentage for $name';
            } else if (_splitMethod == 'shares') {
              label = 'Shares for $name';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: label,
                ),
                onChanged: (value) {
                  final numValue = double.tryParse(value) ?? 0;
                  setState(() {
                    _customSplits[memberId] = numValue;
                  });
                },
              ),
            );
          },
        ),
      );
    }

    return widgets;
  }

  Widget _buildSplitSummary() {
    final amountText = _amountController.text.trim();
    final totalAmount = double.tryParse(amountText);

    if (totalAmount == null || totalAmount <= 0) {
      return const SizedBox.shrink();
    }

    if (_splitType != 'group' || _groupMembers.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate split details
    Map<String, double> splitDetails = {};

    if (_splitMethod == 'equal') {
      final perPerson = totalAmount / _groupMembers.length;
      for (var uid in _groupMembers) {
        splitDetails[uid] = perPerson;
      }
    } else if (_splitMethod == 'unequal') {
      splitDetails = Map.from(_customSplits);
    } else if (_splitMethod == 'percentage') {
      for (var entry in _customSplits.entries) {
        splitDetails[entry.key] = (totalAmount * entry.value) / 100;
      }
    } else if (_splitMethod == 'shares') {
      final totalShares = _customSplits.values.fold(0.0, (sum, shares) => sum + shares);
      if (totalShares > 0) {
        for (var entry in _customSplits.entries) {
          splitDetails[entry.key] = (totalAmount * entry.value) / totalShares;
        }
      }
    }

    if (splitDetails.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Split Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...splitDetails.entries.map((entry) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(entry.key)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                  final name = userData?['name'] ?? 'Unknown';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name),
                        Text(
                          context.formatCurrency(entry.value),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  context.formatCurrency(totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Show split options dialog (Paid by, Split type, Split method)
  Future<void> _showSplitOptionsDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Split Options',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // Paid by selector
                if (_splitType != 'personal') ...[
                  const Text('Paid by:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  ..._getPossiblePayers().map((payer) {
                    final uid = payer['uid'] as String;
                    final name = payer['name'] as String;
                    return RadioListTile<String>(
                      title: Text(name),
                      value: uid,
                      groupValue: _paidBy,
                      onChanged: (value) {
                        setState(() => _paidBy = value);
                        setModalState(() {});
                      },
                    );
                  }),
                  const Divider(),
                ],
                // Split type
                const Text('Split type:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  title: const Text('Personal'),
                  value: 'personal',
                  groupValue: _splitType,
                  onChanged: (value) {
                    setState(() {
                      _splitType = value!;
                      _selectedGroupId = null;
                      _selectedFriends.clear();
                    });
                    setModalState(() {});
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Friends'),
                  value: 'friends',
                  groupValue: _splitType,
                  onChanged: (value) {
                    setState(() {
                      _splitType = value!;
                      _selectedGroupId = null;
                    });
                    setModalState(() {});
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Group'),
                  value: 'group',
                  groupValue: _splitType,
                  onChanged: (value) {
                    setState(() {
                      _splitType = value!;
                      _selectedFriends.clear();
                    });
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppTheme.primaryButtonStyle,
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Show category picker dialog
  Future<void> _showCategoryPicker() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: categories.map((cat) {
                return ListTile(
                  title: Text(cat),
                  leading: Icon(
                    _category == cat ? Icons.check_circle : Icons.circle_outlined,
                    color: _category == cat ? AppTheme.tealAccent : null,
                  ),
                  onTap: () => Navigator.pop(context, cat),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() => _category = selected);
      _checkBudgetWarnings();
    }
  }

  // Show notes dialog
  Future<void> _showNotesDialog() async {
    final controller = TextEditingController(text: _notesController.text);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Note'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter note...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _notesController.text = controller.text);
                Navigator.pop(context);
              },
              style: AppTheme.primaryButtonStyle,
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseId != null ? 'Edit Expense' : 'Add Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveExpense,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "With you and: +X" header (Splitwise-style)
                  if (_splitType != 'personal') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color?.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'With you and: ',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.tealAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+${_getParticipantCount() - 1}',
                              style: const TextStyle(
                                color: AppTheme.tealAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Description field with icon (compact)
                  TextField(
                    controller: _titleController,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter a description',
                      hintStyle: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                      prefixIcon: const Icon(Icons.receipt_long, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Amount field with currency icon (compact)
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: '${context.currencySymbol} 0.00',
                      hintStyle: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                        fontWeight: FontWeight.bold,
                      ),
                      prefixIcon: Icon(Icons.attach_money, size: 24),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) => _checkBudgetWarnings(),
                  ),
                  const SizedBox(height: 16),
                  // Compact Split Method Card (Splitwise-style)
                  InkWell(
                    onTap: () => _showSplitOptionsDialog(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt,
                            color: AppTheme.tealAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getSplitMethodText(),
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Compact info chips row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Category chip
                      InkWell(
                        onTap: () => _showCategoryPicker(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _category != null
                                ? AppTheme.tealAccent.withOpacity(0.1)
                                : theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _category != null
                                  ? AppTheme.tealAccent.withOpacity(0.3)
                                  : theme.dividerColor.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 16,
                                color: _category != null
                                    ? AppTheme.tealAccent
                                    : theme.textTheme.bodyMedium?.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _category ?? 'Category',
                                style: TextStyle(
                                  color: _category != null
                                      ? AppTheme.tealAccent
                                      : theme.textTheme.bodyMedium?.color,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Date chip
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('MMM d').format(_selectedDate),
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Notes chip
                      InkWell(
                        onTap: () => _showNotesDialog(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _notesController.text.isNotEmpty
                                ? AppTheme.tealAccent.withOpacity(0.1)
                                : theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _notesController.text.isNotEmpty
                                  ? AppTheme.tealAccent.withOpacity(0.3)
                                  : theme.dividerColor.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.note_outlined,
                                size: 16,
                                color: _notesController.text.isNotEmpty
                                    ? AppTheme.tealAccent
                                    : theme.textTheme.bodyMedium?.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _notesController.text.isEmpty ? 'Add note' : 'Note',
                                style: TextStyle(
                                  color: _notesController.text.isNotEmpty
                                      ? AppTheme.tealAccent
                                      : theme.textTheme.bodyMedium?.color,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Show Friends selection
                  if (_splitType == 'friends') ...[
                    if (_friends.isEmpty)
                      const Text('No friends found. Add friends first.')
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select friends to split with:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _friends.map((friend) {
                              final friendId = friend['uid'] as String;
                              final nickname = friend['nickname'] as String?;
                              final name = friend['name'] as String? ?? 'Unknown';
                              final displayName = nickname != null && nickname.isNotEmpty
                                  ? nickname
                                  : name;
                              final isSelected = _selectedFriends.contains(friendId);
                              return FilterChip(
                                label: Text(displayName),
                                selected: isSelected,
                                selectedColor: AppTheme.tealAccent,
                                checkmarkColor: Colors.white,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedFriends.add(friendId);
                                    } else {
                                      _selectedFriends.remove(friendId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          // Splitwise-style options for friends
                          if (_selectedFriends.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Split Method:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: _splitMethod,
                              items: const [
                                DropdownMenuItem(value: 'equal', child: Text('Equal Split')),
                                DropdownMenuItem(value: 'unequal', child: Text('Exact Amounts')),
                                DropdownMenuItem(value: 'percentage', child: Text('Percentages')),
                                DropdownMenuItem(value: 'shares', child: Text('Shares')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _splitMethod = value!;
                                  _customSplits.clear();
                                });
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                            ),
                            if (_splitMethod != 'equal') ...[
                              const SizedBox(height: 16),
                              ..._buildCustomSplitInputsForFriends(),
                            ],
                            _buildSplitSummaryForFriends(),
                          ],
                        ],
                      ),
                  ],
                  // Show Group selection
                  if (_splitType == 'group') ...[
                    if (_groups.isEmpty)
                      const Text('No groups found. Create a group first.')
                    else
                      Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _groups.any((g) => g['groupId'] == _selectedGroupId)
                                ? _selectedGroupId
                                : null,
                            hint: const Text('Select a group'),
                            items: _groups.map((group) {
                              return DropdownMenuItem<String>(
                                value: group['groupId'] as String,
                                child: Text(group['name'] as String? ?? 'Unnamed Group'),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              setState(() {
                                _selectedGroupId = value;
                              });
                              if (value != null) {
                                await _loadGroupMembers(value);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Group',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_selectedGroupId != null && _groupMembers.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Split Method:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: _splitMethod,
                              items: const [
                                DropdownMenuItem(value: 'equal', child: Text('Equal Split')),
                                DropdownMenuItem(value: 'unequal', child: Text('Exact Amounts')),
                                DropdownMenuItem(value: 'percentage', child: Text('Percentages')),
                                DropdownMenuItem(value: 'shares', child: Text('Shares')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _splitMethod = value!;
                                  _customSplits.clear();
                                });
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                            ),
                            if (_splitMethod != 'equal') ...[
                              const SizedBox(height: 16),
                              ..._buildCustomSplitInputs(),
                            ],
                            _buildSplitSummary(),
                          ],
                        ],
                      ),
                  ],
                  const SizedBox(height: 20),

                  // Budget warning banner
                  if (_budgetWarnings.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning, color: Colors.red[700], size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _budgetWarnings.map((warning) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  warning,
                                  style: TextStyle(
                                    color: Colors.red[900],
                                    fontSize: 14,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveExpense,
                      child: Text(widget.expenseId != null ? 'Update Expense' : 'Save Expense'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Build custom split inputs for friends
  List<Widget> _buildCustomSplitInputsForFriends() {
    List<Widget> widgets = [];

    // Add current user
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final allParticipants = [currentUserId, ..._selectedFriends];

    for (var friendId in allParticipants) {
      widgets.add(
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(friendId)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();

            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final name = friendId == currentUserId
                ? 'You'
                : userData?['name'] ?? 'Unknown';

            String label = '';
            if (_splitMethod == 'unequal') {
              label = 'Amount for $name';
            } else if (_splitMethod == 'percentage') {
              label = 'Percentage for $name';
            } else if (_splitMethod == 'shares') {
              label = 'Shares for $name';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: label,
                ),
                onChanged: (value) {
                  final numValue = double.tryParse(value) ?? 0.0;
                  setState(() {
                    _customSplits[friendId] = numValue;
                  });
                },
                controller: TextEditingController(
                  text: _customSplits[friendId]?.toString() ?? '',
                ),
              ),
            );
          },
        ),
      );
    }

    return widgets;
  }

  // Build split summary for friends
  Widget _buildSplitSummaryForFriends() {
    final amountText = _amountController.text.trim();
    final totalAmount = double.tryParse(amountText);

    if (totalAmount == null || totalAmount <= 0) {
      return const SizedBox.shrink();
    }

    if (_selectedFriends.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final allParticipants = [currentUserId, ..._selectedFriends];

    // Calculate split details
    Map<String, double> splitDetails = {};

    if (_splitMethod == 'equal') {
      final perPerson = totalAmount / allParticipants.length;
      for (var uid in allParticipants) {
        splitDetails[uid] = perPerson;
      }
    } else if (_splitMethod == 'unequal') {
      splitDetails = Map.from(_customSplits);
    } else if (_splitMethod == 'percentage') {
      for (var entry in _customSplits.entries) {
        splitDetails[entry.key] = (totalAmount * entry.value) / 100;
      }
    } else if (_splitMethod == 'shares') {
      final totalShares = _customSplits.values.fold(0.0, (sum, shares) => sum + shares);
      if (totalShares > 0) {
        for (var entry in _customSplits.entries) {
          splitDetails[entry.key] = (totalAmount * entry.value) / totalShares;
        }
      }
    }

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Split Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 12),
          ...splitDetails.entries.map((entry) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(entry.key)
                  .get(),
              builder: (context, snapshot) {
                final name = entry.key == currentUserId
                    ? 'You'
                    : (snapshot.data?.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                      Text(
                        context.formatCurrency(entry.value),
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
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
  }
}
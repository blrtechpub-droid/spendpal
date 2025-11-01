import 'package:flutter/material.dart';
import 'package:spendpal/widgets/FloatingButtons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/screens/groups/add_group_screen.dart';
import 'package:spendpal/screens/groups/group_home_screen.dart';
import 'package:spendpal/models/group_model.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/services/balance_service.dart';
import 'package:spendpal/screens/requests/pending_requests_screen.dart';
import 'package:spendpal/widgets/empty_state_widget.dart';
import 'package:spendpal/services/group_invitation_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  bool _showSettledGroups = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  void _navigateToSearch() {
    Navigator.pushNamed(context, '/search');
  }

  Stream<QuerySnapshot> _getUserGroups() {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: _currentUser?.uid)
        .snapshots();
  }

  // Generate a consistent color for each group based on group name
  Color _getGroupColor(String groupName) {
    final colors = [
      const Color(0xFFFF6B6B), // Red
      const Color(0xFF4ECDC4), // Teal
      const Color(0xFFFFE66D), // Yellow
      const Color(0xFF95E1D3), // Mint
      const Color(0xFFF38181), // Pink
      const Color(0xFFAA96DA), // Purple
    ];
    final index = groupName.hashCode % colors.length;
    return colors[index.abs()];
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground,
        title: const Text("Groups", style: TextStyle(color: AppTheme.primaryText)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.primaryText),
            onPressed: _navigateToSearch,
            tooltip: 'Search',
          ),
          // Group Invitations notification icon with badge
          FutureBuilder<int>(
            future: GroupInvitationService.getPendingInvitationCount(currentUserId),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: AppTheme.primaryText),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PendingRequestsScreen(
                            initialTab: 1, // Open Group Invitations tab
                          ),
                        ),
                      );
                    },
                    tooltip: 'Notifications',
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 9 ? '9+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_add, color: AppTheme.tealAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddGroupScreen()),
              );
            },
            tooltip: 'Create Group',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getUserGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.tealAccent),
            );
          }

          final groups = snapshot.data?.docs ?? [];

          if (groups.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.groups,
              title: 'No groups yet',
              subtitle: 'Create a group to start splitting expenses',
              actionLabel: 'Create Group',
              onActionPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddGroupScreen()),
                );
              },
            );
          }

          return FutureBuilder<double>(
            future: BalanceService.calculateOverallBalance(currentUserId),
            builder: (context, overallBalanceSnapshot) {
              final overallBalance = overallBalanceSnapshot.data ?? 0.0;

              return ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  // Overall Balance Summary - only show if non-zero
                  if (overallBalance.abs() >= 0.01)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Overall, you',
                            style: TextStyle(
                              color: AppTheme.primaryText,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            overallBalance < 0
                                ? 'owe ₹${(-overallBalance).toStringAsFixed(2)}'
                                : 'are owed ₹${overallBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: overallBalance < 0 ? Colors.orange : AppTheme.tealAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Group Cards
                  ...groups.map((group) => _buildGroupCard(group, currentUserId)),

                  // Non-group Expenses Section
                  FutureBuilder<Map<String, double>>(
                    future: BalanceService.calculateNonGroupBalances(currentUserId),
                    builder: (context, nonGroupSnapshot) {
                      final nonGroupBalances = nonGroupSnapshot.data ?? {};

                      if (nonGroupBalances.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      double totalNonGroup = 0.0;
                      for (var balance in nonGroupBalances.values) {
                        totalNonGroup += balance;
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              leading: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.deepPurple,
                                      Colors.deepPurple.shade300,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.people_alt,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              title: const Text(
                                'Non-group expenses',
                                style: TextStyle(
                                  color: AppTheme.primaryText,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  totalNonGroup < 0
                                      ? 'you owe ₹${(-totalNonGroup).toStringAsFixed(2)}'
                                      : 'you are owed ₹${totalNonGroup.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: totalNonGroup < 0 ? Colors.orange : AppTheme.tealAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            // Individual friend balances - only show non-zero
                            ...nonGroupBalances.entries.where((entry) => entry.value.abs() >= 0.01).map((entry) {
                              return FutureBuilder<String>(
                                future: BalanceService.getUserName(entry.key),
                                builder: (context, nameSnapshot) {
                                  final name = nameSnapshot.data ?? 'Loading...';
                                  final balance = entry.value;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            balance < 0
                                                ? 'You owe $name'
                                                : '$name owes you',
                                            style: const TextStyle(
                                              color: AppTheme.secondaryText,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        Text(
                                          '₹${balance.abs().toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: balance < 0 ? Colors.orange : AppTheme.tealAccent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        ),
                      );
                    },
                  ),

                  // Settled groups message (placeholder)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          'Hiding settled groups (>1 month)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.tertiaryText,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _showSettledGroups = !_showSettledGroups;
                            });
                          },
                          style: AppTheme.secondaryButtonStyle,
                          child: Text(_showSettledGroups
                              ? 'Hide settled-up groups'
                              : 'Show settled-up groups'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGroupCard(DocumentSnapshot group, String currentUserId) {
    final data = group.data() as Map<String, dynamic>;
    final groupName = data['name'] ?? 'Unnamed Group';
    final groupPhoto = data['photo'] ?? '';
    final groupColor = _getGroupColor(groupName);

    return FutureBuilder<Map<String, double>>(
      future: BalanceService.calculateGroupBalances(currentUserId, group.id),
      builder: (context, balanceSnapshot) {
        final balances = balanceSnapshot.data ?? {};

        // Calculate net balance for this group
        double netBalance = 0.0;
        for (var balance in balances.values) {
          netBalance += balance;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: groupColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: groupPhoto.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            groupPhoto,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.home, color: Colors.white, size: 28),
                          ),
                        )
                      : const Icon(Icons.home, color: Colors.white, size: 28),
                ),
                title: Text(
                  groupName,
                  style: const TextStyle(
                    color: AppTheme.primaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: netBalance.abs() >= 0.01
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          netBalance < 0
                              ? 'you owe ₹${(-netBalance).toStringAsFixed(2)}'
                              : 'you are owed ₹${netBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: netBalance < 0 ? Colors.orange : AppTheme.tealAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'settled up',
                          style: TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 14,
                          ),
                        ),
                      ),
                onTap: () {
                  final groupModel = GroupModel.fromDocument(group);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupHomeScreen(group: groupModel),
                    ),
                  );
                },
              ),

              // Individual member balances - only show non-zero
              ...balances.entries.where((entry) => entry.value.abs() >= 0.01).map((entry) {
                return FutureBuilder<String>(
                  future: BalanceService.getUserName(entry.key),
                  builder: (context, nameSnapshot) {
                    final name = nameSnapshot.data ?? 'Loading...';
                    final balance = entry.value;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              balance < 0
                                  ? 'You owe $name'
                                  : '$name owes you',
                              style: const TextStyle(
                                color: AppTheme.secondaryText,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Text(
                            '₹${balance.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              color: balance < 0 ? Colors.orange : AppTheme.tealAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/screens/groups/add_group_screen.dart';
import 'package:spendpal/screens/groups/group_home_screen.dart';
import 'package:spendpal/models/group_model.dart';
import 'package:spendpal/services/balance_service.dart';
import 'package:spendpal/screens/requests/pending_requests_screen.dart';
import 'package:spendpal/widgets/empty_state_widget.dart';
import 'package:spendpal/services/group_invitation_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Groups"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
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
                    icon: const Icon(Icons.notifications_outlined),
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
                            color: Color(0xFFF8F8F8),
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
            icon: Icon(Icons.group_add, color: theme.colorScheme.primary),
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
            return Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
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
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: overallBalance < 0
                              ? [Colors.orange[400]!, Colors.deepOrange[600]!]
                              : [Colors.teal[400]!, Colors.teal[700]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (overallBalance < 0 ? Colors.orange : Colors.teal).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  overallBalance < 0
                                      ? 'Overall, you owe'
                                      : 'Overall, you are owed',
                                  style: const TextStyle(
                                    color: Color(0xFFF8F8F8),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '₹${overallBalance.abs().toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Color(0xFFF8F8F8),
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Group Cards
                  ...groups.map((group) => _buildGroupCard(group, currentUserId, theme)),

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
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.deepPurple,
                                      Colors.deepPurple.shade700,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepPurple.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.people_alt,
                                  color: Color(0xFFF8F8F8),
                                  size: 28,
                                ),
                              ),
                              title: Text(
                                'Non-group expenses',
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  totalNonGroup < 0
                                      ? 'you owe ₹${(-totalNonGroup).toStringAsFixed(2)}'
                                      : 'you are owed ₹${totalNonGroup.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: totalNonGroup < 0 ? Colors.orange : theme.colorScheme.primary,
                                    fontSize: 13,
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
                                            style: TextStyle(
                                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        Text(
                                          '₹${balance.abs().toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: balance < 0 ? Colors.orange : theme.colorScheme.primary,
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
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 32,
                          color: Colors.green[600],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Hiding settled groups (>1 month)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showSettledGroups = !_showSettledGroups;
                            });
                          },
                          icon: Icon(
                            _showSettledGroups ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                          ),
                          label: Text(_showSettledGroups
                              ? 'Hide settled-up groups'
                              : 'Show settled-up groups'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[100],
                            foregroundColor: Colors.green[700],
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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

  Widget _buildGroupCard(DocumentSnapshot group, String currentUserId, ThemeData theme) {
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
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        groupColor,
                        groupColor.withValues(
                          red: (groupColor.r * 0.7).clamp(0, 1),
                          green: (groupColor.g * 0.7).clamp(0, 1),
                          blue: (groupColor.b * 0.7).clamp(0, 1),
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: groupColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: groupPhoto.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            groupPhoto,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.home, color: Color(0xFFF8F8F8), size: 28),
                          ),
                        )
                      : const Icon(Icons.home, color: Color(0xFFF8F8F8), size: 28),
                ),
                title: Text(
                  groupName,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: netBalance.abs() >= 0.01
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          netBalance < 0
                              ? 'you owe ₹${(-netBalance).toStringAsFixed(2)}'
                              : 'you are owed ₹${netBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: netBalance < 0 ? Colors.orange : theme.colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'settled up',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            fontSize: 13,
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
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              balance < 0
                                  ? 'You owe $name'
                                  : '$name owes you',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Text(
                            '₹${balance.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              color: balance < 0 ? Colors.orange : theme.colorScheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}

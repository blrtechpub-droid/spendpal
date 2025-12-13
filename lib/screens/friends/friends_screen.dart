import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/screens/friends/add_friend_screen.dart';
import 'package:spendpal/screens/friends/friend_home_screen.dart';
import 'package:spendpal/screens/requests/pending_requests_screen.dart';
import 'package:spendpal/services/friend_request_service.dart';
import 'package:spendpal/services/group_invitation_service.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/widgets/empty_state_widget.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  bool _showSettledFriends = false;

  void _navigateToAddFriend(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFriendScreen()),
    );
  }

  Future<int> _getPendingRequestsCount(String userId) async {
    final friendRequestsCount = await FriendRequestService.getPendingRequestCount(userId);
    final groupInvitationsCount = await GroupInvitationService.getPendingInvitationCount(userId);
    return friendRequestsCount + groupInvitationsCount;
  }

  Future<Map<String, double>> _calculateFriendBalances() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return {};

    final currentUserId = currentUser.uid;
    Map<String, double> friendBalances = {};

    // Get all expenses where current user is involved
    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('expenses')
        .where('splitWith', arrayContains: currentUserId)
        .get();

    for (var expenseDoc in expensesSnapshot.docs) {
      final data = expenseDoc.data();
      final paidBy = data['paidBy'] as String;
      final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});

      if (paidBy == currentUserId) {
        // Current user paid, others owe them
        splitDetails.forEach((uid, share) {
          if (uid != currentUserId) {
            friendBalances[uid] = (friendBalances[uid] ?? 0.0) + (share as num).toDouble();
          }
        });
      } else {
        // Someone else paid, current user owes their share
        final currentUserShare = (splitDetails[currentUserId] as num?)?.toDouble() ?? 0.0;
        if (currentUserShare > 0 && splitDetails.containsKey(paidBy)) {
          friendBalances[paidBy] = (friendBalances[paidBy] ?? 0.0) - currentUserShare;
        }
      }
    }

    return friendBalances;
  }

  Future<List<Map<String, dynamic>>> _fetchFriendsWithBalances() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final data = userDoc.data();

    // Friends is stored as Map<String, String> (UID -> Nickname)
    final friendsData = data?['friends'];
    List<String> friendIds = [];

    if (friendsData is Map) {
      friendIds = (friendsData as Map).keys.cast<String>().toList();
    } else if (friendsData is List) {
      // Fallback for old data structure
      friendIds = List<String>.from(friendsData);
    }

    // Calculate balances for all friends
    final balances = await _calculateFriendBalances();

    List<Map<String, dynamic>> friends = [];

    for (String friendId in friendIds) {
      final friendDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .get();
      if (friendDoc.exists) {
        final friendData = Map<String, dynamic>.from(friendDoc.data()!);
        friendData['uid'] = friendId;
        // Add the nickname from the friends map
        if (friendsData is Map) {
          friendData['nickname'] = friendsData[friendId] ?? '';
        }
        // Add balance
        friendData['balance'] = balances[friendId] ?? 0.0;
        friends.add(friendData);
      }
    }

    // Sort: non-zero balances first, then settled up
    friends.sort((a, b) {
      final balanceA = (a['balance'] as double).abs();
      final balanceB = (b['balance'] as double).abs();
      if (balanceA < 0.01 && balanceB >= 0.01) return 1;
      if (balanceB < 0.01 && balanceA >= 0.01) return -1;
      return balanceB.compareTo(balanceA);
    });

    return friends;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Friends"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          // Pending requests notification icon with badge
          FutureBuilder<int>(
            future: _getPendingRequestsCount(currentUser.uid),
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
                          builder: (_) => const PendingRequestsScreen(),
                        ),
                      );
                    },
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
            icon: Icon(Icons.person_add, color: theme.colorScheme.primary),
            onPressed: () => _navigateToAddFriend(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return Center(child: Text('User not found', style: TextStyle(color: theme.textTheme.bodyLarge?.color)));
          }

          // Now fetch friends with balances whenever user data changes
          return FutureBuilder<List<Map<String, dynamic>>>(
            key: ValueKey(userSnapshot.data!.data().hashCode), // Rebuild when data changes
            future: _fetchFriendsWithBalances(),
            builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final friends = snapshot.data ?? [];

          if (friends.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.people_outline,
              title: "No friends yet",
              subtitle: "Add friends to split expenses",
              actionLabel: "Add Friend",
              onActionPressed: () => _navigateToAddFriend(context),
            );
          }

          // Separate settled and unsettled friends
          final unsettledFriends = friends.where((f) => (f['balance'] as double).abs() >= 0.01).toList();
          final settledFriends = friends.where((f) => (f['balance'] as double).abs() < 0.01).toList();

          // Calculate overall balance
          double overallBalance = 0.0;
          for (var friend in friends) {
            overallBalance += (friend['balance'] as double);
          }

          return Column(
            children: [
              // Overall Balance Header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: overallBalance > 0
                        ? [Colors.green[400]!, Colors.green[700]!]
                        : overallBalance < 0
                            ? [Colors.orange[400]!, Colors.deepOrange[600]!]
                            : [Colors.grey[400]!, Colors.grey[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (overallBalance > 0
                              ? Colors.green
                              : overallBalance < 0
                                  ? Colors.orange
                                  : Colors.grey)
                          .withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
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
                            overallBalance > 0
                                ? 'Overall, you are owed'
                                : overallBalance < 0
                                    ? 'Overall, you owe'
                                    : 'Overall, you are settled up',
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
              // Friends List
              Expanded(
                child: ListView(
                  children: [
                    // Unsettled friends
                    ...unsettledFriends.map((friend) => _buildFriendTile(context, friend)),

                    // Settled friends toggle button
                    if (settledFriends.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showSettledFriends = !_showSettledFriends;
                            });
                          },
                          icon: Icon(
                            _showSettledFriends ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                          ),
                          label: Text(_showSettledFriends
                              ? 'Hide settled-up friends'
                              : 'Show settled-up friends'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[100],
                            foregroundColor: Colors.green[700],
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Show settled friends when toggled
                      if (_showSettledFriends)
                        ...settledFriends.map((friend) => _buildFriendTile(context, friend)),
                    ],
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

  Widget _buildFriendTile(BuildContext context, Map<String, dynamic> friend) {
    final theme = Theme.of(context);
    final nickname = friend['nickname'];
    final name = friend['name'] ?? 'Unnamed';
    final displayName = nickname != null && nickname.isNotEmpty ? nickname : name;
    final balance = (friend['balance'] as double);
    final isSettled = balance.abs() < 0.01;
    final owesYou = balance > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: theme.colorScheme.primary,
        backgroundImage: friend['photoURL'] != null && friend['photoURL'] != ''
            ? NetworkImage(friend['photoURL'])
            : null,
        child: friend['photoURL'] == null || friend['photoURL'] == ''
            ? Text(
                displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        displayName,
        style: TextStyle(
          color: theme.textTheme.bodyLarge?.color,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: isSettled
          ? Text(
              'settled up',
              style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 12),
            )
          : Text(
              owesYou ? 'owes you' : 'you owe',
              style: TextStyle(
                color: owesYou ? Colors.green : Colors.orange,
                fontSize: 12,
              ),
            ),
      trailing: isSettled
          ? null
          : Text(
              '₹${balance.abs().toStringAsFixed(2)}',
              style: TextStyle(
                color: owesYou ? Colors.green : Colors.orange,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FriendHomeScreen(
              friendId: friend['uid'] as String,
              friendName: displayName,
            ),
          ),
        );
      },
    );
  }
}

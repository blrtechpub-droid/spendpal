import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/screens/friends/add_friend_screen.dart';
import 'package:spendpal/screens/friends/friend_home_screen.dart';
import 'package:spendpal/screens/requests/pending_requests_screen.dart';
import 'package:spendpal/services/friend_request_service.dart';
import 'package:spendpal/services/group_invitation_service.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({Key? key}) : super(key: key);

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
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Friends", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
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
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
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
                        decoration: BoxDecoration(
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
            icon: const Icon(Icons.person_add, color: Colors.white),
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
            return const Center(child: Text('User not found', style: TextStyle(color: Colors.white)));
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    "No friends yet",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text("Add Friend"),
                    onPressed: () => _navigateToAddFriend(context),
                  ),
                ],
              ),
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
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overallBalance > 0
                              ? 'Overall, you are owed'
                              : overallBalance < 0
                                  ? 'Overall, you owe'
                                  : 'Overall, you are settled up',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${overallBalance.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            color: overallBalance > 0
                                ? Colors.green
                                : overallBalance < 0
                                    ? Colors.orange
                                    : Colors.white70,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white),
                      onPressed: () {
                        // TODO: Implement filter
                      },
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey, height: 1),
              // Friends List
              Expanded(
                child: ListView(
                  children: [
                    // Unsettled friends
                    ...unsettledFriends.map((friend) => _buildFriendTile(context, friend)),

                    // Settled friends section
                    if (settledFriends.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Hiding friends that have been settled up over one month.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            // TODO: Show settled friends
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF2C2C2E),
                                title: const Text(
                                  'Settled Friends',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: settledFriends
                                      .map((friend) => _buildFriendTile(context, friend))
                                      .toList(),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text('Show ${settledFriends.length} settled-up friends'),
                        ),
                      ),
                      const SizedBox(height: 20),
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
    final nickname = friend['nickname'];
    final name = friend['name'] ?? 'Unnamed';
    final displayName = nickname != null && nickname.isNotEmpty ? nickname : name;
    final balance = (friend['balance'] as double);
    final isSettled = balance.abs() < 0.01;
    final owesYou = balance > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.orange,
        backgroundImage: friend['photoURL'] != null && friend['photoURL'] != ''
            ? NetworkImage(friend['photoURL'])
            : null,
        child: friend['photoURL'] == null || friend['photoURL'] == ''
            ? Text(
                displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        displayName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: isSettled
          ? const Text(
              'settled up',
              style: TextStyle(color: Colors.grey, fontSize: 12),
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

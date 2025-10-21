import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:spendpal/services/group_invitation_service.dart';
import 'package:spendpal/theme/app_theme.dart';

class AddGroupMembersScreen extends StatefulWidget {
  final String groupId;
  const AddGroupMembersScreen({super.key, required this.groupId});

  @override
  State<AddGroupMembersScreen> createState() => _AddGroupMembersScreenState();
}

class _AddGroupMembersScreenState extends State<AddGroupMembersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, bool> selectedFriends = {}; // uid -> isSelected
  Map<String, String> friendNicknames = {}; // uid -> nickname
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // Get group members to exclude them
      final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
      final groupMembers = List<String>.from(groupDoc.data()?['members'] ?? []);

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();

      // Handle friends as Map<String, String> (UID -> Nickname)
      final friendsData = userDoc.data()?['friends'];
      Map<String, bool> selectedMap = {};
      Map<String, String> nicknameMap = {};

      if (friendsData is Map) {
        for (var entry in (friendsData as Map).entries) {
          final uid = entry.key as String;

          // Skip if friend is already a member
          if (groupMembers.contains(uid)) continue;

          final nickname = entry.value as String? ?? '';
          selectedMap[uid] = false;
          nicknameMap[uid] = nickname;
        }
      } else if (friendsData is List) {
        for (var uid in friendsData) {
          // Skip if friend is already a member
          if (groupMembers.contains(uid as String)) continue;

          selectedMap[uid as String] = false;
          nicknameMap[uid as String] = '';
        }
      }

      setState(() {
        selectedFriends = selectedMap;
        friendNicknames = nicknameMap;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading friends: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _sendInvitations() async {
    final selectedUids = selectedFriends.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one friend')),
      );
      return;
    }

    try {
      final currentUserId = _auth.currentUser?.uid ?? '';

      // Send invitation to each selected friend
      for (var friendId in selectedUids) {
        await GroupInvitationService.sendGroupInvitation(
          groupId: widget.groupId,
          invitedBy: currentUserId,
          invitedUserId: friendId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent ${selectedUids.length} invitation(s)'),
          backgroundColor: AppTheme.tealAccent,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground,
        title: const Text(
          "Invite Group Members",
          style: TextStyle(color: AppTheme.primaryText),
        ),
        iconTheme: const IconThemeData(color: AppTheme.primaryText),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.tealAccent),
            )
          : selectedFriends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 64,
                        color: AppTheme.secondaryText,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No friends available to invite',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All your friends may already be members',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.tertiaryText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Info banner
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.tealAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.tealAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.tealAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Selected friends will receive an invitation to join this group',
                              style: TextStyle(
                                color: AppTheme.secondaryText,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Friends list
                    Expanded(
                      child: ListView(
                        children: selectedFriends.entries.map((entry) {
                          return FutureBuilder<DocumentSnapshot>(
                            future: _firestore.collection('users').doc(entry.key).get(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox();
                              final data = snapshot.data!.data() as Map<String, dynamic>?;

                              // Use nickname if available, otherwise fall back to name
                              final nickname = friendNicknames[entry.key] ?? '';
                              final displayName = nickname.isNotEmpty
                                  ? nickname
                                  : (data?['name'] ?? 'Unknown');
                              final photoURL = data?['photoURL'] ?? '';

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: entry.value
                                      ? AppTheme.tealAccent.withValues(alpha: 0.1)
                                      : AppTheme.cardBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: entry.value
                                        ? AppTheme.tealAccent
                                        : AppTheme.dividerColor,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  value: entry.value,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      selectedFriends[entry.key] = value ?? false;
                                    });
                                  },
                                  activeColor: AppTheme.tealAccent,
                                  title: Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: AppTheme.primaryText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    data?['email'] ?? '',
                                    style: TextStyle(
                                      color: AppTheme.secondaryText,
                                      fontSize: 12,
                                    ),
                                  ),
                                  secondary: CircleAvatar(
                                    backgroundColor: AppTheme.tealAccent,
                                    backgroundImage:
                                        photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                                    child: photoURL.isEmpty
                                        ? Text(
                                            displayName.isNotEmpty
                                                ? displayName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(color: Colors.white),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: selectedFriends.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _sendInvitations,
              backgroundColor: AppTheme.tealAccent,
              label: const Text("Send Invitations"),
              icon: const Icon(Icons.send),
            )
          : null,
    );
  }
}

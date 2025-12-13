import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/friend_request_model.dart';
import 'package:spendpal/models/group_invitation_model.dart';
import 'package:spendpal/services/friend_request_service.dart';
import 'package:spendpal/services/group_invitation_service.dart';
import 'package:spendpal/theme/app_theme.dart';

class PendingRequestsScreen extends StatefulWidget {
  final int initialTab; // 0 for Friend Requests, 1 for Group Invitations

  const PendingRequestsScreen({super.key, this.initialTab = 0});

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground,
        title: const Text(
          'Pending Requests',
          style: TextStyle(color: AppTheme.primaryText),
        ),
        iconTheme: const IconThemeData(color: AppTheme.primaryText),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.tealAccent,
          labelColor: AppTheme.tealAccent,
          unselectedLabelColor: AppTheme.secondaryText,
          tabs: const [
            Tab(text: 'Friend Requests'),
            Tab(text: 'Group Invitations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendRequestsTab(),
          _buildGroupInvitationsTab(),
        ],
      ),
    );
  }

  Widget _buildFriendRequestsTab() {
    return StreamBuilder<List<FriendRequestModel>>(
      stream: FriendRequestService.getPendingReceivedRequests(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.tealAccent));
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_disabled,
                  size: 64,
                  color: AppTheme.secondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending friend requests',
                  style: TextStyle(
                    color: AppTheme.secondaryText,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildFriendRequestCard(request);
          },
        );
      },
    );
  }

  Widget _buildFriendRequestCard(FriendRequestModel request) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(request.fromUserId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final senderName = userData?['name'] ?? 'Unknown';
        final senderEmail = userData?['email'] ?? '';
        final senderPhoto = userData?['photoURL'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.tealAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.tealAccent,
                    backgroundImage:
                        senderPhoto.isNotEmpty ? NetworkImage(senderPhoto) : null,
                    child: senderPhoto.isEmpty
                        ? Text(
                            senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          senderName,
                          style: const TextStyle(
                            color: AppTheme.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          senderEmail,
                          style: TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                        if (request.nickname != null && request.nickname!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.tealAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Wants to save you as "${request.nickname}"',
                              style: const TextStyle(
                                color: AppTheme.tealAccent,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectFriendRequest(request.requestId),
                      style: AppTheme.dangerOutlinedButtonStyle,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptFriendRequest(request.requestId),
                      style: AppTheme.primaryButtonStyle,
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupInvitationsTab() {
    return StreamBuilder<List<GroupInvitationModel>>(
      stream: GroupInvitationService.getPendingInvitations(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.tealAccent));
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading invitations',
                  style: TextStyle(color: AppTheme.secondaryText),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final invitations = snapshot.data ?? [];

        if (invitations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.group_off,
                  size: 64,
                  color: AppTheme.secondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending group invitations',
                  style: TextStyle(
                    color: AppTheme.secondaryText,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        // Debug: Print invitation count
        debugPrint('Group Invitations loaded: ${invitations.length}');
        for (var inv in invitations) {
          debugPrint('  - Group: ${inv.groupId}, InvitedBy: ${inv.invitedBy}, Status: ${inv.status}');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invitations.length,
          itemBuilder: (context, index) {
            final invitation = invitations[index];
            return _buildGroupInvitationCard(invitation);
          },
        );
      },
    );
  }

  Widget _buildGroupInvitationCard(GroupInvitationModel invitation) {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance.collection('groups').doc(invitation.groupId).get(),
        FirebaseFirestore.instance.collection('users').doc(invitation.invitedBy).get(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Still loading
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.tealAccent),
            ),
          );
        }

        final groupDoc = snapshot.data![0];
        final userDoc = snapshot.data![1];

        // Debug: Check if documents exist
        debugPrint('Group ${invitation.groupId} exists: ${groupDoc.exists}');
        debugPrint('User ${invitation.invitedBy} exists: ${userDoc.exists}');

        if (!groupDoc.exists) {
          // Show error card instead of hiding
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Error: Group not found',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Group ID: ${invitation.groupId}',
                  style: const TextStyle(color: AppTheme.secondaryText, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final groupData = groupDoc.data() as Map<String, dynamic>?;
        final userData = userDoc.data() as Map<String, dynamic>?;

        final groupName = groupData?['name'] ?? 'Unknown Group';
        final inviterName = userData?['name'] ?? 'Unknown';
        final members = List<String>.from(groupData?['members'] ?? []);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.tealAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.tealAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.groups,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style: const TextStyle(
                            color: AppTheme.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invited by $inviterName',
                          style: TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${members.length} members',
                          style: TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectGroupInvitation(invitation.invitationId),
                      style: AppTheme.dangerOutlinedButtonStyle,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptGroupInvitation(invitation.invitationId),
                      style: AppTheme.primaryButtonStyle,
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    // Show dialog to optionally set a nickname
    final nicknameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text(
          'Accept Friend Request',
          style: TextStyle(color: AppTheme.primaryText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a nickname for this friend (optional)',
              style: TextStyle(
                color: AppTheme.secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nicknameController,
              style: const TextStyle(color: AppTheme.primaryText),
              decoration: InputDecoration(
                hintText: 'e.g., My Best Friend',
                hintStyle: TextStyle(color: AppTheme.tertiaryText),
                filled: true,
                fillColor: AppTheme.primaryBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.tealAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.primaryButtonStyle,
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final nickname = nicknameController.text.trim();
      await FriendRequestService.acceptFriendRequest(
        requestId,
        receiverNickname: nickname.isEmpty ? null : nickname,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request accepted!'),
          backgroundColor: AppTheme.tealAccent,
        ),
      );
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

  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      await FriendRequestService.rejectFriendRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friend request declined'),
          backgroundColor: Colors.orange,
        ),
      );
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

  Future<void> _acceptGroupInvitation(String invitationId) async {
    try {
      await GroupInvitationService.acceptGroupInvitation(invitationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group invitation accepted!'),
          backgroundColor: AppTheme.tealAccent,
        ),
      );
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

  Future<void> _rejectGroupInvitation(String invitationId) async {
    try {
      await GroupInvitationService.rejectGroupInvitation(invitationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group invitation declined'),
          backgroundColor: Colors.orange,
        ),
      );
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
}

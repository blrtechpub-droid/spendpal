import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/group_invitation_model.dart';

class GroupInvitationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send a group invitation
  static Future<void> sendGroupInvitation({
    required String groupId,
    required String invitedBy,
    required String invitedUserId,
  }) async {
    // Check if user is already a member
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();

    if (!groupDoc.exists) {
      throw Exception('Group not found');
    }

    final members = List<String>.from(groupDoc.data()?['members'] ?? []);

    if (members.contains(invitedUserId)) {
      throw Exception('User is already a member of this group');
    }

    // Check if invitation already exists
    final existingInvitation = await _firestore
        .collection('groupInvitations')
        .where('groupId', isEqualTo: groupId)
        .where('invitedUserId', isEqualTo: invitedUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingInvitation.docs.isNotEmpty) {
      throw Exception('Invitation already sent to this user');
    }

    // Create invitation
    final invitation = GroupInvitationModel(
      invitationId: '',
      groupId: groupId,
      invitedBy: invitedBy,
      invitedUserId: invitedUserId,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _firestore.collection('groupInvitations').add(invitation.toMap());
  }

  /// Accept a group invitation
  static Future<void> acceptGroupInvitation(String invitationId) async {
    final invitationDoc = await _firestore.collection('groupInvitations').doc(invitationId).get();

    if (!invitationDoc.exists) {
      throw Exception('Invitation not found');
    }

    final invitation = GroupInvitationModel.fromFirestore(invitationDoc);

    if (invitation.status != 'pending') {
      throw Exception('This invitation has already been ${invitation.status}');
    }

    await _firestore.runTransaction((transaction) async {
      // Update invitation status
      transaction.update(invitationDoc.reference, {
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Add user to group members
      final groupRef = _firestore.collection('groups').doc(invitation.groupId);
      transaction.update(groupRef, {
        'members': FieldValue.arrayUnion([invitation.invitedUserId]),
      });
    });
  }

  /// Reject a group invitation
  static Future<void> rejectGroupInvitation(String invitationId) async {
    final invitationDoc = await _firestore.collection('groupInvitations').doc(invitationId).get();

    if (!invitationDoc.exists) {
      throw Exception('Invitation not found');
    }

    final invitation = GroupInvitationModel.fromFirestore(invitationDoc);

    if (invitation.status != 'pending') {
      throw Exception('This invitation has already been ${invitation.status}');
    }

    await invitationDoc.reference.update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel a sent group invitation
  static Future<void> cancelGroupInvitation(String invitationId) async {
    final invitationDoc = await _firestore.collection('groupInvitations').doc(invitationId).get();

    if (!invitationDoc.exists) {
      throw Exception('Invitation not found');
    }

    final invitation = GroupInvitationModel.fromFirestore(invitationDoc);

    if (invitation.status != 'pending') {
      throw Exception('Cannot cancel a ${invitation.status} invitation');
    }

    await invitationDoc.reference.delete();
  }

  /// Get pending group invitations for current user
  static Stream<List<GroupInvitationModel>> getPendingInvitations(String userId) {
    return _firestore
        .collection('groupInvitations')
        .where('invitedUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final invitations = snapshot.docs
              .map((doc) => GroupInvitationModel.fromFirestore(doc))
              .toList();
          // Sort in memory to avoid needing Firestore index
          invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return invitations;
        });
  }

  /// Get pending invitations sent for a specific group
  static Stream<List<GroupInvitationModel>> getGroupPendingInvitations(String groupId) {
    return _firestore
        .collection('groupInvitations')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final invitations = snapshot.docs
              .map((doc) => GroupInvitationModel.fromFirestore(doc))
              .toList();
          // Sort in memory to avoid needing Firestore index
          invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return invitations;
        });
  }

  /// Get count of pending invitations
  static Future<int> getPendingInvitationCount(String userId) async {
    final snapshot = await _firestore
        .collection('groupInvitations')
        .where('invitedUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    return snapshot.docs.length;
  }

  /// Leave a group
  static Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupDoc = await groupRef.get();

    if (!groupDoc.exists) {
      throw Exception('Group not found');
    }

    final groupData = groupDoc.data()!;
    final createdBy = groupData['createdBy'];

    // Check if user is the creator
    if (createdBy == userId) {
      // Transfer ownership or delete group
      final members = List<String>.from(groupData['members'] ?? []);
      members.remove(userId);

      if (members.isEmpty) {
        // Delete group if no members left
        await groupRef.delete();
      } else {
        // Transfer ownership to first remaining member
        await groupRef.update({
          'members': FieldValue.arrayRemove([userId]),
          'createdBy': members.first,
        });
      }
    } else {
      // Just remove user from members
      await groupRef.update({
        'members': FieldValue.arrayRemove([userId]),
      });
    }
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/models/group_model.dart';
import 'package:spendpal/screens/groups/add_group_members_screen.dart';
import 'package:spendpal/services/group_invitation_service.dart';
import 'package:spendpal/theme/app_theme.dart';

class GroupSettingsScreen extends StatefulWidget {
  final GroupModel group;

  const GroupSettingsScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _groupNameController.text = widget.group.name;
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _updateGroupName() async {
    final newName = _groupNameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name cannot be empty')),
      );
      return;
    }

    if (newName == widget.group.name) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name unchanged')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.groupId)
          .update({'name': newName});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group name updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating group name: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isCreator = widget.group.createdBy == currentUserId;

    if (!isCreator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the group creator can remove members')),
      );
      return;
    }

    if (memberId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove yourself. Use "Leave Group" instead')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text(
          'Remove Member',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        content: Text(
          'Are you sure you want to remove $memberName from this group?',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.groupId)
          .update({
        'members': FieldValue.arrayRemove([memberId])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$memberName removed from group')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing member: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _leaveGroup() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isCreator = widget.group.createdBy == currentUserId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text(
          'Leave Group',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        content: Text(
          isCreator
              ? 'You are the creator of this group. Leaving will transfer ownership to another member. Are you sure?'
              : 'Are you sure you want to leave this group?',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: AppTheme.warningColor)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await GroupInvitationService.leaveGroup(
        groupId: widget.group.groupId,
        userId: currentUserId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the group')),
        );
        // Pop twice to go back to groups list (settings screen + group home screen)
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteGroup() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isCreator = widget.group.createdBy == currentUserId;

    if (!isCreator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the group creator can delete the group')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text(
          'Delete Group',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        content: Text(
          'Are you sure you want to delete this group? This action cannot be undone. All expenses in this group will remain but will no longer be associated with this group.',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Delete the group document
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.group.groupId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted successfully')),
        );
        // Pop twice to go back to groups list
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isCreator = widget.group.createdBy == currentUserId;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Group Settings'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.group.groupId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groupData = snapshot.data!.data() as Map<String, dynamic>?;
                if (groupData == null) {
                  return const Center(child: Text('Group not found'));
                }

                final members = List<String>.from(groupData['members'] ?? []);

                return ListView(
                  children: [
                    // Group Name Section
                    _buildSectionHeader('Group Information'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _groupNameController,
                        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                        decoration: AppTheme.inputDecoration(
                          labelText: 'Group Name',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check, color: AppTheme.tealAccent),
                            onPressed: _updateGroupName,
                          ),
                        ),
                      ),
                    ),

                    // Currency Selector
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: DropdownButtonFormField<String>(
                        value: groupData['currency'] ?? '₹',
                        decoration: AppTheme.inputDecoration(
                          labelText: 'Currency',
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                        dropdownColor: theme.cardTheme.color,
                        items: const [
                          DropdownMenuItem(value: '₹', child: Text('₹ INR - Indian Rupee')),
                          DropdownMenuItem(value: '\$', child: Text('\$ USD - US Dollar')),
                          DropdownMenuItem(value: '€', child: Text('€ EUR - Euro')),
                          DropdownMenuItem(value: '£', child: Text('£ GBP - British Pound')),
                          DropdownMenuItem(value: '¥', child: Text('¥ JPY - Japanese Yen')),
                          DropdownMenuItem(value: 'A\$', child: Text('A\$ AUD - Australian Dollar')),
                          DropdownMenuItem(value: 'C\$', child: Text('C\$ CAD - Canadian Dollar')),
                        ],
                        onChanged: (value) async {
                          if (value != null) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('groups')
                                  .doc(widget.group.groupId)
                                  .update({'currency': value});
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Currency updated successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error updating currency: $e')),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Members Section
                    _buildSectionHeader('Members (${members.length})'),
                    ...members.map((memberId) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(memberId)
                            .get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const ListTile(
                              leading: CircleAvatar(child: CircularProgressIndicator()),
                              title: Text('Loading...'),
                            );
                          }

                          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                          final name = userData?['name'] ?? 'Unknown';
                          final photoURL = userData?['photoURL'] ?? '';
                          final isCurrentUser = memberId == currentUserId;
                          final isMemberCreator = memberId == widget.group.createdBy;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.tealAccent,
                              backgroundImage: photoURL.isNotEmpty
                                  ? NetworkImage(photoURL)
                                  : null,
                              child: photoURL.isEmpty
                                  ? Text(
                                      name.substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        color: AppTheme.softWhite(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              isCurrentUser ? 'You' : name,
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: isMemberCreator
                                ? Text(
                                    'Creator',
                                    style: TextStyle(
                                      color: AppTheme.tealAccent,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            trailing: isCreator && !isCurrentUser
                                ? IconButton(
                                    icon: const Icon(Icons.remove_circle, color: AppTheme.errorColor),
                                    onPressed: () => _removeMember(memberId, name),
                                  )
                                : null,
                          );
                        },
                      );
                    }).toList(),

                    // Add Members Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Members'),
                        style: AppTheme.primaryButtonStyle,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddGroupMembersScreen(groupId: widget.group.groupId),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                    Divider(color: theme.dividerTheme.color),

                    // Actions Section
                    _buildSectionHeader('Actions'),

                    // Leave Group
                    ListTile(
                      leading: const Icon(Icons.exit_to_app, color: AppTheme.warningColor),
                      title: Text(
                        'Leave Group',
                        style: TextStyle(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: _leaveGroup,
                    ),

                    // Delete Group (only for creator)
                    if (isCreator)
                      ListTile(
                        leading: const Icon(Icons.delete_forever, color: AppTheme.errorColor),
                        title: Text(
                          'Delete Group',
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: _deleteGroup,
                      ),

                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: TextStyle(
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

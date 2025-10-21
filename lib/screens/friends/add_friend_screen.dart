import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/friend_request_service.dart';
import '../../theme/app_theme.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _searchedUser;

  Future<void> _searchUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchedUser = null;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        if (doc.id == currentUserId) {
          setState(() {
            _errorMessage = 'You cannot add yourself as a friend.';
          });
          return;
        }

        setState(() {
          _searchedUser = UserModel.fromFirestore(doc);
        });
      } else {
        setState(() {
          _errorMessage = 'No user found with that email.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching user: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _searchedUser == null) return;

    setState(() => _isLoading = true);

    try {
      await FriendRequestService.sendFriendRequest(
        fromUserId: currentUser.uid,
        toUserId: _searchedUser!.uid,
        nickname: _nicknameController.text.trim().isEmpty
            ? null
            : _nicknameController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to ${_searchedUser!.name}'),
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground,
        title: const Text(
          "Add Friend",
          style: TextStyle(color: AppTheme.primaryText),
        ),
        iconTheme: const IconThemeData(color: AppTheme.primaryText),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.tealAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.tealAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.tealAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Send a friend request. They\'ll receive a notification and can accept or decline.',
                      style: TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Email input
            TextField(
              controller: _emailController,
              style: const TextStyle(color: AppTheme.primaryText),
              decoration: AppTheme.inputDecoration(
                labelText: 'Friend\'s Email',
                hintText: 'example@email.com',
                prefixIcon: const Icon(
                  Icons.email,
                  color: AppTheme.tealAccent,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Search button
            ElevatedButton(
              onPressed: _isLoading ? null : _searchUser,
              style: AppTheme.primaryButtonStyle,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Search"),
            ),

            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // Search result
            if (_searchedUser != null) ...[
              Container(
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
                          radius: 30,
                          backgroundColor: AppTheme.tealAccent,
                          backgroundImage: (_searchedUser!.photoURL?.isNotEmpty ?? false)
                              ? NetworkImage(_searchedUser!.photoURL!)
                              : null,
                          child: (_searchedUser!.photoURL?.isEmpty ?? true)
                              ? Text(
                                  _searchedUser!.name.isNotEmpty
                                      ? _searchedUser!.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _searchedUser!.name,
                                style: const TextStyle(
                                  color: AppTheme.primaryText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _searchedUser!.email,
                                style: TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppTheme.dividerColor),
                    const SizedBox(height: 16),

                    // Optional nickname
                    TextField(
                      controller: _nicknameController,
                      style: const TextStyle(color: AppTheme.primaryText),
                      decoration: AppTheme.inputDecoration(
                        labelText: 'Nickname (Optional)',
                        hintText: 'How you want to save them',
                        prefixIcon: const Icon(
                          Icons.label,
                          color: AppTheme.tealAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Send request button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _sendFriendRequest,
                        style: AppTheme.primaryButtonStyle,
                        icon: const Icon(Icons.person_add),
                        label: const Text("Send Friend Request"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

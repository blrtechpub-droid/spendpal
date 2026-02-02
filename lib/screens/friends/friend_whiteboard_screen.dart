import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

/// Screen for shared notes between two friends
class FriendWhiteboardScreen extends StatefulWidget {
  final String friendId;
  final String friendName;

  const FriendWhiteboardScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<FriendWhiteboardScreen> createState() => _FriendWhiteboardScreenState();
}

class _FriendWhiteboardScreenState extends State<FriendWhiteboardScreen> {
  late TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Generate consistent combined key for friend pair
  String _getFriendNotesKey(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _saveNotes() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() => _isSaving = true);

    try {
      final docKey = _getFriendNotesKey(currentUserId, widget.friendId);
      final docRef = FirebaseFirestore.instance
          .collection('friendNotes')
          .doc(docKey);

      await docRef.set({
        'notes': _notesController.text.trim(),
        'lastModifiedBy': currentUserId,
        'lastModifiedAt': FieldValue.serverTimestamp(),
        'participant1': currentUserId,
        'participant2': widget.friendId,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save notes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildLastModifiedInfo(String? modifiedByName, DateTime? modifiedAt) {
    if (modifiedByName == null || modifiedAt == null) {
      return const SizedBox.shrink();
    }

    final formattedDate = DateFormat('MMM dd, yyyy • h:mm a').format(modifiedAt);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Last edited by $modifiedByName on $formattedDate',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final docKey = _getFriendNotesKey(currentUserId, widget.friendId);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.friendName} - Notes'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveNotes,
            tooltip: 'Save Notes',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('friendNotes')
            .doc(docKey)
            .snapshots(),
        builder: (context, snapshot) {
          // Handle loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Extract data
          String notes = '';
          String? lastModifiedBy;
          DateTime? lastModifiedAt;
          String? lastModifiedByName;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            notes = data?['notes'] ?? '';
            lastModifiedBy = data?['lastModifiedBy'] as String?;
            final timestamp = data?['lastModifiedAt'] as Timestamp?;
            lastModifiedAt = timestamp?.toDate();

            // Update controller if notes changed from server
            if (_notesController.text != notes && !_isSaving) {
              _notesController.text = notes;
              _notesController.selection = TextSelection.fromPosition(
                TextPosition(offset: _notesController.text.length),
              );
            }
          } else {
            // Document doesn't exist yet - set to empty
            _notesController.text = '';
          }

          return FutureBuilder<String?>(
            future: lastModifiedBy != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(lastModifiedBy)
                    .get()
                    .then((doc) => doc.data()?['name'] as String?)
                : Future.value(null),
            builder: (context, nameSnapshot) {
              lastModifiedByName = nameSnapshot.data;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info card
                    Container(
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Shared notes with ${widget.friendName} for reminders and planning',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Last modified info
                    _buildLastModifiedInfo(lastModifiedByName, lastModifiedAt),
                    const SizedBox(height: 16),

                    // Notes editor
                    Expanded(
                      child: TextField(
                        controller: _notesController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: 'Add shared notes...\n\nExamples:\n• Pending payments\n• Upcoming plans\n• Reminders\n• To-do lists',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveNotes,
                        style: AppTheme.primaryButtonStyle,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(_isSaving ? 'Saving...' : 'Save Notes'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

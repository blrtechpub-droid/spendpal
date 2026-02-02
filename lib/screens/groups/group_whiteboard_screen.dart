import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';

class GroupWhiteboardScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? initialNotes;

  const GroupWhiteboardScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.initialNotes,
  });

  @override
  State<GroupWhiteboardScreen> createState() => _GroupWhiteboardScreenState();
}

class _GroupWhiteboardScreenState extends State<GroupWhiteboardScreen> {
  late TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'notes': _notesController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.groupName} - Notes'),
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
      body: Padding(
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
                      'Shared notes for trip planning, expense tracking, or reminders',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notes editor
            Expanded(
              child: TextField(
                controller: _notesController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Add notes, to-do lists, or trip plans...\n\nExamples:\n• Pending payments\n• Upcoming expenses\n• Trip itinerary\n• Shopping list',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Save button (alternative to app bar)
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
      ),
    );
  }
}

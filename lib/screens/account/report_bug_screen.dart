import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/theme/app_theme.dart';

class ReportBugScreen extends StatefulWidget {
  const ReportBugScreen({super.key});

  @override
  State<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends State<ReportBugScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();

  String _selectedPriority = 'Medium';
  String _selectedPlatform = 'Android';
  bool _isSubmitting = false;

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Critical'];
  final List<String> _platforms = ['Android', 'iOS', 'Web', 'All'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _submitBugReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userName = userDoc.data()?['name'] ?? 'Unknown User';
      final userEmail = userDoc.data()?['email'] ?? currentUser.email ?? '';

      // Create bug report in Firestore
      await FirebaseFirestore.instance.collection('bugReports').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'stepsToReproduce': _stepsController.text.trim(),
        'priority': _selectedPriority,
        'platform': _selectedPlatform,
        'status': 'pending', // pending, synced, closed
        'reportedBy': currentUser.uid,
        'reportedByName': userName,
        'reportedByEmail': userEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'githubIssueNumber': null, // Will be populated when synced
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bug report submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting bug report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground,
        title: const Text(
          'Report a Bug',
          style: TextStyle(color: AppTheme.primaryText),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.tealAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Help us improve SpendPal by reporting bugs you encounter',
                      style: TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Title field
            Text(
              'Bug Title *',
              style: TextStyle(
                color: AppTheme.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: AppTheme.primaryText),
              decoration: InputDecoration(
                hintText: 'Brief description of the bug',
                hintStyle: TextStyle(color: AppTheme.secondaryText),
                filled: true,
                fillColor: AppTheme.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a bug title';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Description field
            Text(
              'Description *',
              style: TextStyle(
                color: AppTheme.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: AppTheme.primaryText),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'What happened? What did you expect to happen?',
                hintStyle: TextStyle(color: AppTheme.secondaryText),
                filled: true,
                fillColor: AppTheme.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please describe the bug';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Steps to reproduce
            Text(
              'Steps to Reproduce',
              style: TextStyle(
                color: AppTheme.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _stepsController,
              style: const TextStyle(color: AppTheme.primaryText),
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '1. Go to...\n2. Click on...\n3. See error...',
                hintStyle: TextStyle(color: AppTheme.secondaryText),
                filled: true,
                fillColor: AppTheme.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Priority selection
            Text(
              'Priority',
              style: TextStyle(
                color: AppTheme.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: _selectedPriority,
                isExpanded: true,
                dropdownColor: AppTheme.cardBackground,
                style: const TextStyle(color: AppTheme.primaryText, fontSize: 16),
                underline: const SizedBox(),
                items: _priorities.map((priority) {
                  Color priorityColor;
                  switch (priority) {
                    case 'Critical':
                      priorityColor = Colors.red;
                      break;
                    case 'High':
                      priorityColor = Colors.orange;
                      break;
                    case 'Medium':
                      priorityColor = Colors.yellow;
                      break;
                    default:
                      priorityColor = Colors.green;
                  }
                  return DropdownMenuItem(
                    value: priority,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: priorityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(priority),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPriority = value;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 20),

            // Platform selection
            Text(
              'Platform',
              style: TextStyle(
                color: AppTheme.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: _selectedPlatform,
                isExpanded: true,
                dropdownColor: AppTheme.cardBackground,
                style: const TextStyle(color: AppTheme.primaryText, fontSize: 16),
                underline: const SizedBox(),
                items: _platforms.map((platform) {
                  IconData platformIcon;
                  switch (platform) {
                    case 'iOS':
                      platformIcon = Icons.apple;
                      break;
                    case 'Android':
                      platformIcon = Icons.android;
                      break;
                    case 'Web':
                      platformIcon = Icons.web;
                      break;
                    default:
                      platformIcon = Icons.devices;
                  }
                  return DropdownMenuItem(
                    value: platform,
                    child: Row(
                      children: [
                        Icon(platformIcon, size: 20, color: AppTheme.tealAccent),
                        const SizedBox(width: 12),
                        Text(platform),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPlatform = value;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitBugReport,
                style: AppTheme.primaryButtonStyle,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Bug Report',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Cancel button
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.secondaryText,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

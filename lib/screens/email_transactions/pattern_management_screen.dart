import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/email_pattern_model.dart';
import '../../services/smart_email_parser_service.dart';

/// Screen to manage user's custom email parsing patterns
/// Allows activating/deactivating, viewing details, and deleting patterns
class PatternManagementScreen extends StatefulWidget {
  const PatternManagementScreen({super.key});

  @override
  State<PatternManagementScreen> createState() =>
      _PatternManagementScreenState();
}

class _PatternManagementScreenState extends State<PatternManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Email Pattern Management')),
        body: const Center(child: Text('Please login to manage patterns')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Email Pattern Management',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              SmartEmailParserService.clearCache();
              setState(() {}); // Trigger rebuild
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pattern cache refreshed')),
              );
            },
            tooltip: 'Refresh patterns',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('customEmailPatterns')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading patterns: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final patterns = snapshot.data?.docs ?? [];

          if (patterns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.pattern,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No custom patterns yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload an email screenshot to create patterns',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: patterns.length,
            itemBuilder: (context, index) {
              final doc = patterns[index];
              final pattern = EmailPattern.fromFirestore(doc);

              return _buildPatternCard(pattern);
            },
          );
        },
      ),
    );
  }

  Widget _buildPatternCard(EmailPattern pattern) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        children: [
          // Header with bank name and toggle
          ListTile(
            leading: CircleAvatar(
              backgroundColor: pattern.active
                  ? Colors.green.shade100
                  : Colors.grey.shade200,
              child: Icon(
                pattern.active ? Icons.check_circle : Icons.circle_outlined,
                color: pattern.active ? Colors.green : Colors.grey,
              ),
            ),
            title: Text(
              pattern.bankName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              pattern.bankDomain,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            trailing: Switch(
              value: pattern.active,
              onChanged: (value) => _togglePatternStatus(pattern, value),
            ),
          ),

          const Divider(height: 1),

          // Pattern details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Confidence and priority
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        'Confidence',
                        '${(pattern.actualConfidence * 100).toStringAsFixed(0)}%',
                        pattern.actualConfidence > 0.7
                            ? Colors.green
                            : pattern.actualConfidence > 0.5
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        'Priority',
                        '${pattern.priority}',
                        Colors.blue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Usage stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatColumn(
                        'Used',
                        '${pattern.usageCount}x',
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatColumn(
                        'Success',
                        '${pattern.successCount}',
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildStatColumn(
                        'Failed',
                        '${pattern.failureCount}',
                        Colors.red,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Gmail filter keywords
                if (pattern.gmailFilter != null &&
                    pattern.gmailFilter!['keywords'] != null) ...[
                  const Text(
                    'Keywords:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (pattern.gmailFilter!['keywords'] as List<dynamic>)
                        .map((keyword) => Chip(
                              label: Text(
                                keyword.toString(),
                                style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500),
                              ),
                              backgroundColor: Colors.blue.shade100,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 0,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 12),

                // Tags
                if (pattern.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: pattern.tags
                        .map((tag) => Chip(
                              label: Text(
                                tag,
                                style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w500),
                              ),
                              backgroundColor: Colors.purple.shade100,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 0,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],

                // Creation date
                Text(
                  'Created: ${_formatDate(pattern.createdAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          ButtonBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showPatternDetails(pattern),
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Details'),
              ),
              TextButton.icon(
                onPressed: () => _editPattern(pattern),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () => _deletePattern(pattern),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _togglePatternStatus(EmailPattern pattern, bool active) async {
    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('customEmailPatterns')
          .doc(pattern.id)
          .update({'active': active});

      // Clear cache to reload patterns
      SmartEmailParserService.clearCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active
                  ? 'Pattern activated for ${pattern.bankName}'
                  : 'Pattern deactivated',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating pattern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPatternDetails(EmailPattern pattern) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(pattern.bankName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Bank Domain', pattern.bankDomain),
              _buildDetailRow('Priority', '${pattern.priority}'),
              _buildDetailRow(
                'Confidence',
                '${(pattern.actualConfidence * 100).toStringAsFixed(1)}%',
              ),
              _buildDetailRow('Usage Count', '${pattern.usageCount}'),
              _buildDetailRow('Success Count', '${pattern.successCount}'),
              _buildDetailRow('Failure Count', '${pattern.failureCount}'),
              _buildDetailRow('Verified', pattern.verified ? 'Yes' : 'No'),
              _buildDetailRow('Active', pattern.active ? 'Yes' : 'No'),
              if (pattern.createdAt != null)
                _buildDetailRow('Created', _formatDate(pattern.createdAt)),
              const SizedBox(height: 16),
              const Text(
                'Regex Patterns:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                pattern.patterns.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePattern(EmailPattern pattern) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pattern'),
        content: Text(
          'Are you sure you want to delete the pattern for ${pattern.bankName}?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('customEmailPatterns')
            .doc(pattern.id)
            .delete();

        // Clear cache
        SmartEmailParserService.clearCache();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pattern for ${pattern.bankName} deleted'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting pattern: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _editPattern(EmailPattern pattern) {
    // Controllers for text fields
    final amountRegexController = TextEditingController(
      text: pattern.patterns['amount']?['regex'] ?? '',
    );
    final merchantRegexController = TextEditingController(
      text: pattern.patterns['merchant']?['regex'] ?? '',
    );
    final dateRegexController = TextEditingController(
      text: pattern.patterns['date']?['regex'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Pattern - ${pattern.bankName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit the regex patterns below:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountRegexController,
                decoration: const InputDecoration(
                  labelText: 'Amount Regex',
                  hintText: r'Rs\.?\s*(\d+(?:,\d+)*(?:\.\d{2})?)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: merchantRegexController,
                decoration: const InputDecoration(
                  labelText: 'Merchant Regex',
                  hintText: r'at\s+([A-Z\s]+)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateRegexController,
                decoration: const InputDecoration(
                  labelText: 'Date Regex',
                  hintText: r'(\d{2}-\d{2}-\d{4})',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              // Update the pattern in Firestore
              try {
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('customEmailPatterns')
                    .doc(pattern.id)
                    .update({
                  'patterns.amount.regex': amountRegexController.text,
                  'patterns.merchant.regex': merchantRegexController.text,
                  'patterns.date.regex': dateRegexController.text,
                });

                // Clear cache
                SmartEmailParserService.clearCache();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pattern updated for ${pattern.bankName}'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating pattern: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }
}

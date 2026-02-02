import 'package:flutter/material.dart';
import '../../models/account_tracker_model.dart';
import '../../services/account_tracker_service.dart';
import '../../theme/app_theme.dart';

class EditTrackerDialog extends StatefulWidget {
  final String userId;
  final AccountTrackerModel tracker;

  const EditTrackerDialog({
    super.key,
    required this.userId,
    required this.tracker,
  });

  @override
  State<EditTrackerDialog> createState() => _EditTrackerDialogState();
}

class _EditTrackerDialogState extends State<EditTrackerDialog> {
  late TextEditingController _nameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _emailDomainController;
  late TextEditingController _smsSenderController;

  late List<String> _emailDomains;
  late List<String> _smsSenders;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tracker.name);
    _accountNumberController = TextEditingController(text: widget.tracker.accountNumber ?? '');
    _emailDomainController = TextEditingController();
    _smsSenderController = TextEditingController();

    _emailDomains = List.from(widget.tracker.emailDomains);
    _smsSenders = List.from(widget.tracker.smsSenders);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountNumberController.dispose();
    _emailDomainController.dispose();
    _smsSenderController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tracker name cannot be empty'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedTracker = widget.tracker.copyWith(
        name: _nameController.text.trim(),
        accountNumber: _accountNumberController.text.trim().isEmpty
            ? null
            : _accountNumberController.text.trim(),
        emailDomains: _emailDomains,
        smsSenders: _smsSenders,
        updatedAt: DateTime.now(),
      );

      final success = await AccountTrackerService.updateTracker(updatedTracker);

      if (mounted) {
        if (success) {
          Navigator.pop(context, true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.tracker.name} updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update tracker'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addEmailDomain() {
    final domain = _emailDomainController.text.trim().toLowerCase();

    if (domain.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email domain')),
      );
      return;
    }

    if (_emailDomains.contains(domain)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Domain already exists')),
      );
      return;
    }

    setState(() {
      _emailDomains.add(domain);
      _emailDomainController.clear();
    });
  }

  void _removeEmailDomain(String domain) {
    setState(() {
      _emailDomains.remove(domain);
    });
  }

  void _addSmsSender() {
    final sender = _smsSenderController.text.trim().toUpperCase();

    if (sender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an SMS sender ID')),
      );
      return;
    }

    if (_smsSenders.contains(sender)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sender already exists')),
      );
      return;
    }

    setState(() {
      _smsSenders.add(sender);
      _smsSenderController.clear();
    });
  }

  void _removeSmsSender(String sender) {
    setState(() {
      _smsSenders.remove(sender);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.tracker.colorHex != null
        ? Color(int.parse('0xFF${widget.tracker.colorHex!.replaceAll('#', '')}'))
        : AppTheme.tealAccent;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700, maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        widget.tracker.emoji ?? widget.tracker.typeEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Tracker',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Tracker Name
                  Text(
                    'Tracker Name',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g., HDFC Bank Savings',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Account Number (Optional)
                  Text(
                    'Account Number (Last 4 digits)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _accountNumberController,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g., 1234 (optional)',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      counterText: '',
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Email Domains
                  Row(
                    children: [
                      Text(
                        'Email Domains',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_emailDomains.length} domain(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Add email domain field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailDomainController,
                          decoration: InputDecoration(
                            hintText: 'e.g., hdfcbank.com',
                            filled: true,
                            fillColor: theme.scaffoldBackgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.email, size: 20),
                          ),
                          onSubmitted: (_) => _addEmailDomain(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _addEmailDomain,
                        icon: const Icon(Icons.add, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  // Email domain chips
                  if (_emailDomains.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _emailDomains.map((domain) {
                        return Chip(
                          label: Text(domain),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () => _removeEmailDomain(domain),
                          backgroundColor: color.withValues(alpha: 0.1),
                          side: BorderSide(color: color.withValues(alpha: 0.3)),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // SMS Senders
                  Row(
                    children: [
                      Text(
                        'SMS Sender IDs',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_smsSenders.length} sender(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Add SMS sender field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _smsSenderController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'e.g., VM-HDFCBK',
                            filled: true,
                            fillColor: theme.scaffoldBackgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.message, size: 20),
                          ),
                          onSubmitted: (_) => _addSmsSender(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _addSmsSender,
                        icon: const Icon(Icons.add, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  // SMS sender chips
                  if (_smsSenders.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _smsSenders.map((sender) {
                        return Chip(
                          label: Text(sender),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () => _removeSmsSender(sender),
                          backgroundColor: color.withValues(alpha: 0.1),
                          side: BorderSide(color: color.withValues(alpha: 0.3)),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Help text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Add email domains and SMS sender IDs to automatically match transactions from this account.',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer with Save button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppTheme.dividerColor),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

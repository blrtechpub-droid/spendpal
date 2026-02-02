import 'package:flutter/material.dart';
import 'package:spendpal/models/account_tracker_model.dart';
import 'package:spendpal/models/local_transaction_model.dart';
import 'package:spendpal/services/account_tracker_service.dart';
import 'package:spendpal/services/local_db_service.dart';
import 'package:spendpal/config/tracker_registry.dart';

/// Widget to display tracker badge on transactions
///
/// Shows tracker name, icon, and confidence score
/// For unknown transactions, shows "Unknown - Tap to add" badge
class TrackerBadge extends StatelessWidget {
  final String? trackerId;
  final double? confidence;
  final String userId;
  final bool compact;
  final LocalTransactionModel? transaction; // Optional transaction for creating tracker

  const TrackerBadge({
    super.key,
    required this.trackerId,
    this.confidence,
    required this.userId,
    this.compact = false,
    this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    if (trackerId == null) {
      // Show "Unknown Account" badge with tap to add tracker
      return _buildUnknownBadge(context);
    }

    return FutureBuilder<AccountTrackerModel?>(
      future: AccountTrackerService.getTracker(userId, trackerId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final tracker = snapshot.data!;
        final template = TrackerRegistry.getTemplate(tracker.category);

        if (compact) {
          return _buildCompactBadge(tracker, template, context);
        } else {
          return _buildFullBadge(tracker, template, context);
        }
      },
    );
  }

  Widget _buildCompactBadge(
    AccountTrackerModel tracker,
    TrackerTemplate? template,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final color = template != null
        ? template.color
        : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            template?.emoji ?? '💳',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            tracker.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.9),
            ),
          ),
          if (confidence != null && confidence! > 0) ...[
            const SizedBox(width: 4),
            Icon(
              _getConfidenceIcon(confidence!),
              size: 12,
              color: color.withOpacity(0.7),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullBadge(
    AccountTrackerModel tracker,
    TrackerTemplate? template,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final color = template != null
        ? template.color
        : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              template?.emoji ?? '💳',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 10),
          // Details
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tracker.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (confidence != null && confidence! > 0) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      _getConfidenceIcon(confidence!),
                      size: 12,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(confidence! * 100).toStringAsFixed(0)}% match',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownBadge(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: transaction != null ? () => _showCreateTrackerDialog(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '❓',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
            Text(
              transaction != null ? 'Unknown - Tap to add' : 'Unknown Account',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTrackerDialog(BuildContext context) {
    if (transaction == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateTrackerSheet(
        userId: userId,
        transaction: transaction!,
      ),
    );
  }

  IconData _getConfidenceIcon(double confidence) {
    if (confidence >= 0.9) {
      return Icons.verified;
    } else if (confidence >= 0.7) {
      return Icons.check_circle_outline;
    } else {
      return Icons.help_outline;
    }
  }
}

/// Bottom sheet for creating a tracker from unknown transaction
class _CreateTrackerSheet extends StatefulWidget {
  final String userId;
  final LocalTransactionModel transaction;

  const _CreateTrackerSheet({
    required this.userId,
    required this.transaction,
  });

  @override
  State<_CreateTrackerSheet> createState() => _CreateTrackerSheetState();
}

class _CreateTrackerSheetState extends State<_CreateTrackerSheet> {
  TrackerCategory? _selectedCategory;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Try to detect category from source
    _selectedCategory = _detectCategory();
  }

  TrackerCategory? _detectCategory() {
    if (widget.transaction.sourceIdentifier == null) return null;

    if (widget.transaction.source == TransactionSource.sms) {
      final matches = TrackerRegistry.findMatchingCategoriesForSms(
        widget.transaction.sourceIdentifier!,
      );
      return matches.isNotEmpty ? matches.first : null;
    } else if (widget.transaction.source == TransactionSource.email) {
      final matches = TrackerRegistry.findMatchingCategoriesForEmail(
        widget.transaction.sourceIdentifier!,
      );
      return matches.isNotEmpty ? matches.first : null;
    }
    return null;
  }

  Future<void> _createTracker() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an account type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Create tracker from template
      final tracker = await AccountTrackerService.addTrackerFromTemplate(
        userId: widget.userId,
        category: _selectedCategory!,
      );

      if (tracker == null) {
        throw Exception('Failed to create tracker');
      }

      // Link this transaction to the tracker
      final updatedTransaction = widget.transaction.copyWith(
        trackerId: tracker.id,
        trackerConfidence: 0.85,
      );

      await LocalDBService.instance.updateTransaction(updatedTransaction);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created "${tracker.name}" and linked transaction'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableTemplates = TrackerRegistry.templates.values.toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Add Account Tracker',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Transaction info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaction from:',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.transaction.sourceIdentifier ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Select account type:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),

          const SizedBox(height: 12),

          // Template grid
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: availableTemplates.length,
              itemBuilder: (context, index) {
                final template = availableTemplates[index];
                final isSelected = _selectedCategory == template.category;

                return InkWell(
                  onTap: () => setState(() => _selectedCategory = template.category),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? template.color.withValues(alpha: 0.2)
                          : theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? template.color
                            : theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          template.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            template.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Create button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCreating ? null : _createTracker,
              icon: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(_isCreating ? 'Creating...' : 'Create Tracker'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedCategory != null
                    ? TrackerRegistry.getTemplate(_selectedCategory!)?.color
                    : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

/// Tracker chip for filtering
class TrackerFilterChip extends StatelessWidget {
  final AccountTrackerModel tracker;
  final bool isSelected;
  final VoidCallback onTap;

  const TrackerFilterChip({
    super.key,
    required this.tracker,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final template = TrackerRegistry.getTemplate(tracker.category);
    final color = template?.color ?? Colors.grey;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            template?.emoji ?? '💳',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            tracker.name,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: color.withOpacity(0.3),
      checkmarkColor: color,
      side: BorderSide(
        color: isSelected ? color : color.withOpacity(0.3),
        width: isSelected ? 2 : 1,
      ),
    );
  }
}

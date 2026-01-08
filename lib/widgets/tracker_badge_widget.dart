import 'package:flutter/material.dart';
import 'package:spendpal/models/account_tracker_model.dart';
import 'package:spendpal/services/account_tracker_service.dart';
import 'package:spendpal/config/tracker_registry.dart';

/// Widget to display tracker badge on transactions
///
/// Shows tracker name, icon, and confidence score
class TrackerBadge extends StatelessWidget {
  final String? trackerId;
  final double? confidence;
  final String userId;
  final bool compact;

  const TrackerBadge({
    super.key,
    required this.trackerId,
    this.confidence,
    required this.userId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (trackerId == null) {
      return const SizedBox.shrink();
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

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/models/tracker_suggestion_model.dart';
import 'package:spendpal/services/tracker_suggestion_service.dart';
import 'package:spendpal/theme/app_theme.dart';

/// Widget to display smart tracker suggestions based on unmatched transactions
///
/// Shows suggestions for creating trackers for known banks/wallets
/// when multiple transactions from same source are detected.
class TrackerSuggestionsWidget extends StatefulWidget {
  final VoidCallback? onTrackerCreated; // Callback to refresh transaction list

  const TrackerSuggestionsWidget({
    super.key,
    this.onTrackerCreated,
  });

  @override
  State<TrackerSuggestionsWidget> createState() => _TrackerSuggestionsWidgetState();
}

class _TrackerSuggestionsWidgetState extends State<TrackerSuggestionsWidget> {
  List<TrackerSuggestion> _suggestions = [];
  bool _isLoading = true;
  final Set<String> _dismissedInSession = {}; // Track dismissals in current session

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final suggestions = await TrackerSuggestionService.generateSuggestions(
        userId: userId,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions.where((s) => s.isRelevant).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acceptSuggestion(TrackerSuggestion suggestion) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Creating tracker for ${suggestion.displayName}...'),
            ],
          ),
          duration: const Duration(seconds: 30),
        ),
      );

      // Create tracker and link transactions
      final tracker = await TrackerSuggestionService.acceptSuggestion(
        userId: userId,
        suggestion: suggestion,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      if (tracker != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Created "${tracker.name}" and linked ${suggestion.transactionCount} transactions'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Remove from list and notify parent
        setState(() {
          _suggestions.remove(suggestion);
        });

        widget.onTrackerCreated?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to create tracker'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _dismissSuggestion(TrackerSuggestion suggestion) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await TrackerSuggestionService.dismissSuggestion(
      userId: userId,
      suggestion: suggestion,
    );

    setState(() {
      _suggestions.remove(suggestion);
      _dismissedInSession.add(suggestion.category.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink(); // Don't show loading spinner
    }

    final visibleSuggestions = _suggestions
        .where((s) => !_dismissedInSession.contains(s.category.name))
        .toList();

    if (visibleSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.tealAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.tealAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb, color: AppTheme.tealAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Create trackers for these accounts?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Suggestions list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: visibleSuggestions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final suggestion = visibleSuggestions[index];
            return _buildSuggestionCard(suggestion);
          },
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSuggestionCard(TrackerSuggestion suggestion) {
    final theme = Theme.of(context);

    return Card(
      color: theme.cardTheme.color,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.tealAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Emoji icon
                Text(
                  suggestion.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                // Name and stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${suggestion.transactionCount} transactions • ₹${suggestion.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Detected sender
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.message,
                    size: 14,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'From: ${suggestion.detectedSender}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptSuggestion(suggestion),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Create Tracker', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tealAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _dismissSuggestion(suggestion),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textTheme.bodyMedium?.color,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppTheme.dividerColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Dismiss', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

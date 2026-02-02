import 'package:spendpal/models/tracker_suggestion_model.dart';
import 'package:spendpal/models/local_transaction_model.dart';
import 'package:spendpal/models/account_tracker_model.dart';
import 'package:spendpal/config/tracker_registry.dart';
import 'package:spendpal/services/local_db_service.dart';
import 'package:spendpal/services/account_tracker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for managing tracker creation suggestions
///
/// Analyzes unmatched transactions and suggests tracker creation
/// when multiple transactions from a known bank/wallet are detected.
class TrackerSuggestionService {
  static const String _dismissedSuggestionsKey = 'dismissed_tracker_suggestions';
  static const int _minTransactionsForSuggestion = 2;

  /// Analyze transactions and generate tracker suggestions
  ///
  /// Returns list of suggestions for trackers that should be created
  /// based on unmatched transactions from known banks/wallets.
  static Future<List<TrackerSuggestion>> generateSuggestions({
    required String userId,
  }) async {
    try {
      // Get all pending transactions without tracker
      final transactions = await LocalDBService.instance.getTransactions(
        userId: userId,
        status: TransactionStatus.pending,
      );

      // Filter transactions without tracker
      final unmatchedTransactions = transactions.where((t) => t.trackerId == null).toList();

      if (unmatchedTransactions.isEmpty) {
        return [];
      }

      // Get user's existing trackers to avoid suggesting duplicates
      final existingTrackers = await AccountTrackerService.getActiveTrackers(userId);
      final existingCategories = existingTrackers.map((t) => t.category).toSet();

      // Group transactions by detected category
      final Map<TrackerCategory, List<LocalTransactionModel>> categoryGroups = {};

      for (final transaction in unmatchedTransactions) {
        if (transaction.sourceIdentifier == null) continue;

        // Detect category from sender
        final category = _detectCategory(
          transaction.source,
          transaction.sourceIdentifier!,
        );

        if (category != null && !existingCategories.contains(category)) {
          categoryGroups.putIfAbsent(category, () => []);
          categoryGroups[category]!.add(transaction);
        }
      }

      // Generate suggestions for categories with enough transactions
      final suggestions = <TrackerSuggestion>[];
      final dismissedCategories = await _getDismissedCategories(userId);

      for (final entry in categoryGroups.entries) {
        final category = entry.key;
        final txns = entry.value;

        // Skip if not enough transactions or user dismissed
        if (txns.length < _minTransactionsForSuggestion) continue;
        if (dismissedCategories.contains(category.name)) continue;

        // Calculate stats
        final totalAmount = txns.fold<double>(0, (sum, t) => sum + t.amount);
        final firstSeen = txns.map((t) => t.transactionDate).reduce(
          (a, b) => a.isBefore(b) ? a : b,
        );
        final lastSeen = txns.map((t) => t.transactionDate).reduce(
          (a, b) => a.isAfter(b) ? a : b,
        );

        suggestions.add(TrackerSuggestion(
          category: category,
          detectedSender: txns.first.sourceIdentifier!,
          transactionCount: txns.length,
          totalAmount: totalAmount,
          firstSeenAt: firstSeen,
          lastSeenAt: lastSeen,
        ));
      }

      // Sort by transaction count (most transactions first)
      suggestions.sort((a, b) => b.transactionCount.compareTo(a.transactionCount));

      return suggestions;
    } catch (e) {
      print('❌ Error generating tracker suggestions: $e');
      return [];
    }
  }

  /// Create tracker from suggestion and link past transactions
  ///
  /// Returns the created tracker if successful
  static Future<AccountTrackerModel?> acceptSuggestion({
    required String userId,
    required TrackerSuggestion suggestion,
  }) async {
    try {
      print('✅ Accepting suggestion: ${suggestion.displayName}');

      // Create tracker from template
      final tracker = await AccountTrackerService.addTrackerFromTemplate(
        userId: userId,
        category: suggestion.category,
      );

      if (tracker == null) {
        print('❌ Failed to create tracker from suggestion');
        return null;
      }

      print('✅ Tracker created: ${tracker.name} (${tracker.id})');

      // Retroactively link past unmatched transactions
      final linkedCount = await _linkPastTransactions(
        userId: userId,
        category: suggestion.category,
        trackerId: tracker.id,
      );

      print('✅ Linked $linkedCount past transactions to tracker ${tracker.name}');

      return tracker;
    } catch (e) {
      print('❌ Error accepting suggestion: $e');
      return null;
    }
  }

  /// Dismiss a suggestion (user doesn't want this tracker)
  ///
  /// Remembers dismissal so we don't suggest again
  static Future<void> dismissSuggestion({
    required String userId,
    required TrackerSuggestion suggestion,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = await _getDismissedCategories(userId);
      dismissed.add(suggestion.category.name);

      await prefs.setString(
        '${_dismissedSuggestionsKey}_$userId',
        jsonEncode(dismissed.toList()),
      );

      print('ℹ️ Dismissed suggestion: ${suggestion.displayName}');
    } catch (e) {
      print('❌ Error dismissing suggestion: $e');
    }
  }

  /// Clear all dismissed suggestions (for testing or user reset)
  static Future<void> clearDismissed({required String userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_dismissedSuggestionsKey}_$userId');
      print('ℹ️ Cleared dismissed suggestions');
    } catch (e) {
      print('❌ Error clearing dismissed suggestions: $e');
    }
  }

  /// Detect tracker category from transaction source and sender
  static TrackerCategory? _detectCategory(
    TransactionSource source,
    String sender,
  ) {
    if (source == TransactionSource.sms) {
      final matches = TrackerRegistry.findMatchingCategoriesForSms(sender);
      return matches.isNotEmpty ? matches.first : null;
    } else if (source == TransactionSource.email) {
      final matches = TrackerRegistry.findMatchingCategoriesForEmail(sender);
      return matches.isNotEmpty ? matches.first : null;
    }
    return null;
  }

  /// Link all past unmatched transactions from this category to the tracker
  ///
  /// Returns number of transactions linked
  static Future<int> _linkPastTransactions({
    required String userId,
    required TrackerCategory category,
    required String trackerId,
  }) async {
    try {
      // Get all pending transactions without tracker
      final transactions = await LocalDBService.instance.getTransactions(
        userId: userId,
        status: TransactionStatus.pending,
      );

      final unmatchedTransactions = transactions.where((t) => t.trackerId == null).toList();

      int linkedCount = 0;

      for (final transaction in unmatchedTransactions) {
        if (transaction.sourceIdentifier == null) continue;

        // Check if this transaction matches the category
        final detectedCategory = _detectCategory(
          transaction.source,
          transaction.sourceIdentifier!,
        );

        if (detectedCategory == category) {
          // Update transaction with tracker ID
          final updated = transaction.copyWith(
            trackerId: trackerId,
            trackerConfidence: 0.85, // Auto-linked confidence
          );

          await LocalDBService.instance.updateTransaction(updated);
          linkedCount++;
        }
      }

      return linkedCount;
    } catch (e) {
      print('❌ Error linking past transactions: $e');
      return 0;
    }
  }

  /// Get set of dismissed category names for user
  static Future<Set<String>> _getDismissedCategories(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('${_dismissedSuggestionsKey}_$userId');

      if (json == null) return {};

      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (e) {
      return {};
    }
  }
}

import '../models/account_tracker_model.dart';
import '../models/local_transaction_model.dart';
import '../config/tracker_registry.dart';
import 'account_tracker_service.dart';

/// Service for matching incoming transactions to account trackers
///
/// This service analyzes SMS/email senders and matches them to configured
/// account trackers, enabling automatic categorization by source account.
class TrackerMatchingService {
  /// Match transaction to account tracker
  ///
  /// Returns a tuple of (trackerId, confidence) if a match is found
  /// Returns null if no match is found
  ///
  /// Confidence scoring:
  /// - 1.0: Perfect match (exact sender match for custom tracker)
  /// - 0.9: High confidence (template SMS sender match)
  /// - 0.85: Auto-created tracker match
  /// - 0.8: Good confidence (template email domain match)
  /// - 0.7: Medium confidence (subdomain match)
  ///
  /// Auto-creation:
  /// If [autoCreateTracker] is true and no existing tracker matches,
  /// will auto-create a tracker for known banks/wallets
  static Future<({String trackerId, double confidence})?> matchTransaction({
    required String userId,
    required TransactionSource source,
    required String sender,
    bool autoCreateTracker = true,
  }) async {
    try {
      // Step 1: Get all active trackers for the user
      final activeTrackers = await AccountTrackerService.getActiveTrackers(userId);

      // Step 2: Try to match against existing trackers
      ({String trackerId, double confidence})? existingMatch;
      if (activeTrackers.isNotEmpty) {
        if (source == TransactionSource.sms) {
          existingMatch = _matchSmsSender(sender, activeTrackers);
        } else if (source == TransactionSource.email) {
          existingMatch = _matchEmailSender(sender, activeTrackers);
        }
      }

      if (existingMatch != null) {
        return existingMatch;
      }

      // Step 3: If no match and auto-create enabled, detect category and create tracker
      if (autoCreateTracker) {
        final category = _detectCategory(source, sender);
        if (category != null) {
          print('🔍 Detected category $category for sender: $sender');
          final newTracker = await _autoCreateTracker(userId, category, sender);
          if (newTracker != null) {
            print('✅ Auto-created tracker: ${newTracker.name} (id: ${newTracker.id})');
            return (trackerId: newTracker.id, confidence: 0.85);
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ Error matching transaction to tracker: $e');
      return null;
    }
  }

  /// Match SMS sender to tracker
  static ({String trackerId, double confidence})? _matchSmsSender(
    String sender,
    List<AccountTrackerModel> trackers,
  ) {
    // Try template-based matching
    for (final tracker in trackers) {
      if (TrackerRegistry.matchesSmsSender(tracker.category, sender)) {
        return (trackerId: tracker.id, confidence: 0.9);
      }
    }

    return null;
  }

  /// Match email sender to tracker
  static ({String trackerId, double confidence})? _matchEmailSender(
    String emailAddress,
    List<AccountTrackerModel> trackers,
  ) {
    // Try custom email domain match from tracker's emailDomains field
    for (final tracker in trackers) {
      if (tracker.emailDomains.isNotEmpty) {
        final atIndex = emailAddress.indexOf('@');
        if (atIndex != -1) {
          final domain = emailAddress.substring(atIndex + 1).toLowerCase();

          for (final trackerDomain in tracker.emailDomains) {
            final normalizedTrackerDomain = trackerDomain.toLowerCase();
            if (domain == normalizedTrackerDomain || domain.endsWith('.$normalizedTrackerDomain')) {
              // Exact match = 1.0, subdomain = 0.95
              final confidence = domain == normalizedTrackerDomain ? 1.0 : 0.95;
              return (trackerId: tracker.id, confidence: confidence);
            }
          }
        }
      }
    }

    // Try template-based matching from TrackerRegistry
    for (final tracker in trackers) {
      if (TrackerRegistry.matchesEmailDomain(tracker.category, emailAddress)) {
        final atIndex = emailAddress.indexOf('@');
        if (atIndex != -1) {
          final domain = emailAddress.substring(atIndex + 1).toLowerCase();
          final trackerDomains = TrackerRegistry.getEmailDomainsForCategory(tracker.category);

          // Check if exact domain match or subdomain
          final isExactMatch = trackerDomains.any((d) => domain == d.toLowerCase());
          final confidence = isExactMatch ? 0.8 : 0.7;

          return (trackerId: tracker.id, confidence: confidence);
        }
      }
    }

    return null;
  }

  /// Match multiple transactions in batch (for bulk processing)
  ///
  /// More efficient than calling matchTransaction repeatedly
  static Future<Map<int, ({String trackerId, double confidence})>> matchBatch({
    required String userId,
    required List<BulkTransactionItem> items,
  }) async {
    try {
      // Get all active trackers once
      final activeTrackers = await AccountTrackerService.getActiveTrackers(userId);

      if (activeTrackers.isEmpty) {
        return {};
      }

      final matches = <int, ({String trackerId, double confidence})>{};

      for (final item in items) {
        final match = item.source == TransactionSource.sms
            ? _matchSmsSender(item.sender, activeTrackers)
            : item.source == TransactionSource.email
                ? _matchEmailSender(item.sender, activeTrackers)
                : null;

        if (match != null) {
          matches[item.index] = match;
        }
      }

      return matches;
    } catch (e) {
      print('❌ Error matching batch: $e');
      return {};
    }
  }

  /// Find all transactions that could match a tracker
  ///
  /// Useful for suggesting tracker assignment to existing transactions
  static Future<List<String>> findPotentialMatches({
    required String trackerId,
    required List<LocalTransactionModel> transactions,
  }) async {
    // This would require loading the tracker to check its senders/domains
    // For now, return empty list (can be implemented later if needed)
    return [];
  }

  /// Detect tracker category from SMS sender or email address
  ///
  /// Returns the category if a known pattern is detected, null otherwise
  static TrackerCategory? _detectCategory(TransactionSource source, String sender) {
    if (source == TransactionSource.sms) {
      final matches = TrackerRegistry.findMatchingCategoriesForSms(sender);
      return matches.isNotEmpty ? matches.first : null;
    } else if (source == TransactionSource.email) {
      final matches = TrackerRegistry.findMatchingCategoriesForEmail(sender);
      return matches.isNotEmpty ? matches.first : null;
    }
    return null;
  }

  /// Auto-create a tracker for the user based on detected category
  ///
  /// Returns the created tracker if successful, null otherwise
  /// Only auto-creates for major banks/wallets to avoid tracker spam
  static Future<AccountTrackerModel?> _autoCreateTracker(
    String userId,
    TrackerCategory category,
    String sender,
  ) async {
    try {
      // Only auto-create for major banks and wallets
      const autoCreateCategories = [
        TrackerCategory.hdfcBank,
        TrackerCategory.iciciBank,
        TrackerCategory.axisBank,
        TrackerCategory.sbiBank,
        TrackerCategory.kotakBank,
        TrackerCategory.paytm,
        TrackerCategory.phonePe,
        TrackerCategory.googlePay,
        TrackerCategory.amazonPay,
        TrackerCategory.zerodha,
        TrackerCategory.groww,
      ];

      if (!autoCreateCategories.contains(category)) {
        print('⏭️  Skipping auto-create for category: $category (not in auto-create list)');
        return null;
      }

      // Get template for this category
      final template = TrackerRegistry.getTemplate(category);
      if (template == null) {
        print('❌ No template found for category: $category');
        return null;
      }

      // Check if user already has a tracker for this category (avoid duplicates)
      final existingTrackers = await AccountTrackerService.getTrackersByType(
        userId,
        template.type,
      );
      final hasCategoryTracker = existingTrackers.any((t) => t.category == category);
      if (hasCategoryTracker) {
        print('⏭️  User already has tracker for $category');
        return null;
      }

      // Create tracker from template using existing service method
      final savedTracker = await AccountTrackerService.addTrackerFromTemplate(
        userId: userId,
        category: category,
      );

      if (savedTracker != null) {
        print('✅ Auto-created tracker: ${template.name} for user $userId');
        print('   Detected from: $sender');
        print('   Category: $category');
      }

      return savedTracker;
    } catch (e) {
      print('❌ Error auto-creating tracker: $e');
      return null;
    }
  }
}

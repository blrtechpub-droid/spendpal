import 'package:spendpal/config/tracker_registry.dart';
import 'package:spendpal/models/account_tracker_model.dart';

/// Model for tracker creation suggestions
///
/// Generated when system detects multiple transactions from a known
/// bank/wallet that the user doesn't have a tracker for yet.
class TrackerSuggestion {
  final TrackerCategory category;
  final String detectedSender; // Original sender that triggered detection
  final int transactionCount; // Number of unmatched transactions
  final double totalAmount; // Total amount from these transactions
  final DateTime firstSeenAt; // When first transaction was detected
  final DateTime lastSeenAt; // When most recent transaction was detected
  final bool isDismissed; // Has user dismissed this suggestion?
  final DateTime? dismissedAt;

  TrackerSuggestion({
    required this.category,
    required this.detectedSender,
    required this.transactionCount,
    required this.totalAmount,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.isDismissed = false,
    this.dismissedAt,
  });

  /// Get template for this category
  TrackerTemplate? get template => TrackerRegistry.getTemplate(category);

  /// Get display name (e.g., "Axis Bank")
  String get displayName => template?.name ?? category.name;

  /// Get emoji icon
  String get emoji => template?.emoji ?? '🏦';

  /// Get color hex
  String get colorHex => template?.colorHex ?? '0275D8';

  /// Check if suggestion is still relevant (not dismissed, recent activity)
  bool get isRelevant {
    if (isDismissed) return false;

    // Suggestion expires after 30 days of no activity
    final daysSinceLastSeen = DateTime.now().difference(lastSeenAt).inDays;
    return daysSinceLastSeen <= 30;
  }

  /// Create a copy with updated fields
  TrackerSuggestion copyWith({
    TrackerCategory? category,
    String? detectedSender,
    int? transactionCount,
    double? totalAmount,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    bool? isDismissed,
    DateTime? dismissedAt,
  }) {
    return TrackerSuggestion(
      category: category ?? this.category,
      detectedSender: detectedSender ?? this.detectedSender,
      transactionCount: transactionCount ?? this.transactionCount,
      totalAmount: totalAmount ?? this.totalAmount,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isDismissed: isDismissed ?? this.isDismissed,
      dismissedAt: dismissedAt ?? this.dismissedAt,
    );
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'category': category.name,
      'detectedSender': detectedSender,
      'transactionCount': transactionCount,
      'totalAmount': totalAmount,
      'firstSeenAt': firstSeenAt.toIso8601String(),
      'lastSeenAt': lastSeenAt.toIso8601String(),
      'isDismissed': isDismissed,
      'dismissedAt': dismissedAt?.toIso8601String(),
    };
  }

  /// Create from map
  factory TrackerSuggestion.fromMap(Map<String, dynamic> map) {
    return TrackerSuggestion(
      category: TrackerCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => TrackerCategory.hdfcBank,
      ),
      detectedSender: map['detectedSender'] as String,
      transactionCount: map['transactionCount'] as int,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      firstSeenAt: DateTime.parse(map['firstSeenAt'] as String),
      lastSeenAt: DateTime.parse(map['lastSeenAt'] as String),
      isDismissed: map['isDismissed'] as bool? ?? false,
      dismissedAt: map['dismissedAt'] != null
          ? DateTime.parse(map['dismissedAt'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'TrackerSuggestion($displayName, $transactionCount txns, ₹$totalAmount)';
  }
}

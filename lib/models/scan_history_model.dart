import 'local_transaction_model.dart';

/// Model for tracking scan history with cost information
class ScanHistoryModel {
  final String id;
  final String userId;
  final DateTime scanDate;
  final TransactionSource source; // sms or email
  final ScanMode mode; // fast or ai
  final int daysScanned; // e.g., 7, 15, 30, 60, 90
  final DateTime rangeStart;
  final DateTime rangeEnd;

  // Scan statistics
  final int totalMessages;
  final int filteredMessages; // After bank filter
  final int alreadyProcessed; // Skipped duplicates
  final int patternMatched; // Matched by regex
  final int aiProcessed; // Sent to AI
  final int transactionsFound; // Total transactions extracted
  final int newPatternsLearned; // Patterns created from AI

  // Cost calculation (₹0.13 per AI call)
  double get cost => aiProcessed * 0.13;
  double get potentialCost => (patternMatched + aiProcessed) * 0.13;
  double get savedCost => potentialCost - cost;
  double get savingsPercent => potentialCost > 0 ? (savedCost / potentialCost * 100) : 0;

  ScanHistoryModel({
    required this.id,
    required this.userId,
    required this.scanDate,
    required this.source,
    required this.mode,
    required this.daysScanned,
    required this.rangeStart,
    required this.rangeEnd,
    this.totalMessages = 0,
    this.filteredMessages = 0,
    this.alreadyProcessed = 0,
    this.patternMatched = 0,
    this.aiProcessed = 0,
    this.transactionsFound = 0,
    this.newPatternsLearned = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'scan_date': scanDate.toIso8601String(),
      'source': source.name,
      'mode': mode.name,
      'days_scanned': daysScanned,
      'range_start': rangeStart.toIso8601String(),
      'range_end': rangeEnd.toIso8601String(),
      'total_messages': totalMessages,
      'filtered_messages': filteredMessages,
      'already_processed': alreadyProcessed,
      'pattern_matched': patternMatched,
      'ai_processed': aiProcessed,
      'transactions_found': transactionsFound,
      'new_patterns_learned': newPatternsLearned,
    };
  }

  factory ScanHistoryModel.fromMap(Map<String, dynamic> map) {
    return ScanHistoryModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      scanDate: DateTime.parse(map['scan_date'] as String),
      source: TransactionSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => TransactionSource.sms,
      ),
      mode: ScanMode.values.firstWhere(
        (e) => e.name == map['mode'],
        orElse: () => ScanMode.ai,
      ),
      daysScanned: map['days_scanned'] as int? ?? 30,
      rangeStart: DateTime.parse(map['range_start'] as String),
      rangeEnd: DateTime.parse(map['range_end'] as String),
      totalMessages: map['total_messages'] as int? ?? 0,
      filteredMessages: map['filtered_messages'] as int? ?? 0,
      alreadyProcessed: map['already_processed'] as int? ?? 0,
      patternMatched: map['pattern_matched'] as int? ?? 0,
      aiProcessed: map['ai_processed'] as int? ?? 0,
      transactionsFound: map['transactions_found'] as int? ?? 0,
      newPatternsLearned: map['new_patterns_learned'] as int? ?? 0,
    );
  }

  ScanHistoryModel copyWith({
    String? id,
    String? userId,
    DateTime? scanDate,
    TransactionSource? source,
    ScanMode? mode,
    int? daysScanned,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    int? totalMessages,
    int? filteredMessages,
    int? alreadyProcessed,
    int? patternMatched,
    int? aiProcessed,
    int? transactionsFound,
    int? newPatternsLearned,
  }) {
    return ScanHistoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      scanDate: scanDate ?? this.scanDate,
      source: source ?? this.source,
      mode: mode ?? this.mode,
      daysScanned: daysScanned ?? this.daysScanned,
      rangeStart: rangeStart ?? this.rangeStart,
      rangeEnd: rangeEnd ?? this.rangeEnd,
      totalMessages: totalMessages ?? this.totalMessages,
      filteredMessages: filteredMessages ?? this.filteredMessages,
      alreadyProcessed: alreadyProcessed ?? this.alreadyProcessed,
      patternMatched: patternMatched ?? this.patternMatched,
      aiProcessed: aiProcessed ?? this.aiProcessed,
      transactionsFound: transactionsFound ?? this.transactionsFound,
      newPatternsLearned: newPatternsLearned ?? this.newPatternsLearned,
    );
  }
}

/// Scan mode enum
enum ScanMode {
  fast, // Regex-only, no AI
  ai,   // AI with regex fallback + incremental learning
}

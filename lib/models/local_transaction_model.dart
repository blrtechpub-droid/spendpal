/// Unified transaction model for SMS, Email, and Manual entries
///
/// Privacy-First: All data stored locally in SQLite, never in Firebase
///
/// Supports:
/// - SMS transactions (Android)
/// - Email transactions (iOS/Android)
/// - Manual entries (all platforms)
class LocalTransactionModel {
  final String id;
  final TransactionSource source;
  final String? sourceIdentifier; // SMS sender or email sender

  // Tracker link (for Money Tracker feature)
  final String? trackerId; // Link to AccountTrackerModel
  final double? trackerConfidence; // 0.0-1.0: Match confidence

  // Transaction details
  final double amount;
  final String merchant;
  final String category;
  final DateTime transactionDate;

  // Optional details
  final String? transactionId; // Bank transaction ID
  final String? accountInfo; // Last 4 digits (XX1234)
  final String? notes;

  // Original content (stored encrypted in DB)
  final String? rawContent; // Original SMS/email text

  // Status
  final TransactionStatus status;
  final bool isDebit; // true = expense, false = income/investment

  // Metadata
  final DateTime parsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final String? deviceId;

  // AI/Pattern info
  final ParseMethod parsedBy;
  final String? patternId; // If parsed by regex
  final double? confidence; // AI confidence score (0-1)

  LocalTransactionModel({
    required this.id,
    required this.source,
    this.sourceIdentifier,
    this.trackerId,
    this.trackerConfidence,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.transactionDate,
    this.transactionId,
    this.accountInfo,
    this.notes,
    this.rawContent,
    this.status = TransactionStatus.pending,
    this.isDebit = true,
    DateTime? parsedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.userId,
    this.deviceId,
    this.parsedBy = ParseMethod.manual,
    this.patternId,
    this.confidence,
  })  : parsedAt = parsedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Create from SQLite Map
  factory LocalTransactionModel.fromMap(Map<String, dynamic> map) {
    return LocalTransactionModel(
      id: map['id'] as String,
      source: TransactionSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => TransactionSource.manual,
      ),
      sourceIdentifier: map['source_identifier'] as String?,
      trackerId: map['tracker_id'] as String?,
      trackerConfidence: map['tracker_confidence'] != null
          ? (map['tracker_confidence'] as num).toDouble()
          : null,
      amount: (map['amount'] as num).toDouble(),
      merchant: map['merchant'] as String,
      category: map['category'] as String,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      transactionId: map['transaction_id'] as String?,
      accountInfo: map['account_info'] as String?,
      notes: map['notes'] as String?,
      rawContent: map['raw_content'] as String?,
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TransactionStatus.pending,
      ),
      isDebit: (map['is_debit'] as int) == 1,
      parsedAt: DateTime.parse(map['parsed_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      userId: map['user_id'] as String,
      deviceId: map['device_id'] as String?,
      parsedBy: ParseMethod.values.firstWhere(
        (e) => e.name == map['parsed_by'],
        orElse: () => ParseMethod.manual,
      ),
      patternId: map['pattern_id'] as String?,
      confidence: map['confidence'] != null
          ? (map['confidence'] as num).toDouble()
          : null,
    );
  }

  /// Convert to SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': source.name,
      'source_identifier': sourceIdentifier,
      'tracker_id': trackerId,
      'tracker_confidence': trackerConfidence,
      'amount': amount,
      'merchant': merchant,
      'category': category,
      'transaction_date': transactionDate.toIso8601String(),
      'transaction_id': transactionId,
      'account_info': accountInfo,
      'notes': notes,
      'raw_content': rawContent, // Will be encrypted before storage
      'status': status.name,
      'is_debit': isDebit ? 1 : 0,
      'parsed_at': parsedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_id': userId,
      'device_id': deviceId,
      'parsed_by': parsedBy.name,
      'pattern_id': patternId,
      'confidence': confidence,
    };
  }

  /// Copy with method for updates
  LocalTransactionModel copyWith({
    String? id,
    TransactionSource? source,
    String? sourceIdentifier,
    String? trackerId,
    double? trackerConfidence,
    double? amount,
    String? merchant,
    String? category,
    DateTime? transactionDate,
    String? transactionId,
    String? accountInfo,
    String? notes,
    String? rawContent,
    TransactionStatus? status,
    bool? isDebit,
    DateTime? parsedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    String? deviceId,
    ParseMethod? parsedBy,
    String? patternId,
    double? confidence,
  }) {
    return LocalTransactionModel(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceIdentifier: sourceIdentifier ?? this.sourceIdentifier,
      trackerId: trackerId ?? this.trackerId,
      trackerConfidence: trackerConfidence ?? this.trackerConfidence,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionId: transactionId ?? this.transactionId,
      accountInfo: accountInfo ?? this.accountInfo,
      notes: notes ?? this.notes,
      rawContent: rawContent ?? this.rawContent,
      status: status ?? this.status,
      isDebit: isDebit ?? this.isDebit,
      parsedAt: parsedAt ?? this.parsedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // Always update timestamp
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      parsedBy: parsedBy ?? this.parsedBy,
      patternId: patternId ?? this.patternId,
      confidence: confidence ?? this.confidence,
    );
  }

  /// Display formatted amount with currency
  String get formattedAmount {
    return isDebit
        ? '-₹${amount.toStringAsFixed(2)}'
        : '+₹${amount.toStringAsFixed(2)}';
  }

  /// Get display name for source
  String get sourceDisplayName {
    switch (source) {
      case TransactionSource.sms:
        return 'SMS';
      case TransactionSource.email:
        return 'Email';
      case TransactionSource.manual:
        return 'Manual';
    }
  }

  /// Get icon for source
  String get sourceIcon {
    switch (source) {
      case TransactionSource.sms:
        return '💬';
      case TransactionSource.email:
        return '📧';
      case TransactionSource.manual:
        return '✏️';
    }
  }

  @override
  String toString() {
    return 'LocalTransaction($merchant, ₹$amount, $category, ${transactionDate.toString().split(' ')[0]}, $source)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalTransactionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Transaction source type
enum TransactionSource {
  sms,    // SMS transaction (Android)
  email,  // Email transaction (iOS/Android)
  manual, // Manually entered
}

/// Transaction status
enum TransactionStatus {
  pending,    // Waiting for user review
  confirmed,  // User confirmed transaction
  ignored,    // User ignored/rejected
  duplicate,  // Marked as duplicate
}

/// Parse method
enum ParseMethod {
  ai,     // Parsed by AI (Cloud Function)
  regex,  // Parsed by regex pattern
  manual, // Manually entered
}

/// Bulk transaction item for AI parsing
/// Used to send multiple SMS/emails to Cloud Function at once
/// REUSABLE for both SMS and Email
class BulkTransactionItem {
  final int index;
  final String text; // SMS or email text
  final String sender;
  final DateTime date;
  final TransactionSource source;
  final String? trackerId; // Optional: Pre-assigned tracker ID

  BulkTransactionItem({
    required this.index,
    required this.text,
    required this.sender,
    required this.date,
    required this.source,
    this.trackerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'text': text,
      'sender': sender,
      'date': date.toIso8601String(),
      'source': source.name,
      'trackerId': trackerId,
    };
  }
}

/// AI Parse Result
/// REUSABLE for both SMS and Email parsing
class ParsedTransactionResult {
  final double amount;
  final String merchant;
  final String category;
  final String? transactionId;
  final String? accountInfo;
  final DateTime date;
  final bool isDebit;
  final double confidence;
  final Map<String, dynamic>? regexPattern;

  ParsedTransactionResult({
    required this.amount,
    required this.merchant,
    required this.category,
    this.transactionId,
    this.accountInfo,
    required this.date,
    this.isDebit = true,
    this.confidence = 0.0,
    this.regexPattern,
  });

  factory ParsedTransactionResult.fromMap(Map<String, dynamic> map) {
    return ParsedTransactionResult(
      amount: (map['amount'] as num).toDouble(),
      merchant: map['merchant'] as String,
      category: map['category'] as String,
      transactionId: map['transactionId'] as String?,
      accountInfo: map['accountInfo'] as String?,
      date: DateTime.parse(map['date'] as String),
      isDebit: map['isDebit'] as bool? ?? true,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      regexPattern: map['regexPattern'] as Map<String, dynamic>?,
    );
  }
}

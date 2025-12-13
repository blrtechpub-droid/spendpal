import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for email transaction parsing patterns
/// Stored in Firestore for dynamic, user-customizable parsing
class EmailPattern {
  final String id;
  final String bankDomain;
  final String bankName;
  final Map<String, dynamic> patterns; // amount, merchant, date patterns
  final Map<String, dynamic>? gmailFilter; // from, keywords
  final double confidence;
  final int usageCount;
  final int successCount;
  final int failureCount;
  final bool verified;
  final bool active;
  final int priority; // Higher = used first
  final String? createdBy;
  final DateTime? createdAt;
  final List<String> tags;

  EmailPattern({
    required this.id,
    required this.bankDomain,
    required this.bankName,
    required this.patterns,
    this.gmailFilter,
    this.confidence = 0.5,
    this.usageCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.verified = false,
    this.active = true,
    this.priority = 5,
    this.createdBy,
    this.createdAt,
    this.tags = const [],
  });

  /// Create from Firestore document
  factory EmailPattern.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return EmailPattern(
      id: doc.id,
      bankDomain: data['bankDomain'] ?? '',
      bankName: data['bankName'] ?? '',
      patterns: data['patterns'] ?? {},
      gmailFilter: data['gmailFilter'],
      confidence: (data['confidence'] ?? 0.5).toDouble(),
      usageCount: data['usageCount'] ?? 0,
      successCount: data['successCount'] ?? 0,
      failureCount: data['failureCount'] ?? 0,
      verified: data['verified'] ?? false,
      active: data['active'] ?? true,
      priority: data['priority'] ?? 5,
      createdBy: data['createdBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'bankDomain': bankDomain,
      'bankName': bankName,
      'patterns': patterns,
      if (gmailFilter != null) 'gmailFilter': gmailFilter,
      'confidence': confidence,
      'usageCount': usageCount,
      'successCount': successCount,
      'failureCount': failureCount,
      'verified': verified,
      'active': active,
      'priority': priority,
      if (createdBy != null) 'createdBy': createdBy,
      'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
      'tags': tags,
    };
  }

  /// Create a copy with updated fields
  EmailPattern copyWith({
    String? id,
    String? bankDomain,
    String? bankName,
    Map<String, dynamic>? patterns,
    Map<String, dynamic>? gmailFilter,
    double? confidence,
    int? usageCount,
    int? successCount,
    int? failureCount,
    bool? verified,
    bool? active,
    int? priority,
    String? createdBy,
    DateTime? createdAt,
    List<String>? tags,
  }) {
    return EmailPattern(
      id: id ?? this.id,
      bankDomain: bankDomain ?? this.bankDomain,
      bankName: bankName ?? this.bankName,
      patterns: patterns ?? this.patterns,
      gmailFilter: gmailFilter ?? this.gmailFilter,
      confidence: confidence ?? this.confidence,
      usageCount: usageCount ?? this.usageCount,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      verified: verified ?? this.verified,
      active: active ?? this.active,
      priority: priority ?? this.priority,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
    );
  }

  /// Calculate actual confidence score
  double get actualConfidence {
    if (successCount + failureCount == 0) return confidence;

    final baseConfidence = successCount / (successCount + failureCount);
    final usageWeight = (usageCount / 100).clamp(0.0, 1.0);
    final verifiedBonus = verified ? 1.2 : 1.0;

    return (baseConfidence * usageWeight * verifiedBonus).clamp(0.0, 1.0);
  }
}

/// Model for user's manual corrections and learning data
class EmailLearningData {
  final String id;
  final String userId;
  final String messageId; // Gmail message ID
  final String subject;
  final String senderEmail;
  final String emailBody;
  final DateTime receivedAt;

  // User corrected data
  final double? amount;
  final String? merchant;
  final DateTime? transactionDate;
  final String? type; // debit, credit, upi, etc.
  final String? category;

  // Auto-extracted patterns
  final Map<String, dynamic>? extractedPatterns;
  final String? generatedPatternId;
  final String status; // pending, generated, approved, rejected
  final DateTime createdAt;

  EmailLearningData({
    required this.id,
    required this.userId,
    required this.messageId,
    required this.subject,
    required this.senderEmail,
    required this.emailBody,
    required this.receivedAt,
    this.amount,
    this.merchant,
    this.transactionDate,
    this.type,
    this.category,
    this.extractedPatterns,
    this.generatedPatternId,
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from Firestore document
  factory EmailLearningData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return EmailLearningData(
      id: doc.id,
      userId: data['userId'] ?? '',
      messageId: data['messageId'] ?? '',
      subject: data['subject'] ?? '',
      senderEmail: data['senderEmail'] ?? '',
      emailBody: data['emailBody'] ?? '',
      receivedAt: (data['receivedAt'] as Timestamp).toDate(),
      amount: data['amount']?.toDouble(),
      merchant: data['merchant'],
      transactionDate: (data['transactionDate'] as Timestamp?)?.toDate(),
      type: data['type'],
      category: data['category'],
      extractedPatterns: data['extractedPatterns'],
      generatedPatternId: data['generatedPatternId'],
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'messageId': messageId,
      'subject': subject,
      'senderEmail': senderEmail,
      'emailBody': emailBody,
      'receivedAt': Timestamp.fromDate(receivedAt),
      if (amount != null) 'amount': amount,
      if (merchant != null) 'merchant': merchant,
      if (transactionDate != null) 'transactionDate': Timestamp.fromDate(transactionDate!),
      if (type != null) 'type': type,
      if (category != null) 'category': category,
      if (extractedPatterns != null) 'extractedPatterns': extractedPatterns,
      if (generatedPatternId != null) 'generatedPatternId': generatedPatternId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Extract domain from email address
  String get domain {
    final match = RegExp(r'@([a-zA-Z0-9.-]+)').firstMatch(senderEmail);
    return match?.group(1) ?? '';
  }
}

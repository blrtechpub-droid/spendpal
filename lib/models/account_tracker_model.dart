import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of financial accounts that can be tracked
enum TrackerType {
  banking,
  creditCard,
  investment,
  governmentScheme,
  digitalWallet,
  insurance,
  loan,
}

/// Specific categories/providers for each tracker type
enum TrackerCategory {
  // Banking
  hdfcBank,
  iciciBank,
  sbiBank,
  axisBank,
  kotakBank,
  yesBankIndia,
  indusIndBank,
  pnbBank,
  standardChartered,

  // Investments
  zerodha,
  groww,
  angelOne,
  upstox,
  paisa5,

  // Government Schemes
  nps,
  ppf,
  epf,

  // Digital Wallets
  paytm,
  phonePe,
  googlePay,
  amazonPay,

  // Add more as needed
}

/// Model representing a configured account tracker
///
/// This determines which emails to fetch from Gmail based on user's accounts
class AccountTrackerModel {
  final String id;
  final String name; // User-friendly name: "HDFC Bank Savings"
  final TrackerType type;
  final TrackerCategory category;
  final List<String> emailDomains; // Email domains to search: ['hdfcbank.com', 'hdfcbank.net']
  final List<String> smsSenders; // SMS sender IDs to match: ['VM-HDFCBK', 'CP-HDFCBK']
  final String? accountNumber; // Last 4 digits (optional, for display only)
  final bool isActive; // Enable/disable this tracker
  final String? iconUrl;
  final String? colorHex; // Brand color for UI
  final String? emoji; // Emoji icon for UI
  final DateTime createdAt;
  final DateTime? lastSyncedAt; // Last time emails were synced for this tracker
  final int emailsFetched; // Stats: Total emails fetched from this tracker
  final String userId;
  final bool autoCreated; // Was this tracker auto-created from detected transactions?
  final String? detectedFrom; // Original sender/email that triggered auto-creation
  final DateTime? updatedAt; // Last time tracker was updated

  AccountTrackerModel({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.emailDomains,
    this.smsSenders = const [],
    this.accountNumber,
    this.isActive = true,
    this.iconUrl,
    this.colorHex,
    this.emoji,
    required this.createdAt,
    this.lastSyncedAt,
    this.emailsFetched = 0,
    required this.userId,
    this.autoCreated = false,
    this.detectedFrom,
    this.updatedAt,
  });

  /// Create from Firestore document
  factory AccountTrackerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccountTrackerModel.fromMap(data, doc.id);
  }

  /// Create from map
  factory AccountTrackerModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return AccountTrackerModel(
      id: id ?? map['id'] as String,
      name: map['name'] as String,
      type: TrackerType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TrackerType.banking,
      ),
      category: TrackerCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => TrackerCategory.hdfcBank,
      ),
      emailDomains: List<String>.from(map['emailDomains'] as List? ?? []),
      smsSenders: List<String>.from(map['smsSenders'] as List? ?? []),
      accountNumber: map['accountNumber'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      iconUrl: map['iconUrl'] as String?,
      colorHex: map['colorHex'] as String?,
      emoji: map['emoji'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastSyncedAt: map['lastSyncedAt'] != null
          ? (map['lastSyncedAt'] as Timestamp).toDate()
          : null,
      emailsFetched: map['emailsFetched'] as int? ?? 0,
      userId: map['userId'] as String,
      autoCreated: map['autoCreated'] as bool? ?? false,
      detectedFrom: map['detectedFrom'] as String?,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'category': category.name,
      'emailDomains': emailDomains,
      'smsSenders': smsSenders,
      'accountNumber': accountNumber,
      'isActive': isActive,
      'iconUrl': iconUrl,
      'colorHex': colorHex,
      'emoji': emoji,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSyncedAt': lastSyncedAt != null ? Timestamp.fromDate(lastSyncedAt!) : null,
      'emailsFetched': emailsFetched,
      'userId': userId,
      'autoCreated': autoCreated,
      'detectedFrom': detectedFrom,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Create a copy with updated fields
  AccountTrackerModel copyWith({
    String? id,
    String? name,
    TrackerType? type,
    TrackerCategory? category,
    List<String>? emailDomains,
    List<String>? smsSenders,
    String? accountNumber,
    bool? isActive,
    String? iconUrl,
    String? colorHex,
    String? emoji,
    DateTime? createdAt,
    DateTime? lastSyncedAt,
    int? emailsFetched,
    String? userId,
    bool? autoCreated,
    String? detectedFrom,
    DateTime? updatedAt,
  }) {
    return AccountTrackerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      category: category ?? this.category,
      emailDomains: emailDomains ?? this.emailDomains,
      smsSenders: smsSenders ?? this.smsSenders,
      accountNumber: accountNumber ?? this.accountNumber,
      isActive: isActive ?? this.isActive,
      iconUrl: iconUrl ?? this.iconUrl,
      colorHex: colorHex ?? this.colorHex,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      emailsFetched: emailsFetched ?? this.emailsFetched,
      userId: userId ?? this.userId,
      autoCreated: autoCreated ?? this.autoCreated,
      detectedFrom: detectedFrom ?? this.detectedFrom,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get display name with account number if available
  String get displayName {
    if (accountNumber != null && accountNumber!.isNotEmpty) {
      return '$name (••$accountNumber)';
    }
    return name;
  }

  /// Get type display name
  String get typeDisplayName {
    switch (type) {
      case TrackerType.banking:
        return 'Banking';
      case TrackerType.creditCard:
        return 'Credit Card';
      case TrackerType.investment:
        return 'Investment';
      case TrackerType.governmentScheme:
        return 'Government Scheme';
      case TrackerType.digitalWallet:
        return 'Digital Wallet';
      case TrackerType.insurance:
        return 'Insurance';
      case TrackerType.loan:
        return 'Loan';
    }
  }

  /// Get type emoji icon
  String get typeEmoji {
    switch (type) {
      case TrackerType.banking:
        return '🏦';
      case TrackerType.creditCard:
        return '💳';
      case TrackerType.investment:
        return '📈';
      case TrackerType.governmentScheme:
        return '💰';
      case TrackerType.digitalWallet:
        return '📱';
      case TrackerType.insurance:
        return '🏥';
      case TrackerType.loan:
        return '🏠';
    }
  }
}

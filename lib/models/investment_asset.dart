import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an investment asset (Mutual Fund, Stock, ETF, FD, Gold, etc.)
/// This is the master record for any investment instrument
class InvestmentAsset {
  final String assetId;
  final String userId;
  final String assetType; // 'mutual_fund', 'equity', 'etf', 'fd', 'rd', 'gold', 'crypto', 'property'
  final String name; // Display name (e.g., "Axis Bluechip Fund", "RELIANCE")
  final String? symbol; // For stocks/ETFs: ticker symbol (e.g., "RELIANCE", "NIFTYBEES")
  final String? schemeCode; // For mutual funds: AMFI scheme code
  final String? platform; // Investment platform (e.g., "zerodha", "groww", "5paisa", "etrade")
  final String? trackerId; // Link to AccountTracker for auto-import from emails/SMS
  final String currency; // Default: 'INR'
  final List<String> tags; // User-defined tags for categorization
  final String? goalId; // Link to financial goal (future feature)
  final DateTime createdAt;
  final DateTime updatedAt;

  InvestmentAsset({
    required this.assetId,
    required this.userId,
    required this.assetType,
    required this.name,
    this.symbol,
    this.schemeCode,
    this.platform,
    this.trackerId,
    this.currency = 'INR',
    this.tags = const [],
    this.goalId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'assetId': assetId,
      'userId': userId,
      'assetType': assetType,
      'name': name,
      'symbol': symbol,
      'schemeCode': schemeCode,
      'platform': platform,
      'trackerId': trackerId,
      'currency': currency,
      'tags': tags,
      'goalId': goalId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create from Firestore document
  factory InvestmentAsset.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InvestmentAsset(
      assetId: doc.id,
      userId: data['userId'] ?? '',
      assetType: data['assetType'] ?? 'mutual_fund',
      name: data['name'] ?? '',
      symbol: data['symbol'],
      schemeCode: data['schemeCode'],
      platform: data['platform'],
      trackerId: data['trackerId'],
      currency: data['currency'] ?? 'INR',
      tags: List<String>.from(data['tags'] ?? []),
      goalId: data['goalId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  InvestmentAsset copyWith({
    String? assetId,
    String? userId,
    String? assetType,
    String? name,
    String? symbol,
    String? schemeCode,
    String? platform,
    String? trackerId,
    String? currency,
    List<String>? tags,
    String? goalId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvestmentAsset(
      assetId: assetId ?? this.assetId,
      userId: userId ?? this.userId,
      assetType: assetType ?? this.assetType,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      schemeCode: schemeCode ?? this.schemeCode,
      platform: platform ?? this.platform,
      trackerId: trackerId ?? this.trackerId,
      currency: currency ?? this.currency,
      tags: tags ?? this.tags,
      goalId: goalId ?? this.goalId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Helper to get display identifier (symbol or scheme code)
  String get identifier => symbol ?? schemeCode ?? assetId.substring(0, 8);

  /// Helper to get asset type display name
  String get assetTypeDisplay {
    switch (assetType) {
      case 'mutual_fund':
        return 'Mutual Fund';
      case 'equity':
        return 'Stock';
      case 'etf':
        return 'ETF';
      case 'fd':
        return 'Fixed Deposit';
      case 'rd':
        return 'Recurring Deposit';
      case 'ppf':
        return 'Public Provident Fund';
      case 'epf':
        return 'Employees Provident Fund';
      case 'nps':
        return 'National Pension System';
      case 'gold':
        return 'Gold';
      case 'crypto':
        return 'Cryptocurrency';
      case 'property':
        return 'Property';
      default:
        return assetType;
    }
  }

  /// Helper to get platform display name
  String get platformDisplay {
    if (platform == null) return 'Direct';

    switch (platform!.toLowerCase()) {
      case 'zerodha':
        return 'Zerodha';
      case 'groww':
        return 'Groww';
      case '5paisa':
        return '5Paisa';
      case 'upstox':
        return 'Upstox';
      case 'angelone':
      case 'angel_one':
        return 'Angel One';
      case 'icici_direct':
        return 'ICICI Direct';
      case 'hdfc_securities':
        return 'HDFC Securities';
      case 'kotak_securities':
        return 'Kotak Securities';
      case 'sharekhan':
        return 'Sharekhan';
      case 'motilal_oswal':
        return 'Motilal Oswal';
      case 'etrade':
        return 'E*TRADE';
      case 'robinhood':
        return 'Robinhood';
      case 'webull':
        return 'Webull';
      case 'fidelity':
        return 'Fidelity';
      case 'charles_schwab':
        return 'Charles Schwab';
      case 'interactive_brokers':
        return 'Interactive Brokers';
      case 'coin_dcx':
        return 'CoinDCX';
      case 'wazirx':
        return 'WazirX';
      case 'paytm_money':
        return 'Paytm Money';
      case 'kite':
        return 'Kite by Zerodha';
      case 'other':
        return 'Other';
      default:
        return platform!;
    }
  }
}

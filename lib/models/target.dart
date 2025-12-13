import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents portfolio allocation targets
/// Used by rebalancing rules to detect drift
class Target {
  final String targetId;
  final String userId;
  final String name; // e.g., "Conservative", "Aggressive", "Balanced", "Custom"
  final double equityPercent; // Target equity allocation (0-100)
  final double debtPercent; // Target debt/FD allocation (0-100)
  final double goldPercent; // Target gold allocation (0-100)
  final double cashPercent; // Target cash allocation (0-100)
  final double cryptoPercent; // Target crypto allocation (0-100)
  final double propertyPercent; // Target property allocation (0-100)
  final double bandPercent; // Acceptable deviation band (default: 5%)
  final bool isActive; // Whether this target is currently active
  final String? description; // Description of this allocation strategy
  final DateTime createdAt;
  final DateTime updatedAt;

  Target({
    required this.targetId,
    required this.userId,
    required this.name,
    this.equityPercent = 60.0,
    this.debtPercent = 30.0,
    this.goldPercent = 5.0,
    this.cashPercent = 5.0,
    this.cryptoPercent = 0.0,
    this.propertyPercent = 0.0,
    this.bandPercent = 5.0,
    this.isActive = true,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'targetId': targetId,
      'userId': userId,
      'name': name,
      'equityPercent': equityPercent,
      'debtPercent': debtPercent,
      'goldPercent': goldPercent,
      'cashPercent': cashPercent,
      'cryptoPercent': cryptoPercent,
      'propertyPercent': propertyPercent,
      'bandPercent': bandPercent,
      'isActive': isActive,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create from Firestore document
  factory Target.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Target(
      targetId: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? 'Custom',
      equityPercent: (data['equityPercent'] as num?)?.toDouble() ?? 60.0,
      debtPercent: (data['debtPercent'] as num?)?.toDouble() ?? 30.0,
      goldPercent: (data['goldPercent'] as num?)?.toDouble() ?? 5.0,
      cashPercent: (data['cashPercent'] as num?)?.toDouble() ?? 5.0,
      cryptoPercent: (data['cryptoPercent'] as num?)?.toDouble() ?? 0.0,
      propertyPercent: (data['propertyPercent'] as num?)?.toDouble() ?? 0.0,
      bandPercent: (data['bandPercent'] as num?)?.toDouble() ?? 5.0,
      isActive: data['isActive'] ?? true,
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  Target copyWith({
    String? targetId,
    String? userId,
    String? name,
    double? equityPercent,
    double? debtPercent,
    double? goldPercent,
    double? cashPercent,
    double? cryptoPercent,
    double? propertyPercent,
    double? bandPercent,
    bool? isActive,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Target(
      targetId: targetId ?? this.targetId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      equityPercent: equityPercent ?? this.equityPercent,
      debtPercent: debtPercent ?? this.debtPercent,
      goldPercent: goldPercent ?? this.goldPercent,
      cashPercent: cashPercent ?? this.cashPercent,
      cryptoPercent: cryptoPercent ?? this.cryptoPercent,
      propertyPercent: propertyPercent ?? this.propertyPercent,
      bandPercent: bandPercent ?? this.bandPercent,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Validate that allocations sum to 100%
  bool get isValid {
    final total = equityPercent + debtPercent + goldPercent +
                  cashPercent + cryptoPercent + propertyPercent;
    return (total - 100.0).abs() < 0.01; // Allow for floating point errors
  }

  /// Get total allocation percentage
  double get totalPercent {
    return equityPercent + debtPercent + goldPercent +
           cashPercent + cryptoPercent + propertyPercent;
  }

  /// Calculate drift for a given asset class
  /// Returns the percentage points of drift from target
  double calculateDrift(String assetClass, double actualPercent) {
    double targetValue;
    switch (assetClass.toLowerCase()) {
      case 'equity':
        targetValue = equityPercent;
        break;
      case 'debt':
      case 'fd':
      case 'rd':
        targetValue = debtPercent;
        break;
      case 'gold':
        targetValue = goldPercent;
        break;
      case 'cash':
        targetValue = cashPercent;
        break;
      case 'crypto':
        targetValue = cryptoPercent;
        break;
      case 'property':
        targetValue = propertyPercent;
        break;
      default:
        return 0.0;
    }
    return actualPercent - targetValue;
  }

  /// Check if drift exceeds band for a given asset class
  bool isDrifted(String assetClass, double actualPercent) {
    final drift = calculateDrift(assetClass, actualPercent);
    return drift.abs() > bandPercent;
  }

  /// Get map of all target allocations
  Map<String, double> get allocations {
    return {
      'equity': equityPercent,
      'debt': debtPercent,
      'gold': goldPercent,
      'cash': cashPercent,
      'crypto': cryptoPercent,
      'property': propertyPercent,
    };
  }

  /// Get map of target bands (min/max acceptable ranges)
  Map<String, Map<String, double>> get bands {
    return {
      'equity': {
        'min': (equityPercent - bandPercent).clamp(0.0, 100.0),
        'max': (equityPercent + bandPercent).clamp(0.0, 100.0),
      },
      'debt': {
        'min': (debtPercent - bandPercent).clamp(0.0, 100.0),
        'max': (debtPercent + bandPercent).clamp(0.0, 100.0),
      },
      'gold': {
        'min': (goldPercent - bandPercent).clamp(0.0, 100.0),
        'max': (goldPercent + bandPercent).clamp(0.0, 100.0),
      },
      'cash': {
        'min': (cashPercent - bandPercent).clamp(0.0, 100.0),
        'max': (cashPercent + bandPercent).clamp(0.0, 100.0),
      },
      'crypto': {
        'min': (cryptoPercent - bandPercent).clamp(0.0, 100.0),
        'max': (cryptoPercent + bandPercent).clamp(0.0, 100.0),
      },
      'property': {
        'min': (propertyPercent - bandPercent).clamp(0.0, 100.0),
        'max': (propertyPercent + bandPercent).clamp(0.0, 100.0),
      },
    };
  }

  /// Predefined target templates
  static Target conservative({
    required String targetId,
    required String userId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return Target(
      targetId: targetId,
      userId: userId,
      name: 'Conservative',
      equityPercent: 30.0,
      debtPercent: 60.0,
      goldPercent: 5.0,
      cashPercent: 5.0,
      bandPercent: 5.0,
      description: 'Low-risk allocation with focus on debt instruments',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static Target balanced({
    required String targetId,
    required String userId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return Target(
      targetId: targetId,
      userId: userId,
      name: 'Balanced',
      equityPercent: 60.0,
      debtPercent: 30.0,
      goldPercent: 5.0,
      cashPercent: 5.0,
      bandPercent: 5.0,
      description: 'Balanced allocation for moderate growth with stability',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static Target aggressive({
    required String targetId,
    required String userId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return Target(
      targetId: targetId,
      userId: userId,
      name: 'Aggressive',
      equityPercent: 80.0,
      debtPercent: 10.0,
      goldPercent: 5.0,
      cashPercent: 5.0,
      bandPercent: 5.0,
      description: 'High-risk, high-reward allocation focused on equity',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

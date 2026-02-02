import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum representing budget status based on percentage used
enum BudgetStatus {
  safe, // < 70% used (green)
  warning, // 70-90% used (yellow)
  danger, // 90-100% used (orange)
  exceeded, // > 100% used (red)
}

/// Represents a user's monthly budget with custom cycle support
class BudgetModel {
  final String budgetId;
  final String userId;
  final int cycleStartDay; // 1-31 (day of month when salary is credited)
  final bool isActive;
  final double? overallMonthlyLimit; // Overall monthly budget limit (nullable)
  final Map<String, double> categoryLimits; // Category-specific budgets
  final DateTime createdAt;
  final DateTime updatedAt;

  BudgetModel({
    required this.budgetId,
    required this.userId,
    required this.cycleStartDay,
    this.isActive = true,
    this.overallMonthlyLimit,
    this.categoryLimits = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'budgetId': budgetId,
      'userId': userId,
      'cycleStartDay': cycleStartDay,
      'isActive': isActive,
      'overallMonthlyLimit': overallMonthlyLimit,
      'categoryLimits': categoryLimits,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create from Firestore document
  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      budgetId: doc.id,
      userId: data['userId'] ?? '',
      cycleStartDay: data['cycleStartDay'] ?? 1,
      isActive: data['isActive'] ?? true,
      overallMonthlyLimit: (data['overallMonthlyLimit'] as num?)?.toDouble(),
      categoryLimits: Map<String, double>.from(
        (data['categoryLimits'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, (value as num).toDouble()),
            ) ??
            {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  BudgetModel copyWith({
    String? budgetId,
    String? userId,
    int? cycleStartDay,
    bool? isActive,
    double? overallMonthlyLimit,
    Map<String, double>? categoryLimits,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetModel(
      budgetId: budgetId ?? this.budgetId,
      userId: userId ?? this.userId,
      cycleStartDay: cycleStartDay ?? this.cycleStartDay,
      isActive: isActive ?? this.isActive,
      overallMonthlyLimit: overallMonthlyLimit ?? this.overallMonthlyLimit,
      categoryLimits: categoryLimits ?? this.categoryLimits,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Represents a budget period (start and end dates based on cycle)
class BudgetPeriod {
  final DateTime startDate;
  final DateTime endDate;

  BudgetPeriod({
    required this.startDate,
    required this.endDate,
  });

  /// Calculate current budget period based on cycle start day
  factory BudgetPeriod.current({required int cycleStartDay}) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    DateTime startDate;
    DateTime endDate;

    if (now.day >= cycleStartDay) {
      // Current cycle: this month's cycle day to next month's cycle day
      startDate = DateTime(currentYear, currentMonth, cycleStartDay);

      // Calculate end date (day before next cycle start)
      final nextMonth = currentMonth == 12 ? 1 : currentMonth + 1;
      final nextYear = currentMonth == 12 ? currentYear + 1 : currentYear;
      final nextCycleStart = DateTime(nextYear, nextMonth, cycleStartDay);
      endDate = nextCycleStart.subtract(const Duration(seconds: 1));
    } else {
      // Current cycle: last month's cycle day to this month's cycle day
      final lastMonth = currentMonth == 1 ? 12 : currentMonth - 1;
      final lastYear = currentMonth == 1 ? currentYear - 1 : currentYear;
      startDate = DateTime(lastYear, lastMonth, cycleStartDay);

      // End date is day before this month's cycle start
      final thisCycleStart = DateTime(currentYear, currentMonth, cycleStartDay);
      endDate = thisCycleStart.subtract(const Duration(seconds: 1));
    }

    return BudgetPeriod(startDate: startDate, endDate: endDate);
  }

  /// Get number of days in this period
  int get daysInPeriod => endDate.difference(startDate).inDays + 1;

  /// Get number of days remaining in this period
  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;
    return endDate.difference(now).inDays + 1;
  }

  /// Get percentage of period elapsed
  double get percentageElapsed {
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 0.0;
    if (now.isAfter(endDate)) return 100.0;

    final totalDays = daysInPeriod;
    final daysElapsed = now.difference(startDate).inDays + 1;
    return (daysElapsed / totalDays) * 100;
  }
}

/// Analysis of budget vs actual spending
class BudgetAnalysis {
  final double limit;
  final double spent;
  final double remaining;
  final double percentageUsed;
  final BudgetStatus status;

  BudgetAnalysis({
    required this.limit,
    required this.spent,
  })  : remaining = limit - spent,
        percentageUsed = limit > 0 ? (spent / limit) * 100 : 0.0,
        status = _calculateStatus(spent, limit);

  /// Calculate budget status based on percentage used
  static BudgetStatus _calculateStatus(double spent, double limit) {
    if (limit <= 0) return BudgetStatus.safe;

    final percentage = (spent / limit) * 100;

    if (percentage >= 100) return BudgetStatus.exceeded;
    if (percentage >= 90) return BudgetStatus.danger;
    if (percentage >= 70) return BudgetStatus.warning;
    return BudgetStatus.safe;
  }

  /// Check if budget is exceeded
  bool get isExceeded => spent > limit;

  /// Check if budget is approaching limit (>= 70%)
  bool get isApproachingLimit => percentageUsed >= 70;

  /// Get amount by which budget is exceeded (0 if not exceeded)
  double get excessAmount => spent > limit ? spent - limit : 0.0;
}

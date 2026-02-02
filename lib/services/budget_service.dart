import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget_model.dart';
import 'analytics_service.dart';

/// Service for managing budgets and budget analysis
class BudgetService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== CRUD Operations ====================

  /// Create a new budget for the user
  static Future<String> createBudget({
    required String userId,
    required int cycleStartDay,
    double? overallMonthlyLimit,
    Map<String, double> categoryLimits = const {},
  }) async {
    // Deactivate any existing active budgets
    await deactivateAllBudgets(userId);

    final budget = BudgetModel(
      budgetId: '', // Will be set by Firestore
      userId: userId,
      cycleStartDay: cycleStartDay,
      isActive: true,
      overallMonthlyLimit: overallMonthlyLimit,
      categoryLimits: categoryLimits,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef =
        await _firestore.collection('budgets').add(budget.toMap());
    return docRef.id;
  }

  /// Update an existing budget
  static Future<void> updateBudget({
    required String budgetId,
    int? cycleStartDay,
    double? overallMonthlyLimit,
    Map<String, double>? categoryLimits,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (cycleStartDay != null) {
      updateData['cycleStartDay'] = cycleStartDay;
    }

    if (overallMonthlyLimit != null) {
      updateData['overallMonthlyLimit'] = overallMonthlyLimit;
    }

    if (categoryLimits != null) {
      updateData['categoryLimits'] = categoryLimits;
    }

    await _firestore.collection('budgets').doc(budgetId).update(updateData);
  }

  /// Delete a budget
  static Future<void> deleteBudget(String budgetId) async {
    await _firestore.collection('budgets').doc(budgetId).delete();
  }

  /// Deactivate all active budgets for a user
  static Future<void> deactivateAllBudgets(String userId) async {
    final snapshot = await _firestore
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    await batch.commit();
  }

  // ==================== Query Operations ====================

  /// Get active budget for a user (Stream for real-time updates)
  static Stream<BudgetModel?> getActiveBudget(String userId) {
    return _firestore
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return BudgetModel.fromFirestore(snapshot.docs.first);
    });
  }

  /// Get active budget for a user (Future for one-time fetch)
  static Future<BudgetModel?> getActiveBudgetOnce(String userId) async {
    final snapshot = await _firestore
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return BudgetModel.fromFirestore(snapshot.docs.first);
  }

  /// Get all budgets for a user (including inactive)
  static Future<List<BudgetModel>> getAllBudgets(String userId) async {
    final snapshot = await _firestore
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => BudgetModel.fromFirestore(doc))
        .toList();
  }

  // ==================== Analysis Operations ====================

  /// Analyze overall budget (spending vs limit)
  static Future<BudgetAnalysis?> analyzeOverallBudget({
    required String userId,
    required BudgetModel budget,
  }) async {
    if (budget.overallMonthlyLimit == null) return null;

    final period = BudgetPeriod.current(cycleStartDay: budget.cycleStartDay);
    final totalSpent = await _getTotalSpent(
      userId: userId,
      startDate: period.startDate,
      endDate: period.endDate,
    );

    return BudgetAnalysis(
      limit: budget.overallMonthlyLimit!,
      spent: totalSpent,
    );
  }

  /// Analyze category budgets (spending vs limits for each category)
  static Future<Map<String, BudgetAnalysis>> analyzeCategoryBudgets({
    required String userId,
    required BudgetModel budget,
  }) async {
    if (budget.categoryLimits.isEmpty) return {};

    final period = BudgetPeriod.current(cycleStartDay: budget.cycleStartDay);
    final categoryBreakdown = await AnalyticsService.getCategoryBreakdown(
      userId: userId,
      startDate: period.startDate,
      endDate: period.endDate,
    );

    final Map<String, BudgetAnalysis> analyses = {};

    budget.categoryLimits.forEach((category, limit) {
      final spent = categoryBreakdown[category] ?? 0.0;
      analyses[category] = BudgetAnalysis(limit: limit, spent: spent);
    });

    return analyses;
  }

  /// Check budget impact of adding a new expense
  static Future<Map<String, dynamic>> checkBudgetImpact({
    required String userId,
    required double expenseAmount,
    required String category,
  }) async {
    final budget = await getActiveBudgetOnce(userId);
    if (budget == null) {
      return {
        'overallExceeded': false,
        'categoryExceeded': false,
        'warnings': <String>[],
      };
    }

    final period = BudgetPeriod.current(cycleStartDay: budget.cycleStartDay);
    final warnings = <String>[];
    bool overallExceeded = false;
    bool categoryExceeded = false;

    // Check overall budget
    if (budget.overallMonthlyLimit != null) {
      final totalSpent = await _getTotalSpent(
        userId: userId,
        startDate: period.startDate,
        endDate: period.endDate,
      );

      final newTotal = totalSpent + expenseAmount;
      final limit = budget.overallMonthlyLimit!;

      if (newTotal > limit) {
        overallExceeded = true;
        final excess = newTotal - limit;
        warnings.add(
            'This will exceed your overall monthly budget by ₹${excess.toStringAsFixed(0)}');
      } else if (newTotal / limit >= 0.9) {
        // 90% or more
        final percentage = (newTotal / limit * 100).toStringAsFixed(1);
        warnings.add(
            'This will use $percentage% of your overall budget (₹${newTotal.toStringAsFixed(0)} / ₹${limit.toStringAsFixed(0)})');
      }
    }

    // Check category budget
    if (budget.categoryLimits.containsKey(category)) {
      final categoryBreakdown = await AnalyticsService.getCategoryBreakdown(
        userId: userId,
        startDate: period.startDate,
        endDate: period.endDate,
      );

      final categorySpent = categoryBreakdown[category] ?? 0.0;
      final newCategoryTotal = categorySpent + expenseAmount;
      final categoryLimit = budget.categoryLimits[category]!;

      if (newCategoryTotal > categoryLimit) {
        categoryExceeded = true;
        final excess = newCategoryTotal - categoryLimit;
        warnings.add(
            'This will exceed your $category budget by ₹${excess.toStringAsFixed(0)}');
      } else if (newCategoryTotal / categoryLimit >= 0.9) {
        // 90% or more
        final percentage =
            (newCategoryTotal / categoryLimit * 100).toStringAsFixed(1);
        warnings.add(
            'This will use $percentage% of your $category budget (₹${newCategoryTotal.toStringAsFixed(0)} / ₹${categoryLimit.toStringAsFixed(0)})');
      }
    }

    return {
      'overallExceeded': overallExceeded,
      'categoryExceeded': categoryExceeded,
      'warnings': warnings,
    };
  }

  // ==================== Helper Methods ====================

  /// Get total spending for a period
  static Future<double> _getTotalSpent({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final expenses = await AnalyticsService.getExpensesInRange(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    return expenses.fold<double>(
      0.0,
      (total, expense) =>
          total + ((expense['amount'] as num?)?.toDouble() ?? 0.0),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Service for aggregating and analyzing expense data
class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get expense data for a specific date range
  static Future<List<Map<String, dynamic>>> getExpensesInRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _firestore
        .collection('expenses')
        .where('paidBy', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .where('createdAt', isLessThanOrEqualTo: endDate)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
        'category': data['category'] as String? ?? 'Other',
        'date': (data['createdAt'] as Timestamp).toDate(),
        'title': data['title'] as String? ?? 'Expense',
      };
    }).toList();
  }

  /// Get category breakdown with totals
  static Future<Map<String, double>> getCategoryBreakdown({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final expenses = await getExpensesInRange(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    final Map<String, double> breakdown = {};
    for (final expense in expenses) {
      final category = expense['category'] as String;
      final amount = expense['amount'] as double;
      breakdown[category] = (breakdown[category] ?? 0.0) + amount;
    }

    return breakdown;
  }

  /// Get monthly spending totals for the past N months
  static Future<Map<String, double>> getMonthlyTotals({
    required String userId,
    required int monthsCount,
  }) async {
    final now = DateTime.now();
    final Map<String, double> monthlyTotals = {};

    for (int i = 0; i < monthsCount; i++) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final startOfMonth = DateTime(monthDate.year, monthDate.month, 1);
      final endOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0, 23, 59, 59);

      final expenses = await getExpensesInRange(
        userId: userId,
        startDate: startOfMonth,
        endDate: endOfMonth,
      );

      final total = expenses.fold<double>(
        0.0,
        (acc, expense) => acc + (expense['amount'] as double),
      );

      final monthKey = DateFormat('MMM yyyy').format(monthDate);
      monthlyTotals[monthKey] = total;
    }

    return monthlyTotals;
  }

  /// Get daily spending for the current month
  static Future<Map<DateTime, double>> getDailySpending({
    required String userId,
    required DateTime month,
  }) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final expenses = await getExpensesInRange(
      userId: userId,
      startDate: startOfMonth,
      endDate: endOfMonth,
    );

    final Map<DateTime, double> dailySpending = {};
    for (final expense in expenses) {
      final date = expense['date'] as DateTime;
      final dayKey = DateTime(date.year, date.month, date.day);
      final amount = expense['amount'] as double;
      dailySpending[dayKey] = (dailySpending[dayKey] ?? 0.0) + amount;
    }

    return dailySpending;
  }

  /// Get top spending categories
  static Future<List<Map<String, dynamic>>> getTopCategories({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 5,
  }) async {
    final breakdown = await getCategoryBreakdown(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    final sortedCategories = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCategories.take(limit).map((entry) {
      return {
        'category': entry.key,
        'amount': entry.value,
      };
    }).toList();
  }

  /// Get spending summary for a date range
  static Future<Map<String, dynamic>> getSpendingSummary({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final expenses = await getExpensesInRange(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    final totalSpending = expenses.fold<double>(
      0.0,
      (acc, expense) => acc + (expense['amount'] as double),
    );

    final averagePerDay = totalSpending / (endDate.difference(startDate).inDays + 1);
    final expenseCount = expenses.length;

    return {
      'total': totalSpending,
      'average': averagePerDay,
      'count': expenseCount,
    };
  }

  /// Get category colors for charts
  static Map<String, int> getCategoryColors() {
    return {
      'Food': 0xFFFF6B6B,           // Red
      'Groceries': 0xFF4ECDC4,      // Teal
      'Travel': 0xFF95E1D3,         // Mint
      'Shopping': 0xFFFECA57,       // Yellow
      'Maid': 0xFFEE5A6F,           // Pink
      'Cook': 0xFFC7CEEA,           // Lavender
      'Utilities': 0xFF48DBFB,      // Sky Blue
      'Entertainment': 0xFFFF9FF3,  // Light Pink
      'Healthcare': 0xFF54A0FF,     // Blue
      'Education': 0xFF00D2D3,      // Cyan
      'Personal Care': 0xFFFFAA00,  // Orange
      'Taxes': 0xFFFF6348,          // Red Orange
      'Other': 0xFF9E9E9E,          // Gray
    };
  }
}

import 'dart:math';

/// Service for calculating XIRR (Extended Internal Rate of Return)
/// Uses Newton-Raphson method to find the rate that makes NPV = 0
class XirrService {
  /// Calculate XIRR from a list of cashflows and dates
  ///
  /// Cashflows should be:
  /// - Negative for investments (money out)
  /// - Positive for returns (money in)
  ///
  /// Returns annualized return rate as a percentage (e.g., 15.5 for 15.5%)
  /// Returns null if calculation fails or data is invalid
  static double? calculateXirr({
    required List<double> cashflows,
    required List<DateTime> dates,
    double guess = 0.1, // Initial guess: 10%
    int maxIterations = 100,
    double tolerance = 1e-6,
  }) {
    // Validation
    if (cashflows.length != dates.length) {
      return null;
    }

    if (cashflows.length < 2) {
      return null; // Need at least 2 cashflows
    }

    // Check if there's at least one positive and one negative cashflow
    final hasPositive = cashflows.any((cf) => cf > 0);
    final hasNegative = cashflows.any((cf) => cf < 0);
    if (!hasPositive || !hasNegative) {
      return null; // Need both inflows and outflows
    }

    // Sort cashflows by date
    final indexed = List.generate(
      cashflows.length,
      (i) => {'cashflow': cashflows[i], 'date': dates[i]},
    );
    indexed.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    final sortedCashflows = indexed.map((e) => e['cashflow'] as double).toList();
    final sortedDates = indexed.map((e) => e['date'] as DateTime).toList();

    // Base date (first transaction date)
    final baseDate = sortedDates.first;

    // Calculate days from base date for each transaction
    final days = sortedDates.map((date) {
      return date.difference(baseDate).inDays.toDouble();
    }).toList();

    // Newton-Raphson iteration
    double rate = guess;

    for (int iteration = 0; iteration < maxIterations; iteration++) {
      double npv = 0.0;
      double dnpv = 0.0; // Derivative of NPV

      for (int i = 0; i < sortedCashflows.length; i++) {
        final yearFraction = days[i] / 365.0;
        final discountFactor = pow(1 + rate, yearFraction).toDouble();

        // NPV calculation
        npv += sortedCashflows[i] / discountFactor;

        // Derivative of NPV (for Newton-Raphson)
        dnpv += -sortedCashflows[i] * yearFraction / (discountFactor * (1 + rate));
      }

      // Check convergence
      if (npv.abs() < tolerance) {
        return rate * 100; // Convert to percentage
      }

      // Newton-Raphson update
      if (dnpv.abs() < 1e-10) {
        // Derivative too small, can't continue
        return null;
      }

      rate = rate - npv / dnpv;

      // Prevent rate from going too negative (< -99%)
      if (rate < -0.99) {
        rate = -0.99;
      }
    }

    // Failed to converge
    return null;
  }

  /// Calculate XIRR for an investment asset using its transactions
  /// Includes current value as the final cashflow
  static double? calculateAssetXirr({
    required List<Map<String, dynamic>> transactions, // {date: DateTime, cashflow: double}
    required double currentValue,
    required DateTime currentDate,
  }) {
    if (transactions.isEmpty) {
      return null;
    }

    // Extract cashflows and dates
    final cashflows = transactions.map((t) => t['cashflow'] as double).toList();
    final dates = transactions.map((t) => t['date'] as DateTime).toList();

    // Add current value as final cashflow (money in)
    cashflows.add(currentValue);
    dates.add(currentDate);

    return calculateXirr(cashflows: cashflows, dates: dates);
  }

  /// Calculate simple CAGR (Compound Annual Growth Rate)
  /// Used when XIRR calculation is not possible (e.g., single transaction)
  ///
  /// Formula: CAGR = ((Final Value / Initial Value) ^ (1 / Years)) - 1
  static double? calculateCagr({
    required double initialValue,
    required double finalValue,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    if (initialValue <= 0) return null;
    if (finalValue < 0) return null;

    final days = endDate.difference(startDate).inDays;
    if (days <= 0) return null;

    final years = days / 365.0;

    // CAGR formula
    final cagr = pow(finalValue / initialValue, 1 / years) - 1;

    return cagr * 100; // Convert to percentage
  }

  /// Calculate absolute returns
  /// Returns percentage gain/loss
  static double calculateAbsoluteReturns({
    required double investedAmount,
    required double currentValue,
  }) {
    if (investedAmount == 0) return 0.0;
    return ((currentValue - investedAmount) / investedAmount) * 100;
  }

  /// Format XIRR/CAGR value for display
  /// Returns formatted string like "+15.5%" or "-5.2%"
  static String formatReturn(double? returnValue) {
    if (returnValue == null) return 'N/A';

    final sign = returnValue >= 0 ? '+' : '';
    return '$sign${returnValue.toStringAsFixed(2)}%';
  }

  /// Get annualized return display name based on time period
  static String getReturnLabel({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final days = endDate.difference(startDate).inDays;
    final years = days / 365.0;

    if (years < 1) {
      return 'Absolute Returns';
    } else if (years >= 1) {
      return 'XIRR (Annualized)';
    }

    return 'Returns';
  }

  /// Calculate time-weighted return (TWR)
  /// Useful when there are multiple cashflows at different times
  /// Less affected by timing of cashflows compared to XIRR
  static double? calculateTimeWeightedReturn({
    required List<double> values, // Portfolio values at each cashflow point
    required List<double> cashflows, // Cashflows at each point (0 if no cashflow)
  }) {
    if (values.length != cashflows.length || values.length < 2) {
      return null;
    }

    double twr = 1.0;

    for (int i = 1; i < values.length; i++) {
      final prevValue = values[i - 1];
      final currentValue = values[i];
      final cashflow = cashflows[i];

      // Adjust for cashflow
      final adjustedPrevValue = prevValue + cashflow;

      if (adjustedPrevValue <= 0) continue;

      // Calculate period return
      final periodReturn = (currentValue - adjustedPrevValue) / adjustedPrevValue;
      twr *= (1 + periodReturn);
    }

    // Convert to percentage
    return (twr - 1) * 100;
  }

  /// Validate if XIRR calculation is meaningful
  /// Returns error message if validation fails, null if valid
  static String? validateXirrData({
    required List<double> cashflows,
    required List<DateTime> dates,
  }) {
    if (cashflows.isEmpty || dates.isEmpty) {
      return 'No transactions available';
    }

    if (cashflows.length != dates.length) {
      return 'Data mismatch: cashflows and dates length differ';
    }

    if (cashflows.length < 2) {
      return 'Need at least 2 transactions for XIRR';
    }

    final hasPositive = cashflows.any((cf) => cf > 0);
    final hasNegative = cashflows.any((cf) => cf < 0);

    if (!hasPositive) {
      return 'No positive cashflows (returns) found';
    }

    if (!hasNegative) {
      return 'No negative cashflows (investments) found';
    }

    return null; // Valid
  }

  /// Calculate returns summary for display
  /// Returns a map with different return metrics
  static Map<String, dynamic> calculateReturnsSummary({
    required double totalInvested,
    required double currentValue,
    required DateTime? firstTransactionDate,
    required DateTime currentDate,
    double? xirr,
  }) {
    final absoluteReturns = calculateAbsoluteReturns(
      investedAmount: totalInvested,
      currentValue: currentValue,
    );

    double? cagr;
    if (firstTransactionDate != null) {
      cagr = calculateCagr(
        initialValue: totalInvested,
        finalValue: currentValue,
        startDate: firstTransactionDate,
        endDate: currentDate,
      );
    }

    final profitLoss = currentValue - totalInvested;

    return {
      'absoluteReturns': absoluteReturns,
      'absoluteReturnsFormatted': formatReturn(absoluteReturns),
      'xirr': xirr,
      'xirrFormatted': formatReturn(xirr),
      'cagr': cagr,
      'cagrFormatted': formatReturn(cagr),
      'profitLoss': profitLoss,
      'profitLossFormatted': '${profitLoss >= 0 ? '+' : ''}₹${profitLoss.toStringAsFixed(2)}',
      'hasXirr': xirr != null,
      'hasCagr': cagr != null,
    };
  }
}

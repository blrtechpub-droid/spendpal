import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';

/// Helper utilities for currency formatting
///
/// Use these instead of hardcoded ₹ symbols throughout the app
class CurrencyUtils {
  /// Format amount with currency symbol
  /// Example: formatAmount(context, 1000.50) => "₹1,000.50" or "$1,000.50"
  static String formatAmount(BuildContext context, double amount, {bool showSymbol = true}) {
    final provider = Provider.of<CurrencyProvider>(context, listen: false);
    return provider.formatAmount(amount, showSymbol: showSymbol);
  }

  /// Format amount in compact form (K, L, M, Cr)
  /// Example: formatCompact(context, 150000) => "₹1.5L" or "$150K"
  static String formatCompact(BuildContext context, double amount) {
    final provider = Provider.of<CurrencyProvider>(context, listen: false);
    return provider.formatCompact(amount);
  }

  /// Get currency symbol only
  /// Example: getSymbol(context) => "₹" or "$"
  static String getSymbol(BuildContext context) {
    final provider = Provider.of<CurrencyProvider>(context, listen: false);
    return provider.currencySymbol;
  }

  /// Get currency code only
  /// Example: getCode(context) => "INR" or "USD"
  static String getCode(BuildContext context) {
    final provider = Provider.of<CurrencyProvider>(context, listen: false);
    return provider.currencyCode;
  }
}

/// Widget that displays formatted currency amount
///
/// Automatically updates when currency changes
class CurrencyText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final bool compact;
  final bool showSymbol;

  const CurrencyText(
    this.amount, {
    super.key,
    this.style,
    this.compact = false,
    this.showSymbol = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrencyProvider>(
      builder: (context, provider, child) {
        final text = compact
            ? provider.formatCompact(amount)
            : provider.formatAmount(amount, showSymbol: showSymbol);

        return Text(text, style: style);
      },
    );
  }
}

/// Widget that displays just the currency symbol
///
/// Automatically updates when currency changes
class CurrencySymbol extends StatelessWidget {
  final TextStyle? style;

  const CurrencySymbol({super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrencyProvider>(
      builder: (context, provider, child) {
        return Text(provider.currencySymbol, style: style);
      },
    );
  }
}

/// Helper extension on BuildContext for easy access
extension CurrencyExtension on BuildContext {
  /// Quick access to currency provider
  CurrencyProvider get currency => Provider.of<CurrencyProvider>(this, listen: false);

  /// Quick access to currency symbol
  String get currencySymbol => currency.currencySymbol;

  /// Quick access to currency code
  String get currencyCode => currency.currencyCode;

  /// Format amount
  String formatCurrency(double amount, {bool showSymbol = true}) {
    return currency.formatAmount(amount, showSymbol: showSymbol);
  }

  /// Format amount in compact form
  String formatCurrencyCompact(double amount) {
    return currency.formatCompact(amount);
  }
}

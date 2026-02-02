import 'package:flutter/material.dart';
import '../services/currency_service.dart';

/// Provider for managing currency selection across the app
///
/// Works like ThemeProvider - manages currency state and notifies listeners
class CurrencyProvider with ChangeNotifier {
  Currency _selectedCurrency = const Currency(
    code: 'INR',
    name: 'Indian Rupee',
    symbol: '₹',
  );

  Currency get selectedCurrency => _selectedCurrency;
  String get currencySymbol => _selectedCurrency.symbol;
  String get currencyCode => _selectedCurrency.code;

  CurrencyProvider() {
    _loadCurrency();
  }

  /// Load saved currency from SharedPreferences
  Future<void> _loadCurrency() async {
    _selectedCurrency = await CurrencyService.getSelectedCurrency();
    notifyListeners();
  }

  /// Change currency and save to SharedPreferences
  Future<void> setCurrency(Currency currency) async {
    _selectedCurrency = currency;
    await CurrencyService.setSelectedCurrency(currency);
    notifyListeners();
  }

  /// Format amount with current currency symbol
  String formatAmount(double amount, {bool showSymbol = true}) {
    final formattedAmount = amount.toStringAsFixed(2);

    // Handle thousands separators based on currency
    final parts = formattedAmount.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';

    // Add comma separators (Indian style for INR, Western style for others)
    String formattedInteger;
    if (_selectedCurrency.code == 'INR') {
      // Indian numbering: 1,00,000
      formattedInteger = _formatIndianStyle(integerPart);
    } else {
      // Western numbering: 100,000
      formattedInteger = _formatWesternStyle(integerPart);
    }

    final numberString = '$formattedInteger.$decimalPart';
    return showSymbol ? '${_selectedCurrency.symbol}$numberString' : numberString;
  }

  /// Format with Indian numbering system (lakhs, crores)
  String _formatIndianStyle(String number) {
    if (number.length <= 3) return number;

    final reversed = number.split('').reversed.toList();
    final chunks = <String>[];

    // First group of 3 digits
    chunks.add(reversed.take(3).toList().reversed.join());

    // Remaining groups of 2 digits
    int index = 3;
    while (index < reversed.length) {
      final end = (index + 2).clamp(0, reversed.length);
      chunks.insert(0, reversed.sublist(index, end).reversed.join());
      index += 2;
    }

    return chunks.join(',');
  }

  /// Format with Western numbering system (thousands)
  String _formatWesternStyle(String number) {
    if (number.length <= 3) return number;

    final reversed = number.split('').reversed.toList();
    final chunks = <String>[];

    // Groups of 3 digits
    for (int i = 0; i < reversed.length; i += 3) {
      final end = (i + 3).clamp(0, reversed.length);
      chunks.insert(0, reversed.sublist(i, end).reversed.join());
    }

    return chunks.join(',');
  }

  /// Format for compact display (e.g., "1.2K", "3.5M")
  String formatCompact(double amount) {
    if (amount.abs() >= 10000000) {
      // Crores (for INR) or Millions (for others)
      if (_selectedCurrency.code == 'INR') {
        return '${_selectedCurrency.symbol}${(amount / 10000000).toStringAsFixed(1)}Cr';
      } else {
        return '${_selectedCurrency.symbol}${(amount / 1000000).toStringAsFixed(1)}M';
      }
    } else if (amount.abs() >= 100000) {
      // Lakhs (for INR) or Thousands (for others)
      if (_selectedCurrency.code == 'INR') {
        return '${_selectedCurrency.symbol}${(amount / 100000).toStringAsFixed(1)}L';
      } else {
        return '${_selectedCurrency.symbol}${(amount / 1000).toStringAsFixed(1)}K';
      }
    } else if (amount.abs() >= 1000) {
      return '${_selectedCurrency.symbol}${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return formatAmount(amount);
    }
  }
}

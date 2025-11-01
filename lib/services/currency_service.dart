import 'package:shared_preferences/shared_preferences.dart';

class Currency {
  final String code;
  final String name;
  final String symbol;

  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
  });

  @override
  String toString() => '$code ($symbol)';
}

class CurrencyService {
  static const String _currencyCodeKey = 'selected_currency_code';
  static const String _currencySymbolKey = 'selected_currency_symbol';
  static const String _currencyNameKey = 'selected_currency_name';

  // Popular currencies list
  static const List<Currency> popularCurrencies = [
    Currency(code: 'INR', name: 'Indian Rupee', symbol: '₹'),
    Currency(code: 'USD', name: 'US Dollar', symbol: '\$'),
    Currency(code: 'EUR', name: 'Euro', symbol: '€'),
    Currency(code: 'GBP', name: 'British Pound', symbol: '£'),
    Currency(code: 'JPY', name: 'Japanese Yen', symbol: '¥'),
    Currency(code: 'CNY', name: 'Chinese Yuan', symbol: '¥'),
    Currency(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$'),
    Currency(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$'),
    Currency(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF'),
    Currency(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$'),
    Currency(code: 'HKD', name: 'Hong Kong Dollar', symbol: 'HK\$'),
    Currency(code: 'NZD', name: 'New Zealand Dollar', symbol: 'NZ\$'),
    Currency(code: 'KRW', name: 'South Korean Won', symbol: '₩'),
    Currency(code: 'SEK', name: 'Swedish Krona', symbol: 'kr'),
    Currency(code: 'NOK', name: 'Norwegian Krone', symbol: 'kr'),
    Currency(code: 'MXN', name: 'Mexican Peso', symbol: '\$'),
    Currency(code: 'BRL', name: 'Brazilian Real', symbol: 'R\$'),
    Currency(code: 'ZAR', name: 'South African Rand', symbol: 'R'),
    Currency(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ'),
    Currency(code: 'SAR', name: 'Saudi Riyal', symbol: '﷼'),
  ];

  // Get saved currency
  static Future<Currency> getSelectedCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_currencyCodeKey) ?? 'INR';
    final name = prefs.getString(_currencyNameKey) ?? 'Indian Rupee';
    final symbol = prefs.getString(_currencySymbolKey) ?? '₹';

    return Currency(code: code, name: name, symbol: symbol);
  }

  // Save currency selection
  static Future<void> setSelectedCurrency(Currency currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyCodeKey, currency.code);
    await prefs.setString(_currencyNameKey, currency.name);
    await prefs.setString(_currencySymbolKey, currency.symbol);
  }

  // Get currency symbol only (for quick access)
  static Future<String> getCurrencySymbol() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencySymbolKey) ?? '₹';
  }

  // Get currency code only (for quick access)
  static Future<String> getCurrencyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencyCodeKey) ?? 'INR';
  }

  // Find currency by code
  static Currency? findCurrencyByCode(String code) {
    try {
      return popularCurrencies.firstWhere(
        (currency) => currency.code == code,
      );
    } catch (e) {
      return null;
    }
  }
}

/// Lightweight model for a cached instrument (MF scheme / NSE stock / ETF)
class InstrumentCacheItem {
  final String name;
  final String type; // 'mutual_fund', 'equity', 'etf'
  final String? symbol; // NSE symbol, null for MFs
  final String? schemeCode; // AMFI scheme code, null for stocks
  final String? isin;

  const InstrumentCacheItem({
    required this.name,
    required this.type,
    this.symbol,
    this.schemeCode,
    this.isin,
  });

  /// Convert to SQLite map (includes pre-computed name_lower)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'name_lower': name.toLowerCase(),
      'type': type,
      'symbol': symbol,
      'scheme_code': schemeCode,
      'isin': isin,
    };
  }

  /// Create from SQLite row
  factory InstrumentCacheItem.fromMap(Map<String, dynamic> map) {
    return InstrumentCacheItem(
      name: map['name'] as String,
      type: map['type'] as String,
      symbol: map['symbol'] as String?,
      schemeCode: map['scheme_code'] as String?,
      isin: map['isin'] as String?,
    );
  }

  @override
  String toString() {
    if (type == 'mutual_fund' && schemeCode != null) {
      return '$name ($schemeCode)';
    }
    if (symbol != null) {
      return '$name ($symbol)';
    }
    return name;
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import '../models/instrument_cache_item.dart';
import 'local_db_service.dart';

/// Progress info for cache download
class CacheDownloadProgress {
  final String stage; // 'mutual_funds', 'stocks', 'done', 'error'
  final double progress; // 0.0 - 1.0
  final String message;

  const CacheDownloadProgress({
    required this.stage,
    required this.progress,
    required this.message,
  });
}

/// Singleton service for caching and searching Indian MF schemes and NSE stocks
class InstrumentCacheService {
  InstrumentCacheService._();
  static final InstrumentCacheService instance = InstrumentCacheService._();

  static const _mfCacheKey = 'mutual_funds';
  static const _stockCacheKey = 'nse_stocks';
  static const _cacheTtlDays = 7;
  static const _batchSize = 500;

  final _progressController = StreamController<CacheDownloadProgress>.broadcast();
  Stream<CacheDownloadProgress> get progressStream => _progressController.stream;

  bool _isRefreshing = false;
  bool _cacheReady = false;

  /// Check if cache is populated and not stale; trigger refresh if needed
  Future<void> ensureCacheReady() async {
    if (_cacheReady) return;

    final mfStale = await _isCacheStale(_mfCacheKey);
    final stockStale = await _isCacheStale(_stockCacheKey);

    if (mfStale || stockStale) {
      // Refresh in background — don't await
      _refreshCache(mfStale: mfStale, stockStale: stockStale);
    } else {
      _cacheReady = true;
    }
  }

  /// Force refresh from settings or manual trigger
  Future<void> forceRefresh() async {
    await _refreshCache(mfStale: true, stockStale: true);
  }

  /// Search instruments by query string
  Future<List<InstrumentCacheItem>> searchInstruments({
    required String query,
    String? type, // 'equity', 'mutual_fund', 'etf', or null for all
    int limit = 20,
  }) async {
    if (query.trim().length < 2) return [];

    final db = await LocalDBService.instance.database;
    final queryLower = query.trim().toLowerCase();
    final queryUpper = query.trim().toUpperCase();

    String sql;
    List<dynamic> args;

    if (type == 'mutual_fund') {
      // MF search: match on name or scheme_code
      sql = '''
        SELECT * FROM instrument_cache
        WHERE type = 'mutual_fund'
          AND (name_lower LIKE ? OR scheme_code LIKE ?)
        ORDER BY CASE WHEN name_lower LIKE ? THEN 0 ELSE 1 END
        LIMIT ?
      ''';
      args = ['%$queryLower%', '%$queryUpper%', '$queryLower%', limit];
    } else if (type == 'equity' || type == 'etf') {
      // Stock/ETF search: match on name or symbol
      final types = type == 'equity'
          ? "type = 'equity'"
          : "type = 'etf'";
      sql = '''
        SELECT * FROM instrument_cache
        WHERE $types
          AND (name_lower LIKE ? OR symbol LIKE ?)
        ORDER BY CASE WHEN name_lower LIKE ? THEN 0 WHEN symbol LIKE ? THEN 0 ELSE 1 END
        LIMIT ?
      ''';
      args = ['%$queryLower%', '%$queryUpper%', '$queryLower%', '$queryUpper%', limit];
    } else {
      // Search all types
      sql = '''
        SELECT * FROM instrument_cache
        WHERE (name_lower LIKE ? OR symbol LIKE ? OR scheme_code LIKE ?)
        ORDER BY CASE WHEN name_lower LIKE ? THEN 0 WHEN symbol LIKE ? THEN 0 ELSE 1 END
        LIMIT ?
      ''';
      args = [
        '%$queryLower%', '%$queryUpper%', '%$queryUpper%',
        '$queryLower%', '$queryUpper%', limit,
      ];
    }

    final results = await db.rawQuery(sql, args);
    return results.map((row) => InstrumentCacheItem.fromMap(row)).toList();
  }

  /// Get cache status info
  Future<Map<String, dynamic>> getCacheStatus() async {
    final db = await LocalDBService.instance.database;
    final rows = await db.query('cache_metadata');

    final status = <String, dynamic>{};
    for (final row in rows) {
      final key = row['cache_key'] as String;
      status[key] = {
        'lastUpdated': row['last_updated'],
        'itemCount': row['item_count'],
      };
    }

    // Total count
    final total = await db.rawQuery('SELECT COUNT(*) as cnt FROM instrument_cache');
    status['totalItems'] = Sqflite.firstIntValue(total) ?? 0;

    return status;
  }

  /// Check if cache has any data (for fallback logic in UI)
  Future<bool> hasCacheData() async {
    final db = await LocalDBService.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM instrument_cache');
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }

  // ==================== PRIVATE ====================

  Future<bool> _isCacheStale(String cacheKey) async {
    final db = await LocalDBService.instance.database;
    final rows = await db.query(
      'cache_metadata',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );

    if (rows.isEmpty) return true;

    final lastUpdated = DateTime.tryParse(rows.first['last_updated'] as String);
    if (lastUpdated == null) return true;

    return DateTime.now().difference(lastUpdated).inDays >= _cacheTtlDays;
  }

  Future<void> _refreshCache({
    required bool mfStale,
    required bool stockStale,
  }) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      if (mfStale) {
        _progressController.add(const CacheDownloadProgress(
          stage: 'mutual_funds',
          progress: 0.0,
          message: 'Downloading mutual fund data...',
        ));
        await _fetchAndCacheMfSchemes();
      }

      if (stockStale) {
        _progressController.add(const CacheDownloadProgress(
          stage: 'stocks',
          progress: 0.5,
          message: 'Downloading stock data...',
        ));
        await _fetchAndCacheNseStocks();
      }

      _cacheReady = true;
      _progressController.add(const CacheDownloadProgress(
        stage: 'done',
        progress: 1.0,
        message: 'Cache updated successfully',
      ));
    } catch (e) {
      print('❌ Cache refresh error: $e');
      _progressController.add(CacheDownloadProgress(
        stage: 'error',
        progress: 0.0,
        message: 'Cache update failed: $e',
      ));
      // Check if we have stale data — still usable
      final hasData = await hasCacheData();
      if (hasData) _cacheReady = true;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Fetch all MF schemes from MFAPI and cache in SQLite
  Future<void> _fetchAndCacheMfSchemes() async {
    final response = await http.get(
      Uri.parse('https://api.mfapi.in/mf'),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('MF API returned ${response.statusCode}');
    }

    final List<dynamic> schemes = json.decode(response.body);
    if (schemes.isEmpty) return;

    final db = await LocalDBService.instance.database;

    // Clear existing MF cache
    await db.delete('instrument_cache', where: "type = 'mutual_fund'");

    // Batch insert in chunks
    int inserted = 0;
    for (int i = 0; i < schemes.length; i += _batchSize) {
      final chunk = schemes.skip(i).take(_batchSize);
      final batch = db.batch();

      for (final scheme in chunk) {
        final name = (scheme['schemeName'] ?? '').toString().trim();
        final code = (scheme['schemeCode'] ?? '').toString().trim();
        if (name.isEmpty || code.isEmpty) continue;

        batch.insert('instrument_cache', {
          'name': name,
          'name_lower': name.toLowerCase(),
          'type': 'mutual_fund',
          'symbol': null,
          'scheme_code': code,
          'isin': null,
        });
        inserted++;
      }

      await batch.commit(noResult: true);

      // Update progress
      final progress = (i + _batchSize).clamp(0, schemes.length) / schemes.length;
      _progressController.add(CacheDownloadProgress(
        stage: 'mutual_funds',
        progress: progress * 0.5, // MFs are first half of total progress
        message: 'Caching mutual funds... ${(progress * 100).toInt()}%',
      ));
    }

    // Update metadata
    await db.insert(
      'cache_metadata',
      {
        'cache_key': _mfCacheKey,
        'last_updated': DateTime.now().toIso8601String(),
        'item_count': inserted,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('✅ Cached $inserted mutual fund schemes');
  }

  /// Fetch NSE stock list from CSV and cache in SQLite
  Future<void> _fetchAndCacheNseStocks() async {
    final response = await http.get(
      Uri.parse('https://nsearchives.nseindia.com/content/equities/EQUITY_L.csv'),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/csv,text/plain,*/*',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('NSE API returned ${response.statusCode}');
    }

    final csvData = const CsvToListConverter(eol: '\n').convert(response.body);
    if (csvData.length <= 1) return; // Only header or empty

    final db = await LocalDBService.instance.database;

    // Clear existing stock/ETF cache
    await db.delete('instrument_cache', where: "type = 'equity' OR type = 'etf'");

    // Parse header to find column indices
    final header = csvData[0].map((e) => e.toString().trim().toUpperCase()).toList();
    final symbolIdx = header.indexOf('SYMBOL');
    final nameIdx = header.indexOf('NAME OF COMPANY');
    final isinIdx = header.indexOf('ISIN NUMBER');

    if (symbolIdx == -1 || nameIdx == -1) {
      throw Exception('Unexpected NSE CSV format: $header');
    }

    int inserted = 0;
    final rows = csvData.skip(1).toList(); // Skip header

    for (int i = 0; i < rows.length; i += _batchSize) {
      final chunk = rows.skip(i).take(_batchSize);
      final batch = db.batch();

      for (final row in chunk) {
        if (row.length <= nameIdx) continue;

        final symbol = row[symbolIdx].toString().trim();
        final name = row[nameIdx].toString().trim();
        final isin = isinIdx >= 0 && row.length > isinIdx
            ? row[isinIdx].toString().trim()
            : null;

        if (name.isEmpty || symbol.isEmpty) continue;

        final isEtf = _isLikelyEtf(name, symbol);

        batch.insert('instrument_cache', {
          'name': name,
          'name_lower': name.toLowerCase(),
          'type': isEtf ? 'etf' : 'equity',
          'symbol': symbol,
          'scheme_code': null,
          'isin': isin,
        });
        inserted++;
      }

      await batch.commit(noResult: true);

      final progress = (i + _batchSize).clamp(0, rows.length) / rows.length;
      _progressController.add(CacheDownloadProgress(
        stage: 'stocks',
        progress: 0.5 + progress * 0.5, // Stocks are second half
        message: 'Caching stocks... ${(progress * 100).toInt()}%',
      ));
    }

    // Update metadata
    await db.insert(
      'cache_metadata',
      {
        'cache_key': _stockCacheKey,
        'last_updated': DateTime.now().toIso8601String(),
        'item_count': inserted,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('✅ Cached $inserted NSE stocks/ETFs');
  }

  /// Heuristic ETF detection from NSE data
  bool _isLikelyEtf(String name, String symbol) {
    final nameLower = name.toLowerCase();
    final symbolUpper = symbol.toUpperCase();
    return nameLower.contains('etf') ||
        nameLower.contains('exchange traded') ||
        symbolUpper.endsWith('BEES') ||
        symbolUpper.contains('NIFTY') ||
        symbolUpper.contains('BANKBEES') ||
        symbolUpper.contains('GOLDBEES') ||
        symbolUpper.contains('LIQUIDBEES');
  }

  void dispose() {
    _progressController.close();
  }
}

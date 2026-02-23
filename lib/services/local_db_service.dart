import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/local_transaction_model.dart';
import '../models/local_pattern_model.dart';
import '../models/scan_history_model.dart';
import 'encryption_service.dart';

/// Local database service for privacy-first transaction storage
///
/// All financial data stored locally in SQLite, never in Firebase
/// Supports SMS, Email, and Manual transactions
/// Encrypted raw content for maximum privacy
class LocalDBService {
  static Database? _database;
  static final _databaseName = 'spendpal_local.db';
  static final _databaseVersion = 4; // Incremented for scan_history table

  // Singleton
  LocalDBService._();
  static final LocalDBService instance = LocalDBService._();

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    // Initialize encryption first
    await EncryptionService.initialize();

    // Get app documents directory
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    print('📁 Initializing local database at: $path');

    // Open database
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    print('🔨 Creating database tables...');

    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        source TEXT NOT NULL,
        source_identifier TEXT,

        tracker_id TEXT,
        tracker_confidence REAL,

        amount REAL NOT NULL,
        merchant TEXT NOT NULL,
        category TEXT NOT NULL,
        transaction_date TEXT NOT NULL,

        transaction_id TEXT,
        account_info TEXT,
        notes TEXT,

        raw_content TEXT,

        status TEXT DEFAULT 'pending',
        is_debit INTEGER DEFAULT 1,

        parsed_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        user_id TEXT NOT NULL,
        device_id TEXT,

        parsed_by TEXT,
        pattern_id TEXT,
        confidence REAL
      )
    ''');

    // Indexes for fast queries
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(transaction_date DESC)');
    await db.execute('CREATE INDEX idx_transactions_user ON transactions(user_id)');
    await db.execute('CREATE INDEX idx_transactions_category ON transactions(category)');
    await db.execute('CREATE INDEX idx_transactions_merchant ON transactions(merchant)');
    await db.execute('CREATE INDEX idx_transactions_status ON transactions(status)');
    await db.execute('CREATE INDEX idx_transactions_source ON transactions(source)');
    await db.execute('CREATE INDEX idx_transactions_txn_id ON transactions(transaction_id)');
    await db.execute('CREATE INDEX idx_transactions_tracker ON transactions(tracker_id)');

    // Patterns table (for personal regex patterns)
    await db.execute('''
      CREATE TABLE patterns (
        id TEXT PRIMARY KEY,
        sender_hash TEXT NOT NULL,
        source TEXT NOT NULL,

        pattern TEXT NOT NULL,
        extraction_map TEXT NOT NULL,
        category TEXT NOT NULL,
        is_debit INTEGER DEFAULT 1,

        sample_text TEXT,
        description TEXT,

        accuracy REAL DEFAULT 0,
        match_count INTEGER DEFAULT 0,
        fail_count INTEGER DEFAULT 0,
        last_match_date TEXT,

        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        user_id TEXT NOT NULL,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // Indexes for fast pattern matching
    await db.execute('CREATE INDEX idx_patterns_sender ON patterns(sender_hash)');
    await db.execute('CREATE INDEX idx_patterns_user ON patterns(user_id)');
    await db.execute('CREATE INDEX idx_patterns_source ON patterns(source)');
    await db.execute('CREATE INDEX idx_patterns_active ON patterns(is_active)');
    await db.execute('CREATE INDEX idx_patterns_accuracy ON patterns(accuracy DESC)');

    // Scan history table
    await db.execute('''
      CREATE TABLE scan_history (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        scan_date TEXT NOT NULL,
        source TEXT NOT NULL,
        mode TEXT NOT NULL,
        days_scanned INTEGER NOT NULL,
        range_start TEXT NOT NULL,
        range_end TEXT NOT NULL,
        total_messages INTEGER DEFAULT 0,
        filtered_messages INTEGER DEFAULT 0,
        already_processed INTEGER DEFAULT 0,
        pattern_matched INTEGER DEFAULT 0,
        ai_processed INTEGER DEFAULT 0,
        transactions_found INTEGER DEFAULT 0,
        new_patterns_learned INTEGER DEFAULT 0
      )
    ''');

    // Indexes for scan history
    await db.execute('CREATE INDEX idx_scan_history_user ON scan_history(user_id)');
    await db.execute('CREATE INDEX idx_scan_history_date ON scan_history(scan_date DESC)');
    await db.execute('CREATE INDEX idx_scan_history_source ON scan_history(source)');

    print('✅ Database tables created successfully');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('⬆️ Upgrading database from v$oldVersion to v$newVersion');

    // Migration from v1 to v2: Add patterns table
    if (oldVersion < 2) {
      print('📝 Adding patterns table...');

      await db.execute('''
        CREATE TABLE patterns (
          id TEXT PRIMARY KEY,
          sender_hash TEXT NOT NULL,
          source TEXT NOT NULL,

          pattern TEXT NOT NULL,
          extraction_map TEXT NOT NULL,
          category TEXT NOT NULL,
          is_debit INTEGER DEFAULT 1,

          sample_text TEXT,
          description TEXT,

          accuracy REAL DEFAULT 0,
          match_count INTEGER DEFAULT 0,
          fail_count INTEGER DEFAULT 0,
          last_match_date TEXT,

          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          user_id TEXT NOT NULL,
          is_active INTEGER DEFAULT 1
        )
      ''');

      await db.execute('CREATE INDEX idx_patterns_sender ON patterns(sender_hash)');
      await db.execute('CREATE INDEX idx_patterns_user ON patterns(user_id)');
      await db.execute('CREATE INDEX idx_patterns_source ON patterns(source)');
      await db.execute('CREATE INDEX idx_patterns_active ON patterns(is_active)');
      await db.execute('CREATE INDEX idx_patterns_accuracy ON patterns(accuracy DESC)');

      print('✅ Patterns table added successfully');
    }

    // Migration from v2 to v3: Add tracker columns
    if (oldVersion < 3) {
      print('📝 Adding tracker columns to transactions table...');

      await db.execute('ALTER TABLE transactions ADD COLUMN tracker_id TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN tracker_confidence REAL');
      await db.execute('CREATE INDEX idx_transactions_tracker ON transactions(tracker_id)');

      print('✅ Tracker columns added successfully');
    }

    // Migration from v3 to v4: Add scan_history table
    if (oldVersion < 4) {
      print('📝 Adding scan_history table...');

      await db.execute('''
        CREATE TABLE scan_history (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          scan_date TEXT NOT NULL,
          source TEXT NOT NULL,
          mode TEXT NOT NULL,
          days_scanned INTEGER NOT NULL,
          range_start TEXT NOT NULL,
          range_end TEXT NOT NULL,
          total_messages INTEGER DEFAULT 0,
          filtered_messages INTEGER DEFAULT 0,
          already_processed INTEGER DEFAULT 0,
          pattern_matched INTEGER DEFAULT 0,
          ai_processed INTEGER DEFAULT 0,
          transactions_found INTEGER DEFAULT 0,
          new_patterns_learned INTEGER DEFAULT 0
        )
      ''');

      await db.execute('CREATE INDEX idx_scan_history_user ON scan_history(user_id)');
      await db.execute('CREATE INDEX idx_scan_history_date ON scan_history(scan_date DESC)');
      await db.execute('CREATE INDEX idx_scan_history_source ON scan_history(source)');

      print('✅ Scan history table added successfully');
    }
  }

  /// Insert transaction
  Future<bool> insertTransaction(LocalTransactionModel transaction) async {
    try {
      final db = await database;

      // Encrypt raw content before storage
      final transactionMap = transaction.toMap();
      if (transactionMap['raw_content'] != null && transactionMap['raw_content'].isNotEmpty) {
        transactionMap['raw_content'] = EncryptionService.encrypt(transactionMap['raw_content']);
      }

      await db.insert(
        'transactions',
        transactionMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Transaction saved: ${transaction.merchant} - ₹${transaction.amount}');
      return true;
    } catch (e) {
      print('❌ Error inserting transaction: $e');
      return false;
    }
  }

  /// Insert multiple transactions in batch (faster)
  Future<int> insertBatch(List<LocalTransactionModel> transactions) async {
    if (transactions.isEmpty) return 0;

    try {
      final db = await database;
      int savedCount = 0;

      final batch = db.batch();

      for (final transaction in transactions) {
        final transactionMap = transaction.toMap();

        // Encrypt raw content
        if (transactionMap['raw_content'] != null && transactionMap['raw_content'].isNotEmpty) {
          transactionMap['raw_content'] = EncryptionService.encrypt(transactionMap['raw_content']);
        }

        batch.insert(
          'transactions',
          transactionMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      savedCount = transactions.length;

      print('✅ Batch insert: $savedCount transactions saved');
      return savedCount;
    } catch (e) {
      print('❌ Error in batch insert: $e');
      return 0;
    }
  }

  /// Get all transactions
  Future<List<LocalTransactionModel>> getTransactions({
    String? userId,
    TransactionStatus? status,
    TransactionSource? source,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await database;

      String query = 'SELECT * FROM transactions WHERE 1=1';
      List<dynamic> args = [];

      if (userId != null) {
        query += ' AND user_id = ?';
        args.add(userId);
      }

      if (status != null) {
        query += ' AND status = ?';
        args.add(status.name);
      }

      if (source != null) {
        query += ' AND source = ?';
        args.add(source.name);
      }

      if (category != null) {
        query += ' AND category = ?';
        args.add(category);
      }

      if (startDate != null) {
        query += ' AND transaction_date >= ?';
        args.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        query += ' AND transaction_date <= ?';
        args.add(endDate.toIso8601String());
      }

      query += ' ORDER BY transaction_date DESC';

      if (limit != null) {
        query += ' LIMIT ?';
        args.add(limit);
      }

      if (offset != null) {
        query += ' OFFSET ?';
        args.add(offset);
      }

      print('📊 DEBUG getTransactions: SQL = $query');
      print('📊 DEBUG getTransactions: Args = $args');

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);

      print('📊 DEBUG getTransactions: Returned ${maps.length} rows');

      return maps.map((map) {
        // Create mutable copy of map (database maps are read-only)
        final mutableMap = Map<String, dynamic>.from(map);

        // Decrypt raw content
        if (mutableMap['raw_content'] != null && mutableMap['raw_content'].isNotEmpty) {
          mutableMap['raw_content'] = EncryptionService.decrypt(mutableMap['raw_content']);
        }
        return LocalTransactionModel.fromMap(mutableMap);
      }).toList();
    } catch (e) {
      print('❌ Error getting transactions: $e');
      return [];
    }
  }

  /// Get transaction by ID
  Future<LocalTransactionModel?> getTransaction(String id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;

      // Create mutable copy of map (database maps are read-only)
      final mutableMap = Map<String, dynamic>.from(maps.first);

      // Decrypt raw content
      if (mutableMap['raw_content'] != null && mutableMap['raw_content'].isNotEmpty) {
        mutableMap['raw_content'] = EncryptionService.decrypt(mutableMap['raw_content']);
      }

      return LocalTransactionModel.fromMap(mutableMap);
    } catch (e) {
      print('❌ Error getting transaction: $e');
      return null;
    }
  }

  /// Check if transaction with same transaction ID exists
  Future<bool> isDuplicate({
    required String userId,
    String? transactionId,
  }) async {
    if (transactionId == null || transactionId.isEmpty) {
      return false;
    }

    try {
      final db = await database;
      final result = await db.query(
        'transactions',
        where: 'user_id = ? AND transaction_id = ?',
        whereArgs: [userId, transactionId],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      print('❌ Error checking duplicate: $e');
      return false;
    }
  }

  /// Check for duplicate by merchant, amount, and date (when no transaction ID)
  Future<bool> isDuplicateByDetails({
    required String userId,
    required String merchant,
    required double amount,
    required DateTime transactionDate,
  }) async {
    try {
      final db = await database;

      // Check for same merchant, amount, and date (within same day)
      final startOfDay = DateTime(transactionDate.year, transactionDate.month, transactionDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final result = await db.query(
        'transactions',
        where: 'user_id = ? AND merchant = ? AND amount = ? AND transaction_date >= ? AND transaction_date < ?',
        whereArgs: [
          userId,
          merchant,
          amount,
          startOfDay.toIso8601String(),
          endOfDay.toIso8601String(),
        ],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      print('❌ Error checking duplicate by details: $e');
      return false;
    }
  }

  /// Update transaction
  Future<bool> updateTransaction(LocalTransactionModel transaction) async {
    try {
      final db = await database;

      final transactionMap = transaction.copyWith(
        updatedAt: DateTime.now(),
      ).toMap();

      // Encrypt raw content
      if (transactionMap['raw_content'] != null && transactionMap['raw_content'].isNotEmpty) {
        transactionMap['raw_content'] = EncryptionService.encrypt(transactionMap['raw_content']);
      }

      final count = await db.update(
        'transactions',
        transactionMap,
        where: 'id = ?',
        whereArgs: [transaction.id],
      );

      print('✅ Transaction updated: ${transaction.merchant}');
      return count > 0;
    } catch (e) {
      print('❌ Error updating transaction: $e');
      return false;
    }
  }

  /// Delete transaction
  Future<bool> deleteTransaction(String id) async {
    try {
      final db = await database;
      final count = await db.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );

      print('✅ Transaction deleted: $id');
      return count > 0;
    } catch (e) {
      print('❌ Error deleting transaction: $e');
      return false;
    }
  }

  /// Get transactions by tracker ID
  Future<List<LocalTransactionModel>> getTransactionsByTracker({
    required String userId,
    required String trackerId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      final db = await database;

      String query = 'SELECT * FROM transactions WHERE user_id = ? AND tracker_id = ?';
      List<dynamic> args = [userId, trackerId];

      if (startDate != null) {
        query += ' AND transaction_date >= ?';
        args.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        query += ' AND transaction_date <= ?';
        args.add(endDate.toIso8601String());
      }

      query += ' ORDER BY transaction_date DESC';

      if (limit != null) {
        query += ' LIMIT ?';
        args.add(limit);
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);

      return maps.map((map) {
        final mutableMap = Map<String, dynamic>.from(map);
        if (mutableMap['raw_content'] != null && mutableMap['raw_content'].isNotEmpty) {
          mutableMap['raw_content'] = EncryptionService.decrypt(mutableMap['raw_content']);
        }
        return LocalTransactionModel.fromMap(mutableMap);
      }).toList();
    } catch (e) {
      print('❌ Error getting transactions by tracker: $e');
      return [];
    }
  }

  /// Get transaction count
  Future<int> getTransactionCount({
    String? userId,
    TransactionStatus? status,
    TransactionSource? source,
  }) async {
    try {
      final db = await database;

      String query = 'SELECT COUNT(*) FROM transactions WHERE 1=1';
      List<dynamic> args = [];

      if (userId != null) {
        query += ' AND user_id = ?';
        args.add(userId);
      }

      if (status != null) {
        query += ' AND status = ?';
        args.add(status.name);
      }

      if (source != null) {
        query += ' AND source = ?';
        args.add(source.name);
      }

      final result = await db.rawQuery(query, args);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ Error getting transaction count: $e');
      return 0;
    }
  }

  /// Get category totals
  Future<Map<String, double>> getCategoryTotals({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    bool debitOnly = true,
  }) async {
    try {
      final db = await database;

      String query = '''
        SELECT category, SUM(amount) as total
        FROM transactions
        WHERE user_id = ?
      ''';

      List<dynamic> args = [userId];

      if (debitOnly) {
        query += ' AND is_debit = 1';
      }

      if (startDate != null) {
        query += ' AND transaction_date >= ?';
        args.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        query += ' AND transaction_date <= ?';
        args.add(endDate.toIso8601String());
      }

      query += ' GROUP BY category ORDER BY total DESC';

      final result = await db.rawQuery(query, args);

      return Map.fromEntries(
        result.map((row) => MapEntry(
          row['category'] as String,
          (row['total'] as num).toDouble(),
        )),
      );
    } catch (e) {
      print('❌ Error getting category totals: $e');
      return {};
    }
  }

  /// Export transactions to JSON (for backup)
  Future<List<Map<String, dynamic>>> exportTransactions({
    required String userId,
  }) async {
    try {
      final transactions = await getTransactions(userId: userId);
      return transactions.map((t) => t.toMap()).toList();
    } catch (e) {
      print('❌ Error exporting transactions: $e');
      return [];
    }
  }

  // ==================== PATTERN OPERATIONS ====================

  /// Insert pattern
  Future<bool> insertPattern(LocalPatternModel pattern) async {
    try {
      final db = await database;

      await db.insert(
        'patterns',
        pattern.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Pattern saved: ${pattern.senderHash} - ${pattern.category}');
      return true;
    } catch (e) {
      print('❌ Error inserting pattern: $e');
      return false;
    }
  }

  /// Get all patterns for a user
  Future<List<LocalPatternModel>> getPatterns({
    required String userId,
    TransactionSource? source,
    String? senderHash,
    bool? isActive,
  }) async {
    try {
      final db = await database;

      String query = 'SELECT * FROM patterns WHERE user_id = ?';
      List<dynamic> args = [userId];

      if (source != null) {
        query += ' AND source = ?';
        args.add(source.name);
      }

      if (senderHash != null) {
        query += ' AND sender_hash = ?';
        args.add(senderHash);
      }

      if (isActive != null) {
        query += ' AND is_active = ?';
        args.add(isActive ? 1 : 0);
      }

      // Order by accuracy (best patterns first)
      query += ' ORDER BY accuracy DESC, match_count DESC';

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);

      return maps.map((map) => LocalPatternModel.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error getting patterns: $e');
      return [];
    }
  }

  /// Get pattern by ID
  Future<LocalPatternModel?> getPattern(String id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'patterns',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;

      return LocalPatternModel.fromMap(maps.first);
    } catch (e) {
      print('❌ Error getting pattern: $e');
      return null;
    }
  }

  /// Get patterns for specific sender (for matching)
  Future<List<LocalPatternModel>> getPatternsBySender({
    required String userId,
    required String senderHash,
    required TransactionSource source,
  }) async {
    try {
      final db = await database;

      final List<Map<String, dynamic>> maps = await db.query(
        'patterns',
        where: 'user_id = ? AND sender_hash = ? AND source = ? AND is_active = 1',
        whereArgs: [userId, senderHash, source.name],
        orderBy: 'accuracy DESC, match_count DESC',
      );

      return maps.map((map) => LocalPatternModel.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error getting patterns by sender: $e');
      return [];
    }
  }

  /// Update pattern
  Future<bool> updatePattern(LocalPatternModel pattern) async {
    try {
      final db = await database;

      final patternMap = pattern.copyWith(
        updatedAt: DateTime.now(),
      ).toMap();

      final count = await db.update(
        'patterns',
        patternMap,
        where: 'id = ?',
        whereArgs: [pattern.id],
      );

      print('✅ Pattern updated: ${pattern.senderHash}');
      return count > 0;
    } catch (e) {
      print('❌ Error updating pattern: $e');
      return false;
    }
  }

  /// Delete pattern
  Future<bool> deletePattern(String id) async {
    try {
      final db = await database;
      final count = await db.delete(
        'patterns',
        where: 'id = ?',
        whereArgs: [id],
      );

      print('✅ Pattern deleted: $id');
      return count > 0;
    } catch (e) {
      print('❌ Error deleting pattern: $e');
      return false;
    }
  }

  /// Increment pattern match count (successful match)
  Future<bool> incrementPatternMatch(String patternId) async {
    try {
      final pattern = await getPattern(patternId);
      if (pattern == null) return false;

      final updated = pattern.incrementMatch();
      return await updatePattern(updated);
    } catch (e) {
      print('❌ Error incrementing pattern match: $e');
      return false;
    }
  }

  /// Increment pattern fail count (failed match)
  Future<bool> incrementPatternFail(String patternId) async {
    try {
      final pattern = await getPattern(patternId);
      if (pattern == null) return false;

      final updated = pattern.incrementFail();
      return await updatePattern(updated);
    } catch (e) {
      print('❌ Error incrementing pattern fail: $e');
      return false;
    }
  }

  /// Get pattern count
  Future<int> getPatternCount({
    required String userId,
    TransactionSource? source,
  }) async {
    try {
      final db = await database;

      String query = 'SELECT COUNT(*) FROM patterns WHERE user_id = ?';
      List<dynamic> args = [userId];

      if (source != null) {
        query += ' AND source = ?';
        args.add(source.name);
      }

      final result = await db.rawQuery(query, args);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ Error getting pattern count: $e');
      return 0;
    }
  }

  // ==================== SCAN HISTORY OPERATIONS ====================

  /// Insert scan history record
  Future<bool> insertScanHistory(ScanHistoryModel scanHistory) async {
    try {
      final db = await database;

      await db.insert(
        'scan_history',
        scanHistory.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('✅ Scan history saved: ${scanHistory.source.name} - ${scanHistory.scanDate}');
      return true;
    } catch (e) {
      print('❌ Error inserting scan history: $e');
      return false;
    }
  }

  /// Get all scan history for a user
  Future<List<ScanHistoryModel>> getScanHistory({
    required String userId,
    TransactionSource? source,
    int? limit,
  }) async {
    try {
      final db = await database;

      String query = 'SELECT * FROM scan_history WHERE user_id = ?';
      List<dynamic> args = [userId];

      if (source != null) {
        query += ' AND source = ?';
        args.add(source.name);
      }

      query += ' ORDER BY scan_date DESC';

      if (limit != null) {
        query += ' LIMIT ?';
        args.add(limit);
      }

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);

      return maps.map((map) => ScanHistoryModel.fromMap(map)).toList();
    } catch (e) {
      print('❌ Error getting scan history: $e');
      return [];
    }
  }

  /// Get scan history by ID
  Future<ScanHistoryModel?> getScanHistoryById(String id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'scan_history',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;

      return ScanHistoryModel.fromMap(maps.first);
    } catch (e) {
      print('❌ Error getting scan history: $e');
      return null;
    }
  }

  /// Delete scan history record
  Future<bool> deleteScanHistory(String id) async {
    try {
      final db = await database;
      final count = await db.delete(
        'scan_history',
        where: 'id = ?',
        whereArgs: [id],
      );

      print('✅ Scan history deleted: $id');
      return count > 0;
    } catch (e) {
      print('❌ Error deleting scan history: $e');
      return false;
    }
  }

  /// Get total AI cost for a user
  Future<double> getTotalAICost({
    required String userId,
    TransactionSource? source,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await database;

      String query = 'SELECT SUM(ai_processed) as total FROM scan_history WHERE user_id = ?';
      List<dynamic> args = [userId];

      if (source != null) {
        query += ' AND source = ?';
        args.add(source.name);
      }

      if (startDate != null) {
        query += ' AND scan_date >= ?';
        args.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        query += ' AND scan_date <= ?';
        args.add(endDate.toIso8601String());
      }

      final result = await db.rawQuery(query, args);
      final totalAI = Sqflite.firstIntValue(result) ?? 0;

      return totalAI * 0.13; // ₹0.13 per AI call
    } catch (e) {
      print('❌ Error getting total AI cost: $e');
      return 0.0;
    }
  }

  /// Get scan statistics summary
  Future<Map<String, dynamic>> getScanStatistics({
    required String userId,
  }) async {
    try {
      final db = await database;

      final result = await db.rawQuery('''
        SELECT
          COUNT(*) as total_scans,
          SUM(total_messages) as total_messages,
          SUM(pattern_matched) as total_pattern_matched,
          SUM(ai_processed) as total_ai_processed,
          SUM(transactions_found) as total_transactions,
          SUM(new_patterns_learned) as total_patterns_learned
        FROM scan_history
        WHERE user_id = ?
      ''', [userId]);

      if (result.isEmpty) {
        return {
          'totalScans': 0,
          'totalMessages': 0,
          'totalPatternMatched': 0,
          'totalAIProcessed': 0,
          'totalTransactions': 0,
          'totalPatternsLearned': 0,
          'totalCost': 0.0,
          'totalSaved': 0.0,
        };
      }

      final row = result.first;
      final totalAI = (row['total_ai_processed'] as int?) ?? 0;
      final totalPatternMatched = (row['total_pattern_matched'] as int?) ?? 0;
      final totalCost = totalAI * 0.13;
      final potentialCost = (totalAI + totalPatternMatched) * 0.13;
      final totalSaved = potentialCost - totalCost;

      return {
        'totalScans': (row['total_scans'] as int?) ?? 0,
        'totalMessages': (row['total_messages'] as int?) ?? 0,
        'totalPatternMatched': totalPatternMatched,
        'totalAIProcessed': totalAI,
        'totalTransactions': (row['total_transactions'] as int?) ?? 0,
        'totalPatternsLearned': (row['total_patterns_learned'] as int?) ?? 0,
        'totalCost': totalCost,
        'totalSaved': totalSaved,
      };
    } catch (e) {
      print('❌ Error getting scan statistics: $e');
      return {};
    }
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
    print('🔒 Database closed');
  }

  /// Clear all data (use with caution!)
  Future<void> clearAllData() async {
    try {
      final db = await database;
      await db.delete('transactions');
      print('⚠️ All transactions deleted');
    } catch (e) {
      print('❌ Error clearing data: $e');
    }
  }
}

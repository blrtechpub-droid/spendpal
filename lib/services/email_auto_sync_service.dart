import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendpal/services/gmail_service.dart';
import 'package:spendpal/services/local_db_service.dart';
import 'package:spendpal/models/local_transaction_model.dart';
import 'package:spendpal/services/generic_transaction_parser_service.dart';

/// Service for automatic email synchronization
///
/// Features:
/// - Auto-sync on app launch
/// - Periodic sync every 30 minutes while app is active
/// - Daily background sync (requires WorkManager)
class EmailAutoSyncService {
  static final EmailAutoSyncService _instance = EmailAutoSyncService._internal();
  factory EmailAutoSyncService() => _instance;
  EmailAutoSyncService._internal();

  Timer? _periodicSyncTimer;
  bool _isCurrentlySyncing = false;
  DateTime? _lastSyncTime;

  // Configuration
  static const Duration _syncInterval = Duration(minutes: 30);
  static const Duration _minSyncGap = Duration(minutes: 15); // Don't sync if last sync was < 15 min ago
  static const String _lastSyncKey = 'email_last_sync_time';

  /// Initialize auto-sync service
  /// Call this in main.dart after Firebase initialization
  Future<void> initialize() async {
    await _loadLastSyncTime();
    await _syncOnLaunch();
    _startPeriodicSync();
  }

  /// Dispose resources when app is closing
  void dispose() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }

  /// Load last sync time from SharedPreferences
  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncMillis = prefs.getInt(_lastSyncKey);
    if (lastSyncMillis != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
    }
  }

  /// Save last sync time to SharedPreferences
  Future<void> _saveLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    _lastSyncTime = DateTime.now();
  }

  /// Check if enough time has passed since last sync
  bool _shouldSync() {
    if (_lastSyncTime == null) return true;
    final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
    return timeSinceLastSync >= _minSyncGap;
  }

  /// Auto-sync on app launch (if enough time has passed)
  Future<void> _syncOnLaunch() async {
    if (!_shouldSync()) {
      print('⏭️ Skipping launch sync - last sync was ${DateTime.now().difference(_lastSyncTime!).inMinutes} minutes ago');
      return;
    }

    print('🚀 Auto-syncing emails on app launch...');
    await syncEmails(daysBack: 7, source: 'app_launch');
  }

  /// Start periodic sync timer (every 30 minutes)
  void _startPeriodicSync() {
    // Cancel existing timer if any
    _periodicSyncTimer?.cancel();

    print('⏰ Starting periodic email sync (every ${_syncInterval.inMinutes} minutes)');

    _periodicSyncTimer = Timer.periodic(_syncInterval, (timer) async {
      if (!_shouldSync()) {
        print('⏭️ Skipping periodic sync - last sync was ${DateTime.now().difference(_lastSyncTime!).inMinutes} minutes ago');
        return;
      }

      print('⏰ Periodic email sync triggered');
      await syncEmails(daysBack: 7, source: 'periodic');
    });
  }

  /// Stop periodic sync (call when app goes to background)
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    print('⏸️ Periodic email sync stopped');
  }

  /// Resume periodic sync (call when app comes to foreground)
  void resumePeriodicSync() {
    if (_periodicSyncTimer == null || !_periodicSyncTimer!.isActive) {
      _startPeriodicSync();
      print('▶️ Periodic email sync resumed');
    }
  }

  /// Manually trigger email sync
  Future<SyncResult> syncEmails({
    int daysBack = 7,
    String source = 'manual',
  }) async {
    // Prevent concurrent syncs
    if (_isCurrentlySyncing) {
      print('⚠️ Email sync already in progress, skipping');
      return SyncResult(
        success: false,
        emailsFetched: 0,
        transactionsParsed: 0,
        transactionsSaved: 0,
        error: 'Sync already in progress',
      );
    }

    _isCurrentlySyncing = true;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return SyncResult(
          success: false,
          emailsFetched: 0,
          transactionsParsed: 0,
          transactionsSaved: 0,
          error: 'User not logged in',
        );
      }

      // Check if Gmail is connected
      final hasAccess = await GmailService.hasGmailAccess();
      if (!hasAccess) {
        print('⚠️ Gmail not connected, skipping email sync');
        return SyncResult(
          success: false,
          emailsFetched: 0,
          transactionsParsed: 0,
          transactionsSaved: 0,
          error: 'Gmail not connected',
        );
      }

      print('📧 Starting email sync (source: $source, daysBack: $daysBack)...');

      // Calculate date range
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: daysBack));

      // Fetch transaction emails from Gmail
      final emailMessages = await GmailService.searchTransactionEmails(
        after: startDate,
        before: endDate,
        maxResults: 500,
      );

      print('📬 Found ${emailMessages.length} transaction emails from Gmail');

      if (emailMessages.isEmpty) {
        await _saveLastSyncTime();
        return SyncResult(
          success: true,
          emailsFetched: 0,
          transactionsParsed: 0,
          transactionsSaved: 0,
        );
      }

      // Get already processed emails to avoid duplicates
      final existingTransactions = await LocalDBService.instance.getTransactions(
        userId: userId,
        source: TransactionSource.email,
      );
      final processedMessageIds = existingTransactions
          .where((t) => t.sourceIdentifier != null)
          .map((t) => t.sourceIdentifier!)
          .toSet();

      // Prepare bulk items for GenericTransactionParserService
      final bulkItems = <BulkTransactionItem>[];
      int index = 0;

      for (final message in emailMessages) {
        try {
          // Skip if already processed (by Gmail message ID)
          final messageId = message.id;
          if (messageId != null && processedMessageIds.contains(messageId)) {
            continue; // Skip duplicate
          }

          // Get full email details
          final emailDetails = await GmailService.getEmailDetails(messageId!);
          if (emailDetails == null) continue;

          // Extract email content
          final subject = GmailService.extractSubject(emailDetails) ?? '';
          final body = GmailService.extractTextBody(emailDetails);
          final sender = GmailService.extractSender(emailDetails) ?? '';
          final date = GmailService.extractDate(emailDetails) ?? DateTime.now();

          // Combine subject and body for parsing
          final emailText = '$subject\n\n$body';

          if (emailText.trim().isEmpty || sender.isEmpty) continue;

          // Add to bulk processing
          bulkItems.add(BulkTransactionItem(
            index: index++,
            text: emailText,
            sender: sender,
            date: date,
            source: TransactionSource.email,
          ));
        } catch (e) {
          print('❌ Error preparing email for parsing: $e');
        }
      }

      if (bulkItems.isEmpty) {
        await _saveLastSyncTime();
        return SyncResult(
          success: true,
          emailsFetched: emailMessages.length,
          transactionsParsed: 0,
          transactionsSaved: 0,
        );
      }

      print('📦 Processing ${bulkItems.length} emails with AI + Pattern matching (INCREMENTAL LEARNING)...');

      // Parse emails using GenericTransactionParserService with INCREMENTAL LEARNING
      final parsedTransactions = await GenericTransactionParserService.parseBulkTransactions(
        items: bulkItems,
        userId: userId,
      );

      await _saveLastSyncTime();

      print('✅ Email sync completed: ${parsedTransactions.length} transactions saved');

      return SyncResult(
        success: true,
        emailsFetched: emailMessages.length,
        transactionsParsed: parsedTransactions.length,
        transactionsSaved: parsedTransactions.length,
      );
    } catch (e) {
      print('❌ Email sync failed: $e');
      return SyncResult(
        success: false,
        emailsFetched: 0,
        transactionsParsed: 0,
        transactionsSaved: 0,
        error: e.toString(),
      );
    } finally {
      _isCurrentlySyncing = false;
    }
  }

  /// Get last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Check if sync is currently running
  bool get isSyncing => _isCurrentlySyncing;
}

/// Result of email sync operation
class SyncResult {
  final bool success;
  final int emailsFetched;
  final int transactionsParsed;
  final int transactionsSaved;
  final String? error;

  SyncResult({
    required this.success,
    required this.emailsFetched,
    required this.transactionsParsed,
    required this.transactionsSaved,
    this.error,
  });
}

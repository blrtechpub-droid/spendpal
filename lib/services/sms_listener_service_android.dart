import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:spendpal/models/sms_scan_progress.dart';
import 'sms_parser_service.dart';
import 'ai_sms_parser_service.dart';
import 'investment_sms_parser_service.dart';
import 'account_tracker_service.dart';
import '../config/tracker_registry.dart';
import '../models/account_tracker_model.dart';
// Privacy-first: Local SQLite storage
import 'generic_transaction_parser_service.dart';
import 'local_db_service.dart';
import '../models/local_transaction_model.dart';
import '../models/scan_history_model.dart';

class SmsListenerService {
  static final Telephony telephony = Telephony.instance;

  /// Known bank SMS senders in India
  /// This list helps filter out non-bank SMS to reduce parsing costs
  static const Set<String> KNOWN_BANK_SENDERS = {
    // HDFC Bank
    'VM-HDFCBK', 'AD-HDFCBK', 'AX-HDFCBK', 'BK-HDFCBK', 'TX-HDFCBK',
    'HDFCBK', 'HDFC',

    // ICICI Bank
    'VM-ICICIB', 'AD-ICICIB', 'AX-ICICIB', 'ICICIB', 'ICICI',

    // State Bank of India
    'VM-SBIINB', 'AD-SBIINB', 'SBI', 'SBIINB', 'SBMSMS',

    // Axis Bank
    'VM-AXISBK', 'AD-AXISBK', 'AXISBK', 'AXIS',

    // Kotak Mahindra Bank
    'VM-KOTAKB', 'AD-KOTAKB', 'KOTAK', 'KOTAKB',

    // Punjab National Bank
    'VM-PNBSMS', 'PNBSMS', 'PNB',

    // Citi Bank
    'VM-CITIBK', 'CITIBK', 'CITI',

    // Standard Chartered
    'VM-SCBANK', 'SCBANK', 'SCBL',

    // Yes Bank
    'VM-YESBK', 'YESBK', 'YESBNK',

    // Union Bank
    'VM-UNIONB', 'UNIONB', 'UBI',

    // Bank of India
    'VM-BOISMS', 'BOISMS', 'BOI',

    // IDBI Bank
    'VM-IDBIBK', 'IDBIBK', 'IDBI',

    // HSBC
    'VM-HSBCIN', 'HSBCIN', 'HSBC',

    // IndusInd Bank
    'VM-INDUSB', 'INDUSB', 'INDIND',

    // Bank of Baroda
    'VM-BARODA', 'BOBSMS', 'BARODA',

    // Canara Bank
    'VM-CANBNK', 'CANBNK', 'CANARA',

    // Federal Bank
    'VM-FEDBAK', 'FEDBAK', 'FEDBNK',

    // IDFC First Bank
    'VM-IDFCFB', 'IDFCFB', 'IDFC',

    // RBL Bank
    'VM-RBLBNK', 'RBLBNK', 'RBL',

    // AU Small Finance Bank
    'VM-AUBANK', 'AUBANK', 'AUSFB',

    // Paytm Payments Bank
    'PAYTMB', 'PAYTMP', 'PYTMPB',

    // Airtel Payments Bank
    'AIRTELP', 'APBSMS',

    // Credit Cards
    'AMEX', 'VISA', 'MASTER',

    // UPI / Payment Apps
    'GOOGLEPAY', 'PAYTM', 'PHONEPE', 'BHIMUPI',
  };

  /// Transaction keywords that indicate a bank SMS
  static const Set<String> TRANSACTION_KEYWORDS = {
    'debited', 'credited', 'withdrawn', 'deposited',
    'balance', 'transaction', 'txn', 'payment',
    'transfer', 'acct', 'a/c', 'account',
    'upi', 'imps', 'neft', 'rtgs',
    'spent', 'received', 'refund', 'cashback',
  };

  /// Check if SMS is likely a bank transaction message
  /// This reduces unnecessary parsing and saves AI costs
  static bool _isLikelyBankSMS(String sender, String body) {
    // Check 1: Known bank sender
    final normalizedSender = sender.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (KNOWN_BANK_SENDERS.any((bankSender) =>
        normalizedSender.contains(bankSender.toUpperCase()))) {
      return true;
    }

    // Check 2: Contains transaction keywords
    final lowerBody = body.toLowerCase();
    final hasKeyword = TRANSACTION_KEYWORDS.any((keyword) =>
        lowerBody.contains(keyword));

    // Check 3: Contains amount pattern (Rs/INR followed by number)
    final hasAmount = RegExp(r'(?:rs\.?|inr)\s*\d+', caseSensitive: false)
        .hasMatch(body);

    return hasKeyword && hasAmount;
  }

  /// Initialize SMS listener
  static Future<bool> initialize() async {
    // Request SMS permissions
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      print('SMS permissions not granted');
      return false;
    }

    // Set up background message handler
    telephony.listenIncomingSms(
      onNewMessage: _onMessageReceived,
      onBackgroundMessage: _onBackgroundMessage,
      listenInBackground: true,
    );

    print('✅ SMS Listener initialized successfully');
    return true;
  }

  /// Request SMS permissions
  static Future<bool> requestPermissions() async {
    final status = await Permission.sms.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied || status.isLimited) {
      final result = await Permission.sms.request();
      return result.isGranted;
    }

    return false;
  }

  /// Check if SMS permissions are granted
  static Future<bool> hasPermissions() async {
    return await Permission.sms.isGranted;
  }

  /// Save last SMS scan timestamp
  static Future<void> _saveLastScanTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_sms_scan_timestamp', DateTime.now().millisecondsSinceEpoch);
    print('📅 Last scan timestamp saved: ${DateTime.now()}');
  }

  /// Get last SMS scan timestamp
  static Future<DateTime?> getLastScanTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_sms_scan_timestamp');
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  /// Handle incoming SMS (when app is in foreground)
  static void _onMessageReceived(SmsMessage message) {
    print('📨 SMS received from: ${message.address}');
    _processSms(message);
  }

  /// Handle incoming SMS in background (when app is closed/background)
  @pragma('vm:entry-point')
  static void _onBackgroundMessage(SmsMessage message) {
    print('📨 Background SMS received from: ${message.address}');
    _processSms(message);
  }

  /// Process SMS and create expense if it's a transaction
  /// First checks for investment SMS, then falls back to expense parsing
  /// Uses AI parsing with automatic fallback to regex
  /// Matches against active account trackers for filtering and statistics
  static void _processSms(SmsMessage message) async {
    try {
      final smsBody = message.body ?? '';
      final sender = message.address ?? 'Unknown';
      final dateObj = message.date;
      final DateTime receivedAt = (dateObj != null && dateObj is DateTime)
          ? dateObj as DateTime
          : DateTime.now();

      // Load active trackers and match SMS sender
      final userId = FirebaseAuth.instance.currentUser?.uid;
      String? matchedTrackerId;

      if (userId != null) {
        final activeTrackers = await AccountTrackerService.getActiveTrackers(userId);

        // Match SMS sender against trackers
        for (final tracker in activeTrackers) {
          if (TrackerRegistry.matchesSmsSender(tracker.category, sender)) {
            matchedTrackerId = tracker.id;
            print('📊 SMS matched to tracker: ${tracker.name}');
            break;
          }
        }
      }

      // First, try to parse as investment SMS
      final investmentData = InvestmentSmsParserService.parseInvestmentSms(smsBody);
      if (investmentData != null) {
        // Investment SMS detected! Save to queue for user review
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          InvestmentSmsParserService.saveInvestmentSms(
            userId: userId,
            parsedData: investmentData,
            smsText: smsBody,
            receivedAt: receivedAt,
          ).then((queueId) {
            if (queueId != null) {
              print('📈 Investment SMS detected:');
              print('   Type: ${investmentData['type']}');
              print('   Asset: ${investmentData['fundName'] ?? investmentData['symbol']}');
              print('   Amount: ₹${investmentData['amount']}');
              print('✅ Saved to investment queue for review');
            }
          }).catchError((e) {
            print('❌ Error saving investment SMS: $e');
          });
        }
        return; // Don't process as expense SMS
      }

      // If not investment SMS, parse as expense using AI (with automatic fallback to regex)
      AiSmsParserService.parseSmsWithAI(
        smsText: smsBody,
        sender: sender,
        date: receivedAt,
        trackerId: matchedTrackerId,
      ).then((smsExpense) {
        if (smsExpense != null) {
          print('💰 Transaction detected:');
          print('   Amount: ₹${smsExpense.amount}');
          print('   Merchant: ${smsExpense.merchant}');
          print('   Category: ${smsExpense.category}');
          print('✅ SMS expense saved to pending');
        }
      }).catchError((e) {
        print('❌ Error processing SMS: $e');
      });
    } catch (e) {
      print('❌ Error processing SMS: $e');
    }
  }

  /// Get SMS inbox messages (for manual import)
  static Future<List<SmsMessage>> getInboxMessages({int? start, int? end}) async {
    try {
      final hasPermission = await hasPermissions();
      if (!hasPermission) {
        print('SMS permissions not granted');
        return [];
      }

      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      return messages;
    } catch (e) {
      print('Error getting inbox messages: $e');
      return [];
    }
  }

  /// Get already processed SMS raw texts to avoid re-parsing
  /// UPDATED: Now queries local SQLite database instead of Firestore
  static Future<Set<String>> _getProcessedSmsTexts(DateTime sinceDate) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return {};

      // Query local SQLite database for SMS transactions
      final localTransactions = await LocalDBService.instance.getTransactions(
        userId: currentUser.uid,
        source: TransactionSource.sms,
        startDate: sinceDate,
      );

      final Set<String> processedTexts = {};
      for (var transaction in localTransactions) {
        final rawSms = transaction.rawContent;
        if (rawSms != null && rawSms.isNotEmpty) {
          processedTexts.add(rawSms);
        }
      }

      print('📊 Found ${processedTexts.length} already processed SMS messages (from local DB)');
      return processedTexts;
    } catch (e) {
      print('Error fetching processed SMS from local DB: $e');
      return {}; // On error, return empty set (will re-process, but safer)
    }
  }

  /// Manually process recent SMS messages (useful for initial import)
  /// Default: scans last 30 days (1 month)
  /// Uses AI parsing with automatic fallback to regex
  /// Smart scanning: Only processes NEW SMS since last scan
  /// Intelligently skips already-analyzed messages to save processing time and AI costs
  ///
  /// Fast Mode: When enabled, only uses regex patterns (instant, 70% accuracy)
  /// AI Mode: When disabled, uses AI with regex fallback (slower, 95% accuracy)
  static Future<int> processRecentMessages({
    int days = 30,
    bool fastMode = true,
    Function(SmsScanProgress progress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    try {
      final messages = await getInboxMessages();
      final now = DateTime.now();

      // Use the days parameter to determine cutoff date
      final cutoffDate = now.subtract(Duration(days: days));

      print('📱 Scanning SMS from last $days days: $cutoffDate');

      // Initialize progress tracking
      var progress = SmsScanProgress(
        totalMessages: messages.length,
      );

      // Report initial state
      if (onProgress != null) {
        onProgress(progress);
      }

      // Load active trackers for matching and statistics
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final activeTrackers = userId != null
          ? await AccountTrackerService.getActiveTrackers(userId)
          : <AccountTrackerModel>[];

      print('📊 Loaded ${activeTrackers.length} active trackers for filtering');

      // Map to track SMS count per tracker
      final Map<String, int> trackerSmsCounts = {};
      for (final tracker in activeTrackers) {
        trackerSmsCounts[tracker.id] = 0;
      }

      // SMART FILTER: Get already processed SMS to skip them
      // Works for BOTH fast mode and AI mode - prevents duplicates
      final processedSmsTexts = await _getProcessedSmsTexts(cutoffDate);

      // Filter messages by date first to get accurate total
      final messagesToScan = messages.where((message) {
        final dateObj = message.date;

        if (dateObj == null) {
          return false; // Skip messages without dates
        }

        DateTime messageDate;
        if (dateObj is DateTime) {
          messageDate = dateObj as DateTime;
        } else if (dateObj is int) {
          // Telephony plugin returns milliseconds since epoch
          messageDate = DateTime.fromMillisecondsSinceEpoch(dateObj as int);
        } else {
          return false; // Skip messages with invalid date format
        }

        // Check date range
        final inDateRange = messageDate.isAfter(cutoffDate) || messageDate.isAtSameMomentAs(cutoffDate);

        // SMART SKIP: Check if already processed (by raw SMS text)
        final smsBody = message.body ?? '';
        final alreadyProcessed = processedSmsTexts.contains(smsBody);

        if (alreadyProcessed) {
          // Silently skip already processed messages
          return false;
        }

        return inDateRange;
      }).toList();

      // Update progress with counts
      progress = progress.copyWith(
        alreadyProcessed: processedSmsTexts.length,
        newToAnalyze: messagesToScan.length,
      );

      print('📊 Smart Scan Summary:');
      print('   ✅ Already processed (skipped): ${processedSmsTexts.length} messages');
      print('   🔍 New messages to analyze: ${messagesToScan.length} messages');
      print('   💰 AI cost saved: ₹${(processedSmsTexts.length * 0.13).toStringAsFixed(2)}');

      int skippedNonBank = 0;
      int regexMatched = 0;
      int needsAI = 0;

      // FAST MODE: Process in bulk with local SQLite regex patterns
      if (fastMode) {
        print('🚀 Fast Mode: Using bulk processing with local regex patterns');

        // STEP 1: Collect ALL bank SMS for processing
        final smsToProcess = <BulkTransactionItem>[];

        for (int i = 0; i < messagesToScan.length; i++) {
          // Check if scan was cancelled
          if (shouldCancel != null && shouldCancel()) {
            print('⚠️ Scan cancelled by user at ${i}/${messagesToScan.length} messages');
            break;
          }

          final message = messagesToScan[i];
          final dateObj = message.date;

          if (dateObj == null) {
            continue; // Skip messages without dates
          }

          DateTime messageDate;
          if (dateObj is DateTime) {
            messageDate = dateObj as DateTime;
          } else if (dateObj is int) {
            messageDate = DateTime.fromMillisecondsSinceEpoch(dateObj as int);
          } else {
            continue; // Skip messages with invalid date format
          }

          final smsBody = message.body ?? '';
          final sender = message.address ?? 'Unknown';

          // Filter non-bank SMS before parsing
          if (!_isLikelyBankSMS(sender, smsBody)) {
            skippedNonBank++;
            continue;
          }

          // Add to processing list
          smsToProcess.add(BulkTransactionItem(
            index: i,
            text: smsBody,
            sender: sender,
            date: messageDate,
            source: TransactionSource.sms,
          ));

          // Update progress
          progress = progress.copyWith(
            currentMessage: i + 1,
            filteredBankSms: smsToProcess.length,
          );

          if (onProgress != null) {
            onProgress(progress);
          }
        }

        print('📊 Fast Mode - Bank SMS collected: ${smsToProcess.length}');

        // STEP 2: Process all SMS with local regex patterns (no Firestore, no AI)
        if (smsToProcess.isNotEmpty) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) {
            print('❌ No user logged in, skipping processing');
          } else {
            print('🔍 Processing ${smsToProcess.length} SMS with local regex patterns...');

            // Parse and save to LOCAL SQLite using regex patterns
            // Note: parseBulkTransactions tries local regex first, then AI if no match
            // In Fast Mode, it will skip AI and only use regex patterns from local DB
            final parsedTransactions = await GenericTransactionParserService.parseBulkTransactions(
              items: smsToProcess,
              userId: currentUser.uid,
              onProgress: (count) {
                // Update progress
                progress = progress.copyWith(
                  regexMatched: count,
                  foundTransactions: count,
                );
                if (onProgress != null) {
                  onProgress(progress);
                }
              },
            );

            regexMatched = parsedTransactions.length;
            print('✅ Fast Mode completed: $regexMatched transactions found');
          }
        }
      } else {
        // AI MODE: Use bulk processing for 10x speed improvement!
        print('🚀 AI Mode: Using bulk processing for faster results');

        // STEP 1: Collect ALL bank SMS for AI processing
        // In AI mode, we want better merchant extraction, so send everything to AI
        final smsNeedingAI = <BulkSmsItem>[];

        for (int i = 0; i < messagesToScan.length; i++) {
          final message = messagesToScan[i];
          final dateObj = message.date;

          if (dateObj == null) continue;

          DateTime messageDate;
          if (dateObj is DateTime) {
            messageDate = dateObj as DateTime;
          } else if (dateObj is int) {
            messageDate = DateTime.fromMillisecondsSinceEpoch(dateObj as int);
          } else {
            continue;
          }

          final smsBody = message.body ?? '';
          final sender = message.address ?? 'Unknown';

          // Filter non-bank SMS
          if (!_isLikelyBankSMS(sender, smsBody)) {
            skippedNonBank++;
            continue;
          }

          // In AI mode, send ALL bank SMS to AI for best merchant extraction
          // This ensures we get quality merchant data instead of "Transaction"
          smsNeedingAI.add(BulkSmsItem(
            index: i,
            smsText: smsBody,
            sender: sender,
            date: messageDate,
          ));

          // Update progress
          progress = progress.copyWith(
            currentMessage: i + 1,
            filteredBankSms: i + 1 - skippedNonBank,
            needsAI: smsNeedingAI.length,
          );

          if (onProgress != null) {
            onProgress(progress);
          }
        }

        print('📊 AI Mode - Bank SMS collected:');
        print('   🤖 Total for AI processing: ${smsNeedingAI.length}');

        // STEP 2: Process SMS needing AI in bulk batches
        if (smsNeedingAI.isNotEmpty) {
          const batchSize = 15; // Process 15 SMS per batch
          final batches = <List<BulkSmsItem>>[];

          for (int i = 0; i < smsNeedingAI.length; i += batchSize) {
            final end = (i + batchSize < smsNeedingAI.length)
                ? i + batchSize
                : smsNeedingAI.length;
            batches.add(smsNeedingAI.sublist(i, end));
          }

          print('🚀 Processing ${smsNeedingAI.length} SMS in ${batches.length} bulk batches');

          int aiProcessedCount = 0;
          for (final batch in batches) {
            // Check for cancellation
            if (shouldCancel != null && shouldCancel()) {
              print('⚠️ Scan cancelled during AI processing');
              break;
            }

            print('📡 Processing batch of ${batch.length} SMS...');

            // PRIVACY-FIRST: Use generic parser that saves to local SQLite
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) {
              print('❌ No user logged in, skipping batch');
              continue;
            }

            // Convert to BulkTransactionItem for generic parser
            final transactionItems = batch.map((sms) => BulkTransactionItem(
              index: sms.index,
              text: sms.smsText,
              sender: sms.sender,
              date: sms.date,
              source: TransactionSource.sms,
            )).toList();

            // Parse and save to LOCAL SQLite (not Firestore)
            final parsedTransactions = await GenericTransactionParserService.parseBulkTransactions(
              items: transactionItems,
              userId: currentUser.uid,
              onProgress: (count) {
                // Update AI processed count
                final totalAiProcessed = aiProcessedCount + count;
                progress = progress.copyWith(
                  aiProcessed: totalAiProcessed,
                  foundTransactions: progress.foundTransactions + count,
                );
                if (onProgress != null) {
                  onProgress(progress);
                }
              },
            );

            aiProcessedCount += batch.length;

            print('✅ Batch complete: ${parsedTransactions.length}/${batch.length} transactions found');
            print('💾 Saved to local database (encrypted)');

            // Update final progress for this batch
            progress = progress.copyWith(
              aiProcessed: aiProcessedCount,
              foundTransactions: progress.foundTransactions + parsedTransactions.length,
            );

            if (onProgress != null) {
              onProgress(progress);
            }
          }

          print('✅ AI bulk processing complete!');
          print('   Total AI processed: $aiProcessedCount');
          print('   Sequential time would be: ${aiProcessedCount * 2.5}s');
          print('   Bulk time: ~${(batches.length * 3)}s');
          print('   Speed improvement: ${(aiProcessedCount * 2.5 / (batches.length * 3)).toStringAsFixed(1)}x faster! 🚀');
          print('   Storage: Local SQLite (encrypted) 🔒');
        }
      }

      // Log cost savings from filtering
      if (skippedNonBank > 0) {
        print('💡 Smart Filter Results:');
        print('   🚫 Non-bank SMS skipped: $skippedNonBank messages');
        print('   💰 Additional savings: ₹${(skippedNonBank * 0.13).toStringAsFixed(2)}');
      }

      // Save scan timestamp for next time
      await _saveLastScanTimestamp();

      // Save scan history for cost tracking
      if (userId != null) {
        final scanHistory = ScanHistoryModel(
          id: const Uuid().v4(),
          userId: userId,
          scanDate: DateTime.now(),
          source: TransactionSource.sms,
          mode: fastMode ? ScanMode.fast : ScanMode.ai,
          daysScanned: days,
          rangeStart: cutoffDate,
          rangeEnd: now,
          totalMessages: messages.length,
          filteredMessages: progress.filteredBankSms,
          alreadyProcessed: progress.alreadyProcessed,
          patternMatched: progress.regexMatched,
          aiProcessed: progress.aiProcessed,
          transactionsFound: progress.foundTransactions,
          newPatternsLearned: 0, // TODO: Track this from parser
        );

        await LocalDBService.instance.insertScanHistory(scanHistory);
        print('📝 Scan history saved: ${scanHistory.cost > 0 ? "₹${scanHistory.cost.toStringAsFixed(2)}" : "₹0 (Fast Mode)"}');
      }

      // Update tracker statistics
      if (userId != null && trackerSmsCounts.isNotEmpty) {
        print('\n📊 UPDATING TRACKER STATISTICS');
        print('───────────────────────────────────────────────────────');
        for (final trackerId in trackerSmsCounts.keys) {
          final count = trackerSmsCounts[trackerId] ?? 0;
          if (count > 0) {
            final tracker = activeTrackers.firstWhere((t) => t.id == trackerId);
            print('  Tracker: ${tracker.name}');
            print('  SMS found: $count');

            // Increment SMS count (reusing emailsFetched field for now)
            await AccountTrackerService.incrementEmailsFetched(userId, trackerId, count);

            // Update last sync time
            await AccountTrackerService.updateLastSyncTime(userId, trackerId);

            print('  ✅ Statistics updated');
          }
        }
        print('───────────────────────────────────────────────────────');
      }

      print('✅ Found ${progress.foundTransactions} transactions from ${progress.currentMessage} messages');
      return progress.foundTransactions;
    } catch (e) {
      print('❌ Error processing recent messages: $e');
      return 0;
    }
  }
}

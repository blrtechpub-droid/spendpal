import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sms_parser_service.dart';
import 'ai_sms_parser_service.dart';
import 'investment_sms_parser_service.dart';

class SmsListenerService {
  static final Telephony telephony = Telephony.instance;

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
  static void _processSms(SmsMessage message) {
    try {
      final smsBody = message.body ?? '';
      final sender = message.address ?? 'Unknown';
      final dateObj = message.date;
      final DateTime receivedAt = (dateObj != null && dateObj is DateTime)
          ? dateObj as DateTime
          : DateTime.now();

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

  /// Manually process recent SMS messages (useful for initial import)
  /// Default: scans last 30 days (1 month)
  /// Uses AI parsing with automatic fallback to regex
  /// Smart scanning: Only processes NEW SMS since last scan
  static Future<int> processRecentMessages({int days = 30}) async {
    try {
      final messages = await getInboxMessages();
      final now = DateTime.now();

      // Get last scan timestamp - if available, only scan newer SMS
      final lastScan = await getLastScanTimestamp();
      final cutoffDate = lastScan ?? now.subtract(Duration(days: days));

      print('📱 Scanning SMS since ${lastScan != null ? "last scan" : "$days days ago"}: $cutoffDate');

      int processed = 0;
      int skipped = 0;

      for (var message in messages) {
        final dateObj = message.date;
        final DateTime messageDate = (dateObj != null && dateObj is DateTime)
            ? dateObj as DateTime
            : DateTime.now();

        // Only process messages since cutoff date
        if (messageDate.isBefore(cutoffDate)) {
          skipped++;
          continue; // Skip old messages
        }

        final smsBody = message.body ?? '';
        final sender = message.address ?? 'Unknown';

        // Parse SMS using AI (with automatic fallback to regex)
        // Quick duplicate check happens inside parseSmsWithAI to save AI costs
        final smsExpense = await AiSmsParserService.parseSmsWithAI(
          smsText: smsBody,
          sender: sender,
          date: messageDate,
        );

        if (smsExpense != null) {
          processed++;
        }
      }

      // Save scan timestamp for next time
      await _saveLastScanTimestamp();

      print('✅ Processed $processed new transactions (skipped $skipped old SMS)');
      return processed;
    } catch (e) {
      print('❌ Error processing recent messages: $e');
      return 0;
    }
  }
}

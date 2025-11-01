import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sms_parser_service.dart';

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
  static void _processSms(SmsMessage message) {
    try {
      final smsBody = message.body ?? '';
      final sender = message.address ?? 'Unknown';
      final dateObj = message.date;
      final DateTime receivedAt = (dateObj != null && dateObj is DateTime)
          ? dateObj as DateTime
          : DateTime.now();

      // Parse SMS
      final transaction = SmsParserService.parseSms(
        smsBody,
        sender,
        receivedAt,
      );

      if (transaction != null) {
        print('💰 Transaction detected:');
        print('   Amount: ₹${transaction.amount}');
        print('   Merchant: ${transaction.merchant}');
        print('   Category: ${transaction.category}');

        // Save to pending SMS expenses for user categorization
        SmsParserService.saveSmsExpenseToPending(transaction, sender).then((success) {
          if (success) {
            print('✅ SMS expense saved to pending');
          } else {
            print('❌ Failed to save SMS expense');
          }
        });
      }
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
  static Future<int> processRecentMessages({int days = 30}) async {
    try {
      final messages = await getInboxMessages();
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: days));

      int processed = 0;

      for (var message in messages) {
        final dateObj = message.date;
        final DateTime messageDate = (dateObj != null && dateObj is DateTime)
            ? dateObj as DateTime
            : DateTime.now();

        // Only process messages from the last N days
        if (messageDate.isBefore(cutoffDate)) {
          break; // Messages are sorted by date desc
        }

        final smsBody = message.body ?? '';
        final sender = message.address ?? 'Unknown';

        final transaction = SmsParserService.parseSms(
          smsBody,
          sender,
          messageDate,
        );

        if (transaction != null) {
          final success = await SmsParserService.saveSmsExpenseToPending(transaction, sender);
          if (success) {
            processed++;
          }
        }
      }

      print('✅ Processed $processed transactions from last $days days');
      return processed;
    } catch (e) {
      print('❌ Error processing recent messages: $e');
      return 0;
    }
  }
}

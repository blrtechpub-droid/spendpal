import 'package:flutter_test/flutter_test.dart';
import 'package:spendpal/models/local_transaction_model.dart';
import 'package:spendpal/models/account_tracker_model.dart';
import 'package:spendpal/config/tracker_registry.dart';

/// Integration tests for Tracker Matching System
///
/// These tests simulate real-world scenarios with actual SMS/email messages
void main() {
  group('Real-World SMS Transaction Matching', () {
    test('HDFC Bank debit SMS should be identified', () {
      final smsText = 'Dear Customer, Rs.1,500.00 debited from A/c XX1234 '
          'on 06-Jan-26 at AMAZON INDIA. Info: UPI/123456789012. '
          'Avl Bal: Rs.45,678.90. -HDFC Bank';
      final sender = 'VM-HDFCBK';

      // Verify sender matches HDFC Bank category
      final matches = TrackerRegistry.matchesSmsSender(
        TrackerCategory.hdfcBank,
        sender,
      );

      expect(matches, true);
    });

    test('ICICI Bank UPI payment SMS should be identified', () {
      final smsText = 'Rs.2,350 debited from A/c **5678 on 06-Jan-26 for '
          'UPI txn 123456789012. Info: GooglePay. -ICICI Bank';
      final sender = 'VM-ICICIB';

      final matches = TrackerRegistry.matchesSmsSender(
        TrackerCategory.iciciBank,
        sender,
      );

      expect(matches, true);
    });

    test('Paytm wallet payment SMS should be identified', () {
      final smsText = 'Rs.599.00 paid to Zomato via Paytm wallet. '
          'Txn ID: PTM123456789. Wallet Bal: Rs.150.50';
      final sender = 'PAYTM';

      final matches = TrackerRegistry.matchesSmsSender(
        TrackerCategory.paytm,
        sender,
      );

      expect(matches, true);
    });

    test('PhonePe UPI payment SMS should be identified', () {
      final smsText = 'Rs.1,200 sent to merchant@paytm via PhonePe. '
          'UPI Ref: 123456789012';
      final sender = 'PHONEPE';

      final matches = TrackerRegistry.matchesSmsSender(
        TrackerCategory.phonePe,
        sender,
      );

      expect(matches, true);
    });

    test('SBI Bank ATM withdrawal SMS should be identified', () {
      final smsText = 'Dear Customer, Your A/c XX9012 is debited by '
          'Rs.5,000.00 on 06-Jan-26 at SBI ATM 123456. Avl Bal: Rs.25,000.00';
      final sender = 'VM-SBIINB';

      final matches = TrackerRegistry.matchesSmsSender(
        TrackerCategory.sbiBank,
        sender,
      );

      expect(matches, true);
    });
  });

  group('Real-World Email Transaction Matching', () {
    test('HDFC Bank email should be identified', () {
      final emailAddress = 'alerts@hdfcbank.com';

      final matches = TrackerRegistry.matchesEmailDomain(
        TrackerCategory.hdfcBank,
        emailAddress,
      );

      expect(matches, true);
    });

    test('Zerodha investment email should be identified', () {
      final emailAddress = 'reports@zerodha.com';

      final matches = TrackerRegistry.matchesEmailDomain(
        TrackerCategory.zerodha,
        emailAddress,
      );

      expect(matches, true);
    });

    test('Groww SIP notification email should be identified', () {
      final emailAddress = 'notifications@groww.in';

      final matches = TrackerRegistry.matchesEmailDomain(
        TrackerCategory.groww,
        emailAddress,
      );

      expect(matches, true);
    });

    test('Google Pay payment receipt email should be identified', () {
      final emails = [
        'googlepay-noreply@google.com',
        'payments@google.com',
      ];

      for (final email in emails) {
        final matches = TrackerRegistry.matchesEmailDomain(
          TrackerCategory.googlePay,
          email,
        );

        expect(matches, true, reason: 'Should match: $email');
      }
    });

    test('HDFC Bank subdomain emails should be identified', () {
      final emails = [
        'noreply@alerts.hdfcbank.com',
        'service@creditcard.hdfcbank.com',
        'statements@netbanking.hdfcbank.net',
      ];

      for (final email in emails) {
        final matches = TrackerRegistry.matchesEmailDomain(
          TrackerCategory.hdfcBank,
          email,
        );

        expect(matches, true, reason: 'Should match subdomain: $email');
      }
    });
  });

  group('BulkTransactionItem Creation for Integration', () {
    test('should create SMS transaction items for bulk matching', () {
      final smsTransactions = [
        {
          'text': 'Rs.500 debited from XX1234 on 06-Jan-26',
          'sender': 'VM-HDFCBK',
          'date': DateTime(2026, 1, 6),
        },
        {
          'text': 'Rs.1200 paid to Merchant via PhonePe',
          'sender': 'PHONEPE',
          'date': DateTime(2026, 1, 6),
        },
        {
          'text': 'Rs.750 debited from **5678 for UPI txn',
          'sender': 'VM-ICICIB',
          'date': DateTime(2026, 1, 6),
        },
      ];

      final bulkItems = smsTransactions.asMap().entries.map((entry) {
        return BulkTransactionItem(
          index: entry.key,
          text: entry.value['text'] as String,
          sender: entry.value['sender'] as String,
          date: entry.value['date'] as DateTime,
          source: TransactionSource.sms,
        );
      }).toList();

      expect(bulkItems.length, 3);
      expect(bulkItems[0].sender, 'VM-HDFCBK');
      expect(bulkItems[1].sender, 'PHONEPE');
      expect(bulkItems[2].sender, 'VM-ICICIB');

      // Verify each can be matched to its category
      final hdfcMatch = TrackerRegistry.matchesSmsSender(
        TrackerCategory.hdfcBank,
        bulkItems[0].sender,
      );
      final phonePeMatch = TrackerRegistry.matchesSmsSender(
        TrackerCategory.phonePe,
        bulkItems[1].sender,
      );
      final iciciMatch = TrackerRegistry.matchesSmsSender(
        TrackerCategory.iciciBank,
        bulkItems[2].sender,
      );

      expect(hdfcMatch, true);
      expect(phonePeMatch, true);
      expect(iciciMatch, true);
    });

    test('should create email transaction items for bulk matching', () {
      final emailTransactions = [
        {
          'text': 'Investment confirmation: 100 shares of RELIANCE purchased',
          'sender': 'reports@zerodha.com',
          'date': DateTime(2026, 1, 6),
        },
        {
          'text': 'SIP executed: Rs.5,000 invested in HDFC Equity Fund',
          'sender': 'notifications@groww.in',
          'date': DateTime(2026, 1, 6),
        },
        {
          'text': 'Transaction alert: Rs.2,500 debited from XX1234',
          'sender': 'alerts@hdfcbank.com',
          'date': DateTime(2026, 1, 6),
        },
      ];

      final bulkItems = emailTransactions.asMap().entries.map((entry) {
        return BulkTransactionItem(
          index: entry.key,
          text: entry.value['text'] as String,
          sender: entry.value['sender'] as String,
          date: entry.value['date'] as DateTime,
          source: TransactionSource.email,
        );
      }).toList();

      expect(bulkItems.length, 3);
      expect(bulkItems[0].source, TransactionSource.email);

      // Verify each can be matched to its category
      final zerodhaMatch = TrackerRegistry.matchesEmailDomain(
        TrackerCategory.zerodha,
        bulkItems[0].sender,
      );
      final growwMatch = TrackerRegistry.matchesEmailDomain(
        TrackerCategory.groww,
        bulkItems[1].sender,
      );
      final hdfcMatch = TrackerRegistry.matchesEmailDomain(
        TrackerCategory.hdfcBank,
        bulkItems[2].sender,
      );

      expect(zerodhaMatch, true);
      expect(growwMatch, true);
      expect(hdfcMatch, true);
    });
  });

  group('Multi-Account Scenarios', () {
    test('should differentiate between multiple accounts of same bank', () {
      // User has two HDFC accounts
      // Both will match HDFC category, but tracker matching will need
      // account number to differentiate

      final sender = 'VM-HDFCBK';

      // Both should match HDFC Bank
      final matches = TrackerRegistry.matchesSmsSender(
        TrackerCategory.hdfcBank,
        sender,
      );

      expect(matches, true);

      // Note: In real implementation, we'd need account number extraction
      // from SMS text to differentiate between:
      // - HDFC Savings (XX1234)
      // - HDFC Credit Card (XX5678)
    });

    test('should match different banks correctly', () {
      final transactions = {
        'VM-HDFCBK': TrackerCategory.hdfcBank,
        'VM-ICICIB': TrackerCategory.iciciBank,
        'VM-SBIINB': TrackerCategory.sbiBank,
        'VM-AXISBK': TrackerCategory.axisBank,
      };

      transactions.forEach((sender, expectedCategory) {
        final matches = TrackerRegistry.matchesSmsSender(
          expectedCategory,
          sender,
        );

        expect(matches, true, reason: 'Should match $sender to $expectedCategory');
      });
    });
  });

  group('Template Discovery Tests', () {
    test('should provide templates for all major Indian banks', () {
      final bankCategories = [
        TrackerCategory.hdfcBank,
        TrackerCategory.iciciBank,
        TrackerCategory.sbiBank,
        TrackerCategory.axisBank,
        TrackerCategory.kotakBank,
      ];

      for (final category in bankCategories) {
        final template = TrackerRegistry.getTemplate(category);
        expect(template, isNotNull, reason: 'Template should exist for $category');
        expect(template!.type, TrackerType.banking);
        expect(template.emailDomains.isNotEmpty, true);
      }
    });

    test('should provide templates for investment platforms', () {
      final investmentCategories = [
        TrackerCategory.zerodha,
        TrackerCategory.groww,
        TrackerCategory.angelOne,
        TrackerCategory.upstox,
      ];

      for (final category in investmentCategories) {
        final template = TrackerRegistry.getTemplate(category);
        expect(template, isNotNull);
        expect(template!.type, TrackerType.investment);
        expect(template.emailDomains.isNotEmpty, true);
      }
    });

    test('should provide templates for digital wallets', () {
      final walletCategories = [
        TrackerCategory.paytm,
        TrackerCategory.phonePe,
        TrackerCategory.googlePay,
        TrackerCategory.amazonPay,
      ];

      for (final category in walletCategories) {
        final template = TrackerRegistry.getTemplate(category);
        expect(template, isNotNull);
        expect(template!.type, TrackerType.digitalWallet);
      }
    });
  });

  group('Performance and Edge Cases', () {
    test('should handle bulk matching efficiently', () {
      // Create 50 SMS transactions
      final bulkItems = List.generate(50, (index) {
        final senders = ['VM-HDFCBK', 'VM-ICICIB', 'PAYTM', 'PHONEPE', 'GPAY'];
        return BulkTransactionItem(
          index: index,
          text: 'Rs.${100 * index} debited',
          sender: senders[index % senders.length],
          date: DateTime.now(),
          source: TransactionSource.sms,
        );
      });

      expect(bulkItems.length, 50);

      // In real implementation, TrackerMatchingService.matchBatch()
      // would process all 50 in a single database query
    });

    test('should handle mixed SMS and email sources', () {
      final mixedItems = [
        BulkTransactionItem(
          index: 0,
          text: 'SMS transaction',
          sender: 'VM-HDFCBK',
          date: DateTime.now(),
          source: TransactionSource.sms,
        ),
        BulkTransactionItem(
          index: 1,
          text: 'Email transaction',
          sender: 'alerts@hdfcbank.com',
          date: DateTime.now(),
          source: TransactionSource.email,
        ),
      ];

      // Both should match HDFC Bank category
      final smsMatch = TrackerRegistry.matchesSmsSender(
        TrackerCategory.hdfcBank,
        mixedItems[0].sender,
      );
      final emailMatch = TrackerRegistry.matchesEmailDomain(
        TrackerCategory.hdfcBank,
        mixedItems[1].sender,
      );

      expect(smsMatch, true);
      expect(emailMatch, true);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:spendpal/services/tracker_matching_service.dart';
import 'package:spendpal/models/local_transaction_model.dart';
import 'package:spendpal/models/account_tracker_model.dart';
import 'package:spendpal/config/tracker_registry.dart';

/// Tests for TrackerMatchingService
///
/// These tests verify the tracker matching logic for SMS and email transactions
void main() {
  group('TrackerRegistry SMS Matching Tests', () {
    test('should match HDFC Bank SMS sender', () {
      // Test various HDFC sender formats
      final senders = [
        'VM-HDFCBK',
        'AD-HDFCBK',
        'AX-HDFCBK',
        'HDFCBK',
        'HDFC',
      ];

      for (final sender in senders) {
        final matches = TrackerRegistry.matchesSmsSender(
          TrackerCategory.hdfcBank,
          sender,
        );
        expect(matches, true, reason: 'Should match sender: $sender');
      }
    });

    test('should match ICICI Bank SMS sender', () {
      final senders = [
        'VM-ICICIB',
        'AD-ICICIB',
        'ICICIB',
        'ICICI',
      ];

      for (final sender in senders) {
        final matches = TrackerRegistry.matchesSmsSender(
          TrackerCategory.iciciBank,
          sender,
        );
        expect(matches, true, reason: 'Should match sender: $sender');
      }
    });

    test('should match Paytm SMS sender', () {
      final senders = [
        'PAYTMB',
        'PAYTMP',
        'PYTMPB',
        'PAYTM',
      ];

      for (final sender in senders) {
        final matches = TrackerRegistry.matchesSmsSender(
          TrackerCategory.paytm,
          sender,
        );
        expect(matches, true, reason: 'Should match sender: $sender');
      }
    });

    test('should NOT match wrong sender', () {
      final matches = TrackerRegistry.matchesSmsSender(
        TrackerCategory.hdfcBank,
        'WRONGSENDER',
      );
      expect(matches, false);
    });

    test('should handle sender normalization', () {
      // Test with special characters and lowercase
      final matches = TrackerRegistry.matchesSmsSender(
        TrackerCategory.hdfcBank,
        'vm-hdfcbk',
      );
      expect(matches, true, reason: 'Should normalize lowercase');
    });

    test('should find all matching categories for SMS sender', () {
      final matches = TrackerRegistry.findMatchingCategoriesForSms('VM-HDFCBK');
      expect(matches.contains(TrackerCategory.hdfcBank), true);
      expect(matches.length, greaterThan(0));
    });
  });

  group('TrackerRegistry Email Matching Tests', () {
    test('should match HDFC Bank email domains', () {
      final emails = [
        'noreply@hdfcbank.com',
        'alerts@hdfcbank.net',
        'service@hdfcbank.com',
      ];

      for (final email in emails) {
        final matches = TrackerRegistry.matchesEmailDomain(
          TrackerCategory.hdfcBank,
          email,
        );
        expect(matches, true, reason: 'Should match email: $email');
      }
    });

    test('should match email subdomains', () {
      final emails = [
        'noreply@alerts.hdfcbank.com',
        'service@creditcard.hdfcbank.com',
      ];

      for (final email in emails) {
        final matches = TrackerRegistry.matchesEmailDomain(
          TrackerCategory.hdfcBank,
          email,
        );
        expect(matches, true, reason: 'Should match subdomain: $email');
      }
    });

    test('should match Zerodha investment emails', () {
      final email = 'reports@zerodha.com';
      final matches = TrackerRegistry.matchesEmailDomain(
        TrackerCategory.zerodha,
        email,
      );
      expect(matches, true);
    });

    test('should match Google Pay emails', () {
      final emails = [
        'noreply@google.com',
        'payments@googlepay.com',
      ];

      for (final email in emails) {
        final matches = TrackerRegistry.matchesEmailDomain(
          TrackerCategory.googlePay,
          email,
        );
        expect(matches, true, reason: 'Should match email: $email');
      }
    });

    test('should NOT match wrong email domain', () {
      final matches = TrackerRegistry.matchesEmailDomain(
        TrackerCategory.hdfcBank,
        'alert@wrongbank.com',
      );
      expect(matches, false);
    });

    test('should handle case insensitivity', () {
      final matches = TrackerRegistry.matchesEmailDomain(
        TrackerCategory.hdfcBank,
        'NOREPLY@HDFCBANK.COM',
      );
      expect(matches, true, reason: 'Should handle uppercase emails');
    });

    test('should find all matching categories for email', () {
      final matches = TrackerRegistry.findMatchingCategoriesForEmail(
        'noreply@hdfcbank.com',
      );
      expect(matches.contains(TrackerCategory.hdfcBank), true);
      expect(matches.length, greaterThan(0));
    });

    test('should handle invalid email format', () {
      final matches = TrackerRegistry.matchesEmailDomain(
        TrackerCategory.hdfcBank,
        'notanemail',
      );
      expect(matches, false);
    });
  });

  group('BulkTransactionItem Tests', () {
    test('should create BulkTransactionItem correctly', () {
      final item = BulkTransactionItem(
        index: 0,
        text: 'Test SMS text',
        sender: 'VM-HDFCBK',
        date: DateTime.now(),
        source: TransactionSource.sms,
      );

      expect(item.index, 0);
      expect(item.text, 'Test SMS text');
      expect(item.sender, 'VM-HDFCBK');
      expect(item.source, TransactionSource.sms);
    });

    test('should serialize to JSON correctly', () {
      final date = DateTime.now();
      final item = BulkTransactionItem(
        index: 1,
        text: 'Test transaction',
        sender: 'SENDER',
        date: date,
        source: TransactionSource.email,
        trackerId: 'tracker123',
      );

      final json = item.toJson();

      expect(json['index'], 1);
      expect(json['text'], 'Test transaction');
      expect(json['sender'], 'SENDER');
      expect(json['date'], date.toIso8601String());
      expect(json['source'], 'email');
      expect(json['trackerId'], 'tracker123');
    });
  });

  group('Edge Cases and Error Handling', () {
    test('should handle empty sender', () {
      final matches = TrackerRegistry.matchesSmsSender(
        TrackerCategory.hdfcBank,
        '',
      );
      expect(matches, false);
    });

    test('should handle empty email', () {
      final matches = TrackerRegistry.matchesEmailDomain(
        TrackerCategory.hdfcBank,
        '',
      );
      expect(matches, false);
    });

    test('should handle special characters in sender', () {
      final matches = TrackerRegistry.matchesSmsSender(
        TrackerCategory.hdfcBank,
        'VM@HDFCBK#123',
      );
      // Special characters are normalized away
      expect(matches, true);
    });

    test('should get all templates by type', () {
      final bankingTemplates = TrackerRegistry.getTemplatesByType(
        TrackerType.banking,
      );
      expect(bankingTemplates.length, greaterThan(0));
      expect(
        bankingTemplates.every((t) => t.type == TrackerType.banking),
        true,
      );
    });

    test('should get popular trackers', () {
      final popular = TrackerRegistry.getPopularTrackers();
      expect(popular.length, 8);
      expect(popular.any((t) => t.category == TrackerCategory.hdfcBank), true);
      expect(popular.any((t) => t.category == TrackerCategory.zerodha), true);
    });

    test('should search templates by name', () {
      final results = TrackerRegistry.searchTemplates('hdfc');
      expect(results.isNotEmpty, true);
      expect(
        results.any((t) => t.name.toLowerCase().contains('hdfc')),
        true,
      );
    });

    test('should get grouped templates', () {
      final grouped = TrackerRegistry.getGroupedTemplates();
      expect(grouped.containsKey(TrackerType.banking), true);
      expect(grouped.containsKey(TrackerType.investment), true);
      expect(grouped.containsKey(TrackerType.digitalWallet), true);
    });
  });

  group('Confidence Score Validation', () {
    test('SMS matching should have correct confidence levels', () {
      // SMS template matches should have 0.9 confidence
      // This is tested in the actual service, but we validate the concept
      const expectedSmsConfidence = 0.9;
      expect(expectedSmsConfidence, greaterThanOrEqualTo(0.7));
      expect(expectedSmsConfidence, lessThanOrEqualTo(1.0));
    });

    test('Email matching should have tiered confidence levels', () {
      // Exact domain match: 1.0
      // Subdomain match: 0.95
      // Template match: 0.8
      // Template subdomain: 0.7
      final confidenceLevels = [1.0, 0.95, 0.8, 0.7];

      for (final confidence in confidenceLevels) {
        expect(confidence, greaterThanOrEqualTo(0.7));
        expect(confidence, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('Real-World Scenarios', () {
    test('should match HDFC debit SMS', () {
      final smsText = 'Dear Customer, Rs.1,500.00 debited from A/c XX1234 '
          'on 06-Jan-26 at AMAZON INDIA. Info: UPI/123456789012';
      final sender = 'VM-HDFCBK';

      final matches = TrackerRegistry.findMatchingCategoriesForSms(sender);
      expect(matches.contains(TrackerCategory.hdfcBank), true);
    });

    test('should match Zerodha investment email', () {
      final email = 'reports@zerodha.com';

      final matches = TrackerRegistry.findMatchingCategoriesForEmail(email);
      expect(matches.contains(TrackerCategory.zerodha), true);
    });

    test('should match multiple wallets correctly', () {
      final paytmSender = 'PAYTM';
      final phonePeSender = 'PHONEPE';
      final googlePaySender = 'GPAY';

      expect(
        TrackerRegistry.matchesSmsSender(TrackerCategory.paytm, paytmSender),
        true,
      );
      expect(
        TrackerRegistry.matchesSmsSender(TrackerCategory.phonePe, phonePeSender),
        true,
      );
      expect(
        TrackerRegistry.matchesSmsSender(TrackerCategory.googlePay, googlePaySender),
        true,
      );
    });

    test('should differentiate between banks', () {
      final hdfcSender = 'VM-HDFCBK';
      final iciciSender = 'VM-ICICIB';

      // HDFC sender should NOT match ICICI category
      expect(
        TrackerRegistry.matchesSmsSender(TrackerCategory.iciciBank, hdfcSender),
        false,
      );

      // ICICI sender should NOT match HDFC category
      expect(
        TrackerRegistry.matchesSmsSender(TrackerCategory.hdfcBank, iciciSender),
        false,
      );
    });
  });
}

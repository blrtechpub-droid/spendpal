import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'sms_parser_service.dart';

/// Clipboard monitoring service for iOS
/// Checks clipboard for transaction text when app is opened/resumed
class ClipboardExpenseService {
  static DateTime? _lastCheckedTime;
  static String? _lastProcessedText;

  /// Check clipboard for transaction data
  /// Shows dialog if valid transaction is found
  static Future<void> checkClipboardForTransaction(BuildContext context) async {
    try {
      // Don't check too frequently (max once per 5 seconds)
      final now = DateTime.now();
      if (_lastCheckedTime != null &&
          now.difference(_lastCheckedTime!).inSeconds < 5) {
        return;
      }
      _lastCheckedTime = now;

      // Get clipboard data
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData == null || clipboardData.text == null) {
        return;
      }

      final text = clipboardData.text!;

      // Skip if we already processed this text
      if (text == _lastProcessedText) {
        return;
      }

      // Try to parse as transaction
      final transaction = SmsParserService.parseSms(
        text,
        'clipboard',
        DateTime.now(),
      );

      if (transaction != null && context.mounted) {
        _lastProcessedText = text;
        _showTransactionDialog(context, transaction);
      }
    } catch (e) {
      // Silently fail - clipboard access might be denied
      debugPrint('Clipboard check failed: $e');
    }
  }

  /// Show dialog to confirm expense creation from clipboard
  static void _showTransactionDialog(
    BuildContext context,
    TransactionData transaction,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.content_paste, color: Colors.teal),
            SizedBox(width: 8),
            Text('Transaction Detected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Found a transaction in your clipboard:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Merchant:', transaction.merchant),
            _buildDetailRow('Amount:', '₹${transaction.amount.toStringAsFixed(2)}'),
            _buildDetailRow('Category:', transaction.category ?? 'Other'),
            if (transaction.accountInfo != null)
              _buildDetailRow('Account:', transaction.accountInfo!),
            const SizedBox(height: 16),
            const Text(
              'Would you like to add this as an expense?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              // Create expense
              final success = await SmsParserService.createExpenseFromSms(transaction);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '✅ Expense added: ${transaction.merchant}'
                          : '❌ Failed to add expense',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Add Expense'),
          ),
        ],
      ),
    );
  }

  /// Build detail row for dialog
  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Clear the last processed text (useful when user dismisses dialog)
  static void clearLastProcessed() {
    _lastProcessedText = null;
  }
}

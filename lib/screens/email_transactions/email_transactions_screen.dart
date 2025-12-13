import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/services/email_transaction_parser_service.dart';
import 'package:spendpal/services/gmail_service.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'upload_email_screenshot_screen.dart';
import 'pattern_management_screen.dart';

class EmailTransactionsScreen extends StatefulWidget {
  const EmailTransactionsScreen({super.key});

  @override
  State<EmailTransactionsScreen> createState() => _EmailTransactionsScreenState();
}

class _EmailTransactionsScreenState extends State<EmailTransactionsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isGmailConnected = false;
  bool _isCheckingGmail = true;

  @override
  void initState() {
    super.initState();
    _checkGmailAccess();
  }

  Future<void> _checkGmailAccess() async {
    final hasAccess = await GmailService.hasGmailAccess();
    if (mounted) {
      setState(() {
        _isGmailConnected = hasAccess;
        _isCheckingGmail = false;
      });
    }
  }

  Future<void> _connectGmail() async {
    setState(() => _isCheckingGmail = true);

    try {
      final success = await GmailService.requestGmailAccess();

      if (mounted) {
        if (success) {
          setState(() {
            _isGmailConnected = true;
            _isCheckingGmail = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gmail connected successfully. Tap "Sync Emails" to fetch emails.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          setState(() => _isCheckingGmail = false);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect Gmail'),
              backgroundColor: AppTheme.errorColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingGmail = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _syncEmails() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sync Error'),
            content: const Text('User not logged in'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _isCheckingGmail = true);

    // Show progress dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Syncing Emails'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fetching transaction emails...'),
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    try {
      // Fetch transaction emails - no date filter for debugging
      final messages = await GmailService.searchTransactionEmails(
        maxResults: 100,
      );

      final totalEmails = messages.length;
      int addedCount = 0;
      int skippedCount = 0;
      int currentIndex = 0;
      final List<String> errors = [];
      final List<String> networkErrors = [];

      // Update progress dialog with total found
      if (mounted) {
        Navigator.pop(context); // Close initial progress
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Processing Emails'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Found $totalEmails emails'),
                      const SizedBox(height: 8),
                      Text('Processing: $currentIndex / $totalEmails'),
                      Text('Parsed: $addedCount'),
                      if (networkErrors.isNotEmpty)
                        Text('Network errors: ${networkErrors.length}',
                          style: const TextStyle(color: Colors.orange)),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: totalEmails > 0 ? currentIndex / totalEmails : 0,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      }

      for (final message in messages) {
        currentIndex++;

        try {
          // Get full email details with retry
          final email = await GmailService.getEmailDetails(message.id!);

          // Update progress
          if (mounted) {
            Navigator.pop(context);
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Processing Emails'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Found $totalEmails emails'),
                      const SizedBox(height: 8),
                      Text('Processing: $currentIndex / $totalEmails'),
                      Text('Parsed: $addedCount'),
                      if (networkErrors.isNotEmpty)
                        Text('Network errors: ${networkErrors.length}',
                          style: const TextStyle(color: Colors.orange)),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: totalEmails > 0 ? currentIndex / totalEmails : 0,
                      ),
                    ],
                  ),
                );
              },
            );
          }

          if (email == null) {
            skippedCount++;
            final errorMsg = 'Email ${message.id} - Could not fetch details';
            errors.add(errorMsg);
            // Check if it's a network error
            if (GmailService.lastSearchError?.toLowerCase().contains('network') ?? false) {
              networkErrors.add(errorMsg);
            }
            continue;
          }

          // Extract email metadata
          final sender = GmailService.extractSender(email);
          final subject = GmailService.extractSubject(email);
          final body = GmailService.extractTextBody(email);
          final date = GmailService.extractDate(email);

          if (sender == null || subject == null || date == null) {
            skippedCount++;
            errors.add('Email from ${sender ?? "unknown"} - Missing required fields');
            continue;
          }

          // Parse the email
          final parsedData = EmailTransactionParserService.parseEmail(
            senderEmail: sender,
            subject: subject,
            body: body,
            receivedAt: date,
          );

          if (parsedData != null) {
            // Add to queue
            final added = await EmailTransactionParserService.addToQueue(
              userId: userId,
              parsedData: parsedData,
            );

            if (added) {
              addedCount++;
            } else {
              skippedCount++;
              errors.add('Email from $sender - Failed to add to queue');
            }
          } else {
            skippedCount++;
            errors.add('Email from $sender: "$subject" - Could not parse transaction');
          }
        } catch (e) {
          skippedCount++;
          errors.add('Error processing message ${message.id}: $e');
        }
      }

      setState(() => _isCheckingGmail = false);

      // Update last sync time
      await GmailService.updateLastSyncTime();

      if (mounted) {
        // Close progress dialog
        Navigator.pop(context);

        // Show detailed result dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sync Complete'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total emails found: $totalEmails'),
                  Text('Successfully added: $addedCount'),
                  Text('Skipped: $skippedCount'),
                  if (networkErrors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.wifi_off, color: Colors.orange.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Network Issues Detected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${networkErrors.length} emails failed to download due to network errors.',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Try syncing again when you have a stable internet connection.',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Debug Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (GmailService.lastSearchQuery != null) ...[
                    const Text('Query:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    SelectableText(
                      GmailService.lastSearchQuery!,
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ],
                  if (GmailService.lastSearchError != null) ...[
                    const Text('Error:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                    SelectableText(
                      GmailService.lastSearchError!,
                      style: const TextStyle(fontSize: 10, color: Colors.red),
                    ),
                  ],
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...errors.take(10).map((error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $error', style: const TextStyle(fontSize: 12)),
                    )),
                    if (errors.length > 10)
                      Text('... and ${errors.length - 10} more'),
                  ],
                ],
              ),
            ),
            actions: [
              if (networkErrors.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _syncEmails(); // Retry
                  },
                  child: const Text('Retry'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isCheckingGmail = false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sync Error'),
            content: Text('Error syncing emails: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Email Transactions')),
        body: const Center(child: Text('Please login first')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Email Transactions'),
        elevation: 0,
        actions: [
          // Upload email screenshot button
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Upload Email Screenshot',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UploadEmailScreenshotScreen(),
                ),
              );
            },
          ),
          // Pattern management button
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Manage Patterns',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PatternManagementScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: EmailTransactionParserService.getPendingEmails(userId: userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.tealAccent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading email transactions',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final pendingEmails = snapshot.data ?? [];

          if (pendingEmails.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isGmailConnected ? Icons.inbox : Icons.email_outlined,
                      size: 80,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isGmailConnected
                          ? 'No Pending Email Transactions'
                          : 'Connect Gmail',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isGmailConnected
                          ? 'Tap "Sync Emails" to fetch bank transaction emails'
                          : 'Connect your Gmail to automatically import bank and credit card transactions from emails',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (_isGmailConnected) ...[
                      ElevatedButton.icon(
                        onPressed: _isCheckingGmail ? null : _syncEmails,
                        icon: _isCheckingGmail
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync),
                        label: Text(_isCheckingGmail ? 'Syncing...' : 'Sync Emails'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.tealAccent,
                          foregroundColor: theme.scaffoldBackgroundColor,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _isCheckingGmail ? null : _connectGmail,
                        icon: _isCheckingGmail
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.mail),
                        label: Text(_isCheckingGmail ? 'Connecting...' : 'Connect Gmail'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.tealAccent,
                          foregroundColor: theme.scaffoldBackgroundColor,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Privacy First',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.textTheme.bodyLarge?.color,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• All email processing happens on your device\n'
                              '• Emails are never sent to our servers\n'
                              '• Read-only access (cannot send/delete emails)\n'
                              '• More private than CRED',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendingEmails.length,
            itemBuilder: (context, index) {
              final email = pendingEmails[index];
              return _buildEmailCard(context, theme, email, userId);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmailCard(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> email,
    String userId,
  ) {
    final queueId = email['id'] as String;
    final type = email['type'] as String? ?? 'unknown';
    final amount = (email['amount'] as num?)?.toDouble() ?? 0.0;
    final merchant = email['merchant'] as String? ?? 'Unknown Merchant';
    final subject = email['subject'] as String? ?? '';
    final senderEmail = email['senderEmail'] as String? ?? '';
    final transactionDate = (email['transactionDate'] as Timestamp?)?.toDate();

    // Determine transaction type color and icon
    IconData typeIcon;
    Color typeColor;
    String typeLabel;

    switch (type) {
      case 'debit':
      case 'upi':
        typeIcon = Icons.arrow_upward;
        typeColor = AppTheme.orangeAccent;
        typeLabel = type.toUpperCase();
        break;
      case 'credit':
        typeIcon = Icons.arrow_downward;
        typeColor = Colors.green;
        typeLabel = 'CREDIT';
        break;
      case 'credit_card':
        typeIcon = Icons.credit_card;
        typeColor = Colors.purple;
        typeLabel = 'CC';
        break;
      default:
        typeIcon = Icons.help_outline;
        typeColor = Colors.grey;
        typeLabel = type.toUpperCase();
    }

    return Card(
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showEmailDetail(context, theme, email, userId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Type badge + Amount
              Row(
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeIcon, color: typeColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          typeLabel,
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Amount
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: type == 'credit' ? Colors.green : AppTheme.orangeAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Merchant
              Text(
                merchant,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Email subject
              Text(
                subject,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Sender and date
              Row(
                children: [
                  Icon(
                    Icons.email,
                    size: 14,
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      senderEmail,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (transactionDate != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, yyyy').format(transactionDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _importToExpense(email, userId),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Import', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.tealAccent,
                        side: const BorderSide(color: AppTheme.tealAccent),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _ignoreEmail(queueId, userId),
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text('Ignore', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.textTheme.bodyMedium?.color,
                        side: BorderSide(color: theme.dividerTheme.color ?? Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailDetail(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> email,
    String userId,
  ) {
    final rawText = email['rawText'] as String? ?? '';
    final queueId = email['id'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerTheme.color ?? Colors.grey),
              ),
              child: Text(
                rawText,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodyMedium?.color,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _importToExpense(email, userId);
                    },
                    icon: const Icon(Icons.add_circle),
                    label: const Text('Import to Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tealAccent,
                      foregroundColor: theme.textTheme.bodyLarge?.color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _ignoreEmail(queueId, userId);
                  },
                  icon: const Icon(Icons.block),
                  color: theme.textTheme.bodyMedium?.color,
                  tooltip: 'Ignore',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importToExpense(Map<String, dynamic> email, String userId) async {
    try {
      final queueId = email['id'] as String;
      final success = await EmailTransactionParserService.importToExpense(
        userId: userId,
        queueId: queueId,
        parsedData: email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Imported to expenses' : 'Failed to import'),
            backgroundColor: success ? Colors.green : AppTheme.errorColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _ignoreEmail(String queueId, String userId) async {
    try {
      final success = await EmailTransactionParserService.updateEmailStatus(
        userId: userId,
        queueId: queueId,
        status: 'rejected',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Email ignored' : 'Failed to ignore'),
            backgroundColor: success ? Colors.green : AppTheme.errorColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

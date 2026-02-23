import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:spendpal/services/gmail_service.dart';
import 'package:spendpal/services/generic_transaction_parser_service.dart';
import 'package:spendpal/services/local_db_service.dart';
import 'package:spendpal/services/account_tracker_service.dart';
import 'package:spendpal/services/transaction_display_service.dart';
import 'package:spendpal/models/local_transaction_model.dart';
import 'package:spendpal/models/scan_history_model.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/utils/currency_utils.dart';
import 'package:spendpal/widgets/tracker_badge_widget.dart';
import 'package:intl/intl.dart';
import 'upload_email_screenshot_screen.dart';
import 'pattern_management_screen.dart';
import '../trackers/account_tracker_screen.dart';

class EmailTransactionsScreen extends StatefulWidget {
  const EmailTransactionsScreen({super.key});

  @override
  State<EmailTransactionsScreen> createState() => _EmailTransactionsScreenState();
}

class _EmailTransactionsScreenState extends State<EmailTransactionsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isGmailConnected = false;
  bool _isCheckingGmail = true;

  // Date range filter (default: last 30 days)
  int _selectedDays = 30;
  final List<int> _durationOptions = [7, 15, 30, 60, 90];

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');
  Timer? _debounceTimer;

  // Bulk selection
  bool _selectionMode = false;
  final Set<String> _selectedEmails = {};

  // Transaction count for display
  int _transactionCount = 0;

  // Sorting
  String _sortBy = 'date'; // date, amount, merchant
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _checkGmailAccess();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _searchQueryNotifier.value = _searchController.text;
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
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

  /// Load email transactions with cross-source deduplication (Email + SMS)
  Future<List<TransactionWithMergeInfo>> _loadEmailTransactionsWithDedup(String userId) async {
    // Load both email AND SMS transactions to detect cross-source duplicates
    final emailTransactions = await LocalDBService.instance.getTransactions(
      userId: userId,
      source: TransactionSource.email,
      status: TransactionStatus.pending,
    );

    final smsTransactions = await LocalDBService.instance.getTransactions(
      userId: userId,
      source: TransactionSource.sms,
      status: TransactionStatus.pending,
    );

    // Combine both sources
    final allTransactions = [...emailTransactions, ...smsTransactions];

    // Sort by date (newest first)
    allTransactions.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    // Apply deduplication and get merge info
    final mergedList = TransactionDisplayService.filterAndMergeDuplicates(allTransactions);

    // Filter to show only email transactions (but with merge badges if duplicates exist in SMS)
    return mergedList.where((m) => m.transaction.source == TransactionSource.email).toList();
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

    // Show date range picker before syncing
    int? selectedDaysTemp = _selectedDays;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Date Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose how far back to sync emails:'),
              const SizedBox(height: 16),
              ..._durationOptions.map((days) {
                return RadioListTile<int>(
                  title: Text('Last $days days'),
                  value: days,
                  groupValue: selectedDaysTemp,
                  onChanged: (value) {
                    setDialogState(() {
                      selectedDaysTemp = value!;
                    });
                  },
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedDays = selectedDaysTemp!;
                });
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.tealAccent,
              ),
              child: const Text('Start Sync'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // Check if user has configured any trackers
    final hasTrackers = await AccountTrackerService.hasTrackers(userId);

    if (!hasTrackers) {
      // Show tracker setup prompt
      if (mounted) {
        final setupTrackers = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Setup Account Trackers'),
            content: const SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To sync emails, first configure which accounts you want to track.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text('Examples:'),
                  SizedBox(height: 8),
                  Text('• HDFC Bank, ICICI Bank, SBI'),
                  Text('• Zerodha, Groww'),
                  Text('• NPS, PPF'),
                  Text('• Paytm, PhonePe'),
                  SizedBox(height: 12),
                  Text(
                    'Benefits:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('✓ Faster syncs (only your accounts)'),
                  Text('✓ Better privacy (targeted searches)'),
                  Text('✓ Easy to manage'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                ),
                child: const Text('Setup Trackers'),
              ),
            ],
          ),
        );

        if (setupTrackers == true) {
          // Navigate to tracker setup screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AccountTrackerScreen(),
            ),
          );
        }
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
      print('═══════════════════════════════════════════════════════');
      print('🔄 STARTING EMAIL SYNC WITH TRACKER-BASED SEARCH');
      print('═══════════════════════════════════════════════════════');
      print('📅 Date range: Last $_selectedDays days');
      print('🔐 User ID: $userId');

      final startDate = DateTime.now().subtract(Duration(days: _selectedDays));
      print('📆 From: ${startDate.toIso8601String()}');
      print('📆 To: ${DateTime.now().toIso8601String()}');

      // Get active trackers for statistics tracking
      print('\n📊 Loading active trackers for statistics...');
      final activeTrackers = await AccountTrackerService.getActiveTrackers(userId);
      print('✅ Found ${activeTrackers.length} active trackers');

      // Map to track email count per tracker
      final Map<String, int> trackerEmailCounts = {};
      for (final tracker in activeTrackers) {
        trackerEmailCounts[tracker.id] = 0;
      }

      // Fetch transaction emails using tracker-based search
      print('\n🔍 Searching Gmail using configured trackers...');
      final messages = await GmailService.searchTransactionEmailsFromTrackers(
        userId: userId,
        after: startDate,
        maxResults: 100,
      );

      final totalEmails = messages.length;
      print('✅ Gmail search complete');
      print('📧 Found $totalEmails emails matching criteria');

      if (totalEmails == 0) {
        setState(() => _isCheckingGmail = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sync Complete'),
              content: const Text('No transaction emails found in the selected date range.'),
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

      final List<BulkTransactionItem> emailItems = [];
      final List<String> networkErrors = [];

      // Show fetching progress
      if (mounted) {
        Navigator.pop(context); // Close date picker dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Fetching Emails'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.tealAccent),
                const SizedBox(height: 16),
                Text('Downloading $totalEmails emails...'),
              ],
            ),
          ),
        );
      }

      // Fetch email content and create BulkTransactionItem objects
      print('\n📥 FETCHING EMAIL DETAILS');
      print('───────────────────────────────────────────────────────');
      int currentIndex = 0;
      for (final message in messages) {
        currentIndex++;
        print('\n📧 Email $currentIndex/$totalEmails');
        print('  ID: ${message.id}');

        try {
          final email = await GmailService.getEmailDetails(message.id!);

          if (email == null) {
            networkErrors.add('Email ${message.id} - Could not fetch');
            print('  ❌ Could not fetch email details');
            continue;
          }

          // Extract email metadata
          final sender = GmailService.extractSender(email);
          final subject = GmailService.extractSubject(email);
          final body = GmailService.extractTextBody(email);
          final date = GmailService.extractDate(email);

          print('  From: $sender');
          print('  Subject: $subject');
          print('  Date: $date');
          print('  Body length: ${body?.length ?? 0} chars');

          if (sender == null || date == null) {
            print('  ⚠️ SKIPPING - Missing required fields (sender=$sender, date=$date)');
            continue;
          }

          // Match email to tracker based on sender domain
          String? matchedTrackerId;
          for (final tracker in activeTrackers) {
            for (final domain in tracker.emailDomains) {
              if (sender.toLowerCase().contains(domain.toLowerCase())) {
                matchedTrackerId = tracker.id;
                trackerEmailCounts[tracker.id] = (trackerEmailCounts[tracker.id] ?? 0) + 1;
                print('  📊 Matched to tracker: ${tracker.name}');
                break;
              }
            }
            if (matchedTrackerId != null) break;
          }

          // Create email text combining subject and body
          final emailText = '${subject ?? ''}\n${body ?? ''}';
          print('  Email text length: ${emailText.length} chars');
          print('  Email preview: ${emailText.substring(0, emailText.length > 100 ? 100 : emailText.length)}...');

          // Add to bulk processing list
          emailItems.add(BulkTransactionItem(
            index: currentIndex,
            text: emailText,
            sender: sender,
            date: date,
            source: TransactionSource.email,
          ));

          print('  ✅ Added to processing queue');
        } catch (e, stackTrace) {
          networkErrors.add('Error fetching email ${message.id}: $e');
          print('  ❌ ERROR: $e');
          print('  Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}');
        }
      }

      print('\n───────────────────────────────────────────────────────');
      print('📦 BATCH PREPARATION COMPLETE');
      print('  Total fetched: ${emailItems.length}/${totalEmails}');
      print('  Network errors: ${networkErrors.length}');
      if (networkErrors.isNotEmpty) {
        print('  Errors: ${networkErrors.join(", ")}');
      }
      print('───────────────────────────────────────────────────────');

      // Close fetching dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (emailItems.isEmpty) {
        setState(() => _isCheckingGmail = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sync Complete'),
              content: Text('Could not fetch any emails.\n${networkErrors.length} network errors.'),
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

      // Show AI parsing progress
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('AI Parsing'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.tealAccent),
                const SizedBox(height: 16),
                Text('Parsing ${emailItems.length} emails with AI...'),
                const SizedBox(height: 8),
                const Text(
                  'This may take a minute',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }

      // Parse emails using AI and save to local SQLite
      // Emails are longer than SMS, use smaller batch size
      print('\n🤖 AI PARSING PHASE');
      print('═══════════════════════════════════════════════════════');
      print('📤 Preparing to parse ${emailItems.length} emails...');
      print('🔐 User ID: $userId');
      print('🌐 Cloud Function: parseBulkTransactions');
      print('📦 Batch size: 10 emails per batch (smaller due to email length)');

      final parseStartTime = DateTime.now();
      final allParsedTransactions = <LocalTransactionModel>[];

      // Process in batches of 10 (emails are much longer than SMS)
      final batchSize = 10;
      final totalBatches = (emailItems.length / batchSize).ceil();

      for (int batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
        final startIdx = batchIndex * batchSize;
        final endIdx = (startIdx + batchSize < emailItems.length)
            ? startIdx + batchSize
            : emailItems.length;

        final batch = emailItems.sublist(startIdx, endIdx);

        print('\n📦 Processing batch ${batchIndex + 1}/$totalBatches (${batch.length} emails)...');

        try {
          final batchResults = await GenericTransactionParserService.parseBulkTransactions(
            items: batch,
            userId: userId,
          );

          allParsedTransactions.addAll(batchResults);
          print('✅ Batch ${batchIndex + 1}: ${batchResults.length} transactions found');
        } catch (e) {
          print('❌ Batch ${batchIndex + 1} failed: $e');
        }
      }

      final parseEndTime = DateTime.now();
      final parseDuration = parseEndTime.difference(parseStartTime);

      print('\n✅ AI PARSING COMPLETE');
      print('═══════════════════════════════════════════════════════');
      print('⏱️  Duration: ${parseDuration.inSeconds}s');
      print('📥 Input: ${emailItems.length} emails in $totalBatches batches');
      print('📤 Output: ${allParsedTransactions.length} transactions');
      print('💾 Saved to: Local SQLite database');
      print('📊 Success rate: ${((allParsedTransactions.length / emailItems.length) * 100).toStringAsFixed(1)}%');

      if (allParsedTransactions.isNotEmpty) {
        print('\n📋 Sample transactions:');
        for (var i = 0; i < (allParsedTransactions.length > 3 ? 3 : allParsedTransactions.length); i++) {
          final t = allParsedTransactions[i];
          print('  ${i + 1}. ${t.merchant} - ₹${t.amount} (${t.isDebit ? "Debit" : "Credit"})');
        }
      } else {
        print('⚠️  WARNING: No transactions extracted from emails!');
      }
      print('═══════════════════════════════════════════════════════');

      final parsedTransactions = allParsedTransactions;

      setState(() => _isCheckingGmail = false);

      // Update last sync time
      await GmailService.updateLastSyncTime();

      // Save scan history for cost tracking
      final scanHistory = ScanHistoryModel(
        id: const Uuid().v4(),
        userId: userId,
        scanDate: DateTime.now(),
        source: TransactionSource.email,
        mode: ScanMode.ai, // Email always uses AI mode
        daysScanned: _selectedDays,
        rangeStart: startDate,
        rangeEnd: DateTime.now(),
        totalMessages: totalEmails,
        filteredMessages: emailItems.length,
        alreadyProcessed: totalEmails - emailItems.length,
        patternMatched: 0, // Email parsing uses AI (patterns learned for future)
        aiProcessed: emailItems.length,
        transactionsFound: parsedTransactions.length,
        newPatternsLearned: 0, // TODO: Track from parser
      );

      await LocalDBService.instance.insertScanHistory(scanHistory);
      print('📝 Scan history saved: ₹${scanHistory.cost.toStringAsFixed(2)} (${emailItems.length} AI calls)');

      // Update tracker statistics
      print('\n📊 UPDATING TRACKER STATISTICS');
      print('───────────────────────────────────────────────────────');
      for (final trackerId in trackerEmailCounts.keys) {
        final count = trackerEmailCounts[trackerId] ?? 0;
        if (count > 0) {
          final tracker = activeTrackers.firstWhere((t) => t.id == trackerId);
          print('  Tracker: ${tracker.name}');
          print('  Emails found: $count');

          // Increment email count
          await AccountTrackerService.incrementEmailsFetched(userId, trackerId, count);

          // Update last sync time
          await AccountTrackerService.updateLastSyncTime(userId, trackerId);

          print('  ✅ Statistics updated');
        }
      }
      print('───────────────────────────────────────────────────────');

      if (mounted) {
        // Close AI parsing dialog
        Navigator.pop(context);

        // Show result dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sync Complete'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total emails fetched: $totalEmails'),
                  Text('Successfully parsed: ${parsedTransactions.length}'),
                  Text('Saved to local database: ${parsedTransactions.length}'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.tealAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.tealAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.check_circle, color: AppTheme.tealAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'AI Parsing Complete',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.tealAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Transactions are now in your review queue.\n'
                          'You can categorize and import them below.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
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
    } catch (e, stackTrace) {
      print('\n❌❌❌ SYNC ERROR ❌❌❌');
      print('═══════════════════════════════════════════════════════');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('\n📍 Stack trace:');
      print(stackTrace.toString().split('\n').take(10).join('\n'));
      print('═══════════════════════════════════════════════════════');

      setState(() => _isCheckingGmail = false);

      if (mounted) {
        // Close any open dialogs
        Navigator.of(context).popUntil((route) => route.isFirst);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sync Error'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Failed to sync emails:'),
                  const SizedBox(height: 8),
                  Text(
                    '$e',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Email Transactions'),
            Text(
              _transactionCount == 1 ? '1 transaction' : '$_transactionCount transactions',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          // Scan history
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Scan History & Costs',
            onPressed: () {
              Navigator.pushNamed(context, '/scan_history');
            },
          ),
          // Processing statistics
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Processing Statistics',
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/processing_stats',
                arguments: {'source': TransactionSource.email},
              );
            },
          ),
          // Sync emails button
          IconButton(
            icon: _isCheckingGmail
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync Emails',
            onPressed: _isCheckingGmail ? null : _syncEmails,
          ),
          // Account trackers button
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Manage Account Trackers',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountTrackerScreen(),
                ),
              );
            },
          ),
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
      body: FutureBuilder<List<TransactionWithMergeInfo>>(
        future: _loadEmailTransactionsWithDedup(userId),
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

          final allEmails = snapshot.data ?? [];

          // Update transaction count for display in AppBar
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _transactionCount != allEmails.length) {
              setState(() {
                _transactionCount = allEmails.length;
              });
            }
          });

          if (allEmails.isEmpty) {
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

          return ValueListenableBuilder<String>(
            valueListenable: _searchQueryNotifier,
            builder: (context, searchQuery, _) {
              final filteredEmails = _filterAndSortEmails(allEmails);

              return Stack(
                children: [
                  Column(
                    children: [
                      // Search bar
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Search merchant, subject, amount...',
                            hintStyle: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                            ),
                            prefixIcon: Icon(Icons.search, color: theme.textTheme.bodyMedium?.color),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _searchFocusNode.unfocus();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: theme.cardTheme.color,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),

                      // Filter/Sort bar
                      if (!_selectionMode) _buildFilterSortBar(allEmails),

                      // Selection header
                      if (_selectionMode) _buildSelectionHeader(filteredEmails),

                      // Email list
                      Expanded(
                        child: filteredEmails.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 64,
                                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No emails match your filters',
                                        style: TextStyle(
                                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, _selectionMode ? 80 : 16),
                                itemCount: filteredEmails.length,
                                itemBuilder: (context, index) {
                                  final email = filteredEmails[index];
                                  if (_selectionMode) {
                                    return _buildSelectableCard(email, theme, userId);
                                  }
                                  return _buildEmailCard(context, theme, email, userId);
                                },
                              ),
                      ),
                    ],
                  ),

                  // Bulk action bar
                  if (_selectionMode && _selectedEmails.isNotEmpty)
                    _buildBulkActionBar(allEmails),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmailCard(
    BuildContext context,
    ThemeData theme,
    TransactionWithMergeInfo emailInfo,
    String userId,
  ) {
    final email = emailInfo.transaction;
    final amount = email.amount;
    final merchant = email.merchant;
    final senderEmail = email.sourceIdentifier ?? '';
    final transactionDate = email.transactionDate;
    final category = email.category;

    return Card(
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showEmailDetail(context, theme, emailInfo, userId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Receipt icon + Merchant + Amount (matching SMS layout)
              Row(
                children: [
                  // Receipt icon in teal circle (matching SMS)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.tealAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.email_outlined,
                      color: AppTheme.tealAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Merchant name and date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchant,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          transactionDate != null
                              ? DateFormat('dd MMM yyyy, hh:mm a').format(transactionDate)
                              : 'Unknown date',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Amount (matching SMS teal color)
                  Text(
                    context.formatCurrency(amount),
                    style: const TextStyle(
                      color: AppTheme.tealAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Category and sender email chips (matching SMS style)
              Row(
                children: [
                  _buildChip(category, Icons.category),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChip(
                      senderEmail.split('@').first,
                      Icons.email,
                    ),
                  ),
                ],
              ),

              // Badges row (Merge badge + Tracker badge)
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Merge badge (if this email has SMS duplicates)
                  if (emailInfo.hasDuplicates)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.purple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.merge_type, size: 14, color: Colors.purple),
                          const SizedBox(width: 6),
                          Text(
                            emailInfo.mergeBadgeText,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Tracker badge
                  TrackerBadge(
                    trackerId: email.trackerId,
                    confidence: email.trackerConfidence,
                    userId: userId,
                    compact: true,
                  ),
                ],
              ),

              const SizedBox(height: 12),
              // Action buttons (matching SMS "Categorize" button style)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _importToExpense(emailInfo, userId),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Import', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.tealAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareEmailExpense(emailInfo),
                      icon: const Icon(Icons.group, size: 16),
                      label: const Text('Share', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.tealAccent,
                        side: const BorderSide(color: AppTheme.tealAccent),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _ignoreEmail(emailInfo, userId),
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text('Ignore', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.textTheme.bodyMedium?.color,
                        side: BorderSide(color: theme.dividerTheme.color ?? Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  // Helper method to build chips (matching SMS style)
  Widget _buildChip(String label, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailDetail(
    BuildContext context,
    ThemeData theme,
    TransactionWithMergeInfo emailInfo,
    String userId,
  ) {
    final email = emailInfo.transaction;
    final rawText = email.rawContent ?? '';

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
                      _importToExpense(emailInfo, userId);
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
                    _ignoreEmail(emailInfo, userId);
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

  Future<void> _importToExpense(TransactionWithMergeInfo emailInfo, String userId) async {
    final transaction = emailInfo.transaction;

    try {
      // Convert LocalTransactionModel to Firestore expense
      await FirebaseFirestore.instance.collection('expenses').add({
        'userId': userId,
        'title': transaction.merchant,
        'amount': transaction.amount,
        'category': transaction.category,
        'date': Timestamp.fromDate(transaction.transactionDate),
        'notes': 'Imported from email: ${transaction.sourceIdentifier}',
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'email',
        'isDebit': transaction.isDebit,
      });

      // Update local transaction status to confirmed
      final updatedTransaction = transaction.copyWith(
        status: TransactionStatus.confirmed,
      );
      await LocalDBService.instance.updateTransaction(updatedTransaction);

      // Update duplicate transactions
      if (emailInfo.hasDuplicates) {
        await _updateDuplicateTransactions(transaction, userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imported to expenses'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {}); // Refresh the list
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

  Future<void> _shareEmailExpense(TransactionWithMergeInfo emailInfo) async {
    final email = emailInfo.transaction;
    final userId = _auth.currentUser?.uid ?? '';

    // Navigate to add expense screen with pre-filled data
    final result = await Navigator.pushNamed(
      context,
      '/add_expense',
      arguments: {
        'prefill': true,
        'title': email.merchant,
        'amount': email.amount.toString(),
        'category': email.category,
        'notes': 'From email: ${email.sourceIdentifier ?? 'Unknown'}${email.notes != null ? '\n${email.notes}' : ''}',
        'date': email.transactionDate,
      },
    );

    // If expense was created, mark email as confirmed
    if (result == true && mounted) {
      try {
        final updatedTransaction = email.copyWith(
          status: TransactionStatus.confirmed,
        );
        await LocalDBService.instance.updateTransaction(updatedTransaction);

        // Update duplicates
        if (emailInfo.hasDuplicates) {
          await _updateDuplicateTransactions(email, userId);
        }

        setState(() {}); // Refresh the list
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shared successfully but failed to update status: $e'),
              backgroundColor: AppTheme.orangeAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _ignoreEmail(TransactionWithMergeInfo emailInfo, String userId) async {
    final email = emailInfo.transaction;
    try {
      // Update status to ignored
      final updatedTransaction = email.copyWith(
        status: TransactionStatus.ignored,
      );

      await LocalDBService.instance.updateTransaction(updatedTransaction);

      // Update duplicates
      if (emailInfo.hasDuplicates) {
        await _updateDuplicateTransactionsToStatus(email, userId, TransactionStatus.ignored);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email ignored'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {}); // Refresh the list
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

  /// Update duplicate transactions to a specific status (for ignore action)
  Future<void> _updateDuplicateTransactionsToStatus(
    LocalTransactionModel primaryTransaction,
    String userId,
    TransactionStatus newStatus,
  ) async {
    try {
      final smsTransactions = await LocalDBService.instance.getTransactions(
        userId: userId,
        source: TransactionSource.sms,
        status: TransactionStatus.pending,
      );

      final emailTransactions = await LocalDBService.instance.getTransactions(
        userId: userId,
        source: TransactionSource.email,
        status: TransactionStatus.pending,
      );

      final allTransactions = [...smsTransactions, ...emailTransactions];

      for (final other in allTransactions) {
        if (other.id == primaryTransaction.id) continue;

        if (_isDuplicate(primaryTransaction, other)) {
          final updatedTransaction = other.copyWith(
            status: newStatus,
            updatedAt: DateTime.now(),
          );

          await LocalDBService.instance.updateTransaction(updatedTransaction);
        }
      }
    } catch (e) {
      print('Error updating duplicate transactions to status: $e');
      // Don't throw - partial success is okay
    }
  }

  // Duration picker
  void _showDurationPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Time Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _durationOptions.map((days) {
            return RadioListTile<int>(
              title: Text('Last $days days'),
              value: days,
              groupValue: _selectedDays,
              onChanged: (value) {
                setState(() {
                  _selectedDays = value!;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // Bulk selection methods
  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedEmails.clear();
      }
    });
  }

  void _toggleEmailSelection(String emailId) {
    setState(() {
      if (_selectedEmails.contains(emailId)) {
        _selectedEmails.remove(emailId);
      } else {
        _selectedEmails.add(emailId);
      }
    });
  }

  void _selectAllEmails(List<TransactionWithMergeInfo> emails) {
    setState(() {
      if (_selectedEmails.length == emails.length) {
        _selectedEmails.clear();
      } else {
        _selectedEmails.clear();
        _selectedEmails.addAll(emails.map((e) => e.transaction.id));
      }
    });
  }

  Future<void> _bulkImport(List<TransactionWithMergeInfo> allEmails) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final selectedList = allEmails.where((e) => _selectedEmails.contains(e.transaction.id)).toList();

    if (selectedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No emails selected')),
      );
      return;
    }

    int successCount = 0;
    for (final transactionInfo in selectedList) {
      try {
        await _importToExpense(transactionInfo, userId);
        successCount++;
      } catch (e) {
        print('Error importing transaction ${transactionInfo.transaction.id}: $e');
      }
    }

    setState(() {
      _selectedEmails.clear();
      _selectionMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $successCount of ${selectedList.length} emails'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _bulkIgnore(List<TransactionWithMergeInfo> allEmails, String userId) async {
    if (_selectedEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No emails selected')),
      );
      return;
    }

    final selectedList = allEmails.where((e) => _selectedEmails.contains(e.transaction.id)).toList();

    int successCount = 0;
    for (final transactionInfo in selectedList) {
      try {
        await _ignoreEmail(transactionInfo, userId);
        successCount++;
      } catch (e) {
        print('Error ignoring transaction ${transactionInfo.transaction.id}: $e');
      }
    }

    setState(() {
      _selectedEmails.clear();
      _selectionMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ignored $successCount emails'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Filter and sort emails
  List<TransactionWithMergeInfo> _filterAndSortEmails(List<TransactionWithMergeInfo> emails) {
    var filtered = List<TransactionWithMergeInfo>.from(emails);

    // Apply search filter
    final searchQuery = _searchQueryNotifier.value.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((emailInfo) {
        final email = emailInfo.transaction;
        final merchant = email.merchant.toLowerCase();
        final subject = (email.rawContent?.split('\n').first ?? '').toLowerCase();
        final sender = (email.sourceIdentifier ?? '').toLowerCase();
        final amount = email.amount.toString();

        return merchant.contains(searchQuery) ||
               subject.contains(searchQuery) ||
               sender.contains(searchQuery) ||
               amount.contains(searchQuery);
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case 'date':
          comparison = a.transaction.transactionDate.compareTo(b.transaction.transactionDate);
          break;
        case 'amount':
          comparison = a.transaction.amount.compareTo(b.transaction.amount);
          break;
        case 'merchant':
          comparison = a.transaction.merchant.compareTo(b.transaction.merchant);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  // UI Builder Methods
  Widget _buildFilterSortBar(List<TransactionWithMergeInfo> emails) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Duration filter chip
            FilterChip(
              label: Text('Last $_selectedDays days'),
              avatar: const Icon(Icons.calendar_today, size: 16),
              selected: true,
              onSelected: (_) => _showDurationPicker(),
              selectedColor: AppTheme.tealAccent.withValues(alpha: 0.2),
              labelStyle: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 8),

            // Sort chip
            FilterChip(
              label: Text(_sortBy == 'date' ? 'Date' : _sortBy == 'amount' ? 'Amount' : 'Merchant'),
              avatar: Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
              ),
              selected: true,
              onSelected: (_) => _showSortDialog(),
              selectedColor: Colors.blue.withValues(alpha: 0.2),
              labelStyle: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 8),

            // Selection mode chip
            FilterChip(
              label: const Text('Select'),
              avatar: const Icon(Icons.checklist, size: 16),
              selected: _selectionMode,
              onSelected: (_) => _toggleSelectionMode(),
              selectedColor: Colors.orange.withValues(alpha: 0.2),
              labelStyle: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 8),

            // Count chip
            Chip(
              label: Text('${emails.length} emails'),
              labelStyle: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color,
              ),
              backgroundColor: theme.cardTheme.color,
            ),
          ],
        ),
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort By'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Date'),
              value: 'date',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Amount'),
              value: 'amount',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Merchant'),
              value: 'merchant',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Ascending'),
              value: _sortAscending,
              onChanged: (value) {
                setState(() => _sortAscending = value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(List<TransactionWithMergeInfo> emails) {
    final theme = Theme.of(context);
    final allSelected = _selectedEmails.length == emails.length && emails.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.tealAccent.withValues(alpha: 0.1),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            tristate: _selectedEmails.isNotEmpty && !allSelected,
            onChanged: (_) => _selectAllEmails(emails),
          ),
          Text(
            '${_selectedEmails.length} selected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _toggleSelectionMode,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableCard(
    TransactionWithMergeInfo emailInfo,
    ThemeData theme,
    String userId,
  ) {
    final email = emailInfo.transaction;
    final queueId = email.id;
    final isSelected = _selectedEmails.contains(queueId);

    return Card(
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: AppTheme.tealAccent, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _toggleEmailSelection(queueId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleEmailSelection(queueId),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEmailCardContent(email, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailCardContent(LocalTransactionModel email, ThemeData theme) {
    final amount = email.amount;
    final merchant = email.merchant;
    final transactionDate = email.transactionDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                merchant,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              context.formatCurrency(amount),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.tealAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          transactionDate != null
              ? DateFormat('dd MMM yyyy').format(transactionDate)
              : 'Unknown date',
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildBulkActionBar(List<TransactionWithMergeInfo> allEmails) {
    final theme = Theme.of(context);
    final userId = _auth.currentUser?.uid ?? '';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _bulkImport(allEmails),
                icon: const Icon(Icons.add_circle, size: 20),
                label: Text('Import (${_selectedEmails.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _bulkIgnore(allEmails, userId),
                icon: const Icon(Icons.block, size: 20),
                label: const Text('Ignore'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textTheme.bodyMedium?.color,
                  side: BorderSide(color: theme.dividerTheme.color ?? Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Update all duplicate copies of a transaction when one is imported/confirmed
  Future<void> _updateDuplicateTransactions(
    LocalTransactionModel primaryTransaction,
    String userId,
  ) async {
    try {
      // Load all pending transactions from both sources
      final smsTransactions = await LocalDBService.instance.getTransactions(
        userId: userId,
        source: TransactionSource.sms,
        status: TransactionStatus.pending,
      );

      final emailTransactions = await LocalDBService.instance.getTransactions(
        userId: userId,
        source: TransactionSource.email,
        status: TransactionStatus.pending,
      );

      final allTransactions = [...smsTransactions, ...emailTransactions];

      // Find all duplicates of the primary transaction
      for (final other in allTransactions) {
        // Skip the primary transaction itself
        if (other.id == primaryTransaction.id) continue;

        // Check if this is a duplicate
        if (_isDuplicate(primaryTransaction, other)) {
          // Update the duplicate to confirmed status
          final updatedTransaction = other.copyWith(
            status: TransactionStatus.confirmed,
            updatedAt: DateTime.now(),
          );

          await LocalDBService.instance.updateTransaction(updatedTransaction);
        }
      }
    } catch (e) {
      print('Error updating duplicate transactions: $e');
      // Don't throw - partial success is okay
    }
  }

  /// Check if two transactions are duplicates (same logic as TransactionDisplayService)
  bool _isDuplicate(LocalTransactionModel t1, LocalTransactionModel t2) {
    // Same source - not duplicate
    if (t1.source == t2.source) return false;

    // Check by transaction ID (exact match)
    if (t1.transactionId != null &&
        t2.transactionId != null &&
        t1.transactionId!.isNotEmpty &&
        t2.transactionId!.isNotEmpty &&
        t1.transactionId == t2.transactionId) {
      return true;
    }

    // Fuzzy match: amount + date + merchant
    final amountMatch = (t1.amount - t2.amount).abs() < 0.01;
    final dateMatch = t1.transactionDate
            .difference(t2.transactionDate)
            .abs()
            .inHours < 24;
    final merchantMatch = _isMerchantSimilar(t1.merchant, t2.merchant);

    return amountMatch && dateMatch && merchantMatch;
  }

  /// Check if two merchant names are similar (same logic as TransactionDisplayService)
  bool _isMerchantSimilar(String merchant1, String merchant2) {
    final clean1 = _cleanMerchantName(merchant1);
    final clean2 = _cleanMerchantName(merchant2);

    if (clean1 == clean2) return true;
    if (clean1.contains(clean2) || clean2.contains(clean1)) return true;

    final words1 = clean1.split(' ').where((w) => w.isNotEmpty).toSet();
    final words2 = clean2.split(' ').where((w) => w.isNotEmpty).toSet();
    if (words1.isEmpty || words2.isEmpty) return false;

    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    final similarity = intersection / union;

    return similarity >= 0.6;
  }

  /// Clean merchant name for comparison
  String _cleanMerchantName(String merchant) {
    return merchant
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

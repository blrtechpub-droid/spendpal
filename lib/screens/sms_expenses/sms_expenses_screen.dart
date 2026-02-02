import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/models/sms_expense_model.dart';
import 'package:spendpal/models/sms_scan_progress.dart';
import 'package:spendpal/services/sms_expense_service.dart';
import 'package:spendpal/services/sms_listener_service.dart';
import 'package:spendpal/services/sms_parser_service.dart';
import 'package:spendpal/services/currency_service.dart';
import 'package:spendpal/services/transaction_categorization_service.dart';
import 'package:spendpal/services/regex_pattern_tracker.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/widgets/empty_state_widget.dart';
import 'package:spendpal/widgets/transaction_categorization_dialog.dart';
import 'package:spendpal/services/account_tracker_service.dart';
import 'package:spendpal/models/account_tracker_model.dart';
import 'package:spendpal/services/transaction_display_service.dart';
import 'package:spendpal/widgets/tracker_suggestions_widget.dart';
import 'package:spendpal/config/tracker_registry.dart';
// Privacy-first: Local SQLite storage
import 'package:spendpal/services/local_db_service.dart';
import 'package:spendpal/models/local_transaction_model.dart';

class SmsExpensesScreen extends StatefulWidget {
  const SmsExpensesScreen({super.key});

  @override
  State<SmsExpensesScreen> createState() => _SmsExpensesScreenState();
}

class _SmsExpensesScreenState extends State<SmsExpensesScreen> {
  bool _isScanning = false;
  String _currencySymbol = '₹';
  int _selectedDays = 30; // Default: 1 month
  String? _lastError;
  bool _permissionDenied = false;
  DateTime? _lastScanTime;
  bool _fastMode = true; // Fast Mode: regex-only, no AI (10x faster!)

  final List<int> _durationOptions = [7, 15, 30, 60, 90];

  // Bulk selection
  bool _selectionMode = false;
  final Set<String> _selectedExpenses = {};

  // Filtering
  String? _filterCategory;
  DateTimeRange? _filterDateRange;
  double? _filterMinAmount;
  double? _filterMaxAmount;
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier<String>('');

  // Sorting
  String _sortBy = 'date'; // date, amount, merchant
  bool _sortAscending = false;

  // Search controller and focus
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  // Privacy-first: Local SQLite refresh key
  int _refreshKey = 0;
  int _transactionCount = 0; // Track number of transactions for display

  /// Refresh transactions from local database
  void _refreshTransactions() {
    if (mounted) {
      setState(() {
        _refreshKey++;
      });
    }
  }

  /// Load transactions from local SQLite with cross-source deduplication
  Future<List<TransactionWithMergeInfo>> _loadLocalTransactions() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('⚠️ DEBUG: No current user, returning empty list');
      return [];
    }

    print('🔎 DEBUG: Loading SMS transactions for user: ${currentUser.uid}');
    print('🔎 DEBUG: Query params - source: TransactionSource.sms, status: TransactionStatus.pending');

    // Load both SMS AND Email transactions to detect cross-source duplicates
    final smsTransactions = await LocalDBService.instance.getTransactions(
      userId: currentUser.uid,
      source: TransactionSource.sms,
      status: TransactionStatus.pending,
    );

    print('🔎 DEBUG: smsTransactions loaded: ${smsTransactions.length} items');

    final emailTransactions = await LocalDBService.instance.getTransactions(
      userId: currentUser.uid,
      source: TransactionSource.email,
      status: TransactionStatus.pending,
    );

    // Combine both sources for deduplication detection
    final allTransactions = [...smsTransactions, ...emailTransactions];
    print('🔄 DEBUG: Combined transactions: ${allTransactions.length} (${smsTransactions.length} SMS + ${emailTransactions.length} Email)');

    // Sort by date (newest first)
    allTransactions.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    // Apply deduplication - this will find duplicates but keep ALL transactions
    final mergedList = TransactionDisplayService.filterAndMergeDuplicates(allTransactions);
    print('🔄 DEBUG: After deduplication: ${mergedList.length} items');

    // ⚠️ FIX: Show ALL SMS transactions, even if they have duplicates in Email
    // Don't filter out duplicates - just show merge badges
    final smsOnly = mergedList.where((m) => m.transaction.source == TransactionSource.sms).toList();
    print('🔄 DEBUG: After filtering for SMS source: ${smsOnly.length} items');

    return smsOnly;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrencySymbol();
    _checkPlatformSupport();
    _loadLastScanTime();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Start new timer - only update after 300ms of no typing
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        // Update the notifier - ValueListenableBuilder will rebuild only the list
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

  Future<void> _loadLastScanTime() async {
    final lastScan = await SmsListenerService.getLastScanTimestamp();
    if (mounted) {
      setState(() {
        _lastScanTime = lastScan;
      });
    }
  }

  void _checkPlatformSupport() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      setState(() {
        _lastError = 'SMS scanning is not supported on iOS due to platform restrictions.';
      });
    }
  }

  Future<void> _loadCurrencySymbol() async {
    final symbol = await CurrencyService.getCurrencySymbol();
    if (mounted) {
      setState(() {
        _currencySymbol = symbol;
      });
    }
  }

  Future<void> _scanSmsMessages() async {
    // Check platform support
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS scanning is not supported on iOS'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() {
      _isScanning = true;
      _lastError = null;
      _permissionDenied = false;
    });

    try {
      // Check permissions first
      final hasPermission = await SmsListenerService.hasPermissions();

      if (!hasPermission) {
        // Request permissions
        final granted = await SmsListenerService.requestPermissions();

        if (!granted) {
          setState(() {
            _permissionDenied = true;
            _lastError = 'SMS permission denied. Please grant SMS permission in Settings to scan messages.';
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('SMS permission denied. Please enable in Settings.'),
                backgroundColor: AppTheme.errorColor,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () {
                    // User can manually go to settings
                  },
                ),
              ),
            );
          }
          return;
        }
      }

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _ScanProgressDialog(
            onScan: (updateProgress, shouldCancel) async {
              final count = await SmsListenerService.processRecentMessages(
                days: _selectedDays,
                fastMode: _fastMode, // Use Fast Mode setting from toggle
                onProgress: (progress) {
                  updateProgress(progress);
                },
                shouldCancel: shouldCancel,
              );
              return count;
            },
          ),
        ).then((count) async {
          if (count != null) {
            // Reload last scan time
            await _loadLastScanTime();

            setState(() {
              _lastError = null;
              _permissionDenied = false;
            });

            if (mounted) {
              final daysText = _getDurationLabel(_selectedDays);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Found $count transaction${count == 1 ? '' : 's'} from last $daysText'),
                  backgroundColor: count > 0 ? AppTheme.tealAccent : AppTheme.secondaryText,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      final errorMessage = _getDetailedErrorMessage(e);
      setState(() {
        _lastError = errorMessage;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  String _getDetailedErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('permission')) {
      return 'SMS permission denied or not granted. Please enable SMS permission in Settings.';
    } else if (errorStr.contains('not found') || errorStr.contains('null')) {
      return 'Unable to access SMS database. Please check app permissions.';
    } else if (errorStr.contains('timeout')) {
      return 'SMS scan timed out. Please try again with a shorter duration.';
    } else if (errorStr.contains('platform')) {
      return 'SMS scanning is not supported on this platform.';
    } else {
      return 'Error scanning SMS: ${error.toString()}';
    }
  }

  void _showDurationPicker() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Scan Duration',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how far back to scan for transactions',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ..._durationOptions.map((days) {
              final isSelected = days == _selectedDays;
              final label = days == 7 ? '7 days (1 week)' :
                           days == 15 ? '15 days (2 weeks)' :
                           days == 30 ? '30 days (1 month)' :
                           days == 60 ? '60 days (2 months)' :
                           days == 90 ? '90 days (3 months)' : '$days days';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.tealAccent : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.tealAccent : theme.textTheme.bodyLarge?.color,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _selectedDays = days;
                  });
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _shareWithFriendOrGroup(SmsExpenseModel smsExpense) async {
    // Navigate to add expense screen with pre-filled data
    final result = await Navigator.pushNamed(
      context,
      '/add_expense',
      arguments: {
        'prefill': true,
        'title': smsExpense.merchant,
        'amount': smsExpense.amount,
        'date': smsExpense.date,
        'category': smsExpense.category,
        'notes':
            'From SMS: ${smsExpense.accountInfo ?? ""}\nTxn: ${smsExpense.transactionId ?? "N/A"}',
        'smsExpenseId': smsExpense.id,
      },
    );

    // If expense was created, mark SMS expense as categorized
    if (result != null && result is String) {
      await SmsExpenseService.markAsCategorized(smsExpense.id, result);
    }
  }

  Future<void> _showCategorizationDialog(SmsExpenseModel smsExpense) async {
    final result = await showDialog<TransactionCategorizationResult>(
      context: context,
      builder: (context) => TransactionCategorizationDialog(
        title: smsExpense.merchant,
        amount: smsExpense.amount,
        transactionType: smsExpense.isCredit ? TransactionType.credit : TransactionType.debit,
        description: smsExpense.accountInfo,
        trackerId: smsExpense.trackerId, // Pass matched tracker for account filtering
      ),
    );

    if (result == null) return;

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              ),
              SizedBox(width: 12),
              Text('Categorizing...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Prepare metadata
    final metadata = {
      'sender': smsExpense.smsSender,
      'rawSms': smsExpense.rawSms,
      'transactionId': smsExpense.transactionId,
      'accountInfo': smsExpense.accountInfo,
      'parsedAt': smsExpense.parsedAt.toIso8601String(),
      'smsExpenseId': smsExpense.id,
    };

    String? recordId;

    // Call appropriate service method based on category
    try {
      switch (result.category) {
        case 'salary':
          recordId = await TransactionCategorizationService.categorizeSalary(
            transactionId: smsExpense.id,
            transactionSource: 'sms',
            amount: smsExpense.amount,
            date: smsExpense.date,
            description: smsExpense.merchant,
            accountId: result.accountId,
            accountSource: result.accountSource,
            account: result.account,
            notes: result.notes,
            metadata: metadata,
          );
          break;

        case 'investment_return':
          recordId = await TransactionCategorizationService.categorizeInvestmentReturn(
            transactionId: smsExpense.id,
            transactionSource: 'sms',
            amount: smsExpense.amount,
            date: smsExpense.date,
            description: smsExpense.merchant,
            accountId: result.accountId,
            accountSource: result.accountSource,
            account: result.account,
            notes: result.notes,
            metadata: metadata,
          );
          break;

        case 'cashback':
          recordId = await TransactionCategorizationService.categorizeCashback(
            transactionId: smsExpense.id,
            transactionSource: 'sms',
            amount: smsExpense.amount,
            date: smsExpense.date,
            description: smsExpense.merchant,
            accountId: result.accountId,
            accountSource: result.accountSource,
            account: result.account,
            notes: result.notes,
            metadata: metadata,
          );
          break;

        case 'refund':
          recordId = await TransactionCategorizationService.categorizeRefund(
            transactionId: smsExpense.id,
            transactionSource: 'sms',
            amount: smsExpense.amount,
            date: smsExpense.date,
            description: smsExpense.merchant,
            accountId: result.accountId,
            accountSource: result.accountSource,
            account: result.account,
            notes: result.notes,
            metadata: metadata,
          );
          break;

        case 'other_income':
          recordId = await TransactionCategorizationService.categorizeOtherIncome(
            transactionId: smsExpense.id,
            transactionSource: 'sms',
            amount: smsExpense.amount,
            date: smsExpense.date,
            description: smsExpense.merchant,
            accountId: result.accountId,
            accountSource: result.accountSource,
            account: result.account,
            notes: result.notes,
            metadata: metadata,
          );
          break;

        case 'expense':
          recordId = await TransactionCategorizationService.categorizeExpense(
            transactionId: smsExpense.id,
            transactionSource: 'sms',
            amount: smsExpense.amount,
            date: smsExpense.date,
            description: smsExpense.merchant,
            accountId: result.accountId,
            accountSource: result.accountSource,
            account: result.account,
            notes: result.notes,
            category: smsExpense.category,
            metadata: metadata,
          );
          break;

        case 'investment':
          recordId = await TransactionCategorizationService.categorizeInvestment(
            transactionId: smsExpense.id,
            transactionSource: 'sms',
            amount: smsExpense.amount,
            date: smsExpense.date,
            description: smsExpense.merchant,
            accountId: result.accountId,
            accountSource: result.accountSource,
            account: result.account,
            notes: result.notes,
            metadata: metadata,
          );
          break;

        case 'loan_payment':
          recordId = await TransactionCategorizationService.categorizeLoanPayment(
            transactionId: smsExpense.id,
            transactionSource: 'sms',
            amount: smsExpense.amount,
            date: smsExpense.date,
            description: smsExpense.merchant,
            accountId: result.accountId,
            accountSource: result.accountSource,
            account: result.account,
            notes: result.notes,
            metadata: metadata,
          );
          break;

        case 'transfer':
          recordId = await TransactionCategorizationService.categorizeTransfer(
            transactionId: smsExpense.id,
            transactionSource: 'sms',
            amount: smsExpense.amount,
            date: smsExpense.date,
            description: smsExpense.merchant,
            accountId: result.accountId,
            accountSource: result.accountSource,
            account: result.account,
            notes: result.notes,
            metadata: metadata,
          );
          break;
      }

      if (mounted) {
        if (recordId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully categorized as ${result.category.replaceAll('_', ' ')}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to categorize transaction'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
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

  Future<void> _ignoreSmsExpense(SmsExpenseModel smsExpense) async {
    // Update transaction status to ignored in local database
    final transaction = await LocalDBService.instance.getTransaction(smsExpense.id);
    if (transaction == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction not found'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final updated = transaction.copyWith(status: TransactionStatus.ignored);
    final success = await LocalDBService.instance.updateTransaction(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Expense ignored' : 'Failed to ignore expense'),
          backgroundColor: success ? AppTheme.tealAccent : AppTheme.errorColor,
          duration: const Duration(seconds: 2),
        ),
      );

      if (success) {
        _refreshTransactions();
      }
    }
  }

  Future<void> _deleteSmsExpense(SmsExpenseModel smsExpense) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        title: Text('Delete Expense?', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
        content: Text(
          'This will permanently delete this SMS expense. This action cannot be undone.',
          style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Delete from local database
      final success = await LocalDBService.instance.deleteTransaction(smsExpense.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Expense deleted' : 'Failed to delete expense'),
            backgroundColor: success ? AppTheme.tealAccent : AppTheme.errorColor,
            duration: const Duration(seconds: 2),
          ),
        );

        if (success) {
          _refreshTransactions();
        }
      }
    }
  }

  // Bulk operations
  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedExpenses.clear();
      }
    });
  }

  void _toggleExpenseSelection(String expenseId) {
    setState(() {
      if (_selectedExpenses.contains(expenseId)) {
        _selectedExpenses.remove(expenseId);
      } else {
        _selectedExpenses.add(expenseId);
      }
    });
  }

  void _selectAllExpenses(List<SmsExpenseModel> expenses) {
    setState(() {
      _selectedExpenses.clear();
      _selectedExpenses.addAll(expenses.map((e) => e.id));
    });
  }

  Future<void> _bulkDelete() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        title: Text('Delete ${_selectedExpenses.length} expenses?', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
        content: Text(
          'This will permanently delete ${_selectedExpenses.length} SMS expense${_selectedExpenses.length == 1 ? '' : 's'}. This action cannot be undone.',
          style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Delete from local database
      int successCount = 0;
      for (final expenseId in _selectedExpenses) {
        final success = await LocalDBService.instance.deleteTransaction(expenseId);
        if (success) successCount++;
      }

      setState(() {
        _selectedExpenses.clear();
        _selectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $successCount expense${successCount == 1 ? '' : 's'}'),
            backgroundColor: AppTheme.tealAccent,
            duration: const Duration(seconds: 2),
          ),
        );

        _refreshTransactions();
      }
    }
  }

  Future<void> _bulkConvertToExpenses(List<SmsExpenseModel> allExpenses) async {
    final selectedItems = allExpenses.where((e) => _selectedExpenses.contains(e.id)).toList();

    int successCount = 0;
    for (final smsExpense in selectedItems) {
      // Share with friend/group (converts to expense)
      await _shareWithFriendOrGroup(smsExpense);
      successCount++;
    }

    setState(() {
      _selectedExpenses.clear();
      _selectionMode = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Converted $successCount expense${successCount == 1 ? '' : 's'}'),
          backgroundColor: AppTheme.tealAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Filtering and sorting
  List<SmsExpenseModel> _applyFiltersAndSort(List<SmsExpenseModel> expenses) {
    print('🔍 DEBUG: Total expenses before filter: ${expenses.length}');
    print('🔍 DEBUG: Filter category: $_filterCategory');
    print('🔍 DEBUG: Filter date range: $_filterDateRange');
    print('🔍 DEBUG: Filter min amount: $_filterMinAmount');
    print('🔍 DEBUG: Filter max amount: $_filterMaxAmount');
    print('🔍 DEBUG: Search query: "${_searchQueryNotifier.value}"');

    var filtered = expenses.where((expense) {
      // Category filter
      if (_filterCategory != null && expense.category != _filterCategory) {
        return false;
      }

      // Date range filter
      if (_filterDateRange != null) {
        if (expense.date.isBefore(_filterDateRange!.start) ||
            expense.date.isAfter(_filterDateRange!.end)) {
          return false;
        }
      }

      // Amount filter
      if (_filterMinAmount != null && expense.amount < _filterMinAmount!) {
        return false;
      }
      if (_filterMaxAmount != null && expense.amount > _filterMaxAmount!) {
        return false;
      }

      // Search query
      if (_searchQueryNotifier.value.isNotEmpty) {
        final query = _searchQueryNotifier.value.toLowerCase();
        return expense.merchant.toLowerCase().contains(query) ||
            (expense.accountInfo?.toLowerCase().contains(query) ?? false) ||
            expense.category.toLowerCase().contains(query);
      }

      return true;
    }).toList();

    print('🔍 DEBUG: Filtered expenses count: ${filtered.length}');

    // Sort
    filtered.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'amount':
          comparison = a.amount.compareTo(b.amount);
          break;
        case 'merchant':
          comparison = a.merchant.compareTo(b.merchant);
          break;
        case 'date':
        default:
          comparison = a.date.compareTo(b.date);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  void _showExpenseDetails(SmsExpenseModel smsExpense) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppTheme.tealAccent, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    smsExpense.merchant,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Amount', '$_currencySymbol${smsExpense.amount.toStringAsFixed(2)}'),
            _buildDetailRow('Date', DateFormat('dd MMM yyyy, hh:mm a').format(smsExpense.date)),
            _buildDetailRow('Category', smsExpense.category),
            if (smsExpense.accountInfo != null)
              _buildDetailRow('Account', smsExpense.accountInfo!),
            if (smsExpense.transactionId != null)
              _buildDetailRow('Transaction ID', smsExpense.transactionId!),
            _buildDetailRow('Sender', smsExpense.smsSender),
            const SizedBox(height: 16),
            Text(
              'Original SMS:',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                smsExpense.rawSms,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCategorizationDialog(smsExpense);
                    },
                    icon: const Icon(Icons.category),
                    label: const Text('Categorize'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tealAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _shareWithFriendOrGroup(smsExpense);
                    },
                    icon: const Icon(Icons.group),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.tealAccent,
                      side: const BorderSide(color: AppTheme.tealAccent),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLastScanText() {
    final countText = _transactionCount == 1
        ? '1 transaction'
        : '$_transactionCount transactions';

    if (_lastScanTime == null) {
      return countText;
    }

    final now = DateTime.now();
    final difference = now.difference(_lastScanTime!);

    String scanText;
    if (difference.inMinutes < 1) {
      scanText = 'Last scan: Just now';
    } else if (difference.inMinutes < 60) {
      scanText = 'Last scan: ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      scanText = 'Last scan: ${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      scanText = 'Last scan: Yesterday';
    } else if (difference.inDays < 7) {
      scanText = 'Last scan: ${difference.inDays}d ago';
    } else {
      scanText = 'Last scan: ${DateFormat('MMM dd').format(_lastScanTime!)}';
    }

    return '$scanText • $countText';
  }

  String _getDurationLabel(int days) {
    switch (days) {
      case 7:
        return '1 week';
      case 15:
        return '2 weeks';
      case 30:
        return '1 month';
      case 60:
        return '2 months';
      case 90:
        return '3 months';
      default:
        return '$days days';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SMS Expenses',
              style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 20),
            ),
            Text(
              _getLastScanText(),
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // Processing statistics
          IconButton(
            icon: const Icon(Icons.analytics, color: AppTheme.tealAccent),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/processing_stats',
                arguments: {'source': TransactionSource.sms},
              );
            },
            tooltip: 'Processing Statistics',
          ),
          // Regex patterns viewer
          IconButton(
            icon: const Icon(Icons.code, color: AppTheme.tealAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const _RegexPatternsDialog(),
              );
            },
            tooltip: 'View SMS patterns',
          ),
        ],
      ),
      // PRIVACY-FIRST: Query local SQLite instead of Firestore
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshTransactions();
          // Wait a moment for the refresh to trigger
          await Future.delayed(const Duration(milliseconds: 100));
        },
        color: AppTheme.tealAccent,
        child: FutureBuilder<List<TransactionWithMergeInfo>>(
          key: ValueKey(_refreshKey), // Rebuild on refresh
          future: _loadLocalTransactions(),
          builder: (context, snapshot) {
            // Show error message if there's a last error
            if (_lastError != null) {
              return _buildErrorState(_lastError!);
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.tealAccent),
              );
            }

            if (snapshot.hasError) {
              final errorMsg = _getDetailedErrorMessage(snapshot.error);
              return _buildErrorState(errorMsg);
            }

            final transactionsWithMergeInfo = snapshot.data ?? [];
            print('📊 DEBUG: transactionsWithMergeInfo loaded: ${transactionsWithMergeInfo.length} items');

            // Extract transactions and build merge info map
            final localTransactions = transactionsWithMergeInfo.map((m) => m.transaction).toList();
            print('📊 DEBUG: localTransactions extracted: ${localTransactions.length} items');

            final mergeInfoMap = Map<String, TransactionWithMergeInfo>.fromEntries(
              transactionsWithMergeInfo.map((m) => MapEntry(m.transaction.id, m))
            );

            // Convert to SmsExpenseModel for compatibility with existing UI
            // TODO: Refactor UI to use LocalTransactionModel directly
            final smsExpenses = localTransactions.map((t) => SmsExpenseModel(
              id: t.id,
              userId: t.userId,
              amount: t.amount,
              merchant: t.merchant,
              category: t.category,
              date: t.transactionDate,
              rawSms: t.rawContent ?? '',
              smsSender: t.sourceIdentifier ?? '',
              transactionId: t.transactionId,
              accountInfo: t.accountInfo,
              status: t.status.name,
              parsedAt: t.parsedAt,
              trackerId: t.trackerId, // Include tracker ID for account linking
            )).toList();

            print('💰 DEBUG: smsExpenses created: ${smsExpenses.length} items');
            if (smsExpenses.isNotEmpty) {
              print('💰 DEBUG: First expense - Merchant: ${smsExpenses.first.merchant}, Amount: ${smsExpenses.first.amount}, Category: ${smsExpenses.first.category}');
            }

            // Update transaction count for display in AppBar
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _transactionCount != smsExpenses.length) {
                setState(() {
                  _transactionCount = smsExpenses.length;
                });
              }
            });

            if (smsExpenses.isEmpty) {
              return Column(
                children: [
                // Scan controls even when empty
                Container(
                  color: theme.scaffoldBackgroundColor,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Duration selector
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showDurationPicker,
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text('Scan from last ${_getDurationLabel(_selectedDays)}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.tealAccent,
                            side: const BorderSide(color: AppTheme.tealAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Scan button
                      ElevatedButton.icon(
                        onPressed: _isScanning ? null : _scanSmsMessages,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: const Text('Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.tealAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Fast Mode Toggle (also shown in empty state)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _fastMode
                        ? AppTheme.tealAccent.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _fastMode
                          ? AppTheme.tealAccent.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _fastMode ? Icons.bolt : Icons.auto_awesome,
                        size: 18,
                        color: _fastMode ? AppTheme.tealAccent : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fastMode ? 'Fast Mode (Regex Only)' : 'Accurate Mode (AI Enabled)',
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _fastMode
                                  ? 'Instant • 70% accuracy • Free'
                                  : 'Slower • 95% accuracy • Uses AI credits',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _fastMode,
                        onChanged: (value) {
                          setState(() {
                            _fastMode = value;
                          });
                        },
                        activeColor: AppTheme.tealAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Empty state
                Expanded(
                  child: EmptyStateWidget(
                    icon: Icons.message_outlined,
                    title: 'No SMS Expenses',
                    subtitle: 'Tap the Scan button above to scan your SMS\nfor banking transactions',
                  ),
                ),
                ],
              );
            }

            return Stack(
              children: [
                Column(
                  children: [
                  // Filter and sort bar (static, doesn't rebuild on search)
                  if (!_selectionMode) _buildFilterSortBar(smsExpenses),
                  // Selection mode header
                  if (_selectionMode) _buildSelectionHeader(smsExpenses),
                  // List - wrapped in ValueListenableBuilder to rebuild only this portion
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _searchQueryNotifier,
                      builder: (context, searchQuery, child) {
                        // Apply filters and sorting
                        final filteredExpenses = _applyFiltersAndSort(smsExpenses);

                        // Show empty state if no matches
                        if (filteredExpenses.isEmpty && (
                            _filterCategory != null ||
                            _filterDateRange != null ||
                            _filterMinAmount != null ||
                            _filterMaxAmount != null ||
                            searchQuery.isNotEmpty)) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.filter_alt_off, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text('No expenses match your filters'),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _filterCategory = null;
                                      _filterDateRange = null;
                                      _filterMinAmount = null;
                                      _filterMaxAmount = null;
                                      _searchQueryNotifier.value = '';
                                      _searchController.clear();
                                    });
                                  },
                                  child: const Text('Clear Filters'),
                                ),
                              ],
                            ),
                          );
                        }

                        // Render the list with suggestions
                        return CustomScrollView(
                          slivers: [
                            // Tracker suggestions (if any)
                            if (!_selectionMode)
                              SliverToBoxAdapter(
                                child: TrackerSuggestionsWidget(
                                  onTrackerCreated: _refreshTransactions,
                                ),
                              ),
                            // Transaction list
                            SliverPadding(
                              padding: const EdgeInsets.all(16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final smsExpense = filteredExpenses[index];
                            return _selectionMode
                                ? _buildSelectableCard(smsExpense)
                                : Slidable(
                                    key: ValueKey(smsExpense.id),
                                    endActionPane: ActionPane(
                                      motion: const ScrollMotion(),
                                      children: [
                                        SlidableAction(
                                          onPressed: (_) => _ignoreSmsExpense(smsExpense),
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          icon: Icons.visibility_off,
                                          label: 'Ignore',
                                        ),
                                        SlidableAction(
                                          onPressed: (_) => _deleteSmsExpense(smsExpense),
                                          backgroundColor: AppTheme.errorColor,
                                          foregroundColor: Colors.white,
                                          icon: Icons.delete,
                                          label: 'Delete',
                                        ),
                                      ],
                                    ),
                                    child: _buildSmsExpenseCard(smsExpense),
                                  );
                                  },
                                  childCount: filteredExpenses.length,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  ],
                ),
                // Bulk action bar at bottom
                if (_selectionMode && _selectedExpenses.isNotEmpty)
                  ValueListenableBuilder<String>(
                    valueListenable: _searchQueryNotifier,
                    builder: (context, _, __) {
                      final filteredExpenses = _applyFiltersAndSort(smsExpenses);
                      return Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: _buildBulkActionBar(filteredExpenses),
                      );
                    },
                  ),
              ],
            );
        },
      ),
    ),
  );
  }

  Widget _buildFilterSortBar(List<SmsExpenseModel> expenses) {
    final theme = Theme.of(context);
    final categories = expenses.map((e) => e.category).toSet().toList()..sort();

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Scan controls (Duration + Scan button)
          Row(
            children: [
              // Duration selector
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showDurationPicker,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('Scan from last ${_getDurationLabel(_selectedDays)}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.tealAccent,
                    side: const BorderSide(color: AppTheme.tealAccent),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Scan button
              ElevatedButton.icon(
                onPressed: _isScanning ? null : _scanSmsMessages,
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fast Mode Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _fastMode
                  ? AppTheme.tealAccent.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _fastMode
                    ? AppTheme.tealAccent.withValues(alpha: 0.3)
                    : Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _fastMode ? Icons.bolt : Icons.auto_awesome,
                  size: 18,
                  color: _fastMode ? AppTheme.tealAccent : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fastMode ? 'Fast Mode (Regex Only)' : 'Accurate Mode (AI Enabled)',
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _fastMode
                            ? 'Instant • 70% accuracy • Free'
                            : 'Slower • 95% accuracy • Uses AI credits',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _fastMode,
                  onChanged: (value) {
                    setState(() {
                      _fastMode = value;
                    });
                  },
                  activeColor: AppTheme.tealAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Search bar
          ValueListenableBuilder<String>(
            valueListenable: _searchQueryNotifier,
            builder: (context, searchQuery, child) {
              return TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search merchant, category...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Filter and sort chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Sort button
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(_sortBy == 'date' ? 'Date' : _sortBy == 'amount' ? 'Amount' : 'Merchant'),
                    ],
                  ),
                  selected: true,
                  onSelected: (_) {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: const Text('Sort by Date'),
                              leading: Radio(value: 'date', groupValue: _sortBy, onChanged: (v) {
                                setState(() => _sortBy = v!);
                                Navigator.pop(context);
                              }),
                            ),
                            ListTile(
                              title: const Text('Sort by Amount'),
                              leading: Radio(value: 'amount', groupValue: _sortBy, onChanged: (v) {
                                setState(() => _sortBy = v!);
                                Navigator.pop(context);
                              }),
                            ),
                            ListTile(
                              title: const Text('Sort by Merchant'),
                              leading: Radio(value: 'merchant', groupValue: _sortBy, onChanged: (v) {
                                setState(() => _sortBy = v!);
                                Navigator.pop(context);
                              }),
                            ),
                            SwitchListTile(
                              title: const Text('Ascending'),
                              value: _sortAscending,
                              onChanged: (v) => setState(() => _sortAscending = v),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Category filter
                FilterChip(
                  label: Text(_filterCategory ?? 'Category'),
                  selected: _filterCategory != null,
                  onSelected: (_) {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...categories.map((cat) => ListTile(
                              title: Text(cat),
                              onTap: () {
                                setState(() => _filterCategory = cat);
                                Navigator.pop(context);
                              },
                            )),
                            ListTile(
                              title: const Text('Clear filter'),
                              leading: const Icon(Icons.clear),
                              onTap: () {
                                setState(() => _filterCategory = null);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Selection mode toggle
                FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.checklist, size: 16),
                      const SizedBox(width: 4),
                      Text(_selectionMode ? 'Cancel' : 'Select'),
                    ],
                  ),
                  selected: _selectionMode,
                  onSelected: (_) => _toggleSelectionMode(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(List<SmsExpenseModel> expenses) {
    final theme = Theme.of(context);
    return Container(
      color: AppTheme.tealAccent.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            '${_selectedExpenses.length} selected',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _selectAllExpenses(expenses),
            child: const Text('Select All'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableCard(SmsExpenseModel smsExpense) {
    final isSelected = _selectedExpenses.contains(smsExpense.id);
    return InkWell(
      onTap: () => _toggleExpenseSelection(smsExpense.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: isSelected ? AppTheme.tealAccent.withValues(alpha: 0.2) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleExpenseSelection(smsExpense.id),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      smsExpense.merchant,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy').format(smsExpense.date),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                '$_currencySymbol${smsExpense.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.tealAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionBar(List<SmsExpenseModel> expenses) {
    final theme = Theme.of(context);
    return Card(
      elevation: 8,
      color: theme.cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _bulkConvertToExpenses(expenses),
                icon: const Icon(Icons.sync_alt, size: 18),
                label: const Text('Convert'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _bulkDelete,
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsExpenseCard(SmsExpenseModel smsExpense) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showExpenseDetails(smsExpense),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.tealAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: AppTheme.tealAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          smsExpense.merchant,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(smsExpense.date),
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$_currencySymbol${smsExpense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppTheme.tealAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(smsExpense.category, Icons.category),
                  if (smsExpense.accountInfo != null)
                    _buildChip(smsExpense.accountInfo!, Icons.credit_card),
                  if (smsExpense.trackerId != null)
                    FutureBuilder<AccountTrackerModel?>(
                      future: _loadTracker(smsExpense.trackerId!),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          final tracker = snapshot.data!;
                          return _buildTrackerChip(tracker);
                        }
                        return const SizedBox.shrink();
                      },
                    )
                  else
                    // Show unknown badge when no tracker assigned
                    _buildUnknownTrackerChip(smsExpense),
                ],
              ),
              const SizedBox(height: 12),
              // Categorize button (new unified approach)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCategorizationDialog(smsExpense),
                      icon: const Icon(Icons.category, size: 18),
                      label: const Text('Categorize'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.tealAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareWithFriendOrGroup(smsExpense),
                      icon: const Icon(Icons.group, size: 18),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.textTheme.bodyLarge?.color,
                        side: const BorderSide(color: AppTheme.dividerColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
          Text(
            label,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Load tracker information for an SMS expense
  Future<AccountTrackerModel?> _loadTracker(String trackerId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    try {
      return await AccountTrackerService.getTracker(currentUser.uid, trackerId);
    } catch (e) {
      return null;
    }
  }

  /// Build tracker chip widget
  Widget _buildTrackerChip(AccountTrackerModel tracker) {
    final theme = Theme.of(context);
    final color = Color(int.parse('0xFF${tracker.colorHex}'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            tracker.name,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build unknown tracker chip with tap to create
  Widget _buildUnknownTrackerChip(SmsExpenseModel smsExpense) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _showCreateTrackerFromSms(smsExpense),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('❓', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              'Unknown - Tap to add',
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to create tracker from SMS expense
  void _showCreateTrackerFromSms(SmsExpenseModel smsExpense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateTrackerFromSmsSheet(
        userId: smsExpense.userId,
        smsExpense: smsExpense,
        onTrackerCreated: () {
          // Refresh the list to show the updated tracker badges
          _refreshTransactions();
        },
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    final theme = Theme.of(context);
    final isPermissionError = _permissionDenied;
    final isIOSError = errorMessage.contains('iOS') || errorMessage.contains('platform restrictions');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isIOSError ? Icons.phone_iphone :
              isPermissionError ? Icons.security :
              Icons.error_outline,
              size: 80,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 24),
            Text(
              isIOSError ? 'Platform Not Supported' :
              isPermissionError ? 'Permission Required' :
              'Error',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (isIOSError)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why SMS scanning doesn\'t work on iOS:',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• iOS restricts SMS access for privacy\n'
                      '• Only user-initiated actions allowed\n'
                      '• No background SMS scanning\n'
                      '• Manual expense entry only',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              )
            else if (isPermissionError)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _lastError = null;
                    _permissionDenied = false;
                  });
                  _scanSmsMessages();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Request Permission Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                  foregroundColor: theme.textTheme.bodyLarge?.color,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _lastError = null;
                  });
                },
                icon: const Icon(Icons.close),
                label: const Text('Dismiss'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Progress Dialog for SMS Scanning
class _ScanProgressDialog extends StatefulWidget {
  final Future<int> Function(
    void Function(SmsScanProgress progress) updateProgress,
    bool Function() shouldCancel,
  ) onScan;

  const _ScanProgressDialog({required this.onScan});

  @override
  State<_ScanProgressDialog> createState() => _ScanProgressDialogState();
}

class _ScanProgressDialogState extends State<_ScanProgressDialog> {
  SmsScanProgress _progress = SmsScanProgress();
  bool _isComplete = false;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  bool _shouldCancel() => _isCancelled;

  void _handleCancel() {
    setState(() {
      _isCancelled = true;
    });
  }

  void _startScan() async {
    try {
      final count = await widget.onScan(
        (progress) {
          if (mounted && !_isCancelled) {
            setState(() {
              _progress = progress;
            });
          }
        },
        _shouldCancel,
      );

      if (mounted) {
        if (_isCancelled) {
          Navigator.pop(context, null);
        } else {
          setState(() {
            _isComplete = true;
          });
          // Auto-close after 1 second
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.pop(context, count);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressValue = _progress.progressPercentage;

    return AlertDialog(
      backgroundColor: theme.cardTheme.color,
      title: Row(
        children: [
          if (!_isComplete && !_isCancelled)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.tealAccent),
              ),
            )
          else if (_isComplete)
            const Icon(Icons.check_circle, color: AppTheme.tealAccent, size: 24)
          else
            const Icon(Icons.cancel, color: AppTheme.errorColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isCancelled
                  ? 'Cancelling...'
                  : _isComplete
                      ? 'Scan Complete'
                      : 'Scanning SMS...',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: progressValue,
            backgroundColor: theme.dividerTheme.color,
            valueColor: AlwaysStoppedAnimation<Color>(
              _isCancelled ? AppTheme.errorColor : AppTheme.tealAccent,
            ),
          ),
          const SizedBox(height: 16),
          // Enhanced Stats
          if (_progress.totalMessages > 0) ...[
            // Total Messages
            _buildStatRow(
              theme,
              icon: Icons.message,
              label: 'Total Messages',
              value: '${_progress.totalMessages}',
              color: theme.textTheme.bodyMedium?.color,
            ),
            const SizedBox(height: 8),

            // Bank SMS (filtered)
            if (_progress.filteredBankSms > 0) ...[
              _buildStatRow(
                theme,
                icon: Icons.account_balance,
                label: '├─ Bank SMS',
                value: '${_progress.filteredBankSms}',
                color: Colors.blue,
                indent: true,
              ),
              const SizedBox(height: 6),
            ],

            // Already Processed
            if (_progress.alreadyProcessed > 0) ...[
              _buildStatRow(
                theme,
                icon: Icons.check_circle_outline,
                label: '├─ Already Processed',
                value: '${_progress.alreadyProcessed}',
                color: Colors.grey,
                indent: true,
              ),
              const SizedBox(height: 6),
            ],

            // New to Analyze
            if (_progress.newToAnalyze > 0) ...[
              _buildStatRow(
                theme,
                icon: Icons.analytics,
                label: '├─ New to Analyze',
                value: '${_progress.newToAnalyze}',
                color: AppTheme.tealAccent,
                indent: true,
              ),
              const SizedBox(height: 6),
            ],

            // Regex Matched
            if (_progress.regexMatched > 0) ...[
              _buildStatRow(
                theme,
                icon: Icons.bolt,
                label: '   ├─ Regex Matched',
                value: '${_progress.regexMatched} ✅',
                color: AppTheme.tealAccent,
                indent: true,
              ),
              const SizedBox(height: 6),
            ],

            // Processed by AI
            if (_progress.aiProcessed > 0) ...[
              _buildStatRow(
                theme,
                icon: Icons.auto_awesome,
                label: '   └─ AI Processed',
                value: '${_progress.aiProcessed} 🤖',
                color: Colors.orange,
                indent: true,
              ),
              const SizedBox(height: 8),
            ],

            const Divider(),
            const SizedBox(height: 8),

            // Transactions Found (highlighted)
            _buildStatRow(
              theme,
              icon: Icons.paid,
              label: 'Transactions Found',
              value: '${_progress.foundTransactions}',
              color: AppTheme.tealAccent,
              bold: true,
            ),
          ] else
            Text(
              'Loading messages...',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
        ],
      ),
      actions: [
        if (!_isComplete && !_isCancelled)
          TextButton(
            onPressed: _handleCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
      ],
    );
  }

  Widget _buildStatRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    Color? color,
    bool indent = false,
    bool bold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? theme.textTheme.bodyMedium?.color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color ?? theme.textTheme.bodyMedium?.color,
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? theme.textTheme.bodyMedium?.color,
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Dialog to display regex patterns used for SMS parsing
class _RegexPatternsDialog extends StatefulWidget {
  const _RegexPatternsDialog();

  @override
  State<_RegexPatternsDialog> createState() => _RegexPatternsDialogState();
}

class _RegexPatternsDialogState extends State<_RegexPatternsDialog> {
  // Example strings for each pattern category
  static const Map<String, List<String>> patternExamples = {
    'debit': [
      'debited by INR 1,234.56',
      'withdrawn Rs 500.00',
      'debited with 2500',
      'spent Rs 1500.50',
    ],
    'credit': [
      'credited with INR 5,000.00',
      'deposited Rs 10000',
      'received INR 3500.75',
    ],
    'salary': [
      'salary credited INR 50,000.00',
      'sal credited with Rs 45000',
      'credited with INR 60000.00 Info: SALARY',
    ],
    'balance': [
      'Available balance: INR 12,345.67',
      'Avl bal: Rs 5000.50',
      'balance is Rs 8500',
    ],
    'creditCardPayment': [
      'payment of Rs 5,000.00 received',
      'bill payment of INR 3500.00',
      'payment of Rs 1500 is received',
    ],
  };

  // Store hit counts for all patterns
  Map<String, Map<int, int>> _hitCounts = {};
  bool _isLoadingHitCounts = true;

  @override
  void initState() {
    super.initState();
    _loadHitCounts();
  }

  Future<void> _loadHitCounts() async {
    final patterns = SmsParserService.transactionPatterns;
    final Map<String, Map<int, int>> counts = {};

    for (final entry in patterns.entries) {
      final categoryName = entry.key;
      final patternCount = entry.value.length;
      counts[categoryName] = await RegexPatternTracker.getCategoryHitCounts(categoryName, patternCount);
    }

    if (mounted) {
      setState(() {
        _hitCounts = counts;
        _isLoadingHitCounts = false;
      });
    }
  }

  Future<void> _resetHitCounts() async {
    await RegexPatternTracker.resetAllCounts();
    await _loadHitCounts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hit counts reset successfully'),
          backgroundColor: AppTheme.tealAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final patterns = SmsParserService.transactionPatterns;

    return AlertDialog(
      backgroundColor: theme.cardTheme.color,
      title: Row(
        children: [
          const Icon(Icons.code, color: AppTheme.tealAccent),
          const SizedBox(width: 12),
          Text(
            'SMS Regex Patterns',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Regular expressions used to detect transactions in SMS messages:',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ...patterns.entries.map((entry) {
                final categoryName = entry.key;
                final regexList = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.tealAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          categoryName.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.tealAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Regex patterns
                      ...regexList.asMap().entries.map((patternEntry) {
                        final index = patternEntry.key;
                        final regex = patternEntry.value;
                        final examples = patternExamples[categoryName] ?? [];
                        final example = index < examples.length ? examples[index] : null;
                        final hitCount = _hitCounts[categoryName]?[index] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Pattern header with hit count and copy button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Pattern ${index + 1}',
                                          style: TextStyle(
                                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Hit count badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: hitCount > 0
                                                ? AppTheme.tealAccent.withValues(alpha: 0.2)
                                                : Colors.grey.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 10,
                                                color: hitCount > 0 ? AppTheme.tealAccent : Colors.grey,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '$hitCount ${hitCount == 1 ? 'hit' : 'hits'}',
                                                style: TextStyle(
                                                  color: hitCount > 0 ? AppTheme.tealAccent : Colors.grey,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    InkWell(
                                      onTap: () {
                                        // Copy to clipboard
                                        final data = ClipboardData(text: regex.pattern);
                                        Clipboard.setData(data);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Pattern copied to clipboard'),
                                            duration: Duration(seconds: 1),
                                            backgroundColor: AppTheme.tealAccent,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.tealAccent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.copy, size: 12, color: AppTheme.tealAccent),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Copy',
                                              style: TextStyle(
                                                color: AppTheme.tealAccent,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Regex pattern
                                SelectableText(
                                  regex.pattern,
                                  style: TextStyle(
                                    color: theme.textTheme.bodyLarge?.color,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                // Case sensitivity info
                                if (!regex.isCaseSensitive) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Case insensitive',
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                // Example
                                if (example != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.tealAccent.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppTheme.tealAccent.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Example:',
                                          style: TextStyle(
                                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          example,
                                          style: TextStyle(
                                            color: theme.textTheme.bodyLarge?.color,
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
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
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        // Reset Hit Counts button
        TextButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: theme.cardTheme.color,
                title: Text('Reset Hit Counts?', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                content: Text(
                  'This will reset all pattern usage statistics to zero. The patterns themselves will not be affected.',
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _resetHitCounts();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                    ),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reset Counts'),
        ),
        // AI Pattern Generator button
        TextButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const _AiPatternGeneratorDialog(),
            );
          },
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: const Text('AI Generator'),
        ),
        const Spacer(),
        // Close button
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// AI Pattern Generator Dialog
class _AiPatternGeneratorDialog extends StatefulWidget {
  const _AiPatternGeneratorDialog();

  @override
  State<_AiPatternGeneratorDialog> createState() => _AiPatternGeneratorDialogState();
}

class _AiPatternGeneratorDialogState extends State<_AiPatternGeneratorDialog> {
  final _smsController = TextEditingController();
  final _patternController = TextEditingController();
  bool _isAnalyzing = false;
  bool _hasGeneratedPattern = false;
  String? _errorMessage;

  @override
  void dispose() {
    _smsController.dispose();
    _patternController.dispose();
    super.dispose();
  }

  Future<void> _analyzeWithAI() async {
    final smsText = _smsController.text.trim();

    if (smsText.isEmpty) {
      setState(() {
        _errorMessage = 'Please paste an SMS message first';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      // TODO: Integrate with AI service (Gemini, OpenAI, etc.)
      // For now, show a placeholder message
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isAnalyzing = false;
        _hasGeneratedPattern = true;
        _errorMessage = 'AI integration coming soon! For now, manually create your regex pattern below.';
        _patternController.text = r'debited\s+by\s+Rs\.?\s*(\d+(?:,\d+)*(?:\.\d{2})?)';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI pattern generation feature is under development'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Error analyzing SMS: $e';
      });
    }
  }

  Future<void> _addPattern() async {
    final pattern = _patternController.text.trim();

    if (pattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a regex pattern'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Validate regex pattern
    try {
      RegExp(pattern);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid regex pattern: $e'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // TODO: Add pattern to custom patterns collection
    // This requires implementing a custom pattern storage system
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom pattern storage feature coming soon!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.cardTheme.color,
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.tealAccent),
          const SizedBox(width: 12),
          Text(
            'AI Pattern Generator',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paste an SMS message below and let AI generate a regex pattern to match similar messages:',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),

              // SMS Input Field
              TextField(
                controller: _smsController,
                decoration: InputDecoration(
                  labelText: 'SMS Message',
                  hintText: 'Paste your SMS message here...',
                  prefixIcon: const Icon(Icons.message),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                ),
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                maxLines: 4,
              ),
              const SizedBox(height: 12),

              // Analyze Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _analyzeWithAI,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_isAnalyzing ? 'Analyzing...' : 'Generate Pattern with AI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tealAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              // Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Generated Pattern Section
              if (_hasGeneratedPattern) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Generated Regex Pattern:',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _patternController,
                  decoration: InputDecoration(
                    labelText: 'Regex Pattern',
                    hintText: 'Edit the generated pattern if needed...',
                    prefixIcon: const Icon(Icons.code),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                  ),
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Text(
                  'You can edit the pattern above before adding it to your collection.',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_hasGeneratedPattern)
          ElevatedButton.icon(
            onPressed: _addPattern,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Pattern'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.tealAccent,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }
}

/// Bottom sheet for creating a tracker from SMS expense
class _CreateTrackerFromSmsSheet extends StatefulWidget {
  final String userId;
  final SmsExpenseModel smsExpense;
  final VoidCallback onTrackerCreated;

  const _CreateTrackerFromSmsSheet({
    required this.userId,
    required this.smsExpense,
    required this.onTrackerCreated,
  });

  @override
  State<_CreateTrackerFromSmsSheet> createState() => _CreateTrackerFromSmsSheetState();
}

class _CreateTrackerFromSmsSheetState extends State<_CreateTrackerFromSmsSheet> {
  TrackerCategory? _selectedCategory;
  AccountTrackerModel? _selectedExistingTracker;
  bool _isCreating = false;
  bool _showCreateNew = false;
  List<AccountTrackerModel> _existingTrackers = [];

  @override
  void initState() {
    super.initState();
    _loadExistingTrackers();
    // Try to detect category from SMS sender
    _selectedCategory = _detectCategory();
  }

  Future<void> _loadExistingTrackers() async {
    final trackers = await AccountTrackerService.getActiveTrackers(widget.userId);
    setState(() {
      _existingTrackers = trackers;
    });
  }

  TrackerCategory? _detectCategory() {
    final matches = TrackerRegistry.findMatchingCategoriesForSms(
      widget.smsExpense.smsSender,
    );
    return matches.isNotEmpty ? matches.first : null;
  }

  Future<void> _addToExistingTracker() async {
    if (_selectedExistingTracker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a tracker'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final tracker = _selectedExistingTracker!;

      // Add SMS sender to tracker's smsSenders list if not already there
      final updatedSenders = List<String>.from(tracker.smsSenders);
      if (!updatedSenders.contains(widget.smsExpense.smsSender)) {
        updatedSenders.add(widget.smsExpense.smsSender);
      }

      final updatedTracker = tracker.copyWith(
        smsSenders: updatedSenders,
        updatedAt: DateTime.now(),
      );

      // Update tracker in Firestore
      final success = await AccountTrackerService.updateTracker(updatedTracker);

      if (!success) {
        throw Exception('Failed to update tracker');
      }

      // Link ALL SMS transactions from this sender to the tracker (retroactive)
      // Privacy-first: Update local SQLite database
      final allSmsTransactions = await LocalDBService.instance.getTransactions(
        userId: widget.userId,
        source: TransactionSource.sms,
      );

      // Filter by source identifier (SMS sender)
      final matchingTransactions = allSmsTransactions
          .where((t) => t.sourceIdentifier == widget.smsExpense.smsSender)
          .toList();

      int linkedCount = 0;
      for (final transaction in matchingTransactions) {
        final updated = transaction.copyWith(
          trackerId: tracker.id,
          trackerConfidence: 0.95, // High confidence for manual linking
        );
        await LocalDBService.instance.updateTransaction(updated);
        linkedCount++;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added sender to "${tracker.name}" and linked $linkedCount transactions'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onTrackerCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _createNewTracker() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an account type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Create tracker from template
      final tracker = await AccountTrackerService.addTrackerFromTemplate(
        userId: widget.userId,
        category: _selectedCategory!,
      );

      if (tracker == null) {
        throw Exception('Failed to create tracker');
      }

      // Add this SMS sender to the tracker's smsSenders list
      final updatedSenders = List<String>.from(tracker.smsSenders);
      if (!updatedSenders.contains(widget.smsExpense.smsSender)) {
        updatedSenders.add(widget.smsExpense.smsSender);

        final updatedTracker = tracker.copyWith(
          smsSenders: updatedSenders,
          updatedAt: DateTime.now(),
        );

        await AccountTrackerService.updateTracker(updatedTracker);
      }

      // Link ALL SMS transactions from this sender to the tracker (retroactive)
      // Privacy-first: Update local SQLite database
      final allSmsTransactions = await LocalDBService.instance.getTransactions(
        userId: widget.userId,
        source: TransactionSource.sms,
      );

      // Filter by source identifier (SMS sender)
      final matchingTransactions = allSmsTransactions
          .where((t) => t.sourceIdentifier == widget.smsExpense.smsSender)
          .toList();

      int linkedCount = 0;
      for (final transaction in matchingTransactions) {
        final updated = transaction.copyWith(
          trackerId: tracker.id,
          trackerConfidence: 0.95, // High confidence for manual linking
        );
        await LocalDBService.instance.updateTransaction(updated);
        linkedCount++;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created "${tracker.name}" and linked $linkedCount transactions'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onTrackerCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              if (_showCreateNew)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _showCreateNew = false),
                ),
              Expanded(
                child: Text(
                  _showCreateNew ? 'Create New Tracker' : 'Link to Account',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Transaction info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMS from:',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.smsExpense.smsSender,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Transaction: ${widget.smsExpense.merchant}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (!_showCreateNew) ..._buildExistingTrackersList(theme)
          else ..._buildCreateNewTrackerView(theme),

          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  List<Widget> _buildExistingTrackersList(ThemeData theme) {
    return [
      Text(
        'Add sender to existing tracker:',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        ),
      ),

      const SizedBox(height: 12),

      // Existing trackers list
      if (_existingTrackers.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('No existing trackers found'),
          ),
        )
      else
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _existingTrackers.length,
            itemBuilder: (context, index) {
              final tracker = _existingTrackers[index];
              final isSelected = _selectedExistingTracker?.id == tracker.id;
              final color = Color(int.parse('0xFF${tracker.colorHex}'));

              return InkWell(
                onTap: () => setState(() => _selectedExistingTracker = tracker),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.2)
                        : theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(tracker.emoji ?? '💳', style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tracker.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (tracker.accountNumber != null)
                              Text(
                                'A/c: ${tracker.accountNumber}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: color, size: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

      const SizedBox(height: 16),

      // Action buttons
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showCreateNew = true),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create New'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.textTheme.bodyLarge?.color,
                side: BorderSide(color: AppTheme.dividerColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isCreating || _selectedExistingTracker == null ? null : _addToExistingTracker,
              icon: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link, size: 18),
              label: Text(_isCreating ? 'Adding...' : 'Add to Tracker'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedExistingTracker != null
                    ? Color(int.parse('0xFF${_selectedExistingTracker!.colorHex}'))
                    : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildCreateNewTrackerView(ThemeData theme) {
    final availableTemplates = TrackerRegistry.templates.values.toList();

    return [
      Text(
        'Select account type:',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        ),
      ),

      const SizedBox(height: 12),

      // Template grid
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: availableTemplates.length,
          itemBuilder: (context, index) {
            final template = availableTemplates[index];
            final isSelected = _selectedCategory == template.category;

            return InkWell(
              onTap: () => setState(() => _selectedCategory = template.category),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? template.color.withValues(alpha: 0.2)
                      : theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? template.color
                        : theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      template.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        template.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      const SizedBox(height: 20),

      // Create button
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isCreating ? null : _createNewTracker,
          icon: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add),
          label: Text(_isCreating ? 'Creating...' : 'Create Tracker'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedCategory != null
                ? TrackerRegistry.getTemplate(_selectedCategory!)?.color
                : Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    ];
  }
}

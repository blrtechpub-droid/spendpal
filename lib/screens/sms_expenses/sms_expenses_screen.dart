import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:spendpal/models/sms_expense_model.dart';
import 'package:spendpal/services/sms_expense_service.dart';
import 'package:spendpal/services/sms_listener_service.dart';
import 'package:spendpal/services/currency_service.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/widgets/empty_state_widget.dart';

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

  final List<int> _durationOptions = [7, 15, 30, 60, 90];

  @override
  void initState() {
    super.initState();
    _loadCurrencySymbol();
    _checkPlatformSupport();
    _loadLastScanTime();
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

      final count = await SmsListenerService.processRecentMessages(days: _selectedDays);

      // Reload last scan time
      await _loadLastScanTime();

      setState(() {
        _lastError = null;
        _permissionDenied = false;
      });

      if (mounted) {
        final daysText = _selectedDays == 7 ? '7 days' :
                         _selectedDays == 15 ? '15 days' :
                         _selectedDays == 30 ? '1 month' :
                         _selectedDays == 60 ? '2 months' :
                         _selectedDays == 90 ? '3 months' : '$_selectedDays days';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found $count transaction${count == 1 ? '' : 's'} from last $daysText'),
            backgroundColor: count > 0 ? AppTheme.tealAccent : AppTheme.secondaryText,
            duration: const Duration(seconds: 3),
          ),
        );
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

  Future<void> _categorizeAsPersonal(SmsExpenseModel smsExpense) async {
    try {
      final expenseId = await SmsExpenseService.categorizeAsPersonal(smsExpense);

      if (mounted) {
        if (expenseId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to personal expenses'),
              backgroundColor: AppTheme.tealAccent,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add expense'),
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

  Future<void> _categorizeAsSalary(SmsExpenseModel smsExpense) async {
    try {
      final salaryId = await SmsExpenseService.categorizeAsSalary(smsExpense);

      if (mounted) {
        if (salaryId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to salary records'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add salary'),
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

  Future<void> _ignoreSmsExpense(SmsExpenseModel smsExpense) async {
    final success = await SmsExpenseService.ignoreSmsExpense(smsExpense.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Expense ignored' : 'Failed to ignore expense'),
          backgroundColor: success ? AppTheme.tealAccent : AppTheme.errorColor,
          duration: const Duration(seconds: 2),
        ),
      );
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
      final success = await SmsExpenseService.deleteSmsExpense(smsExpense.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Expense deleted' : 'Failed to delete expense'),
            backgroundColor: success ? AppTheme.tealAccent : AppTheme.errorColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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
            // Show Salary button in modal for credit transactions
            smsExpense.isCredit
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _categorizeAsPersonal(smsExpense);
                              },
                              icon: const Icon(Icons.person, size: 18),
                              label: const Text('Personal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.tealAccent,
                                foregroundColor: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _categorizeAsSalary(smsExpense);
                              },
                              icon: const Icon(Icons.account_balance_wallet, size: 18),
                              label: const Text('Salary'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _shareWithFriendOrGroup(smsExpense);
                          },
                          icon: const Icon(Icons.group),
                          label: const Text('Share with Friends/Group'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.cardTheme.color,
                            foregroundColor: AppTheme.tealAccent,
                            side: const BorderSide(color: AppTheme.tealAccent),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _categorizeAsPersonal(smsExpense);
                          },
                          icon: const Icon(Icons.person),
                          label: const Text('Personal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.tealAccent,
                            foregroundColor: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _shareWithFriendOrGroup(smsExpense);
                          },
                          icon: const Icon(Icons.group),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.cardTheme.color,
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
    if (_lastScanTime == null) {
      return 'Never scanned';
    }

    final now = DateTime.now();
    final difference = now.difference(_lastScanTime!);

    if (difference.inMinutes < 1) {
      return 'Last scan: Just now';
    } else if (difference.inMinutes < 60) {
      return 'Last scan: ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Last scan: ${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Last scan: Yesterday';
    } else if (difference.inDays < 7) {
      return 'Last scan: ${difference.inDays}d ago';
    } else {
      return 'Last scan: ${DateFormat('MMM dd').format(_lastScanTime!)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final durationLabel = _selectedDays == 7 ? '1 week' :
                          _selectedDays == 15 ? '2 weeks' :
                          _selectedDays == 30 ? '1 month' :
                          _selectedDays == 60 ? '2 months' :
                          _selectedDays == 90 ? '3 months' : '$_selectedDays days';

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
          // Duration selector button
          TextButton.icon(
            onPressed: _showDurationPicker,
            icon: const Icon(Icons.calendar_today, size: 18, color: AppTheme.tealAccent),
            label: Text(
              durationLabel,
              style: const TextStyle(color: AppTheme.tealAccent, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          // Scan/Refresh button
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.tealAccent),
                    ),
                  )
                : const Icon(Icons.refresh, color: AppTheme.tealAccent),
            onPressed: _isScanning ? null : _scanSmsMessages,
            tooltip: 'Scan SMS from last $durationLabel',
          ),
        ],
      ),
      body: StreamBuilder<List<SmsExpenseModel>>(
        stream: SmsExpenseService.getPendingSmsExpenses(),
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

          final smsExpenses = snapshot.data ?? [];

          if (smsExpenses.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.message_outlined,
              title: 'No SMS Expenses',
              subtitle: 'Tap the refresh icon to scan your SMS\nfor banking transactions from last 30 days',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: smsExpenses.length,
            itemBuilder: (context, index) {
              final smsExpense = smsExpenses[index];
              return Slidable(
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
          );
        },
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
              Row(
                children: [
                  _buildChip(smsExpense.category, Icons.category),
                  if (smsExpense.accountInfo != null) ...[
                    const SizedBox(width: 8),
                    _buildChip(smsExpense.accountInfo!, Icons.credit_card),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Show Salary button only for credit transactions
              smsExpense.isCredit
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _categorizeAsPersonal(smsExpense),
                            icon: const Icon(Icons.person, size: 14),
                            label: const Text('Personal', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.tealAccent,
                              side: const BorderSide(color: AppTheme.tealAccent),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _categorizeAsSalary(smsExpense),
                            icon: const Icon(Icons.account_balance_wallet, size: 14),
                            label: const Text('Salary', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _shareWithFriendOrGroup(smsExpense),
                            icon: const Icon(Icons.group, size: 14),
                            label: const Text('Share', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.textTheme.bodyLarge?.color,
                              side: const BorderSide(color: AppTheme.dividerColor),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _categorizeAsPersonal(smsExpense),
                            icon: const Icon(Icons.person, size: 16),
                            label: const Text('Personal'),
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
                            onPressed: () => _shareWithFriendOrGroup(smsExpense),
                            icon: const Icon(Icons.group, size: 16),
                            label: const Text('Share'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.textTheme.bodyLarge?.color,
                              side: const BorderSide(color: AppTheme.dividerColor),
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

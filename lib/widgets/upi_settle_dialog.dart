import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:upi_india/upi_india.dart'; // Temporarily disabled
import 'package:spendpal/models/simplified_debt_model.dart';
import 'package:spendpal/models/user_model.dart';
import 'package:spendpal/services/upi_payment_service.dart';
import 'package:spendpal/services/debt_simplification_service.dart';

/// Enhanced settle dialog with UPI payment integration
class UpiSettleDialog extends StatefulWidget {
  final SimplifiedDebt debt;
  final VoidCallback onSettled;

  const UpiSettleDialog({
    super.key,
    required this.debt,
    required this.onSettled,
  });

  @override
  State<UpiSettleDialog> createState() => _UpiSettleDialogState();
}

class _UpiSettleDialogState extends State<UpiSettleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _upiIdController = TextEditingController();
  final UpiPaymentService _upiService = UpiPaymentService();
  final DebtSimplificationService _debtService = DebtSimplificationService();

  String _paymentMethod = 'upi';
  bool _isProcessing = false;
  String? _receiverUpiId;
  List<UpiApp> _upiApps = [];

  @override
  void initState() {
    super.initState();
    print('DEBUG UpiSettleDialog: Debt received:');
    print('  fromUserId: ${widget.debt.fromUserId}');
    print('  fromUserName: ${widget.debt.fromUserName}');
    print('  toUserId: ${widget.debt.toUserId}');
    print('  toUserName: ${widget.debt.toUserName}');
    print('  amount: ${widget.debt.amount}');
    print('  groupId: ${widget.debt.groupId}');
    _amountController.text = widget.debt.amount.toStringAsFixed(2);
    _loadReceiverUpiId();
    _loadUpiApps();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _loadReceiverUpiId() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.debt.toUserId)
          .get();

      if (userDoc.exists) {
        final user = UserModel.fromFirestore(userDoc);
        setState(() {
          _receiverUpiId = user.upiId;
          if (_receiverUpiId != null) {
            _upiIdController.text = _receiverUpiId!;
          }
        });
      }
    } catch (e) {
      print('Error loading receiver UPI ID: $e');
    }
  }

  Future<void> _loadUpiApps() async {
    final apps = await _upiService.getAvailableUpiApps();
    setState(() {
      _upiApps = apps;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.payment, color: Colors.teal),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Settle Up'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Receiver info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.teal.withValues(alpha: 0.15) : Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.teal.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Text(
                        widget.debt.toUserName.isNotEmpty
                            ? widget.debt.toUserName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paying to',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.debt.toUserName.isNotEmpty
                                ? widget.debt.toUserName
                                : 'Unknown User',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.currency_rupee, color: Colors.teal),
                  hintText: 'Enter amount',
                  hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Payment method selector
              Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'upi',
                      label: Text('UPI', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.account_balance_wallet, size: 18),
                    ),
                    ButtonSegment(
                      value: 'cash',
                      label: Text('Cash', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.money, size: 18),
                    ),
                    ButtonSegment(
                      value: 'other',
                      label: Text('Other', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.more_horiz, size: 18),
                    ),
                  ],
                  selected: {_paymentMethod},
                  onSelectionChanged: (Set<String> selected) {
                    setState(() {
                      _paymentMethod = selected.first;
                    });
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // UPI ID field (only shown for UPI payment)
              if (_paymentMethod == 'upi') ...[
                TextFormField(
                  controller: _upiIdController,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Receiver UPI ID',
                    labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.teal, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.alternate_email, color: Colors.teal),
                    hintText: 'user@paytm',
                    hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                    suffixIcon: _receiverUpiId != null
                        ? const Icon(Icons.verified, color: Colors.green)
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (value) {
                    if (_paymentMethod == 'upi') {
                      if (value == null || value.isEmpty) {
                        return 'Please enter UPI ID';
                      }
                      if (!_upiService.isValidUpiId(value)) {
                        return 'Invalid UPI ID format';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                if (_receiverUpiId == null)
                  Text(
                    'Receiver hasn\'t set up UPI ID. Enter manually.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              // Notes field
              TextFormField(
                controller: _notesController,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.note, color: Colors.teal),
                  hintText: 'Add a note',
                  hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _handleSettlement,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(_paymentMethod == 'upi' ? 'Pay with UPI' : 'Record Payment'),
        ),
      ],
    );
  }

  Future<void> _handleSettlement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.parse(_amountController.text);

    setState(() => _isProcessing = true);

    try {
      if (_paymentMethod == 'upi') {
        await _processUpiPayment(amount);
      } else {
        await _recordNonUpiSettlement(amount);
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
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processUpiPayment(double amount) async {
    if (_upiApps.isEmpty) {
      throw Exception('No UPI apps found. Please install a UPI app like Google Pay or PhonePe.');
    }

    final receiverUpiId = _upiIdController.text.trim();

    // Show UPI app picker
    final selectedApp = await _upiService.showUpiAppPicker(context, _upiApps);
    if (selectedApp == null) {
      throw Exception('No UPI app selected');
    }

    // Initiate UPI payment
    final transactionRef = _upiService.generateTransactionRef();
    final response = await _upiService.initiatePayment(
      receiverUpiId: receiverUpiId,
      receiverName: widget.debt.toUserName,
      amount: amount,
      transactionNote: 'SpendPal settlement: ${widget.debt.groupName ?? "Personal"}',
      app: selectedApp,
      transactionRefId: transactionRef,
    );

    if (response == null) {
      throw Exception('UPI payment failed. Please try again.');
    }

    final result = UpiPaymentResult.fromUpiResponse(response);

    if (result.isSuccess) {
      // Record successful settlement
      await _debtService.recordSettlement(
        toUserId: widget.debt.toUserId,
        toUserName: widget.debt.toUserName,
        amount: amount,
        groupId: widget.debt.groupId,
        groupName: widget.debt.groupName,
        paymentMethod: 'upi',
        transactionId: result.transactionId,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('₹$amount paid successfully via UPI!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSettled();
      }
    } else {
      throw Exception(result.message);
    }
  }

  Future<void> _recordNonUpiSettlement(double amount) async {
    await _debtService.recordSettlement(
      toUserId: widget.debt.toUserId,
      toUserName: widget.debt.toUserName,
      amount: amount,
      groupId: widget.debt.groupId,
      groupName: widget.debt.groupName,
      paymentMethod: _paymentMethod,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('₹$amount settlement recorded!'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSettled();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/models/money_tracker_model.dart';
import 'package:spendpal/theme/app_theme.dart';

class AddCreditCardScreen extends StatefulWidget {
  final MoneyTrackerAccount? account;
  final String? accountId;

  const AddCreditCardScreen({
    super.key,
    this.account,
    this.accountId,
  });

  @override
  State<AddCreditCardScreen> createState() => _AddCreditCardScreenState();
}

class _AddCreditCardScreenState extends State<AddCreditCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNameController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _currentSpendController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _cardNameController.text = widget.account!.accountName;
      _creditLimitController.text = (widget.account!.creditLimit ?? 0).toStringAsFixed(2);
      _currentSpendController.text = widget.account!.balance.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _cardNameController.dispose();
    _creditLimitController.dispose();
    _currentSpendController.dispose();
    super.dispose();
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final cardName = _cardNameController.text.trim();
      final creditLimit = double.parse(_creditLimitController.text.trim());
      final currentSpend = double.parse(_currentSpendController.text.trim());

      if (currentSpend > creditLimit) {
        throw Exception('Current spending cannot exceed credit limit');
      }

      final cardData = {
        'userId': currentUser.uid,
        'accountType': 'credit_card',
        'accountName': cardName,
        'balance': currentSpend,
        'creditLimit': creditLimit,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        // Update existing card
        await _firestore
            .collection('moneyAccounts')
            .doc(widget.accountId!)
            .update(cardData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Credit card updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new card
        cardData['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('moneyAccounts').add(cardData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Credit card added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text(
          'Delete Credit Card',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        content: Text(
          'Are you sure you want to delete this credit card? This action cannot be undone.',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await _firestore
          .collection('moneyAccounts')
          .doc(widget.accountId!)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credit card deleted'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting card: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Credit Card' : 'Add Credit Card'),
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                  onPressed: _isLoading ? null : _deleteCard,
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.credit_card,
                  size: 64,
                  color: Colors.purple,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Card Name
            TextFormField(
              controller: _cardNameController,
              decoration: InputDecoration(
                labelText: 'Card Name',
                hintText: 'e.g., HDFC Credit Card, ICICI Visa',
                prefixIcon: const Icon(Icons.credit_card),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.cardTheme.color,
              ),
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter card name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Credit Limit
            TextFormField(
              controller: _creditLimitController,
              decoration: InputDecoration(
                labelText: 'Credit Limit',
                hintText: '0.00',
                prefixIcon: const Icon(Icons.account_balance_wallet),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.cardTheme.color,
              ),
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter credit limit';
                }
                final limit = double.tryParse(value.trim());
                if (limit == null || limit <= 0) {
                  return 'Please enter a valid credit limit';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Current Spending
            TextFormField(
              controller: _currentSpendController,
              decoration: InputDecoration(
                labelText: 'Current Spending',
                hintText: '0.00',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.cardTheme.color,
              ),
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter current spending';
                }
                final spending = double.tryParse(value.trim());
                if (spending == null || spending < 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.purple.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.purple,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Current spending represents how much you\'ve already used from your credit limit.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update Card' : 'Add Card',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

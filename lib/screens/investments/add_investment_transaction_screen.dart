import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/services/portfolio_service.dart';
import 'package:spendpal/services/investment_transaction_service.dart';
import 'package:spendpal/models/investment_asset.dart';

class AddInvestmentTransactionScreen extends StatefulWidget {
  const AddInvestmentTransactionScreen({super.key});

  @override
  State<AddInvestmentTransactionScreen> createState() =>
      _AddInvestmentTransactionScreenState();
}

class _AddInvestmentTransactionScreenState
    extends State<AddInvestmentTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final PortfolioService _portfolioService = PortfolioService();
  final InvestmentTransactionService _transactionService =
      InvestmentTransactionService();

  String? _userId;
  bool _isLoading = false;
  int _currentStep = 0;

  // Asset selection or creation
  bool _createNewAsset = false;
  InvestmentAsset? _selectedAsset;
  List<InvestmentAsset> _existingAssets = [];

  // New asset fields
  final _assetNameController = TextEditingController();
  final _symbolController = TextEditingController();
  final _schemeCodeController = TextEditingController();
  String _assetType = 'equity';

  // Transaction fields
  String _transactionType = 'BUY';
  final _dateController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _amountController = TextEditingController();
  final _feesController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _dateController.text = _formatDate(_selectedDate);
    _feesController.text = '0';
    _loadExistingAssets();
  }

  @override
  void dispose() {
    _assetNameController.dispose();
    _symbolController.dispose();
    _schemeCodeController.dispose();
    _dateController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _amountController.dispose();
    _feesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingAssets() async {
    if (_userId == null) return;

    final assets = await _portfolioService.getAssets(userId: _userId!);
    setState(() {
      _existingAssets = assets;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Create asset if needed
      InvestmentAsset? asset = _selectedAsset;

      if (_createNewAsset) {
        asset = await _transactionService.createAsset(
          userId: _userId!,
          assetType: _assetType,
          name: _assetNameController.text,
          symbol: _symbolController.text.isEmpty ? null : _symbolController.text,
          schemeCode: _schemeCodeController.text.isEmpty
              ? null
              : _schemeCodeController.text,
        );

        if (asset == null) {
          throw Exception('Failed to create asset');
        }
      }

      if (asset == null) {
        throw Exception('No asset selected');
      }

      // Step 2: Add transaction
      bool success = false;

      switch (_transactionType) {
        case 'BUY':
          final txn = await _transactionService.addBuyTransaction(
            userId: _userId!,
            assetId: asset.assetId,
            date: _selectedDate,
            quantity: double.parse(_quantityController.text),
            price: double.parse(_priceController.text),
            fees: double.parse(_feesController.text),
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );
          success = txn != null;
          break;

        case 'SELL':
          final txn = await _transactionService.addSellTransaction(
            userId: _userId!,
            assetId: asset.assetId,
            date: _selectedDate,
            quantity: double.parse(_quantityController.text),
            price: double.parse(_priceController.text),
            fees: double.parse(_feesController.text),
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );
          success = txn != null;
          break;

        case 'SIP':
          final txn = await _transactionService.addSipTransaction(
            userId: _userId!,
            assetId: asset.assetId,
            date: _selectedDate,
            quantity: double.parse(_quantityController.text),
            price: double.parse(_priceController.text),
            fees: double.parse(_feesController.text),
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );
          success = txn != null;
          break;

        case 'DIVIDEND':
          final txn = await _transactionService.addDividendTransaction(
            userId: _userId!,
            assetId: asset.assetId,
            date: _selectedDate,
            amount: double.parse(_amountController.text),
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );
          success = txn != null;
          break;

        case 'FEE':
          final txn = await _transactionService.addFeeTransaction(
            userId: _userId!,
            assetId: asset.assetId,
            date: _selectedDate,
            amount: double.parse(_amountController.text),
            notes: _notesController.text.isEmpty ? null : _notesController.text,
          );
          success = txn != null;
          break;
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Failed to add transaction');
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() {
                _currentStep++;
              });
            } else {
              _submit();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
              });
            }
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : details.onStepContinue,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_currentStep == 2 ? 'Submit' : 'Continue'),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            // Step 1: Select or Create Asset
            Step(
              title: const Text('Select Asset'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Create New Asset'),
                    value: _createNewAsset,
                    onChanged: (value) {
                      setState(() {
                        _createNewAsset = value;
                        _selectedAsset = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  if (_createNewAsset) ..._buildNewAssetFields()
                  else ..._buildAssetSelection(),
                ],
              ),
            ),

            // Step 2: Transaction Type
            Step(
              title: const Text('Transaction Type'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _transactionType,
                    decoration: const InputDecoration(
                      labelText: 'Transaction Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'BUY', child: Text('Buy')),
                      DropdownMenuItem(value: 'SELL', child: Text('Sell')),
                      DropdownMenuItem(value: 'SIP', child: Text('SIP')),
                      DropdownMenuItem(value: 'DIVIDEND', child: Text('Dividend')),
                      DropdownMenuItem(value: 'FEE', child: Text('Fee/Charges')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _transactionType = value!;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Step 3: Transaction Details
            Step(
              title: const Text('Details'),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: Column(
                children: _buildTransactionFields(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAssetSelection() {
    return [
      DropdownButtonFormField<InvestmentAsset>(
        value: _selectedAsset,
        decoration: const InputDecoration(
          labelText: 'Select Asset',
          border: OutlineInputBorder(),
        ),
        items: _existingAssets.map((asset) {
          return DropdownMenuItem(
            value: asset,
            child: Text(asset.name),
          );
        }).toList(),
        onChanged: (asset) {
          setState(() {
            _selectedAsset = asset;
          });
        },
        validator: (value) {
          if (!_createNewAsset && value == null) {
            return 'Please select an asset';
          }
          return null;
        },
      ),
    ];
  }

  List<Widget> _buildNewAssetFields() {
    return [
      DropdownButtonFormField<String>(
        value: _assetType,
        decoration: const InputDecoration(
          labelText: 'Asset Type',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'mutual_fund', child: Text('Mutual Fund')),
          DropdownMenuItem(value: 'equity', child: Text('Stock')),
          DropdownMenuItem(value: 'etf', child: Text('ETF')),
          DropdownMenuItem(value: 'fd', child: Text('Fixed Deposit')),
          DropdownMenuItem(value: 'rd', child: Text('Recurring Deposit')),
          DropdownMenuItem(value: 'gold', child: Text('Gold')),
        ],
        onChanged: (value) {
          setState(() {
            _assetType = value!;
          });
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _assetNameController,
        decoration: const InputDecoration(
          labelText: 'Asset Name *',
          border: OutlineInputBorder(),
          hintText: 'e.g., Axis Bluechip Fund',
        ),
        validator: (value) {
          if (_createNewAsset && (value == null || value.isEmpty)) {
            return 'Please enter asset name';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      if (_assetType == 'equity' || _assetType == 'etf')
        TextFormField(
          controller: _symbolController,
          decoration: const InputDecoration(
            labelText: 'Stock Symbol',
            border: OutlineInputBorder(),
            hintText: 'e.g., RELIANCE',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
      if (_assetType == 'mutual_fund')
        TextFormField(
          controller: _schemeCodeController,
          decoration: const InputDecoration(
            labelText: 'Scheme Code',
            border: OutlineInputBorder(),
            hintText: 'AMFI scheme code',
          ),
        ),
    ];
  }

  List<Widget> _buildTransactionFields() {
    final needsQuantity = ['BUY', 'SELL', 'SIP'].contains(_transactionType);
    final needsAmount = ['DIVIDEND', 'FEE'].contains(_transactionType);

    return [
      // Date
      TextFormField(
        controller: _dateController,
        decoration: const InputDecoration(
          labelText: 'Date',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today),
        ),
        readOnly: true,
        onTap: _selectDate,
      ),
      const SizedBox(height: 16),

      // Quantity (for BUY/SELL/SIP)
      if (needsQuantity) ...[
        TextFormField(
          controller: _quantityController,
          decoration: const InputDecoration(
            labelText: 'Quantity/Units',
            border: OutlineInputBorder(),
            hintText: '0.00',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
          ],
          validator: (value) {
            if (needsQuantity && (value == null || value.isEmpty)) {
              return 'Please enter quantity';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _priceController,
          decoration: const InputDecoration(
            labelText: 'Price per Unit',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_rupee),
            hintText: '0.00',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          validator: (value) {
            if (needsQuantity && (value == null || value.isEmpty)) {
              return 'Please enter price';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],

      // Amount (for DIVIDEND/FEE)
      if (needsAmount) ...[
        TextFormField(
          controller: _amountController,
          decoration: const InputDecoration(
            labelText: 'Amount',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_rupee),
            hintText: '0.00',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          validator: (value) {
            if (needsAmount && (value == null || value.isEmpty)) {
              return 'Please enter amount';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],

      // Fees (for BUY/SELL/SIP)
      if (needsQuantity) ...[
        TextFormField(
          controller: _feesController,
          decoration: const InputDecoration(
            labelText: 'Fees/Charges',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_rupee),
            hintText: '0.00',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
        ),
        const SizedBox(height: 16),
      ],

      // Notes
      TextFormField(
        controller: _notesController,
        decoration: const InputDecoration(
          labelText: 'Notes (Optional)',
          border: OutlineInputBorder(),
          hintText: 'Add any additional details',
        ),
        maxLines: 3,
      ),
    ];
  }
}

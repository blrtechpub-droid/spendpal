import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/services/portfolio_service.dart';
import 'package:spendpal/services/investment_transaction_service.dart';
import 'package:spendpal/models/investment_asset.dart';

class UpdatePriceScreen extends StatefulWidget {
  final String? assetId;
  final InvestmentAsset? asset;

  const UpdatePriceScreen({
    super.key,
    this.assetId,
    this.asset,
  });

  @override
  State<UpdatePriceScreen> createState() => _UpdatePriceScreenState();
}

class _UpdatePriceScreenState extends State<UpdatePriceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final PortfolioService _portfolioService = PortfolioService();
  final InvestmentTransactionService _transactionService = InvestmentTransactionService();

  String? _userId;
  InvestmentAsset? _selectedAsset;
  List<InvestmentAsset> _assets = [];
  bool _isLoading = false;
  double? _currentPrice;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _selectedAsset = widget.asset;
    _loadAssets();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    if (_userId == null) return;

    final assets = await _portfolioService.getAssets(userId: _userId!);
    setState(() {
      _assets = assets;
      if (widget.asset != null) {
        _selectedAsset = widget.asset;
        _loadCurrentPrice();
      }
    });
  }

  Future<void> _loadCurrentPrice() async {
    if (_selectedAsset == null || _userId == null) return;

    final holding = await _portfolioService.getHoldingForAsset(
      userId: _userId!,
      assetId: _selectedAsset!.assetId,
    );

    if (holding != null && holding.currentPrice != null) {
      setState(() {
        _currentPrice = holding.currentPrice;
        _priceController.text = holding.currentPrice!.toStringAsFixed(2);
      });
    }
  }

  Future<void> _updatePrice() async {
    if (!_formKey.currentState!.validate() || _selectedAsset == null || _userId == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newPrice = double.parse(_priceController.text);

      final success = await _transactionService.updateCurrentPrice(
        userId: _userId!,
        assetId: _selectedAsset!.assetId,
        currentPrice: newPrice,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Price updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update price'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Price'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Asset Selection
            if (widget.asset == null)
              DropdownButtonFormField<InvestmentAsset>(
                value: _selectedAsset,
                decoration: const InputDecoration(
                  labelText: 'Select Asset',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
                items: _assets.map((asset) {
                  return DropdownMenuItem(
                    value: asset,
                    child: Text(
                      asset.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (asset) {
                  setState(() {
                    _selectedAsset = asset;
                    _currentPrice = null;
                    _priceController.clear();
                  });
                  _loadCurrentPrice();
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select an asset';
                  }
                  return null;
                },
              ),

            if (widget.asset != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedAsset?.name ?? '',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getAssetTypeDisplay(_selectedAsset?.assetType ?? ''),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Current Price Display
            if (_currentPrice != null)
              Card(
                color: Colors.blue.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Price',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '₹${_currentPrice!.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_currentPrice != null) const SizedBox(height: 16),

            // New Price Input
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'New Price',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the new price';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Please enter a valid price';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Info Card
            Card(
              color: Colors.orange.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Note',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This will update the current price for calculating your portfolio value and unrealized P/L. It does not create a transaction.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Update Button
            ElevatedButton(
              onPressed: _isLoading ? null : _updatePrice,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Update Price',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAssetTypeDisplay(String assetType) {
    switch (assetType) {
      case 'mutual_fund':
        return 'Mutual Fund';
      case 'equity':
        return 'Stock';
      case 'etf':
        return 'ETF';
      case 'fd':
        return 'Fixed Deposit';
      case 'rd':
        return 'Recurring Deposit';
      case 'gold':
        return 'Gold';
      default:
        return assetType;
    }
  }
}

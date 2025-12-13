import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/services/portfolio_service.dart';
import 'package:spendpal/models/investment_asset.dart';
import 'package:spendpal/models/investment_holding.dart';
import 'package:spendpal/models/investment_transaction.dart';
import 'package:intl/intl.dart';

class AssetDetailScreen extends StatefulWidget {
  final String? assetId;
  final InvestmentAsset? asset;

  const AssetDetailScreen({
    super.key,
    this.assetId,
    this.asset,
  });

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  final PortfolioService _portfolioService = PortfolioService();

  String? _userId;
  InvestmentAsset? _asset;
  InvestmentHolding? _holding;
  List<InvestmentTransaction> _transactions = [];
  bool _isLoading = false;
  double? _xirr;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _asset = widget.asset;
    _loadAssetDetails();
  }

  Future<void> _loadAssetDetails() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Use existing asset or get from assetId
      final assetIdToUse = _asset?.assetId ?? widget.assetId;

      if (assetIdToUse == null) {
        throw Exception('No asset ID provided');
      }

      // Load complete asset performance data
      final performanceData = await _portfolioService.getAssetPerformance(
        userId: _userId!,
        assetId: assetIdToUse,
      );

      if (performanceData['hasData'] != true) {
        throw Exception(performanceData['error'] ?? 'Failed to load asset data');
      }

      // Extract data from performance result
      _asset = performanceData['asset'] as InvestmentAsset;
      _holding = performanceData['holding'] as InvestmentHolding?;
      _transactions = (performanceData['transactions'] as List<InvestmentTransaction>?) ?? [];
      _xirr = performanceData['xirr'] as double?;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading asset details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    await _loadAssetDetails();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_asset?.name ?? 'Asset Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'update_price') {
                _navigateToUpdatePrice();
              } else if (value == 'add_transaction') {
                _navigateToAddTransaction();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'update_price',
                child: Row(
                  children: [
                    Icon(Icons.currency_rupee),
                    SizedBox(width: 8),
                    Text('Update Price'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add_transaction',
                child: Row(
                  children: [
                    Icon(Icons.add),
                    SizedBox(width: 8),
                    Text('Add Transaction'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Asset Info Card
                  _buildAssetInfoCard(theme),
                  const SizedBox(height: 16),

                  // Holdings Summary Card
                  if (_holding != null) ...[
                    _buildHoldingSummaryCard(theme),
                    const SizedBox(height: 16),
                  ],

                  // Performance Metrics Card
                  if (_holding != null && _holding!.quantity > 0) ...[
                    _buildPerformanceCard(theme),
                    const SizedBox(height: 16),
                  ],

                  // Transaction History
                  _buildTransactionHistory(theme),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddTransaction,
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
      ),
    );
  }

  Widget _buildAssetInfoCard(ThemeData theme) {
    if (_asset == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getAssetIcon(_asset!.assetType),
                    color: theme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _asset!.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getAssetTypeDisplay(_asset!.assetType),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_asset!.symbol != null || _asset!.schemeCode != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              if (_asset!.symbol != null)
                _buildInfoRow(theme, 'Symbol', _asset!.symbol!),
              if (_asset!.schemeCode != null)
                _buildInfoRow(theme, 'Scheme Code', _asset!.schemeCode!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingSummaryCard(ThemeData theme) {
    if (_holding == null) return const SizedBox.shrink();

    final isProfit = _holding!.unrealizedPL >= 0;
    final plColor = isProfit ? Colors.green : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Holdings',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricColumn(
                  theme,
                  'Quantity',
                  _holding!.quantity.toStringAsFixed(4),
                ),
                _buildMetricColumn(
                  theme,
                  'Avg Price',
                  '₹${_holding!.avgPrice.toStringAsFixed(2)}',
                ),
                _buildMetricColumn(
                  theme,
                  'Current Price',
                  _holding!.currentPrice != null
                      ? '₹${_holding!.currentPrice!.toStringAsFixed(2)}'
                      : 'N/A',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricColumn(
                  theme,
                  'Invested',
                  '₹${_holding!.investedAmount.toStringAsFixed(2)}',
                ),
                _buildMetricColumn(
                  theme,
                  'Current Value',
                  '₹${_holding!.currentValue.toStringAsFixed(2)}',
                ),
                _buildMetricColumn(
                  theme,
                  'Unrealized P/L',
                  '${isProfit ? '+' : ''}₹${_holding!.unrealizedPL.toStringAsFixed(2)}',
                  valueColor: plColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: plColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${isProfit ? '+' : ''}${_holding!.unrealizedPLPercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: plColor,
                    fontSize: 18,
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

  Widget _buildPerformanceCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_xirr != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'XIRR',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  Text(
                    '${_xirr! >= 0 ? '+' : ''}${_xirr!.toStringAsFixed(2)}%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _xirr! >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Extended Internal Rate of Return',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ] else ...[
              Center(
                child: Text(
                  'Insufficient data for XIRR calculation',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHistory(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction History',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_transactions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No transactions yet',
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _transactions.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final txn = _transactions[index];
                  return _buildTransactionTile(theme, txn);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(ThemeData theme, InvestmentTransaction txn) {
    final isInflow = txn.isDisposal || txn.isIncome;
    final color = isInflow ? Colors.green : Colors.red;
    final icon = _getTransactionIcon(txn.type);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Row(
        children: [
          Text(
            _getTransactionTypeDisplay(txn.type),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${isInflow ? '+' : '-'}₹${txn.amount.toStringAsFixed(2)}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(DateFormat('dd MMM yyyy').format(txn.date)),
          if (txn.quantity != null && txn.price != null)
            Text(
              '${txn.quantity!.toStringAsFixed(4)} units @ ₹${txn.price!.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall,
            ),
          if (txn.fees > 0)
            Text(
              'Fees: ₹${txn.fees.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
          if (txn.notes != null && txn.notes!.isNotEmpty)
            Text(
              txn.notes!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(
    ThemeData theme,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToUpdatePrice() {
    if (_asset == null) return;

    Navigator.pushNamed(
      context,
      '/update_price',
      arguments: {'asset': _asset},
    ).then((value) {
      if (value == true) {
        _refresh();
      }
    });
  }

  void _navigateToAddTransaction() {
    if (_asset == null) return;

    Navigator.pushNamed(
      context,
      '/add_investment_transaction',
      arguments: {'asset': _asset},
    ).then((value) {
      if (value == true) {
        _refresh();
      }
    });
  }

  IconData _getAssetIcon(String assetType) {
    switch (assetType) {
      case 'mutual_fund':
        return Icons.pie_chart;
      case 'equity':
        return Icons.show_chart;
      case 'etf':
        return Icons.trending_up;
      case 'fd':
        return Icons.account_balance;
      case 'rd':
        return Icons.savings;
      case 'gold':
        return Icons.diamond;
      default:
        return Icons.attach_money;
    }
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

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'BUY':
        return Icons.add_shopping_cart;
      case 'SELL':
        return Icons.remove_shopping_cart;
      case 'SIP':
        return Icons.autorenew;
      case 'DIVIDEND':
        return Icons.money;
      case 'FEE':
        return Icons.account_balance_wallet;
      default:
        return Icons.receipt;
    }
  }

  String _getTransactionTypeDisplay(String type) {
    switch (type) {
      case 'BUY':
        return 'Buy';
      case 'SELL':
        return 'Sell';
      case 'SIP':
        return 'SIP';
      case 'DIVIDEND':
        return 'Dividend';
      case 'FEE':
        return 'Fee/Charges';
      default:
        return type;
    }
  }
}

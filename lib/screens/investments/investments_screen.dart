import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/services/portfolio_service.dart';
import 'package:spendpal/services/valuation_service.dart';
import 'package:spendpal/services/account_tracker_service.dart';
import 'package:spendpal/models/account_tracker_model.dart';
import 'package:spendpal/config/investment_platform_registry.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({Key? key}) : super(key: key);

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> with SingleTickerProviderStateMixin {
  final PortfolioService _portfolioService = PortfolioService();
  final ValuationService _valuationService = ValuationService();
  late TabController _tabController;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadPortfolioData() async {
    if (_userId == null) return {};

    final summary = await _portfolioService.getPortfolioSummary(userId: _userId!);
    final allocation = await _valuationService.getAssetAllocation(userId: _userId!);

    return {
      'summary': summary,
      'allocation': allocation,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Investments'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Mutual Funds'),
            Tab(text: 'Equity'),
            Tab(text: 'ETF'),
            Tab(text: 'FD/RD'),
            Tab(text: 'PPF/EPF/NPS'),
            Tab(text: 'Gold'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Manage Trackers',
            onPressed: () {
              _showTrackerManagement(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.sms),
            tooltip: 'Review Investment SMS',
            onPressed: () {
              Navigator.pushNamed(context, '/investment_sms_review');
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to add asset screen
              Navigator.pushNamed(context, '/add_investment_transaction');
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadPortfolioData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('Error loading portfolio', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                ],
              ),
            );
          }

          final data = snapshot.data ?? {};
          final summary = data['summary'] as Map<String, dynamic>? ?? {};
          final allocation = data['allocation'] as Map<String, double>? ?? {};
          final portfolioItems = summary['portfolioItems'] as List<Map<String, dynamic>>? ?? [];

          final totalInvested = summary['totalInvested'] as double? ?? 0.0;
          final totalCurrent = summary['totalCurrent'] as double? ?? 0.0;
          final totalPL = summary['totalPL'] as double? ?? 0.0;
          final totalPLPercent = summary['totalPLPercent'] as double? ?? 0.0;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: Column(
              children: [
                // Portfolio Summary Card
                _buildSummaryCard(
                  theme,
                  totalInvested,
                  totalCurrent,
                  totalPL,
                  totalPLPercent,
                ),

                // Asset List
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAssetList(context, theme, portfolioItems, null),
                      _buildAssetList(context, theme, portfolioItems, 'mutual_fund'),
                      _buildAssetList(context, theme, portfolioItems, 'equity'),
                      _buildAssetList(context, theme, portfolioItems, 'etf'),
                      _buildAssetList(context, theme, portfolioItems, ['fd', 'rd']),
                      _buildAssetList(context, theme, portfolioItems, ['ppf', 'epf', 'nps']),
                      _buildAssetList(context, theme, portfolioItems, 'gold'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Show bottom sheet to choose: Add Asset or Add Transaction
          _showAddOptionsSheet(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    double invested,
    double current,
    double pl,
    double plPercent,
  ) {
    final isProfit = pl >= 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit
              ? [Colors.green[400]!, Colors.green[700]!]
              : [Colors.red[400]!, Colors.red[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isProfit ? Colors.green : Colors.red).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_up, color: Color(0xFFF8F8F8), size: 28),
              ),
              const SizedBox(width: 12),
              const Text(
                'Portfolio Summary',
                style: TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invested',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_formatCompact(invested)}',
                    style: const TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Current',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8).withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_formatCompact(current)}',
                    style: const TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total P/L',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8).withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${pl >= 0 ? '+' : ''}₹${pl.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${plPercent >= 0 ? '+' : ''}${plPercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8).withValues(alpha: 0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssetList(
    BuildContext context,
    ThemeData theme,
    List<Map<String, dynamic>> items,
    dynamic typeFilter, // Can be String or List<String>
  ) {
    // Filter items by asset type
    final filteredItems = typeFilter == null
        ? items
        : items.where((item) {
            final assetType = item['assetType'] as String;
            if (typeFilter is List<String>) {
              return typeFilter.contains(assetType);
            }
            return assetType == typeFilter;
          }).toList();

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No investments yet',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first investment',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildAssetCard(context, theme, item);
      },
    );
  }

  Widget _buildAssetCard(BuildContext context, ThemeData theme, Map<String, dynamic> item) {
    final name = item['name'] as String;
    final assetType = item['assetType'] as String;
    final quantity = item['quantity'] as double;
    final currentPrice = item['currentPrice'] as double?;
    final investedAmount = item['investedAmount'] as double;
    final currentValue = item['currentValue'] as double;
    final pl = item['unrealizedPL'] as double;
    final plPercent = item['unrealizedPLPercent'] as double;
    final asset = item['asset'];

    final isPL = pl >= 0;
    final plColor = isPL ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/asset_detail',
            arguments: {'assetId': asset.assetId, 'asset': asset},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getAssetTypeDisplay(assetType),
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: plColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${pl >= 0 ? '+' : ''}${plPercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: plColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invested',
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${investedAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Current',
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${currentValue.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'P/L',
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pl >= 0 ? '+' : ''}₹${pl.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: plColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_chart),
              title: const Text('Add New Asset'),
              subtitle: const Text('Create a new investment asset'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to add transaction screen (which supports creating new assets)
                Navigator.pushNamed(context, '/add_investment_transaction');
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Add Transaction'),
              subtitle: const Text('Buy, sell, or add dividend'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/add_investment_transaction');
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Update Price'),
              subtitle: const Text('Manually update current price'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/update_price');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatCompact(double value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(2)}Cr';
    } else if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(2)}L';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
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
      case 'ppf':
        return 'Public Provident Fund';
      case 'epf':
        return 'Employees Provident Fund';
      case 'nps':
        return 'National Pension System';
      case 'gold':
        return 'Gold';
      default:
        return assetType;
    }
  }

  void _showTrackerManagement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) return const SizedBox();

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sync, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Investment Trackers',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Existing Trackers Section
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('accountTrackers')
                      .where('userId', isEqualTo: currentUser.uid)
                      .where('type', isEqualTo: 'investment')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final trackers = snapshot.data?.docs ?? [];

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Existing trackers list
                        if (trackers.isNotEmpty) ...[
                          const Text(
                            'Active Trackers',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ...trackers.map((doc) {
                            final tracker = AccountTrackerModel.fromFirestore(doc);
                            final platform = getPlatformById(tracker.name.toLowerCase().replaceAll(' ', '_'));

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: platform?.color ?? Colors.blue,
                                  child: Icon(platform?.icon ?? Icons.account_balance, color: Colors.white),
                                ),
                                title: Text(tracker.name),
                                subtitle: Text(
                                  '${tracker.emailsFetched} emails fetched',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: tracker.isActive,
                                      onChanged: (value) async {
                                        await FirebaseFirestore.instance
                                            .collection('accountTrackers')
                                            .doc(tracker.id)
                                            .update({'isActive': value});
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Tracker?'),
                                            content: Text('Remove tracker for ${tracker.name}?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          await FirebaseFirestore.instance
                                              .collection('accountTrackers')
                                              .doc(tracker.id)
                                              .delete();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 24),
                        ],

                        // Add new tracker section
                        const Text(
                          'Add New Tracker',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Select a platform to automatically import investment transactions from emails:',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),

                        // Platform selection cards
                        ...investmentPlatforms.map((platform) {
                          // Check if tracker already exists
                          final trackerExists = trackers.any((doc) {
                            final tracker = AccountTrackerModel.fromFirestore(doc);
                            return tracker.name.toLowerCase() == platform.name.toLowerCase();
                          });

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              enabled: !trackerExists,
                              leading: CircleAvatar(
                                backgroundColor: platform.color,
                                child: Icon(platform.icon, color: Colors.white),
                              ),
                              title: Text(platform.name),
                              subtitle: Text(
                                platform.supportedAssetTypes.join(', '),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: trackerExists
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.add_circle_outline),
                              onTap: trackerExists
                                  ? null
                                  : () => _createInvestmentTracker(context, platform, currentUser.uid),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createInvestmentTracker(
    BuildContext context,
    InvestmentPlatform platform,
    String userId,
  ) async {
    try {
      // Map platform ID to TrackerCategory enum
      final category = _getTrackerCategory(platform.id);

      final tracker = AccountTrackerModel(
        id: FirebaseFirestore.instance.collection('accountTrackers').doc().id,
        userId: userId,
        name: platform.name,
        type: TrackerType.investment,
        category: category,
        emailDomains: [platform.emailDomain],
        colorHex: '#${platform.color.toARGB32().toRadixString(16).substring(2)}',
        isActive: true,
        emailsFetched: 0,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('accountTrackers')
          .doc(tracker.id)
          .set(tracker.toMap());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${platform.name} tracker created'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating tracker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  TrackerCategory _getTrackerCategory(String platformId) {
    switch (platformId) {
      case 'zerodha':
        return TrackerCategory.zerodha;
      case 'groww':
        return TrackerCategory.groww;
      case 'angelone':
        return TrackerCategory.angelOne;
      case 'upstox':
        return TrackerCategory.upstox;
      case '5paisa':
        return TrackerCategory.paisa5;
      default:
        // For platforms not in enum, use a generic one
        return TrackerCategory.zerodha; // Default fallback
    }
  }
}

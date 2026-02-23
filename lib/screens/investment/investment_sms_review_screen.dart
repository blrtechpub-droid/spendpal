import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/services/investment_sms_parser_service.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/utils/currency_utils.dart';

/// Screen to review and categorize investment SMS
/// Users can approve/reject detected investment transactions before importing
class InvestmentSmsReviewScreen extends StatefulWidget {
  const InvestmentSmsReviewScreen({super.key});

  @override
  State<InvestmentSmsReviewScreen> createState() => _InvestmentSmsReviewScreenState();
}

class _InvestmentSmsReviewScreenState extends State<InvestmentSmsReviewScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground,
        title: const Text(
          'Investment SMS',
          style: TextStyle(color: AppTheme.primaryText),
        ),
        iconTheme: const IconThemeData(color: AppTheme.primaryText),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: InvestmentSmsParserService.getPendingInvestmentSms(userId: currentUserId),
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
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading SMS',
                    style: TextStyle(color: AppTheme.secondaryText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final smsList = snapshot.data ?? [];

          if (smsList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox,
                    size: 64,
                    color: AppTheme.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending investment SMS',
                    style: TextStyle(
                      color: AppTheme.secondaryText,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Investment SMS will appear here for review',
                    style: TextStyle(
                      color: AppTheme.tertiaryText,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: smsList.length,
            itemBuilder: (context, index) {
              final smsData = smsList[index];
              return _buildSmsCard(smsData);
            },
          );
        },
      ),
    );
  }

  Widget _buildSmsCard(Map<String, dynamic> smsData) {
    final type = smsData['type'] as String? ?? 'unknown';
    final rawText = smsData['rawText'] as String? ?? '';
    final queueId = smsData['id'] as String? ?? '';

    // Extract transaction details
    final fundName = smsData['fundName'] as String?;
    final symbol = smsData['symbol'] as String?;
    final amount = (smsData['amount'] as num?)?.toDouble();
    final units = (smsData['units'] as num?)?.toDouble();
    final quantity = (smsData['quantity'] as num?)?.toDouble();
    final nav = (smsData['nav'] as num?)?.toDouble();
    final price = (smsData['price'] as num?)?.toDouble();
    final receivedAt = smsData['receivedAt']?.toDate() ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.tealAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with type and date
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getTypeColor(type).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getTypeIcon(type),
                  color: _getTypeColor(type),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTypeDisplayName(type),
                        style: TextStyle(
                          color: _getTypeColor(type),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(receivedAt),
                        style: TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Transaction details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Asset name
                if (fundName != null || symbol != null) ...[
                  Text(
                    fundName ?? symbol ?? '',
                    style: const TextStyle(
                      color: AppTheme.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Amount
                if (amount != null)
                  _buildDetailRow(
                    'Amount',
                    context.formatCurrency(amount),
                    Colors.green,
                  ),

                // Units (for MF)
                if (units != null)
                  _buildDetailRow(
                    'Units',
                    units.toStringAsFixed(3),
                    AppTheme.tealAccent,
                  ),

                // Quantity (for stocks)
                if (quantity != null)
                  _buildDetailRow(
                    'Quantity',
                    quantity.toString(),
                    AppTheme.tealAccent,
                  ),

                // NAV
                if (nav != null)
                  _buildDetailRow(
                    'NAV',
                    context.formatCurrency(nav),
                    AppTheme.secondaryText,
                  ),

                // Price (for stocks)
                if (price != null)
                  _buildDetailRow(
                    'Price',
                    context.formatCurrency(price),
                    AppTheme.secondaryText,
                  ),

                // Raw SMS text (expandable)
                if (rawText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: 8),
                    title: Text(
                      'View SMS Text',
                      style: TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rawText,
                          style: TextStyle(
                            color: AppTheme.tertiaryText,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectSms(queueId),
                    style: AppTheme.dangerOutlinedButtonStyle,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveSms(queueId, smsData),
                    style: AppTheme.primaryButtonStyle,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.secondaryText,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'mf_purchase':
        return 'Mutual Fund Purchase';
      case 'sip':
        return 'SIP Investment';
      case 'mf_redemption':
        return 'Mutual Fund Redemption';
      case 'dividend':
        return 'Dividend Credit';
      case 'stock_buy':
        return 'Stock Purchase';
      case 'stock_sell':
        return 'Stock Sale';
      case 'nav_update':
        return 'NAV Update';
      default:
        return type;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'mf_purchase':
      case 'sip':
        return Icons.trending_up;
      case 'mf_redemption':
      case 'stock_sell':
        return Icons.trending_down;
      case 'dividend':
        return Icons.account_balance_wallet;
      case 'stock_buy':
        return Icons.shopping_cart;
      case 'nav_update':
        return Icons.info_outline;
      default:
        return Icons.payment;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'mf_purchase':
      case 'sip':
      case 'stock_buy':
        return Colors.green;
      case 'mf_redemption':
      case 'stock_sell':
        return Colors.orange;
      case 'dividend':
        return AppTheme.tealAccent;
      case 'nav_update':
        return Colors.blue;
      default:
        return AppTheme.secondaryText;
    }
  }

  Future<void> _approveSms(String queueId, Map<String, dynamic> smsData) async {
    try {
      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Importing transaction...'),
            ],
          ),
          duration: Duration(seconds: 5),
          backgroundColor: AppTheme.tealAccent,
        ),
      );

      // Import to investment transactions
      final success = await InvestmentSmsParserService.importToInvestmentTransaction(
        userId: currentUserId,
        queueId: queueId,
        parsedData: smsData,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction imported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to import transaction. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectSms(String queueId) async {
    try {
      await InvestmentSmsParserService.updateSmsStatus(
        userId: currentUserId,
        queueId: queueId,
        status: 'rejected',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Investment SMS rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/simplified_debt_model.dart';
import '../../services/debt_simplification_service.dart';
import '../../services/balance_service.dart';
import '../../widgets/upi_settle_dialog.dart';
import '../../utils/currency_utils.dart';

/// Screen showing group-specific balances with both simplified debts and member balances
class GroupBalancesScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupBalancesScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupBalancesScreen> createState() => _GroupBalancesScreenState();
}

class _GroupBalancesScreenState extends State<GroupBalancesScreen> {
  List<SimplifiedDebt> _simplifiedDebts = [];
  Map<String, double> _memberBalances = {};
  Map<String, String> _memberNames = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch both datasets in parallel
      final results = await Future.wait([
        DebtSimplificationService().simplifyGroupDebts(widget.groupId),
        BalanceService.calculateGroupBalances(currentUserId, widget.groupId),
      ]);

      final simplifiedDebts = results[0] as List<SimplifiedDebt>;
      final memberBalances = results[1] as Map<String, double>;

      // Fetch user names for all members
      final userIds = memberBalances.keys.toList();
      final names = await _fetchMemberNames(userIds);

      setState(() {
        _simplifiedDebts = simplifiedDebts;
        _memberBalances = memberBalances;
        _memberNames = names;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Map<String, String>> _fetchMemberNames(List<String> userIds) async {
    final names = <String, String>{};
    for (final userId in userIds) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      names[userId] = doc.data()?['name'] ?? 'Unknown';
    }
    return names;
  }

  Future<void> _handleSettleUp(SimplifiedDebt debt) async {
    await showDialog(
      context: context,
      builder: (context) => UpiSettleDialog(
        debt: debt,
        onSettled: () {
          _loadBalances(); // Refresh after settlement
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${widget.groupName} - Balances'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadBalances,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSimplifiedDebtsCard(),
                        const SizedBox(height: 24),
                        _buildMemberBalancesCard(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading balances',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadBalances,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimplifiedDebtsCard() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal[400]!, Colors.teal[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Simplified Debts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _simplifiedDebts.isEmpty
                      ? 'All settled up!'
                      : '${_simplifiedDebts.length} transaction${_simplifiedDebts.length == 1 ? '' : 's'} needed to settle all debts',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Debts list
          if (_simplifiedDebts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.green[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No debts to settle!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Everyone in this group is settled up',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _simplifiedDebts.map((debt) {
                  final isInvolved = currentUserId != null &&
                      (debt.fromUserId == currentUserId ||
                          debt.toUserId == currentUserId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: Colors.teal[700],
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${debt.fromUserName} → ${debt.toUserName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.formatCurrency(debt.amount),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isInvolved && debt.fromUserId == currentUserId)
                            ElevatedButton(
                              onPressed: () => _handleSettleUp(debt),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Settle'),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberBalancesCard() {
    // Sort members: positive balances first (descending), then negative (ascending)
    final sortedMembers = _memberBalances.entries.toList()
      ..sort((a, b) {
        if (a.value > 0 && b.value < 0) return -1;
        if (a.value < 0 && b.value > 0) return 1;
        if (a.value >= 0 && b.value >= 0) return b.value.compareTo(a.value);
        return a.value.compareTo(b.value);
      });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[400]!, Colors.deepOrange[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Member Balances',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Detailed balance for each member',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Member list
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: sortedMembers.map((entry) {
                final userId = entry.key;
                final balance = entry.value;
                final name = _memberNames[userId] ?? 'Unknown';

                Color balanceColor;
                String balanceText;
                IconData balanceIcon;

                if (balance > 0) {
                  balanceColor = Colors.green[700]!;
                  balanceText = '+${context.formatCurrency(balance)} (gets back)';
                  balanceIcon = Icons.arrow_upward;
                } else if (balance < 0) {
                  balanceColor = Colors.red[700]!;
                  balanceText = '-${context.formatCurrency(-balance)} (owes)';
                  balanceIcon = Icons.arrow_downward;
                } else {
                  balanceColor = Colors.grey[600]!;
                  balanceText = '${context.currencySymbol}0 (settled up)';
                  balanceIcon = Icons.check_circle_outline;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: Colors.grey[50],
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: balance > 0
                          ? Colors.green[100]
                          : balance < 0
                              ? Colors.red[100]
                              : Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        color: balance > 0
                            ? Colors.green[700]
                            : balance < 0
                                ? Colors.red[700]
                                : Colors.grey[600],
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        Icon(balanceIcon, size: 16, color: balanceColor),
                        const SizedBox(width: 4),
                        Text(
                          balanceText,
                          style: TextStyle(
                            color: balanceColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

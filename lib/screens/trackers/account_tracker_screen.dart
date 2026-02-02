import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/account_tracker_model.dart';
import '../../services/account_tracker_service.dart';
import '../../theme/app_theme.dart';
import 'add_tracker_dialog.dart';
import 'edit_tracker_dialog.dart';

class AccountTrackerScreen extends StatefulWidget {
  const AccountTrackerScreen({super.key});

  @override
  State<AccountTrackerScreen> createState() => _AccountTrackerScreenState();
}

class _AccountTrackerScreenState extends State<AccountTrackerScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Trackers')),
        body: const Center(child: Text('Please login first')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Account Trackers'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<AccountTrackerModel>>(
        stream: AccountTrackerService.streamTrackers(userId),
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
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading trackers',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                ],
              ),
            );
          }

          final allTrackers = snapshot.data ?? [];

          if (allTrackers.isEmpty) {
            return _buildEmptyState(theme, userId);
          }

          // Group trackers by type
          final grouped = <TrackerType, List<AccountTrackerModel>>{};
          for (final tracker in allTrackers) {
            grouped.putIfAbsent(tracker.type, () => []);
            grouped[tracker.type]!.add(tracker);
          }

          return Column(
            children: [
              // Stats header
              _buildStatsHeader(allTrackers, theme),

              // Tracker list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...TrackerType.values.map((type) {
                      final trackers = grouped[type] ?? [];
                      if (trackers.isEmpty) return const SizedBox.shrink();

                      return _buildTrackerTypeSection(
                        type,
                        trackers,
                        theme,
                        userId,
                      );
                    }),

                    // Empty types section
                    ...TrackerType.values.map((type) {
                      final trackers = grouped[type] ?? [];
                      if (trackers.isNotEmpty) return const SizedBox.shrink();

                      return _buildEmptyTypeSection(type, theme, userId);
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTrackerDialog(userId),
        backgroundColor: AppTheme.tealAccent,
        icon: const Icon(Icons.add),
        label: const Text('Add Tracker'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String userId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.tealAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet,
                size: 80,
                color: AppTheme.tealAccent,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Account Trackers',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add trackers to automatically sync\ntransactions from your banks,\ninvestments, and wallets',
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddTrackerDialog(userId),
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Tracker'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.tealAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoBox(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Why use trackers?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Faster email syncs (only your accounts)\n'
            '• Better privacy (targeted searches)\n'
            '• Easy to manage (enable/disable anytime)\n'
            '• Organized transactions by source',
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(List<AccountTrackerModel> trackers, ThemeData theme) {
    final activeCount = trackers.where((t) => t.isActive).length;
    final totalEmails = trackers.fold<int>(0, (sum, t) => sum + t.emailsFetched);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            '${trackers.length}',
            'Total Trackers',
            Icons.account_balance_wallet,
            theme,
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.dividerTheme.color,
          ),
          _buildStatItem(
            '$activeCount',
            'Active',
            Icons.check_circle,
            theme,
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.dividerTheme.color,
          ),
          _buildStatItem(
            '$totalEmails',
            'Emails Synced',
            Icons.email,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.tealAccent),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackerTypeSection(
    TrackerType type,
    List<AccountTrackerModel> trackers,
    ThemeData theme,
    String userId,
  ) {
    final emoji = trackers.first.typeEmoji;
    final typeName = trackers.first.typeDisplayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                '$typeName (${trackers.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
        ...trackers.map((tracker) => _buildTrackerCard(tracker, theme, userId)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmptyTypeSection(TrackerType type, ThemeData theme, String userId) {
    String emoji = '🏦';
    String typeName = 'Banking';

    switch (type) {
      case TrackerType.banking:
        emoji = '🏦';
        typeName = 'Banking';
        break;
      case TrackerType.creditCard:
        emoji = '💳';
        typeName = 'Credit Card';
        break;
      case TrackerType.investment:
        emoji = '📈';
        typeName = 'Investment';
        break;
      case TrackerType.governmentScheme:
        emoji = '💰';
        typeName = 'Government Scheme';
        break;
      case TrackerType.digitalWallet:
        emoji = '📱';
        typeName = 'Digital Wallet';
        break;
      case TrackerType.insurance:
        emoji = '🏥';
        typeName = 'Insurance';
        break;
      case TrackerType.loan:
        emoji = '🏠';
        typeName = 'Loan';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: theme.cardTheme.color?.withValues(alpha: 0.5),
        child: ListTile(
          leading: Text(emoji, style: const TextStyle(fontSize: 24)),
          title: Text(
            typeName,
            style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
          ),
          subtitle: const Text('No trackers added yet'),
          trailing: TextButton.icon(
            onPressed: () => _showAddTrackerDialog(userId, preselectedType: type),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackerCard(
    AccountTrackerModel tracker,
    ThemeData theme,
    String userId,
  ) {
    final color = tracker.colorHex != null
        ? Color(int.parse('0xFF${tracker.colorHex!.replaceAll('#', '')}'))
        : AppTheme.tealAccent;

    return Card(
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: tracker.isActive
            ? BorderSide.none
            : BorderSide(color: theme.dividerTheme.color ?? Colors.grey, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _showTrackerDetails(tracker, userId),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              tracker.typeEmoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          tracker.displayName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: tracker.isActive
                ? theme.textTheme.bodyLarge?.color
                : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              tracker.emailDomains.join(', '),
              style: TextStyle(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (tracker.emailsFetched > 0 || tracker.lastSyncedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (tracker.emailsFetched > 0) ...[
                    Icon(
                      Icons.email_outlined,
                      size: 12,
                      color: AppTheme.tealAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${tracker.emailsFetched} synced',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.tealAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (tracker.emailsFetched > 0 && tracker.lastSyncedAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (tracker.lastSyncedAt != null) ...[
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatLastSyncTime(tracker.lastSyncedAt!),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: tracker.isActive,
              onChanged: (value) => _toggleTracker(userId, tracker.id),
              activeColor: AppTheme.tealAccent,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'delete':
                    _deleteTracker(userId, tracker.id, tracker.name);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTracker(String userId, String trackerId) async {
    final success = await AccountTrackerService.toggleTracker(userId, trackerId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Tracker updated' : 'Failed to update tracker'),
          backgroundColor: success ? Colors.green : AppTheme.errorColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteTracker(String userId, String trackerId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tracker'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await AccountTrackerService.deleteTracker(userId, trackerId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Tracker deleted' : 'Failed to delete tracker'),
          backgroundColor: success ? Colors.green : AppTheme.errorColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatLastSyncTime(DateTime lastSyncedAt) {
    final now = DateTime.now();
    final difference = now.difference(lastSyncedAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  void _showAddTrackerDialog(String userId, {TrackerType? preselectedType}) {
    showDialog(
      context: context,
      builder: (context) => AddTrackerDialog(
        userId: userId,
        preselectedType: preselectedType,
      ),
    );
  }

  void _showTrackerDetails(AccountTrackerModel tracker, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          final theme = Theme.of(context);
          final color = tracker.colorHex != null
              ? Color(int.parse('0xFF${tracker.colorHex!.replaceAll('#', '')}'))
              : AppTheme.tealAccent;

          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                // Header with icon and name
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          tracker.emoji ?? tracker.typeEmoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tracker.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tracker.typeDisplayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Email Domains
                if (tracker.emailDomains.isNotEmpty) ...[
                  _buildDetailSection(
                    theme,
                    'Email Domains',
                    Icons.email,
                    tracker.emailDomains.map((domain) =>
                      Chip(
                        label: Text(domain),
                        backgroundColor: color.withValues(alpha: 0.1),
                        side: BorderSide(color: color.withValues(alpha: 0.3)),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // SMS Senders
                if (tracker.smsSenders.isNotEmpty) ...[
                  _buildDetailSection(
                    theme,
                    'SMS Senders',
                    Icons.message,
                    tracker.smsSenders.map((sender) =>
                      Chip(
                        label: Text(sender),
                        backgroundColor: color.withValues(alpha: 0.1),
                        side: BorderSide(color: color.withValues(alpha: 0.3)),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Account Number
                if (tracker.accountNumber != null) ...[
                  _buildInfoRow(theme, 'Account Number', '••${tracker.accountNumber}', Icons.credit_card),
                  const SizedBox(height: 12),
                ],

                // Category
                _buildInfoRow(theme, 'Category', tracker.category.name, Icons.category),
                const SizedBox(height: 12),

                // Status
                _buildInfoRow(
                  theme,
                  'Status',
                  tracker.isActive ? 'Active' : 'Inactive',
                  tracker.isActive ? Icons.check_circle : Icons.cancel,
                  valueColor: tracker.isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 12),

                // Auto-created badge
                if (tracker.autoCreated == true) ...[
                  _buildInfoRow(theme, 'Created', 'Auto-created', Icons.auto_awesome),
                  if (tracker.detectedFrom != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, top: 4),
                      child: Text(
                        'From: ${tracker.detectedFrom}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],

                // Stats
                const Divider(),
                const SizedBox(height: 16),

                Text(
                  'Statistics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 12),

                if (tracker.emailsFetched > 0)
                  _buildInfoRow(theme, 'Emails Synced', '${tracker.emailsFetched}', Icons.email_outlined),

                if (tracker.lastSyncedAt != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(theme, 'Last Synced', _formatLastSyncTime(tracker.lastSyncedAt!), Icons.access_time),
                ],

                _buildInfoRow(theme, 'Created', _formatDate(tracker.createdAt), Icons.calendar_today),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteTracker(userId, tracker.id, tracker.name);
                        },
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditTrackerDialog(tracker, userId);
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailSection(
    ThemeData theme,
    String title,
    IconData icon,
    List<Widget> chips,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    {Color? valueColor}
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? theme.textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showEditTrackerDialog(AccountTrackerModel tracker, String userId) {
    showDialog(
      context: context,
      builder: (context) => EditTrackerDialog(
        userId: userId,
        tracker: tracker,
      ),
    ).then((updated) {
      if (updated == true) {
        // Refresh is handled automatically by StreamBuilder
        // This callback is just for potential future use
      }
    });
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Account Trackers'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Trackers control which emails to sync from Gmail.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Benefits:'),
              SizedBox(height: 8),
              Text('• Faster syncs - Only searches your accounts'),
              Text('• Better privacy - Targeted email searches'),
              Text('• Easy management - Enable/disable anytime'),
              Text('• Organized data - Track by source'),
              SizedBox(height: 16),
              Text(
                'How it works:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Add trackers for your accounts'),
              Text('2. Connect Gmail'),
              Text('3. Sync emails - Only from configured trackers'),
              Text('4. Review and import transactions'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

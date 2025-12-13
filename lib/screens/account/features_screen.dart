import 'package:flutter/material.dart';
import 'package:spendpal/theme/app_theme.dart';

class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('App Features'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.tealAccent.withValues(alpha: 0.2),
                  AppTheme.tealAccent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.stars,
                      color: AppTheme.tealAccent,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'SpendPal Features',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Explore all the powerful features at your fingertips',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Expense Management
          _buildCategorySection(
            context,
            title: 'Expense Management',
            icon: Icons.account_balance_wallet,
            features: [
              FeatureItem(
                icon: Icons.receipt_long,
                title: 'Track Expenses',
                description: 'Add and manage personal and group expenses',
                route: '/add_expense',
                detailedDescription: 'Record all your expenses with detailed information including amount, category, date, and notes. Perfect for keeping track of both personal spending and shared group expenses.',
                howToUse: [
                  'Tap the + button on the home screen',
                  'Enter expense details (title, amount, category)',
                  'Select the date and add optional notes',
                  'Choose to split with friends or groups',
                  'Save to track the expense',
                ],
                benefits: [
                  'Never lose track of your spending',
                  'Categorize expenses for better insights',
                  'Add notes and receipts for reference',
                  'View complete expense history',
                ],
              ),
              FeatureItem(
                icon: Icons.people,
                title: 'Split with Friends',
                description: 'Split bills equally or by custom amounts',
                route: '/add_expense',
                detailedDescription: 'Easily split expenses with friends using multiple split methods. Choose equal split, unequal amounts, percentages, or shares based on your needs.',
                howToUse: [
                  'Create or add an expense',
                  'Select friends to split with',
                  'Choose split method (equal, custom, percentage, shares)',
                  'Enter individual amounts if needed',
                  'Save to automatically calculate balances',
                ],
                benefits: [
                  'Multiple split methods for flexibility',
                  'Automatic balance calculations',
                  'Track who owes what',
                  'Simplify group payments',
                ],
              ),
              FeatureItem(
                icon: Icons.groups,
                title: 'Group Expenses',
                description: 'Create groups and track shared expenses',
                route: '/home',
                tabIndex: 2,
                detailedDescription: 'Create groups for trips, roommates, events, or any shared expenses. Keep all group transactions organized in one place with clear visibility of who paid and who owes.',
                howToUse: [
                  'Go to Groups tab',
                  'Create a new group with a name',
                  'Invite friends to join',
                  'Add expenses within the group',
                  'View group balance summary',
                ],
                benefits: [
                  'Organize expenses by context',
                  'Separate personal and group spending',
                  'Track group balances independently',
                  'Perfect for trips and shared living',
                ],
              ),
              FeatureItem(
                icon: Icons.calculate,
                title: 'Balance Tracker',
                description: 'See who owes you and who you owe',
                route: '/home',
                tabIndex: 0,
                detailedDescription: 'Get a clear overview of all your balances at a glance. See total amounts owed to you, amounts you owe, and individual balances with each friend or group.',
                howToUse: [
                  'Open the app to see balance summary',
                  'View overall balance at the top',
                  'See individual friend balances',
                  'Tap on a balance to see details',
                  'Track changes over time',
                ],
                benefits: [
                  'Clear financial overview',
                  'No confusion about who owes what',
                  'Real-time balance updates',
                  'Simplify settlements',
                ],
              ),
            ],
          ),

          // Smart Auto-Import Features
          _buildCategorySection(
            context,
            title: 'Smart Auto-Import Features',
            icon: Icons.auto_awesome,
            features: [
              FeatureItem(
                icon: Icons.sms,
                title: 'Auto SMS Parsing',
                description: 'Automatically detect transactions from bank SMS',
                subtitle: 'Android only',
                detailedDescription: 'SpendPal automatically reads and parses transaction SMS from your bank to detect expenses. The app intelligently extracts amount, merchant, and transaction details without manual entry.',
                howToUse: [
                  'Grant SMS permission when prompted',
                  'App listens for bank transaction SMS',
                  'Transactions are auto-detected and parsed',
                  'Review detected transactions in SMS Queue',
                  'Approve to add to your expenses',
                ],
                benefits: [
                  'Save time on manual entry',
                  'Never miss a transaction',
                  'Accurate amount and merchant details',
                  'Automatic expense tracking',
                ],
                platformNote: 'This feature is only available on Android devices due to platform SMS access restrictions.',
              ),
              FeatureItem(
                icon: Icons.email,
                title: 'Email Transaction Import',
                description: 'Auto-import transactions from bank emails',
                subtitle: 'COMING SOON',
                detailedDescription: 'Automatically parse and import transaction details from bank and payment notification emails. Works with emails from all major banks, credit cards, and payment platforms.',
                howToUse: [
                  'Connect your Gmail account',
                  'Grant email access permission',
                  'App automatically scans for transaction emails',
                  'Review detected transactions in Email Queue',
                  'Approve to add to your expenses',
                ],
                benefits: [
                  'Works across all platforms (iOS & Android)',
                  'Captures transactions from email alerts',
                  'Supports all major banks and platforms',
                  'More detailed transaction information',
                ],
                platformNote: 'Requires Gmail account and OAuth authorization for email access.',
              ),
              FeatureItem(
                icon: Icons.category,
                title: 'AI Categorization',
                description: 'Smart AI-powered expense categorization',
                detailedDescription: 'Advanced AI analyzes transaction details and automatically suggests the most appropriate category. The system learns from your patterns to provide increasingly accurate categorizations.',
                howToUse: [
                  'Add an expense or approve SMS/email transaction',
                  'AI automatically suggests a category',
                  'Review the suggested category',
                  'Accept or change to your preference',
                  'AI learns from your corrections',
                ],
                benefits: [
                  'Intelligent category suggestions',
                  'Learns from your behavior',
                  'Reduces manual categorization',
                  'Improves analytics accuracy',
                ],
              ),
              FeatureItem(
                icon: Icons.inbox,
                title: 'Transaction Queue',
                description: 'Review and approve detected transactions',
                detailedDescription: 'All auto-detected transactions from SMS and emails are queued for your review before being added to expenses. This gives you full control and prevents unwanted transactions from being tracked.',
                howToUse: [
                  'Receive transaction notification (SMS/email)',
                  'Check Transaction Queue for pending items',
                  'Review parsed transaction details',
                  'Approve to add or reject to ignore',
                  'Approved items become expenses',
                ],
                benefits: [
                  'Review before adding',
                  'Prevent duplicate entries',
                  'Full control over what\'s tracked',
                  'See parsing accuracy',
                ],
                platformNote: 'SMS detection is Android-only. Email detection works on all platforms.',
              ),
            ],
          ),

          // Investment Tracking
          _buildCategorySection(
            context,
            title: 'Investment Tracking',
            icon: Icons.trending_up,
            features: [
              FeatureItem(
                icon: Icons.account_balance,
                title: 'Portfolio Management',
                description: 'Track mutual funds, stocks, ETFs, and more',
                route: '/investments',
                detailedDescription: 'Comprehensive investment portfolio tracking supporting multiple asset types including mutual funds, stocks, ETFs, bonds, and more. Monitor your complete investment portfolio in one place.',
                howToUse: [
                  'Navigate to Investments tab',
                  'Add your holdings manually or via SMS',
                  'View portfolio value and allocation',
                  'Track individual asset performance',
                  'Monitor overall portfolio returns',
                ],
                benefits: [
                  'Unified view of all investments',
                  'Support for multiple asset types',
                  'Real-time portfolio tracking',
                  'Performance monitoring',
                ],
              ),
              FeatureItem(
                icon: Icons.sms_outlined,
                title: 'Investment SMS Import',
                description: 'Auto-import from AMC/broker SMS messages',
                route: '/investment_sms_review',
                subtitle: 'NEW',
                detailedDescription: 'Automatically parse and import investment transactions from SMS sent by AMCs (Asset Management Companies) and stock brokers. Supports mutual fund purchases, SIPs, redemptions, dividend credits, stock trades, and NAV updates.',
                howToUse: [
                  'Grant SMS permission to the app',
                  'Receive investment SMS from AMC/broker',
                  'App auto-detects and parses details',
                  'Review in Investment SMS Review screen',
                  'Approve to add to your portfolio',
                ],
                benefits: [
                  'Zero manual entry for investments',
                  'Accurate transaction details',
                  'Supports all major AMCs and brokers',
                  'Tracks SIPs, dividends, and trades',
                ],
                platformNote: 'Investment SMS Import is only available on Android devices.',
              ),
              FeatureItem(
                icon: Icons.mark_email_read,
                title: 'Investment Email Import',
                description: 'Auto-import from AMC/broker emails',
                subtitle: 'COMING SOON',
                detailedDescription: 'Automatically parse and import investment transactions from confirmation emails sent by AMCs and brokers. Works across all platforms and provides more detailed transaction information than SMS.',
                howToUse: [
                  'Connect your Gmail account',
                  'Grant email access permission',
                  'Receive investment confirmation emails',
                  'App auto-detects and parses details',
                  'Review and approve to add to portfolio',
                ],
                benefits: [
                  'Works on all platforms (iOS & Android)',
                  'More detailed than SMS (contract notes, NAV details)',
                  'Supports all AMCs and brokers',
                  'Tracks purchases, redemptions, dividends',
                ],
                platformNote: 'Requires Gmail account and OAuth authorization for email access.',
              ),
              FeatureItem(
                icon: Icons.add_chart,
                title: 'Manual Transactions',
                description: 'Add buy, sell, SIP, and dividend transactions',
                route: '/investments',
                detailedDescription: 'Manually record investment transactions for complete portfolio tracking. Add purchases, sales, SIP installments, dividend credits, and other investment activities with detailed information.',
                howToUse: [
                  'Go to Investments screen',
                  'Tap Add Transaction button',
                  'Select transaction type (Buy/Sell/SIP/Dividend)',
                  'Enter asset details and amount',
                  'Save to update portfolio',
                ],
                benefits: [
                  'Record all transaction types',
                  'Complete transaction history',
                  'Accurate cost basis tracking',
                  'Detailed portfolio records',
                ],
              ),
              FeatureItem(
                icon: Icons.pie_chart,
                title: 'Asset Allocation',
                description: 'View portfolio breakdown by asset type',
                route: '/investments',
                detailedDescription: 'Visualize your investment portfolio distribution across different asset classes. See how your investments are allocated between equity, debt, gold, and other asset types.',
                howToUse: [
                  'Open Investments screen',
                  'View pie chart of asset allocation',
                  'See percentage breakdown',
                  'Tap segments for detailed view',
                  'Monitor allocation changes over time',
                ],
                benefits: [
                  'Visual portfolio analysis',
                  'Asset class diversification tracking',
                  'Easy rebalancing insights',
                  'Risk profile monitoring',
                ],
              ),
              FeatureItem(
                icon: Icons.attach_money,
                title: 'P&L Tracking',
                description: 'Monitor gains, losses, and returns',
                route: '/investments',
                detailedDescription: 'Track your investment profit and loss with detailed analytics. Monitor unrealized gains, realized profits, dividend income, and overall portfolio returns.',
                howToUse: [
                  'Navigate to Investments screen',
                  'View overall P&L summary',
                  'See individual asset returns',
                  'Check realized vs unrealized gains',
                  'Monitor return percentages',
                ],
                benefits: [
                  'Clear profit/loss visibility',
                  'Track investment performance',
                  'Dividend income tracking',
                  'Investment decision insights',
                ],
              ),
            ],
          ),

          // Bill & Receipt Management
          _buildCategorySection(
            context,
            title: 'Bill & Receipt Management',
            icon: Icons.receipt,
            features: [
              FeatureItem(
                icon: Icons.camera_alt,
                title: 'Bill Upload',
                description: 'Scan and upload bills with AI parsing',
                route: '/home',
                tabIndex: 1,
                detailedDescription: 'Take photos of bills and receipts to automatically extract key information. AI-powered parsing identifies total amount, merchant name, date, and line items for accurate expense tracking.',
                howToUse: [
                  'Go to Activity tab',
                  'Tap camera icon to capture bill',
                  'AI automatically extracts details',
                  'Review and edit parsed information',
                  'Save to create expense with receipt',
                ],
                benefits: [
                  'No manual typing required',
                  'Accurate OCR text extraction',
                  'Attach receipts to expenses',
                  'Digital backup of physical bills',
                ],
              ),
              FeatureItem(
                icon: Icons.qr_code_scanner,
                title: 'QR Code Scanner',
                description: 'Scan QR codes for quick payments',
                route: '/scan_qr',
                detailedDescription: 'Scan UPI QR codes and payment QR codes to quickly capture payment details. Useful for recording payments made via QR code scanning.',
                howToUse: [
                  'Tap QR scanner button',
                  'Point camera at QR code',
                  'App extracts payment information',
                  'Confirm details and amount',
                  'Save as expense or payment',
                ],
                benefits: [
                  'Quick payment recording',
                  'Accurate merchant details',
                  'No typing needed',
                  'UPI QR code support',
                ],
              ),
              FeatureItem(
                icon: Icons.document_scanner,
                title: 'Receipt Scanner',
                description: 'Extract items and amounts from receipts',
                route: '/home',
                tabIndex: 1,
                detailedDescription: 'Advanced receipt scanning that extracts individual line items, quantities, and prices. Perfect for detailed expense tracking with itemized breakdowns.',
                howToUse: [
                  'Navigate to Activity tab',
                  'Use camera to scan receipt',
                  'View extracted line items',
                  'Edit or confirm items',
                  'Save detailed expense record',
                ],
                benefits: [
                  'Itemized expense tracking',
                  'Price and quantity extraction',
                  'Detailed purchase records',
                  'Better expense categorization',
                ],
              ),
            ],
          ),

          // Social Features
          _buildCategorySection(
            context,
            title: 'Social Features',
            icon: Icons.people_outline,
            features: [
              FeatureItem(
                icon: Icons.person_add,
                title: 'Add Friends',
                description: 'Connect with friends to split expenses',
                route: '/home',
                tabIndex: 3,
                detailedDescription: 'Build your network by adding friends via email search. Once connected, you can split expenses, track balances, and settle payments with them.',
                howToUse: [
                  'Go to Friends tab',
                  'Tap Add Friend button',
                  'Search by email address',
                  'Send friend request with optional nickname',
                  'Wait for them to accept',
                ],
                benefits: [
                  'Easy friend discovery',
                  'Custom nicknames for friends',
                  'Privacy-focused consent system',
                  'Build your expense network',
                ],
              ),
              FeatureItem(
                icon: Icons.group_add,
                title: 'Create Groups',
                description: 'Form groups for trips, roommates, etc.',
                route: '/home',
                tabIndex: 2,
                detailedDescription: 'Organize expenses by creating groups for different contexts like trips, roommates, projects, or events. Each group has its own balance tracking and expense history.',
                howToUse: [
                  'Navigate to Groups tab',
                  'Tap Create Group button',
                  'Enter group name and details',
                  'Invite friends to join',
                  'Start adding group expenses',
                ],
                benefits: [
                  'Organize by context',
                  'Invite unlimited members',
                  'Separate group balances',
                  'Perfect for trips and events',
                ],
              ),
              FeatureItem(
                icon: Icons.notifications,
                title: 'Friend Requests',
                description: 'Accept or decline friend invitations',
                detailedDescription: 'Manage incoming friend requests with full control. Review who wants to connect and accept or decline based on your preferences. The consent-based system ensures privacy.',
                howToUse: [
                  'Receive friend request notification',
                  'Open Pending Requests screen',
                  'View sender details and nickname',
                  'Accept to become friends',
                  'Or decline to reject request',
                ],
                benefits: [
                  'Full control over connections',
                  'See who sent the request',
                  'Review before accepting',
                  'Privacy protection',
                ],
              ),
              FeatureItem(
                icon: Icons.mail,
                title: 'Group Invitations',
                description: 'Join groups via invitation',
                detailedDescription: 'Receive and manage group invitations from friends. Accept to join groups and start sharing expenses, or decline if not interested. All group additions require your consent.',
                howToUse: [
                  'Receive group invitation',
                  'Check Pending Requests screen',
                  'View group details and inviter',
                  'Accept to join the group',
                  'Or decline the invitation',
                ],
                benefits: [
                  'Join groups selectively',
                  'See who invited you',
                  'Consent-based privacy',
                  'Easy group onboarding',
                ],
              ),
            ],
          ),

          // Settlements & Payments
          _buildCategorySection(
            context,
            title: 'Settlements & Payments',
            icon: Icons.payments,
            features: [
              FeatureItem(
                icon: Icons.check_circle,
                title: 'Settle Up',
                description: 'Record payments to settle balances',
                detailedDescription: 'Record when you pay someone or receive payment to settle balances. The app automatically updates all relevant balances and tracks the settlement history.',
                howToUse: [
                  'View balance with a friend or group',
                  'Tap Settle Up button',
                  'Enter payment amount',
                  'Select payment method',
                  'Confirm to update balances',
                ],
                benefits: [
                  'Clear balance tracking',
                  'Payment history records',
                  'Automatic balance updates',
                  'Multiple payment methods',
                ],
              ),
              FeatureItem(
                icon: Icons.verified,
                title: 'Payment Verification',
                description: 'Confirm received payments',
                detailedDescription: 'Verify payments received from friends to ensure both parties agree on settlements. This adds accountability and prevents disputes.',
                howToUse: [
                  'Receive payment notification',
                  'Review payment details',
                  'Verify amount received',
                  'Confirm to settle balance',
                  'Both balances updated',
                ],
                benefits: [
                  'Two-party verification',
                  'Prevent disputes',
                  'Payment accountability',
                  'Clear settlement records',
                ],
              ),
              FeatureItem(
                icon: Icons.history,
                title: 'Settlement History',
                description: 'View all past settlements',
                route: '/home',
                tabIndex: 4,
                detailedDescription: 'Access complete history of all settlements and payments. See when payments were made, amounts, and who was involved.',
                howToUse: [
                  'Go to Activity tab',
                  'View settlement transactions',
                  'Filter by date or person',
                  'See payment details',
                  'Track settlement patterns',
                ],
                benefits: [
                  'Complete payment history',
                  'Settlement tracking',
                  'Dispute resolution',
                  'Financial records',
                ],
              ),
            ],
          ),

          // Analytics & Insights
          _buildCategorySection(
            context,
            title: 'Analytics & Insights',
            icon: Icons.bar_chart,
            features: [
              FeatureItem(
                icon: Icons.analytics,
                title: 'Spending Analytics',
                description: 'View charts and trends of your spending',
                detailedDescription: 'Visualize your spending patterns with interactive charts and graphs. See trends over time, identify spending peaks, and make informed financial decisions.',
                howToUse: [
                  'Navigate to Analytics screen',
                  'View spending charts',
                  'Select different time periods',
                  'Analyze spending trends',
                  'Identify patterns',
                ],
                benefits: [
                  'Visual spending insights',
                  'Trend identification',
                  'Better financial awareness',
                  'Data-driven decisions',
                ],
              ),
              FeatureItem(
                icon: Icons.category,
                title: 'Category Breakdown',
                description: 'See spending by category',
                detailedDescription: 'Understand where your money goes with detailed category breakdowns. See percentage distribution and amounts spent in each category.',
                howToUse: [
                  'Open Analytics screen',
                  'View category pie chart',
                  'See percentage breakdown',
                  'Compare category spending',
                  'Identify top categories',
                ],
                benefits: [
                  'Category-wise insights',
                  'Spending distribution',
                  'Budget planning help',
                  'Expense optimization',
                ],
              ),
              FeatureItem(
                icon: Icons.calendar_month,
                title: 'Monthly Reports',
                description: 'Track month-over-month spending',
                detailedDescription: 'Get comprehensive monthly spending reports. Compare months, track changes, and monitor your financial progress over time.',
                howToUse: [
                  'Access Analytics section',
                  'Select monthly view',
                  'Compare different months',
                  'View spending summaries',
                  'Track monthly trends',
                ],
                benefits: [
                  'Month-to-month comparison',
                  'Spending trend tracking',
                  'Budget monitoring',
                  'Financial progress insights',
                ],
              ),
            ],
          ),

          // Data Management
          _buildCategorySection(
            context,
            title: 'Data Management',
            icon: Icons.cloud,
            features: [
              FeatureItem(
                icon: Icons.upload_file,
                title: 'Import from Splitwise',
                description: 'Import your Splitwise data via CSV',
                detailedDescription: 'Seamlessly migrate from Splitwise by importing your expense data via CSV export. All expenses, groups, and balances are imported automatically.',
                howToUse: [
                  'Export CSV from Splitwise',
                  'Go to Account > Import from Splitwise',
                  'Select CSV file',
                  'Review import preview',
                  'Confirm to import data',
                ],
                benefits: [
                  'Easy Splitwise migration',
                  'No data loss',
                  'Automatic expense import',
                  'Preserve history',
                ],
              ),
              FeatureItem(
                icon: Icons.download,
                title: 'Export Data',
                description: 'Download your expense data',
                detailedDescription: 'Export all your expense data in standard formats for backup or analysis. Download expenses, transactions, and balances anytime.',
                howToUse: [
                  'Go to Account settings',
                  'Select Export Data',
                  'Choose date range and format',
                  'Confirm export',
                  'Download your data file',
                ],
                benefits: [
                  'Data backup',
                  'External analysis',
                  'Data portability',
                  'Record keeping',
                ],
              ),
              FeatureItem(
                icon: Icons.sync,
                title: 'Cloud Sync',
                description: 'Real-time sync across devices',
                detailedDescription: 'All your data is automatically synced to the cloud in real-time. Access your expenses from any device, always up-to-date.',
                howToUse: [
                  'Sign in to your account',
                  'Data syncs automatically',
                  'Access from any device',
                  'Changes sync instantly',
                  'Never lose data',
                ],
                benefits: [
                  'Multi-device access',
                  'Real-time updates',
                  'Automatic backup',
                  'Data security',
                ],
              ),
            ],
          ),

          // Customization
          _buildCategorySection(
            context,
            title: 'Customization',
            icon: Icons.palette,
            features: [
              FeatureItem(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                description: 'Switch between light and dark themes',
                detailedDescription: 'Choose between light and dark themes based on your preference or lighting conditions. Easy on the eyes with a beautiful dark color scheme.',
                howToUse: [
                  'Go to Account settings',
                  'Find Theme toggle',
                  'Switch between Light/Dark',
                  'App updates instantly',
                  'Preference is saved',
                ],
                benefits: [
                  'Reduced eye strain',
                  'Better night viewing',
                  'Battery savings on OLED',
                  'Personal preference',
                ],
              ),
              FeatureItem(
                icon: Icons.currency_exchange,
                title: 'Multi-Currency',
                description: 'Support for 150+ currencies',
                detailedDescription: 'Track expenses in any of 150+ supported currencies. Perfect for international use, travel, or multi-currency transactions.',
                howToUse: [
                  'Go to Account > Currency',
                  'Browse currency list',
                  'Select your currency',
                  'All amounts display in your currency',
                  'Change anytime',
                ],
                benefits: [
                  '150+ currencies supported',
                  'Perfect for travelers',
                  'Accurate currency symbols',
                  'International use',
                ],
              ),
              FeatureItem(
                icon: Icons.language,
                title: 'Localization',
                description: 'Multiple language support',
                detailedDescription: 'Use SpendPal in your preferred language with comprehensive localization support. Interface and content adapt to your language choice.',
                howToUse: [
                  'Go to Account > Language',
                  'Select preferred language',
                  'App updates interface',
                  'All text translates',
                  'Preference saved',
                ],
                benefits: [
                  'Native language support',
                  'Better user experience',
                  'Global accessibility',
                  'Cultural adaptation',
                ],
              ),
            ],
          ),

          // Footer
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.tealAccent,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'More features coming soon!',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We\'re constantly working on new features to make expense tracking even better.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<FeatureItem> features,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppTheme.tealAccent,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...features.map((feature) => _buildFeatureCard(context, feature)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, FeatureItem feature) {
    final theme = Theme.of(context);
    final hasAction = feature.route != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.tealAccent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.tealAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              feature.icon,
              color: AppTheme.tealAccent,
              size: 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  feature.title,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (feature.subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.tealAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    feature.subtitle!,
                    style: const TextStyle(
                      color: AppTheme.tealAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              feature.description,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ),
          children: [
            // Detailed information section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.tealAccent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (feature.detailedDescription != null) ...[
                    Text(
                      'About',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feature.detailedDescription!,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (feature.howToUse != null) ...[
                    Text(
                      'How to Use',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...feature.howToUse!.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppTheme.tealAccent.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${entry.key + 1}',
                                  style: const TextStyle(
                                    color: AppTheme.tealAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                  if (feature.benefits != null && feature.benefits!.isNotEmpty) ...[
                    Text(
                      'Benefits',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...feature.benefits!.map((benefit) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.tealAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                benefit,
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                  if (feature.platformNote != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature.platformNote!,
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (hasAction) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (feature.tabIndex != null) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/home',
                              (route) => false,
                            );
                          } else {
                            Navigator.pushNamed(context, feature.route!);
                          }
                        },
                        style: AppTheme.primaryButtonStyle,
                        icon: const Icon(Icons.launch, size: 18),
                        label: const Text('Try Now'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeatureItem {
  final IconData icon;
  final String title;
  final String description;
  final String? subtitle;
  final String? route;
  final int? tabIndex;
  final String? detailedDescription;
  final List<String>? howToUse;
  final List<String>? benefits;
  final String? platformNote;

  FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    this.subtitle,
    this.route,
    this.tabIndex,
    this.detailedDescription,
    this.howToUse,
    this.benefits,
    this.platformNote,
  });
}

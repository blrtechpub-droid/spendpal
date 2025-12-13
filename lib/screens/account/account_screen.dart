import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:spendpal/screens/account/report_bug_screen.dart';
import 'package:spendpal/screens/account/currency_selection_screen.dart';
import 'package:spendpal/screens/account/features_screen.dart';
import 'package:spendpal/screens/analytics/analytics_screen.dart';
import 'package:spendpal/screens/import/splitwise_import_screen.dart';
import 'package:spendpal/services/currency_service.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/providers/theme_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Currency? _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _loadSelectedCurrency();
  }

  Future<void> _loadSelectedCurrency() async {
    final currency = await CurrencyService.getSelectedCurrency();
    setState(() {
      _selectedCurrency = currency;
    });
  }

  Future<Map<String, dynamic>?> _getUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    return userDoc.data();
  }

  Future<void> _signOut(BuildContext context) async {
    final dialogTheme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogTheme.cardTheme.color,
        title: Text('Sign Out', style: TextStyle(color: dialogTheme.textTheme.bodyLarge?.color)),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: dialogTheme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign Out', style: TextStyle(color: dialogTheme.colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Account'),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data;
          final name = userData?['name'] ?? 'User';
          final email = currentUser?.email ?? '';
          final photoURL = userData?['photoURL'] ?? '';

          return ListView(
            children: [
              // User Profile Section
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.tealAccent.withValues(alpha: 0.2),
                      AppTheme.tealAccent.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.tealAccent.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.tealAccent.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: AppTheme.avatarRadiusLarge,
                        backgroundColor: AppTheme.tealAccent,
                        backgroundImage: photoURL.isNotEmpty
                            ? NetworkImage(photoURL)
                            : null,
                        child: photoURL.isEmpty
                            ? Text(
                                name.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.softWhite(context),
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      name,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.light ? Colors.grey[50] : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.tealAccent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppTheme.tealAccent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Edit profile feature coming soon')),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: theme.dividerTheme.color, height: 1),

              // Settings Section
              _buildSectionHeader('Settings'),
              _buildListTile(
                context,
                icon: Icons.star,
                title: 'Features',
                subtitle: 'Explore all app features',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FeaturesScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                context,
                icon: Icons.bar_chart,
                title: 'Analytics',
                subtitle: 'View spending trends and insights',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AnalyticsScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                context,
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Manage notification preferences',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications settings coming soon')),
                  );
                },
              ),
              _buildListTile(
                context,
                icon: Icons.currency_rupee,
                title: 'Currency',
                subtitle: _selectedCurrency != null
                    ? '${_selectedCurrency!.code} (${_selectedCurrency!.symbol})'
                    : 'INR (₹)',
                onTap: () async {
                  final result = await Navigator.push<Currency>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CurrencySelectionScreen(),
                    ),
                  );

                  if (result != null) {
                    setState(() {
                      _selectedCurrency = result;
                    });
                  }
                },
              ),
              _buildListTile(
                context,
                icon: Icons.language,
                title: 'Language',
                subtitle: 'English',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Language settings coming soon')),
                  );
                },
              ),
              // Theme toggle with Switch
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return ListTile(
                    leading: Icon(
                      themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                    title: Text(
                      'Theme',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      themeProvider.isDarkMode ? 'Dark' : 'Light',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    trailing: Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: (value) {
                        themeProvider.toggleTheme();
                      },
                      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTheme.tealAccent;
                        }
                        return Colors.grey;
                      }),
                      trackColor: WidgetStateProperty.resolveWith<Color>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppTheme.tealAccent.withValues(alpha: 0.5);
                        }
                        return Colors.grey.withValues(alpha: 0.3);
                      }),
                    ),
                  );
                },
              ),

              Divider(color: theme.dividerTheme.color, height: 1),

              // Data & Privacy Section
              _buildSectionHeader('Data & Privacy'),
              _buildListTile(
                context,
                icon: Icons.download,
                title: 'Export Data',
                subtitle: 'Download your expense data',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export data feature coming soon')),
                  );
                },
              ),
              _buildListTile(
                context,
                icon: Icons.upload,
                title: 'Import from Splitwise',
                subtitle: 'Import expenses from Splitwise CSV',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SplitwiseImportScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                context,
                icon: Icons.delete_forever,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete account feature coming soon')),
                  );
                },
                textColor: AppTheme.errorColor,
              ),

              Divider(color: theme.dividerTheme.color, height: 1),

              // Help & Support Section
              _buildSectionHeader('Help & Support'),
              _buildListTile(
                context,
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Help center coming soon')),
                  );
                },
              ),
              _buildListTile(
                context,
                icon: Icons.bug_report,
                title: 'Report a Bug',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReportBugScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                context,
                icon: Icons.feedback,
                title: 'Send Feedback',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feedback feature coming soon')),
                  );
                },
              ),

              Divider(color: theme.dividerTheme.color, height: 1),

              // About Section
              _buildSectionHeader('About'),
              _buildListTile(
                context,
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: '1.0.0',
                onTap: null,
              ),
              _buildListTile(
                context,
                icon: Icons.description,
                title: 'Terms of Service',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Terms of Service coming soon')),
                  );
                },
              ),
              _buildListTile(
                context,
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Privacy Policy coming soon')),
                  );
                },
              ),

              Divider(color: theme.dividerTheme.color, height: 1),

              // Sign Out Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                ),
              ),

              // App Info
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'SpendPal - Split expenses with friends\nMade with ❤️',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: TextStyle(
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: textColor ?? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? theme.textTheme.bodyLarge?.color,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 14),
            )
          : null,
      trailing: onTap != null
          ? Icon(Icons.chevron_right, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7))
          : null,
      onTap: onTap,
    );
  }
}

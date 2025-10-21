import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/screens/account/report_bug_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
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

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Account', style: TextStyle(color: Colors.white)),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.teal,
                      backgroundImage: photoURL.isNotEmpty
                          ? NetworkImage(photoURL)
                          : null,
                      child: photoURL.isEmpty
                          ? Text(
                              name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit profile feature coming soon')),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Profile'),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.grey, height: 1),

              // Settings Section
              _buildSectionHeader('Settings'),
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
                subtitle: 'INR (₹)',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Currency settings coming soon')),
                  );
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
              _buildListTile(
                context,
                icon: Icons.dark_mode,
                title: 'Theme',
                subtitle: 'Dark',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Theme settings coming soon')),
                  );
                },
              ),

              const Divider(color: Colors.grey, height: 1),

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
                icon: Icons.delete_forever,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete account feature coming soon')),
                  );
                },
                textColor: Colors.red,
              ),

              const Divider(color: Colors.grey, height: 1),

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

              const Divider(color: Colors.grey, height: 1),

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

              const Divider(color: Colors.grey, height: 1),

              // Sign Out Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
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
                    color: Colors.grey[600],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
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
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            )
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: Colors.white70)
          : null,
      onTap: onTap,
    );
  }
}

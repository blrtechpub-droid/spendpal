import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/screens/login/login_screen.dart';
import 'package:spendpal/screens/home/home_screen.dart';
import 'package:spendpal/theme/app_theme.dart';

/// AuthWrapper checks the authentication state on app startup
/// - If user is logged in → Navigate to HomeScreen
/// - If user is not logged in → Navigate to LoginScreen
/// - Shows splash screen while checking
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show splash screen while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // Check if user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in → Go to Home
          return const HomeScreen();
        } else {
          // User is not logged in → Go to Login
          return const LoginScreen();
        }
      },
    );
  }
}

/// Simple splash screen shown while checking authentication
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.tealAccent,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.tealAccent.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            // App Name
            const Text(
              'SpendPal',
              style: TextStyle(
                color: AppTheme.primaryText,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Loading indicator
            const CircularProgressIndicator(
              color: AppTheme.tealAccent,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}

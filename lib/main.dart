import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'firebase_options.dart';
import 'screens/auth/auth_wrapper.dart';
import 'screens/login/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/expense/expense_screen.dart';
import 'screens/qr/qr_scanner_screen.dart';
import 'screens/investments/investments_screen.dart';
import 'screens/investments/update_price_screen.dart';
import 'screens/investments/asset_detail_screen.dart';
import 'screens/investments/add_investment_transaction_screen.dart';
import 'screens/investments/add_asset_screen.dart';
import 'screens/investment/investment_sms_review_screen.dart';
import 'screens/email_transactions/email_transactions_screen.dart';
import 'screens/budget/budget_screen.dart';
import 'screens/personal/sms_processing_stats_screen.dart';
import 'screens/personal/processing_stats_screen.dart';
import 'screens/settings/currency_selector_screen.dart';
import 'models/local_transaction_model.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/currency_provider.dart';

// SMS service (automatically uses stub on iOS, real implementation on Android)
import 'services/sms_listener_service.dart';
// import 'services/email_auto_sync_service.dart'; // TODO: Complete implementation


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Capture errors not caught by Flutter (async errors)
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Disable offline persistence to avoid stale cached data
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  // Initialize SMS listener for Android only
  // On iOS, stub implementation returns false (SMS not supported)
  if (Platform.isAndroid) {
    SmsListenerService.initialize().then((success) {
      if (success) {
        print('✅ SMS auto-expense tracking enabled');
      } else {
        print('❌ SMS permissions not granted - auto-expense disabled');
      }
    }).catchError((e) {
      print('❌ SMS service error: $e');
    });
  }

  // TODO: Initialize email auto-sync service when implementation is complete
  // EmailAutoSyncService().initialize().then((_) {
  //   print('✅ Email auto-sync service initialized');
  // }).catchError((e) {
  //   print('❌ Email auto-sync error: $e');
  // });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'SpendPal',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode, // Use theme from provider
          initialRoute: '/', // Start with auth check
          routes: {
            '/': (context) => const AuthWrapper(), // Check auth state on startup
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
            '/add_expense': (context) => const AddExpenseScreen(),
            '/scan_qr': (context) => const QRScannerScreen(),
            '/budget': (context) => const BudgetScreen(),
            '/investments': (context) => const InvestmentsScreen(),
            '/update_price': (context) => const UpdatePriceScreen(),
            '/add_asset': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return AddAssetScreen(
                asset: args?['asset'],
                isEdit: args?['isEdit'] ?? false,
              );
            },
            '/add_investment_transaction': (context) => const AddInvestmentTransactionScreen(),
            '/investment_sms_review': (context) => const InvestmentSmsReviewScreen(),
            '/email_transactions': (context) => const EmailTransactionsScreen(),
            '/sms_processing_stats': (context) => const SmsProcessingStatsScreen(),
            '/processing_stats': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return ProcessingStatsScreen(
                initialSource: args?['source'],
              );
            },
            '/currency_selector': (context) => const CurrencySelectorScreen(),
            '/asset_detail': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
              return AssetDetailScreen(
                assetId: args['assetId'] as String?,
                asset: args['asset'],
              );
            },
          },
        );
      },
    );
  }
}



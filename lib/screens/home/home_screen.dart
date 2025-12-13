import 'package:flutter/material.dart';
import 'package:spendpal/screens/groups/groups_screen.dart';
import 'package:spendpal/screens/friends/friends_screen.dart';
import 'package:spendpal/screens/activity/activity_screen.dart';
import 'package:spendpal/screens/account/account_screen.dart';
import 'package:spendpal/screens/debts/debts_screen.dart';
import 'package:spendpal/screens/personal/personal_screen.dart';
import 'package:spendpal/screens/personal/bill_upload_screen.dart';
import 'package:spendpal/widgets/FloatingButtons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs =  [
    const DebtsScreen(), // Balances/Debts tab (like Splitwise)
    const PersonalExpensesScreen(), // Personal expenses with SMS/Statements/Receipts/Tracker
    GroupsScreen(),
    const FriendsScreen(),
    ActivityScreen(),
    const AccountScreen(),
  ];

  void _handleAddExpense(BuildContext context) {
    Navigator.pushNamed(context, '/add_expense');
  }

  void _handleScan(BuildContext context) {
    Navigator.pushNamed(context, '/scan_qr');
  }

  void _handleUploadBill(BuildContext context) {
    // Navigate to bill upload screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BillUploadScreen(),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Balances'),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Personal'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Activity'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
      floatingActionButton: FloatingButtons(
        onAddExpense: () => Navigator.pushNamed(context, '/add_expense'),
        onScan: () => Navigator.pushNamed(context, '/scan_qr'),
        onUploadBill: () => _handleUploadBill(context),
      ),
    );
  }
}
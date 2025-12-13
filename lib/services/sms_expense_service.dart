import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/models/sms_expense_model.dart';

class SmsExpenseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get stream of pending SMS expenses for current user
  static Stream<List<SmsExpenseModel>> getPendingSmsExpenses() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('sms_expenses')
        .where('userId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('date', descending: true)
        .snapshots()
        .handleError((error) {
          print('Error loading SMS expenses: $error');
          // Return empty list on error instead of breaking the stream
          return [];
        })
        .map((snapshot) => snapshot.docs
            .map((doc) => SmsExpenseModel.fromDocument(doc))
            .toList())
        .handleError((error) {
          print('Error parsing SMS expenses: $error');
          return <SmsExpenseModel>[];
        });
  }

  /// Get count of pending SMS expenses
  static Future<int> getPendingCount() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return 0;
    }

    final snapshot = await _firestore
        .collection('sms_expenses')
        .where('userId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  /// Categorize SMS expense as personal expense
  static Future<String?> categorizeAsPersonal(SmsExpenseModel smsExpense) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create expense in main collection
      final expenseData = {
        'title': smsExpense.merchant,
        'amount': smsExpense.amount,
        'notes':
            'Auto-imported from SMS\n${smsExpense.accountInfo ?? ""}\nTxn: ${smsExpense.transactionId ?? "N/A"}',
        'date': Timestamp.fromDate(smsExpense.date),
        'paidBy': currentUser.uid,
        'splitWith': [currentUser.uid], // Personal expense
        'splitDetails': {currentUser.uid: smsExpense.amount},
        'splitMethod': 'equal',
        'category': smsExpense.category,
        'groupId': null, // Personal expense, no group
        'isFromBill': true, // Mark as auto-imported
        'billMetadata': {
          'source': 'sms',
          'sender': smsExpense.smsSender,
          'rawSms': smsExpense.rawSms,
          'transactionId': smsExpense.transactionId,
          'accountInfo': smsExpense.accountInfo,
          'parsedAt': Timestamp.fromDate(smsExpense.parsedAt),
          'smsExpenseId': smsExpense.id,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final expenseDoc = await _firestore.collection('expenses').add(expenseData);

      // Update SMS expense status
      await _firestore.collection('sms_expenses').doc(smsExpense.id).update({
        'status': 'categorized',
        'categorizedAt': FieldValue.serverTimestamp(),
        'linkedExpenseId': expenseDoc.id,
      });

      return expenseDoc.id;
    } catch (e) {
      print('Error categorizing SMS expense as personal: $e');
      return null;
    }
  }

  /// Categorize SMS expense as salary (add to Money Tracker)
  static Future<String?> categorizeAsSalary(SmsExpenseModel smsExpense) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Extract month and year from transaction date
      final date = smsExpense.date;
      final month = date.month;
      final year = date.year;

      // Create salary record in salaryRecords collection
      final salaryData = {
        'userId': currentUser.uid,
        'amount': smsExpense.amount,
        'month': month,
        'year': year,
        'source': 'sms', // Mark as auto-imported from SMS
        'notes': 'Auto-imported from SMS\n${smsExpense.merchant}\nAccount: ${smsExpense.accountInfo ?? "N/A"}\nTxn: ${smsExpense.transactionId ?? "N/A"}',
        'smsMetadata': {
          'sender': smsExpense.smsSender,
          'rawSms': smsExpense.rawSms,
          'transactionId': smsExpense.transactionId,
          'accountInfo': smsExpense.accountInfo,
          'parsedAt': Timestamp.fromDate(smsExpense.parsedAt),
          'smsExpenseId': smsExpense.id,
          'transactionDate': Timestamp.fromDate(date),
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      final salaryDoc = await _firestore.collection('salaryRecords').add(salaryData);

      // Update SMS expense status
      await _firestore.collection('sms_expenses').doc(smsExpense.id).update({
        'status': 'categorized',
        'categorizedAt': FieldValue.serverTimestamp(),
        'linkedExpenseId': salaryDoc.id, // Link to salary record
      });

      return salaryDoc.id;
    } catch (e) {
      print('Error categorizing SMS expense as salary: $e');
      return null;
    }
  }

  /// Mark SMS expense as categorized (when user manually creates expense from it)
  static Future<bool> markAsCategorized(String smsExpenseId, String expenseId) async {
    try {
      await _firestore.collection('sms_expenses').doc(smsExpenseId).update({
        'status': 'categorized',
        'categorizedAt': FieldValue.serverTimestamp(),
        'linkedExpenseId': expenseId,
      });
      return true;
    } catch (e) {
      print('Error marking SMS expense as categorized: $e');
      return false;
    }
  }

  /// Ignore SMS expense (mark as ignored, hide from pending list)
  static Future<bool> ignoreSmsExpense(String smsExpenseId) async {
    try {
      await _firestore.collection('sms_expenses').doc(smsExpenseId).update({
        'status': 'ignored',
        'categorizedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error ignoring SMS expense: $e');
      return false;
    }
  }

  /// Delete SMS expense permanently
  static Future<bool> deleteSmsExpense(String smsExpenseId) async {
    try {
      await _firestore.collection('sms_expenses').doc(smsExpenseId).delete();
      return true;
    } catch (e) {
      print('Error deleting SMS expense: $e');
      return false;
    }
  }

  /// Get all SMS expenses (for history/review)
  static Future<List<SmsExpenseModel>> getAllSmsExpenses({
    int limit = 50,
    String? status,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return [];
    }

    Query query = _firestore
        .collection('sms_expenses')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('date', descending: true)
        .limit(limit);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => SmsExpenseModel.fromDocument(doc))
        .toList();
  }

  /// Restore ignored SMS expense back to pending
  static Future<bool> restoreSmsExpense(String smsExpenseId) async {
    try {
      await _firestore.collection('sms_expenses').doc(smsExpenseId).update({
        'status': 'pending',
        'categorizedAt': null,
      });
      return true;
    } catch (e) {
      print('Error restoring SMS expense: $e');
      return false;
    }
  }
}

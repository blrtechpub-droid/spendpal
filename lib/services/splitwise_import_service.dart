import 'dart:io';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:spendpal/models/splitwise_expense_model.dart';

class SplitwiseImportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Parse Splitwise CSV file
  Future<SplitwiseImportData> parseCSV(File file) async {
    final csvString = await file.readAsString();
    final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

    if (rows.isEmpty) {
      throw Exception('CSV file is empty');
    }

    // Splitwise CSV format:
    // Date,Description,Category,Cost,Currency
    // The first row is headers
    final headers = rows[0].map((e) => e.toString().toLowerCase()).toList();

    final expenses = <SplitwiseExpense>[];
    final allUsers = <String>{};
    final expensesByUser = <String, List<SplitwiseExpense>>{};

    // Process each row (skip header)
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 5) continue; // Skip invalid rows

      try {
        final dateStr = row[0].toString();
        final description = row[1].toString();
        final category = row[2].toString();
        final costStr = row[3].toString();
        final currency = row[4].toString();

        // Parse cost
        final cost = double.tryParse(costStr) ?? 0.0;
        if (cost == 0.0) continue;

        // For simplicity, we'll parse additional columns for paidBy and owedBy
        // Splitwise exports can vary, so we'll handle a simplified format
        // Column 5: Paid by (person name)
        // Columns 6+: Split details (can be complex)

        final paidBy = row.length > 5 ? row[5].toString() : 'Unknown';

        // Parse split details - Splitwise typically has columns like:
        // "Person1 lent Person2 $X" or "Person1 paid $X, Person2 owes $Y"
        final owedBy = <String, double>{};

        // Simple case: split equally between 2 people
        if (row.length > 6) {
          final splitInfo = row[6].toString();
          // Try to parse who owes what
          // For now, we'll just track the payer and assume equal split
          if (splitInfo.isNotEmpty && splitInfo.toLowerCase() != paidBy.toLowerCase()) {
            owedBy[splitInfo] = cost / 2;
          }
        } else {
          // If no split info, assume equal split between payer and current user
          owedBy['you'] = cost / 2;
        }

        final expense = SplitwiseExpense(
          date: dateStr,
          description: description,
          category: category,
          cost: cost,
          currency: currency,
          paidBy: paidBy,
          owedBy: owedBy,
        );

        expenses.add(expense);

        // Track users
        allUsers.addAll(expense.allUsers);

        // Group by user
        for (final user in expense.allUsers) {
          expensesByUser.putIfAbsent(user, () => []);
          expensesByUser[user]!.add(expense);
        }
      } catch (e) {
        // Skip rows that can't be parsed
        continue;
      }
    }

    return SplitwiseImportData(
      allExpenses: expenses,
      allUsers: allUsers,
      expensesByUser: expensesByUser,
    );
  }

  // Import expenses to Firestore
  Future<int> importExpenses(
    List<SplitwiseExpense> expenses,
    Map<String, String> userMapping, // Splitwise name -> SpendPal UID
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    int importedCount = 0;

    for (final expense in expenses) {
      try {
        // Map Splitwise users to SpendPal UIDs
        final paidByUid = userMapping[expense.paidBy];
        if (paidByUid == null) continue; // Skip if user not mapped

        // Create split details
        final splitDetails = <String, double>{};
        final splitWith = <String>[];

        for (final entry in expense.owedBy.entries) {
          final uid = userMapping[entry.key];
          if (uid != null) {
            splitDetails[uid] = entry.value;
            splitWith.add(uid);
          }
        }

        // Only add paidBy if they're not already in splitWith
        if (!splitWith.contains(paidByUid)) {
          splitWith.add(paidByUid);
        }

        // Parse date
        DateTime? expenseDate;
        try {
          // Try common date formats
          expenseDate = DateFormat('yyyy-MM-dd').parse(expense.date);
        } catch (e) {
          try {
            expenseDate = DateFormat('M/d/yyyy').parse(expense.date);
          } catch (e2) {
            expenseDate = DateTime.now(); // Fallback to now
          }
        }

        // Create expense in Firestore
        await _firestore.collection('expenses').add({
          'title': expense.description,
          'amount': expense.cost,
          'date': Timestamp.fromDate(expenseDate),
          'category': expense.category.isNotEmpty ? expense.category : 'Other',
          'notes': 'Imported from Splitwise',
          'paidBy': paidByUid,
          'splitWith': splitWith,
          'splitDetails': splitDetails,
          'splitMethod': 'unequal',
          'groupId': null, // Not associated with any group
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        importedCount++;
      } catch (e) {
        // Skip expenses that fail to import
        continue;
      }
    }

    return importedCount;
  }

  // Get user's friends from Firestore to help with mapping
  Future<Map<String, String>> getUserFriends() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return {};

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data();
      if (userData == null) return {};

      // Friends is a Map<String, String> where key is UID and value is nickname
      final friendsMap = userData['friends'] as Map<String, dynamic>?;
      if (friendsMap == null) return {};

      // We need to flip this - we need UID -> name
      // But first we need to get the actual names from the user documents
      final friendDetails = <String, String>{};

      for (final friendUid in friendsMap.keys) {
        final friendDoc = await _firestore
            .collection('users')
            .doc(friendUid)
            .get();

        if (friendDoc.exists) {
          final friendData = friendDoc.data();
          final friendName = friendData?['name'] ?? friendsMap[friendUid] ?? 'Unknown';
          friendDetails[friendUid] = friendName;
        }
      }

      // Add current user
      friendDetails[currentUser.uid] = userData['name'] ?? 'Me';

      return friendDetails;
    } catch (e) {
      return {};
    }
  }
}

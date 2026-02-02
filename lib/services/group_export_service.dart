import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense_model.dart';

class GroupExportService {
  static final GroupExportService _instance = GroupExportService._internal();
  factory GroupExportService() => _instance;
  GroupExportService._internal();

  /// Export group expenses to CSV file
  Future<String> exportToCSV({
    required String groupId,
    required String groupName,
  }) async {
    try {
      // Fetch all group expenses
      final snapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('groupId', isEqualTo: groupId)
          .orderBy('date', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('No expenses to export');
      }

      final expenses = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ExpenseModel.fromMap(data);
          })
          .toList();

      // Fetch member names
      final memberIds = expenses.map((e) => e.paidBy).toSet().toList();
      final memberNames = await _fetchMemberNames(memberIds);

      // Create CSV data
      List<List<dynamic>> rows = [
        // Header row
        [
          'Date',
          'Description',
          'Category',
          'Amount',
          'Paid By',
          'Split With',
          'Currency',
          'Notes',
        ],
      ];

      for (final expense in expenses) {
        final paidByName = memberNames[expense.paidBy] ?? 'Unknown';
        final splitWithNames = expense.sharedWith
            .map((uid) => memberNames[uid] ?? uid)
            .join(', ');

        rows.add([
          DateFormat('yyyy-MM-dd').format(expense.date),
          expense.title,
          expense.category,
          expense.amount.toStringAsFixed(2),
          paidByName,
          splitWithNames,
          '₹', // Currency symbol
          expense.notes,
        ]);
      }

      // Generate CSV string
      String csv = const ListToCsvConverter().convert(rows);

      // Save to file
      final directory = await getTemporaryDirectory();
      final fileName =
          '${groupName.replaceAll(' ', '_')}_expenses_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(csv);

      return filePath;
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  /// Export group expenses to PDF file
  Future<String> exportToPDF({
    required String groupId,
    required String groupName,
  }) async {
    try {
      // Fetch all group expenses
      final snapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('groupId', isEqualTo: groupId)
          .orderBy('date', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('No expenses to export');
      }

      final expenses = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ExpenseModel.fromMap(data);
          })
          .toList();

      // Fetch member names
      final memberIds = expenses.map((e) => e.paidBy).toSet().toList();
      final memberNames = await _fetchMemberNames(memberIds);

      // Calculate totals
      final totalAmount = expenses.fold<double>(0, (sum, e) => sum + e.amount);
      final categoryTotals = <String, double>{};
      for (final expense in expenses) {
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0) + expense.amount;
      }

      // Create PDF document
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      groupName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Expense Report',
                      style: const pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated on ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Summary',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Expenses:'),
                        pw.Text('${expenses.length}'),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Amount:'),
                        pw.Text(
                          '₹${totalAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Average Expense:'),
                        pw.Text(
                          '₹${(totalAmount / expenses.length).toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Category Breakdown
              pw.Text(
                'Category Breakdown',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              ...categoryTotals.entries.map((entry) {
                final percentage = (entry.value / totalAmount) * 100;
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${entry.key}:'),
                      pw.Row(
                        children: [
                          pw.Text('₹${entry.value.toStringAsFixed(2)}'),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            '(${percentage.toStringAsFixed(1)}%)',
                            style: const pw.TextStyle(
                              color: PdfColors.grey600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 20),

              // Expenses Table
              pw.Text(
                'Expense Details',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerLeft,
                },
                data: [
                  // Header
                  ['Date', 'Description', 'Category', 'Amount', 'Paid By'],
                  // Data rows
                  ...expenses.map((expense) {
                    return [
                      DateFormat('MMM dd').format(expense.date),
                      expense.title.length > 30
                          ? '${expense.title.substring(0, 30)}...'
                          : expense.title,
                      expense.category,
                      '₹${expense.amount.toStringAsFixed(2)}',
                      memberNames[expense.paidBy] ?? 'Unknown',
                    ];
                  }),
                ],
              ),
            ];
          },
        ),
      );

      // Save to file
      final directory = await getTemporaryDirectory();
      final fileName =
          '${groupName.replaceAll(' ', '_')}_expenses_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      return filePath;
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  /// Share exported file
  Future<void> shareFile(String filePath, String fileName) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: fileName,
        text: 'Expense report exported from SpendPal',
      );
    } catch (e) {
      throw Exception('Failed to share file: $e');
    }
  }

  /// Export friend expenses to CSV file
  Future<String> exportFriendExpensesToCSV({
    required String currentUserId,
    required String friendId,
    required String friendName,
  }) async {
    try {
      // Fetch all non-group expenses
      final snapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('groupId', isEqualTo: null)
          .orderBy('date', descending: true)
          .get();

      // Filter for friend expenses
      final friendExpenses = snapshot.docs
          .where((doc) {
            final splitWith = List<String>.from(doc['splitWith'] ?? doc['sharedWith'] ?? []);
            return splitWith.contains(currentUserId) && splitWith.contains(friendId);
          })
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ExpenseModel.fromMap(data);
          })
          .toList();

      if (friendExpenses.isEmpty) {
        throw Exception('No expenses to export');
      }

      // Fetch member names
      final memberIds = [currentUserId, friendId];
      final memberNames = await _fetchMemberNames(memberIds);

      // Create CSV data
      List<List<dynamic>> rows = [
        // Header row
        ['Date', 'Description', 'Category', 'Amount', 'Paid By', 'Split With', 'Currency', 'Notes'],
      ];

      for (final expense in friendExpenses) {
        final paidByName = memberNames[expense.paidBy] ?? 'Unknown';
        final splitWithNames = expense.sharedWith
            .map((uid) => memberNames[uid] ?? uid)
            .join(', ');

        rows.add([
          DateFormat('yyyy-MM-dd').format(expense.date),
          expense.title,
          expense.category,
          expense.amount.toStringAsFixed(2),
          paidByName,
          splitWithNames,
          '₹',
          expense.notes,
        ]);
      }

      // Generate CSV string
      String csv = const ListToCsvConverter().convert(rows);

      // Save to file
      final directory = await getTemporaryDirectory();
      final fileName =
          '${friendName.replaceAll(' ', '_')}_expenses_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(csv);

      return filePath;
    } catch (e) {
      throw Exception('Failed to export friend CSV: $e');
    }
  }

  /// Export friend expenses to PDF file
  Future<String> exportFriendExpensesToPDF({
    required String currentUserId,
    required String friendId,
    required String friendName,
  }) async {
    try {
      // Fetch all non-group expenses
      final snapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('groupId', isEqualTo: null)
          .orderBy('date', descending: true)
          .get();

      // Filter for friend expenses
      final friendExpenses = snapshot.docs
          .where((doc) {
            final splitWith = List<String>.from(doc['splitWith'] ?? doc['sharedWith'] ?? []);
            return splitWith.contains(currentUserId) && splitWith.contains(friendId);
          })
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ExpenseModel.fromMap(data);
          })
          .toList();

      if (friendExpenses.isEmpty) {
        throw Exception('No expenses to export');
      }

      // Fetch member names
      final memberIds = [currentUserId, friendId];
      final memberNames = await _fetchMemberNames(memberIds);

      // Calculate totals
      final totalAmount = friendExpenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );

      // Create PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 16),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 2),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Friend Expenses with $friendName',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Expense Report',
                      style: const pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated on ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Summary',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Expenses:'),
                        pw.Text('${friendExpenses.length}'),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Amount:'),
                        pw.Text('₹${totalAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Expenses Table
              pw.Text(
                'Expense Details',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.teal,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['Date', 'Description', 'Category', 'Amount', 'Paid By'],
                data: friendExpenses.map((expense) {
                  return [
                    DateFormat('MMM dd, yyyy').format(expense.date),
                    expense.title,
                    expense.category,
                    '₹${expense.amount.toStringAsFixed(2)}',
                    memberNames[expense.paidBy] ?? 'Unknown',
                  ];
                }).toList(),
              ),
            ];
          },
        ),
      );

      // Save to file
      final directory = await getTemporaryDirectory();
      final fileName =
          '${friendName.replaceAll(' ', '_')}_expenses_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      return filePath;
    } catch (e) {
      throw Exception('Failed to export friend PDF: $e');
    }
  }

  /// Fetch member names from Firestore
  Future<Map<String, String>> _fetchMemberNames(List<String> userIds) async {
    final names = <String, String>{};
    for (final userId in userIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        names[userId] = doc.data()?['name'] ?? 'Unknown';
      } catch (e) {
        names[userId] = userId;
      }
    }
    return names;
  }
}

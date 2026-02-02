import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String groupId; // Can be empty for personal expenses
  final String title;
  final double amount;
  final String paidBy; // uid
  final List<String> sharedWith; // list of uids
  final DateTime date;
  final String notes;

  // New fields for bill parsing
  final String category; // Food, Travel, Shopping, etc.
  final List<String> tags; // Optional tags
  final String? billImageUrl; // Firebase Storage URL for uploaded bill
  final bool isFromBill; // Track if expense was created from bill upload
  final Map<String, dynamic>? billMetadata; // Store parsing info (parsedBy, bankName, etc.)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.sharedWith,
    required this.date,
    required this.notes,
    this.category = 'Other',
    this.tags = const [],
    this.billImageUrl,
    this.isFromBill = false,
    this.billMetadata,
    this.createdAt,
    this.updatedAt,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> data) {
    return ExpenseModel(
      id: data['id'] ?? '',
      groupId: data['groupId'] ?? '',
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      paidBy: data['paidBy'] ?? '',
      // Support both 'sharedWith' and 'splitWith' field names
      sharedWith: List<String>.from(data['sharedWith'] ?? data['splitWith'] ?? []),
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      notes: data['notes'] ?? '',
      category: data['category'] ?? 'Other',
      tags: List<String>.from(data['tags'] ?? []),
      billImageUrl: data['billImageUrl'],
      isFromBill: data['isFromBill'] ?? false,
      billMetadata: data['billMetadata'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'paidBy': paidBy,
      'sharedWith': sharedWith,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'category': category,
      'tags': tags,
      'billImageUrl': billImageUrl,
      'isFromBill': isFromBill,
      'billMetadata': billMetadata,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Helper method to create expense from parsed transaction
  factory ExpenseModel.fromTransaction({
    required String id,
    required String title,
    required double amount,
    required String paidBy,
    required DateTime date,
    required String category,
    String groupId = '',
    List<String> sharedWith = const [],
    String notes = '',
    List<String> tags = const [],
    String? billImageUrl,
    Map<String, dynamic>? billMetadata,
  }) {
    return ExpenseModel(
      id: id,
      groupId: groupId,
      title: title,
      amount: amount,
      paidBy: paidBy,
      sharedWith: sharedWith,
      date: date,
      notes: notes,
      category: category,
      tags: tags,
      billImageUrl: billImageUrl,
      isFromBill: true,
      billMetadata: billMetadata,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
/// Model for individual transactions parsed from a bill
/// Used in the transaction review screen before creating expenses
class TransactionModel {
  final String id; // Temporary ID for UI state management
  final String date; // ISO format date string (YYYY-MM-DD)
  final String merchant; // Merchant/vendor name
  final double amount;
  final String category; // Inferred category (Food, Travel, etc.)

  // UI state for transaction review
  bool isSelected; // Whether user selected this transaction
  String assignedTo; // 'self', 'friend:<uid>', 'group:<groupId>'
  String? assignedToName; // Display name for UI
  String? notes; // Optional notes added by user

  TransactionModel({
    required this.id,
    required this.date,
    required this.merchant,
    required this.amount,
    required this.category,
    this.isSelected = true, // Selected by default
    this.assignedTo = 'self',
    this.assignedToName,
    this.notes,
  });

  // Parse from backend API response
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: json['date'] ?? '',
      merchant: json['merchant'] ?? 'Unknown Merchant',
      amount: (json['amount'] ?? 0).toDouble(),
      category: json['category'] ?? 'Other',
      isSelected: json['isSelected'] ?? true,
      assignedTo: json['assignedTo'] ?? 'self',
      assignedToName: json['assignedToName'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'merchant': merchant,
      'amount': amount,
      'category': category,
      'isSelected': isSelected,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'notes': notes,
    };
  }

  // Create a copy with modified fields
  TransactionModel copyWith({
    String? id,
    String? date,
    String? merchant,
    double? amount,
    String? category,
    bool? isSelected,
    String? assignedTo,
    String? assignedToName,
    String? notes,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      merchant: merchant ?? this.merchant,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      isSelected: isSelected ?? this.isSelected,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      notes: notes ?? this.notes,
    );
  }

  // Parse date string to DateTime
  DateTime? get parsedDate {
    try {
      return DateTime.parse(date);
    } catch (e) {
      return null;
    }
  }

  // Extract assignment type and ID
  AssignmentInfo get assignmentInfo {
    if (assignedTo == 'self') {
      return AssignmentInfo(type: AssignmentType.self, id: null);
    } else if (assignedTo.startsWith('friend:')) {
      return AssignmentInfo(
        type: AssignmentType.friend,
        id: assignedTo.replaceFirst('friend:', ''),
      );
    } else if (assignedTo.startsWith('group:')) {
      return AssignmentInfo(
        type: AssignmentType.group,
        id: assignedTo.replaceFirst('group:', ''),
      );
    }
    return AssignmentInfo(type: AssignmentType.self, id: null);
  }
}

// Helper enum for assignment types
enum AssignmentType { self, friend, group }

// Helper class for assignment info
class AssignmentInfo {
  final AssignmentType type;
  final String? id;

  AssignmentInfo({required this.type, this.id});
}

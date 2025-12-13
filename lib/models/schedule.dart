import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a recurring schedule (SIP, EMI, installment)
/// Used to track and remind users of upcoming payments
class Schedule {
  final String scheduleId;
  final String userId;
  final String name; // e.g., "Axis Bluechip SIP", "Home Loan EMI"
  final String type; // 'SIP', 'EMI', 'INSTALLMENT'
  final String relatedId; // assetId for SIP, liabilityId for EMI/INSTALLMENT
  final double amount; // Scheduled amount
  final String cadence; // 'DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY'
  final int dueDay; // Day of month (1-31) for MONTHLY, day of week (1-7) for WEEKLY
  final DateTime startDate; // When schedule begins
  final DateTime? endDate; // When schedule ends (null = indefinite)
  final DateTime? nextDueDate; // Next payment due date
  final DateTime? lastExecutedDate; // Last payment date
  final bool isActive; // Whether schedule is active
  final bool sendReminder; // Whether to send reminder notifications
  final int reminderDaysBefore; // Days before due date to send reminder (default: 1)
  final List<String> tags; // User-defined tags
  final String? notes; // Additional notes
  final DateTime createdAt;
  final DateTime updatedAt;

  Schedule({
    required this.scheduleId,
    required this.userId,
    required this.name,
    required this.type,
    required this.relatedId,
    required this.amount,
    this.cadence = 'MONTHLY',
    required this.dueDay,
    required this.startDate,
    this.endDate,
    this.nextDueDate,
    this.lastExecutedDate,
    this.isActive = true,
    this.sendReminder = true,
    this.reminderDaysBefore = 1,
    this.tags = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'scheduleId': scheduleId,
      'userId': userId,
      'name': name,
      'type': type,
      'relatedId': relatedId,
      'amount': amount,
      'cadence': cadence,
      'dueDay': dueDay,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'nextDueDate': nextDueDate != null ? Timestamp.fromDate(nextDueDate!) : null,
      'lastExecutedDate': lastExecutedDate != null ? Timestamp.fromDate(lastExecutedDate!) : null,
      'isActive': isActive,
      'sendReminder': sendReminder,
      'reminderDaysBefore': reminderDaysBefore,
      'tags': tags,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create from Firestore document
  factory Schedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Schedule(
      scheduleId: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? 'SIP',
      relatedId: data['relatedId'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      cadence: data['cadence'] ?? 'MONTHLY',
      dueDay: data['dueDay'] ?? 1,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      nextDueDate: (data['nextDueDate'] as Timestamp?)?.toDate(),
      lastExecutedDate: (data['lastExecutedDate'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
      sendReminder: data['sendReminder'] ?? true,
      reminderDaysBefore: data['reminderDaysBefore'] ?? 1,
      tags: List<String>.from(data['tags'] ?? []),
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  Schedule copyWith({
    String? scheduleId,
    String? userId,
    String? name,
    String? type,
    String? relatedId,
    double? amount,
    String? cadence,
    int? dueDay,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextDueDate,
    DateTime? lastExecutedDate,
    bool? isActive,
    bool? sendReminder,
    int? reminderDaysBefore,
    List<String>? tags,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Schedule(
      scheduleId: scheduleId ?? this.scheduleId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      amount: amount ?? this.amount,
      cadence: cadence ?? this.cadence,
      dueDay: dueDay ?? this.dueDay,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      lastExecutedDate: lastExecutedDate ?? this.lastExecutedDate,
      isActive: isActive ?? this.isActive,
      sendReminder: sendReminder ?? this.sendReminder,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Helper to get schedule type display name
  String get typeDisplay {
    switch (type) {
      case 'SIP':
        return 'SIP';
      case 'EMI':
        return 'EMI';
      case 'INSTALLMENT':
        return 'Installment';
      default:
        return type;
    }
  }

  /// Helper to get cadence display name
  String get cadenceDisplay {
    switch (cadence) {
      case 'DAILY':
        return 'Daily';
      case 'WEEKLY':
        return 'Weekly';
      case 'MONTHLY':
        return 'Monthly';
      case 'QUARTERLY':
        return 'Quarterly';
      case 'YEARLY':
        return 'Yearly';
      default:
        return cadence;
    }
  }

  /// Check if payment is overdue
  bool get isOverdue {
    if (nextDueDate == null || !isActive) return false;
    return DateTime.now().isAfter(nextDueDate!);
  }

  /// Check if payment is due today
  bool get isDueToday {
    if (nextDueDate == null || !isActive) return false;
    final now = DateTime.now();
    return nextDueDate!.year == now.year &&
        nextDueDate!.month == now.month &&
        nextDueDate!.day == now.day;
  }

  /// Check if reminder should be shown
  bool get shouldShowReminder {
    if (nextDueDate == null || !isActive || !sendReminder) return false;
    final reminderDate = nextDueDate!.subtract(Duration(days: reminderDaysBefore));
    final now = DateTime.now();
    return now.isAfter(reminderDate) && now.isBefore(nextDueDate!);
  }

  /// Calculate days until next payment
  int get daysUntilNext {
    if (nextDueDate == null) return 0;
    final now = DateTime.now();
    return nextDueDate!.difference(now).inDays;
  }

  /// Calculate next due date based on cadence
  DateTime? calculateNextDueDate({DateTime? fromDate}) {
    final baseDate = fromDate ?? lastExecutedDate ?? startDate;

    switch (cadence) {
      case 'DAILY':
        return DateTime(baseDate.year, baseDate.month, baseDate.day + 1);
      case 'WEEKLY':
        return DateTime(baseDate.year, baseDate.month, baseDate.day + 7);
      case 'MONTHLY':
        // Find next occurrence of dueDay
        int nextMonth = baseDate.month + 1;
        int nextYear = baseDate.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        return DateTime(nextYear, nextMonth, dueDay.clamp(1, 28));
      case 'QUARTERLY':
        int nextMonth = baseDate.month + 3;
        int nextYear = baseDate.year;
        while (nextMonth > 12) {
          nextMonth -= 12;
          nextYear++;
        }
        return DateTime(nextYear, nextMonth, dueDay.clamp(1, 28));
      case 'YEARLY':
        return DateTime(baseDate.year + 1, baseDate.month, dueDay.clamp(1, 28));
      default:
        return null;
    }
  }
}

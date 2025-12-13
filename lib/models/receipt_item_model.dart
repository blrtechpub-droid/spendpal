import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for individual items extracted from receipts
/// This creates a searchable database of all purchased items
class ReceiptItemModel {
  final String id;
  final String receiptId; // Link to parent receipt
  final String userId;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String? category; // Auto-categorized based on item name
  final String? unit; // kg, ltr, pcs, etc.
  final DateTime purchasedAt; // Date from receipt
  final String merchant; // Store/restaurant name
  final String? notes;

  ReceiptItemModel({
    required this.id,
    required this.receiptId,
    required this.userId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.category,
    this.unit,
    required this.purchasedAt,
    required this.merchant,
    this.notes,
  });

  /// Create from Firestore document
  factory ReceiptItemModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReceiptItemModel(
      id: doc.id,
      receiptId: data['receiptId'] as String,
      userId: data['userId'] as String,
      itemName: data['itemName'] as String,
      quantity: (data['quantity'] as num).toDouble(),
      unitPrice: (data['unitPrice'] as num).toDouble(),
      totalPrice: (data['totalPrice'] as num).toDouble(),
      category: data['category'] as String?,
      unit: data['unit'] as String?,
      purchasedAt: (data['purchasedAt'] as Timestamp).toDate(),
      merchant: data['merchant'] as String,
      notes: data['notes'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'receiptId': receiptId,
      'userId': userId,
      'itemName': itemName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'category': category,
      'unit': unit,
      'purchasedAt': Timestamp.fromDate(purchasedAt),
      'merchant': merchant,
      'notes': notes,
    };
  }

  /// Calculate savings if discounted
  double get potentialDiscount => unitPrice > 0 ? (unitPrice * quantity) - totalPrice : 0;
}

/// Model for complete receipt with items
class ReceiptModel {
  final String id;
  final String userId;
  final String merchant;
  final DateTime date;
  final double totalAmount;
  final double? taxAmount;
  final double? discountAmount;
  final String? receiptNumber;
  final String? paymentMethod;
  final List<ReceiptItemModel> items;
  final String fileUrl; // Link to original receipt image/PDF
  final String? rawText; // OCR extracted text
  final DateTime uploadedAt;
  final String parsedBy; // 'regex', 'ai', 'manual'

  ReceiptModel({
    required this.id,
    required this.userId,
    required this.merchant,
    required this.date,
    required this.totalAmount,
    this.taxAmount,
    this.discountAmount,
    this.receiptNumber,
    this.paymentMethod,
    required this.items,
    required this.fileUrl,
    this.rawText,
    required this.uploadedAt,
    required this.parsedBy,
  });

  /// Create from Firestore document
  factory ReceiptModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReceiptModel(
      id: doc.id,
      userId: data['userId'] as String,
      merchant: data['merchant'] as String,
      date: (data['date'] as Timestamp).toDate(),
      totalAmount: (data['totalAmount'] as num).toDouble(),
      taxAmount: (data['taxAmount'] as num?)?.toDouble(),
      discountAmount: (data['discountAmount'] as num?)?.toDouble(),
      receiptNumber: data['receiptNumber'] as String?,
      paymentMethod: data['paymentMethod'] as String?,
      items: [], // Items loaded separately from receipt_items collection
      fileUrl: data['fileUrl'] as String,
      rawText: data['rawText'] as String?,
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      parsedBy: data['parsedBy'] as String? ?? 'ai',
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'merchant': merchant,
      'date': Timestamp.fromDate(date),
      'totalAmount': totalAmount,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'receiptNumber': receiptNumber,
      'paymentMethod': paymentMethod,
      'itemCount': items.length,
      'fileUrl': fileUrl,
      'rawText': rawText,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'parsedBy': parsedBy,
    };
  }

  /// Calculate subtotal (before tax)
  double get subtotal => totalAmount - (taxAmount ?? 0);

  /// Get category breakdown
  Map<String, double> get categoryBreakdown {
    final Map<String, double> breakdown = {};
    for (final item in items) {
      final category = item.category ?? 'Other';
      breakdown[category] = (breakdown[category] ?? 0) + item.totalPrice;
    }
    return breakdown;
  }

  /// Get most expensive item
  ReceiptItemModel? get mostExpensiveItem {
    if (items.isEmpty) return null;
    return items.reduce((a, b) => a.totalPrice > b.totalPrice ? a : b);
  }
}

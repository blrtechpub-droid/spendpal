import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:spendpal/models/receipt_item_model.dart';
import 'package:spendpal/models/regex_pattern_model.dart';
import 'package:spendpal/services/regex_pattern_service.dart';

class ReceiptUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload receipt to Firebase Storage
  Future<String> uploadReceiptToStorage(
    File file, {
    required void Function(double) onProgress,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = path.extension(file.path);
      final String fileName = 'receipt_$timestamp$extension';
      final String filePath = 'receipts/${user.uid}/$fileName';

      final Reference ref = _storage.ref().child(filePath);
      final UploadTask uploadTask = ref.putFile(file);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });

      await uploadTask;
      final String downloadURL = await ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      throw Exception('Failed to upload receipt: $e');
    }
  }

  /// Parse receipt using self-learning system: Regex First → AI Fallback
  Future<ReceiptModel> parseReceipt({
    required String fileUrl,
    String? merchant,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    print('📄 Parsing receipt...');

    // TODO: Step 1 - Try regex patterns first (when implemented)
    // Currently skipped - no regex patterns yet for receipts

    // Step 2: Use AI parsing
    print('🤖 Calling AI to parse receipt (₹1 cost)...');

    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('parseReceipt');

    final result = await callable.call({
      'fileUrl': fileUrl,
      'merchant': merchant,
    });

    final Map<String, dynamic> responseData =
        Map<String, dynamic>.from(result.data as Map);

    if (responseData['status'] != 'success') {
      throw Exception('Receipt parsing failed');
    }

    // Extract receipt metadata
    final receiptData = responseData['receipt'];
    final itemsData = responseData['items'] as List;

    // Convert items
    final items = itemsData.map((item) {
      return ReceiptItemModel(
        id: '', // Will be set when saved
        receiptId: '', // Will be set when saved
        userId: user.uid,
        itemName: item['itemName'] as String,
        quantity: (item['quantity'] as num).toDouble(),
        unitPrice: (item['unitPrice'] as num).toDouble(),
        totalPrice: (item['totalPrice'] as num).toDouble(),
        category: item['category'] as String?,
        unit: item['unit'] as String?,
        purchasedAt: DateTime.parse(receiptData['date'] as String),
        merchant: receiptData['merchant'] as String,
      );
    }).toList();

    // Step 3: Save AI-generated regex pattern
    final regexPatternData = responseData['regexPattern'];
    if (regexPatternData != null) {
      print('🎓 AI generated a regex pattern! Saving for future use...');
      try {
        final generatedPattern = GeneratedPattern(
          pattern: regexPatternData['pattern'] as String,
          description: regexPatternData['description'] as String,
          extractionMap: Map<String, int>.from(
            regexPatternData['extractionMap'] as Map,
          ),
          confidence: regexPatternData['confidence'] as int,
          categoryHint: regexPatternData['categoryHint'] as String?,
        );

        final saved = await RegexPatternService.saveReceiptPattern(
          generatedPattern: generatedPattern,
          merchant: receiptData['merchant'] as String,
          type: 'receipt',
        );

        if (saved) {
          print('✅ Regex pattern saved! Future receipts from ${receiptData['merchant']} will be FREE');
        }
      } catch (e) {
        print('⚠️ Failed to save regex pattern: $e');
      }
    }

    // Create receipt model
    final receipt = ReceiptModel(
      id: '', // Will be set when saved
      userId: user.uid,
      merchant: receiptData['merchant'] as String,
      date: DateTime.parse(receiptData['date'] as String),
      totalAmount: (receiptData['totalAmount'] as num).toDouble(),
      taxAmount: (receiptData['taxAmount'] as num?)?.toDouble(),
      discountAmount: (receiptData['discountAmount'] as num?)?.toDouble(),
      receiptNumber: receiptData['receiptNumber'] as String?,
      paymentMethod: receiptData['paymentMethod'] as String?,
      items: items,
      fileUrl: fileUrl,
      uploadedAt: DateTime.now(),
      parsedBy: 'ai',
    );

    print('✅ Receipt parsed: ${items.length} items, total: ₹${receipt.totalAmount}');
    return receipt;
  }

  /// Save receipt and items to Firestore
  Future<void> saveReceipt(ReceiptModel receipt) async {
    try {
      // Save receipt metadata
      final receiptRef = await _firestore.collection('receipts').add(receipt.toFirestore());

      // Save individual items
      final batch = _firestore.batch();

      for (final item in receipt.items) {
        final itemRef = _firestore.collection('receipt_items').doc();
        final itemWithReceipt = ReceiptItemModel(
          id: itemRef.id,
          receiptId: receiptRef.id,
          userId: item.userId,
          itemName: item.itemName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
          category: item.category,
          unit: item.unit,
          purchasedAt: item.purchasedAt,
          merchant: item.merchant,
          notes: item.notes,
        );
        batch.set(itemRef, itemWithReceipt.toFirestore());
      }

      await batch.commit();

      print('💾 Saved receipt with ${receipt.items.length} items to Firestore');
    } catch (e) {
      throw Exception('Failed to save receipt: $e');
    }
  }

  /// Complete flow: Upload, Parse, and Save
  Stream<ReceiptUploadStatus> uploadAndParseReceipt({
    required File file,
    String? merchant,
  }) async* {
    try {
      // Phase 1: Uploading
      yield ReceiptUploadStatus(
        phase: 'uploading',
        progress: 0.0,
        message: 'Uploading receipt...',
      );

      String fileUrl = await uploadReceiptToStorage(
        file,
        onProgress: (progress) {},
      );

      yield ReceiptUploadStatus(
        phase: 'uploading',
        progress: 1.0,
        message: 'Upload complete',
      );

      // Phase 2: Parsing
      yield ReceiptUploadStatus(
        phase: 'parsing',
        progress: 0.5,
        message: 'Extracting items from receipt...',
      );

      ReceiptModel receipt = await parseReceipt(
        fileUrl: fileUrl,
        merchant: merchant,
      );

      yield ReceiptUploadStatus(
        phase: 'parsing',
        progress: 1.0,
        message: 'Parsing complete',
      );

      // Phase 3: Saving
      yield ReceiptUploadStatus(
        phase: 'saving',
        progress: 0.5,
        message: 'Saving receipt data...',
      );

      await saveReceipt(receipt);

      yield ReceiptUploadStatus(
        phase: 'saving',
        progress: 1.0,
        message: 'Receipt saved',
      );

      // Phase 4: Completed
      yield ReceiptUploadStatus.completed(receipt);
    } catch (e) {
      yield ReceiptUploadStatus.error(e.toString());
    }
  }

  /// Get all receipts for current user
  Stream<List<ReceiptModel>> getUserReceipts() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('receipts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReceiptModel.fromDocument(doc))
            .toList());
  }

  /// Get items from a specific receipt
  Future<List<ReceiptItemModel>> getReceiptItems(String receiptId) async {
    final snapshot = await _firestore
        .collection('receipt_items')
        .where('receiptId', isEqualTo: receiptId)
        .orderBy('itemName')
        .get();

    return snapshot.docs
        .map((doc) => ReceiptItemModel.fromDocument(doc))
        .toList();
  }

  /// Search items across all receipts
  Future<List<ReceiptItemModel>> searchItems(String query) async {
    final User? user = _auth.currentUser;
    if (user == null) return [];

    // This is a simple implementation - for better search, use Algolia or similar
    final snapshot = await _firestore
        .collection('receipt_items')
        .where('userId', isEqualTo: user.uid)
        .limit(100)
        .get();

    return snapshot.docs
        .map((doc) => ReceiptItemModel.fromDocument(doc))
        .where((item) =>
            item.itemName.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}

/// Status tracker for receipt upload process
class ReceiptUploadStatus {
  final String phase; // 'uploading', 'parsing', 'saving', 'completed', 'error'
  final double progress; // 0.0 to 1.0
  final String message;
  final ReceiptModel? receipt;
  final String? error;

  ReceiptUploadStatus({
    required this.phase,
    required this.progress,
    required this.message,
    this.receipt,
    this.error,
  });

  factory ReceiptUploadStatus.completed(ReceiptModel receipt) {
    return ReceiptUploadStatus(
      phase: 'completed',
      progress: 1.0,
      message: 'Receipt uploaded successfully',
      receipt: receipt,
    );
  }

  factory ReceiptUploadStatus.error(String error) {
    return ReceiptUploadStatus(
      phase: 'error',
      progress: 0.0,
      message: error,
      error: error,
    );
  }
}

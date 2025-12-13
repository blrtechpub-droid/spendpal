import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for tracking bill upload history to prevent duplicates
class BillUploadHistoryModel {
  final String id;
  final String userId;
  final String fileHash; // SHA-256 hash of file content
  final String fileName;
  final int fileSizeBytes;
  final String fileUrl;
  final DateTime uploadedAt;
  final String? bankName;
  final String? month;
  final String? year;
  final int transactionCount;
  final String status; // 'processed', 'failed'
  final String? linkedBillId; // Link to original parsing response

  BillUploadHistoryModel({
    required this.id,
    required this.userId,
    required this.fileHash,
    required this.fileName,
    required this.fileSizeBytes,
    required this.fileUrl,
    required this.uploadedAt,
    this.bankName,
    this.month,
    this.year,
    required this.transactionCount,
    required this.status,
    this.linkedBillId,
  });

  /// Create from Firestore document
  factory BillUploadHistoryModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BillUploadHistoryModel(
      id: doc.id,
      userId: data['userId'] as String,
      fileHash: data['fileHash'] as String,
      fileName: data['fileName'] as String,
      fileSizeBytes: data['fileSizeBytes'] as int,
      fileUrl: data['fileUrl'] as String,
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      bankName: data['bankName'] as String?,
      month: data['month'] as String?,
      year: data['year'] as String?,
      transactionCount: data['transactionCount'] as int? ?? 0,
      status: data['status'] as String? ?? 'processed',
      linkedBillId: data['linkedBillId'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'fileHash': fileHash,
      'fileName': fileName,
      'fileSizeBytes': fileSizeBytes,
      'fileUrl': fileUrl,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'bankName': bankName,
      'month': month,
      'year': year,
      'transactionCount': transactionCount,
      'status': status,
      'linkedBillId': linkedBillId,
    };
  }

  /// Check if bill is recent (uploaded in last hour)
  bool get isRecent {
    final difference = DateTime.now().difference(uploadedAt);
    return difference.inHours < 1;
  }

  /// Get file size in MB
  double get fileSizeMB => fileSizeBytes / (1024 * 1024);
}

import 'transaction_model.dart';

/// Model for the backend API response when parsing a bill
class BillParsingResponse {
  final String status; // 'success', 'error', 'partial'
  final String parsedBy; // 'rule', 'llm', 'ocr'
  final List<TransactionModel> transactions;
  final String? errorMessage;
  final Map<String, dynamic>? metadata; // Additional info like bankName, month, year

  BillParsingResponse({
    required this.status,
    required this.parsedBy,
    required this.transactions,
    this.errorMessage,
    this.metadata,
  });

  factory BillParsingResponse.fromJson(Map<String, dynamic> json) {
    var transactionsList = json['transactions'] as List<dynamic>? ?? [];
    List<TransactionModel> transactions = transactionsList
        .map((t) => TransactionModel.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList();

    // Safely convert metadata
    Map<String, dynamic>? metadata;
    if (json['metadata'] != null) {
      metadata = Map<String, dynamic>.from(json['metadata'] as Map);
    }

    return BillParsingResponse(
      status: json['status'] ?? 'error',
      parsedBy: json['parsedBy'] ?? 'unknown',
      transactions: transactions,
      errorMessage: json['errorMessage'],
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'parsedBy': parsedBy,
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'errorMessage': errorMessage,
      'metadata': metadata,
    };
  }

  bool get isSuccess => status == 'success' && transactions.isNotEmpty;
  bool get hasError => status == 'error';

  String get bankName => metadata?['bankName'] ?? 'Unknown';
  String get month => metadata?['month'] ?? '';
  String get year => metadata?['year'] ?? '';
}

/// Model for bill upload status
class BillUploadStatus {
  final String phase; // 'uploading', 'extracting', 'parsing', 'completed', 'error'
  final double progress; // 0.0 to 1.0
  final String? message;
  final BillParsingResponse? result;

  BillUploadStatus({
    required this.phase,
    required this.progress,
    this.message,
    this.result,
  });

  factory BillUploadStatus.uploading(double progress) {
    return BillUploadStatus(
      phase: 'uploading',
      progress: progress * 0.3, // Uploading is 30% of total
      message: 'Uploading bill...',
    );
  }

  factory BillUploadStatus.extracting() {
    return BillUploadStatus(
      phase: 'extracting',
      progress: 0.4,
      message: 'Extracting text from bill...',
    );
  }

  factory BillUploadStatus.parsing() {
    return BillUploadStatus(
      phase: 'parsing',
      progress: 0.7,
      message: 'Parsing transactions...',
    );
  }

  factory BillUploadStatus.completed(BillParsingResponse result) {
    return BillUploadStatus(
      phase: 'completed',
      progress: 1.0,
      message: 'Bill parsed successfully!',
      result: result,
    );
  }

  factory BillUploadStatus.error(String message) {
    return BillUploadStatus(
      phase: 'error',
      progress: 0.0,
      message: message,
    );
  }
}

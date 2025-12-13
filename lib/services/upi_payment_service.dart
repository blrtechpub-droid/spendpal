// Temporarily disabled due to plugin compatibility issues
// import 'package:upi_india/upi_india.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

/// Stub classes for UPI (while plugin is disabled)
class UpiApp {
  final String name;
  final String packageName;
  final Uint8List? icon;

  UpiApp({required this.name, required this.packageName, this.icon});
}

class UpiResponse {
  final String? transactionId;
  final String? transactionRefId;
  final String? responseCode;
  final String? approvalRefNo;
  final UpiPaymentStatus status;

  UpiResponse({
    this.transactionId,
    this.transactionRefId,
    this.responseCode,
    this.approvalRefNo,
    required this.status,
  });
}

enum UpiPaymentStatus {
  SUCCESS,
  FAILURE,
  SUBMITTED,
}

/// Service for handling UPI payments in India
/// Integrates with Google Pay, PhonePe, Paytm, and other UPI apps
/// NOTE: UPI integration temporarily disabled - using fallback payment recording
class UpiPaymentService {
  // final UpiIndia _upiIndia = UpiIndia();

  /// Get list of available UPI apps installed on the device
  Future<List<UpiApp>> getAvailableUpiApps() async {
    try {
      // Return empty list when UPI plugin is disabled
      return [];
    } catch (e) {
      print('Error getting UPI apps: $e');
      return [];
    }
  }

  /// Initiate UPI payment
  /// Returns UpiResponse with transaction details
  Future<UpiResponse?> initiatePayment({
    required String receiverUpiId,
    required String receiverName,
    required double amount,
    required String transactionNote,
    required UpiApp app,
    String? transactionRefId,
  }) async {
    try {
      // UPI plugin disabled - return null to trigger fallback
      return null;
    } catch (e) {
      print('Error initiating UPI payment: $e');
      return null;
    }
  }

  /// Parse UPI response status
  UpiTransactionStatus getTransactionStatus(UpiResponse response) {
    switch (response.status) {
      case UpiPaymentStatus.SUCCESS:
        return UpiTransactionStatus.success;
      case UpiPaymentStatus.FAILURE:
        return UpiTransactionStatus.failure;
      case UpiPaymentStatus.SUBMITTED:
        return UpiTransactionStatus.pending;
      default:
        return UpiTransactionStatus.unknown;
    }
  }

  /// Show UPI app selection bottom sheet
  Future<UpiApp?> showUpiAppPicker(BuildContext context, List<UpiApp> apps) async {
    if (apps.isEmpty) {
      return null;
    }

    return await showModalBottomSheet<UpiApp>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.payment, color: Colors.teal),
                    const SizedBox(width: 12),
                    const Text(
                      'Choose Payment App',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    return ListTile(
                      leading: app.icon != null
                          ? Image.memory(
                              app.icon!,
                              width: 40,
                              height: 40,
                            )
                          : const Icon(Icons.payment),
                      title: Text(app.name),
                      subtitle: Text(_getAppDescription(app)),
                      onTap: () => Navigator.pop(context, app),
                      trailing: const Icon(Icons.chevron_right),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// Get friendly description for UPI app
  String _getAppDescription(UpiApp app) {
    final appName = app.name.toLowerCase();
    if (appName.contains('google')) return 'Google Pay';
    if (appName.contains('phonepe')) return 'PhonePe';
    if (appName.contains('paytm')) return 'Paytm';
    if (appName.contains('bhim')) return 'BHIM UPI';
    if (appName.contains('amazon')) return 'Amazon Pay';
    if (appName.contains('whatsapp')) return 'WhatsApp Pay';
    return 'UPI Payment App';
  }

  /// Validate UPI ID format
  bool isValidUpiId(String upiId) {
    // UPI ID format: username@bankname
    final regex = RegExp(r'^[\w.-]+@[\w]+$');
    return regex.hasMatch(upiId);
  }

  /// Generate transaction reference ID
  String generateTransactionRef() {
    return 'SPENDPAL${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Transaction status enum
enum UpiTransactionStatus {
  success,
  failure,
  pending,
  unknown,
}

/// Model for UPI payment result
class UpiPaymentResult {
  final UpiTransactionStatus status;
  final String? transactionId;
  final String? transactionRefId;
  final String? responseCode;
  final String? approvalRefNo;
  final String message;

  UpiPaymentResult({
    required this.status,
    this.transactionId,
    this.transactionRefId,
    this.responseCode,
    this.approvalRefNo,
    required this.message,
  });

  factory UpiPaymentResult.fromUpiResponse(UpiResponse response) {
    UpiTransactionStatus status;
    String message;

    switch (response.status) {
      case UpiPaymentStatus.SUCCESS:
        status = UpiTransactionStatus.success;
        message = 'Payment successful!';
        break;
      case UpiPaymentStatus.FAILURE:
        status = UpiTransactionStatus.failure;
        message = 'Payment failed. Please try again.';
        break;
      case UpiPaymentStatus.SUBMITTED:
        status = UpiTransactionStatus.pending;
        message = 'Payment submitted. Waiting for confirmation.';
        break;
      default:
        status = UpiTransactionStatus.unknown;
        message = 'Payment status unknown. Please check with your bank.';
    }

    return UpiPaymentResult(
      status: status,
      transactionId: response.transactionId,
      transactionRefId: response.transactionRefId,
      responseCode: response.responseCode,
      approvalRefNo: response.approvalRefNo,
      message: message,
    );
  }

  bool get isSuccess => status == UpiTransactionStatus.success;
  bool get isFailed => status == UpiTransactionStatus.failure;
  bool get isPending => status == UpiTransactionStatus.pending;
}

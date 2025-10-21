import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class FloatingButtons extends StatelessWidget {
  final VoidCallback onAddExpense;
  final VoidCallback onScan;
  final VoidCallback? onUploadBill;

  const FloatingButtons({
    super.key,
    required this.onAddExpense,
    required this.onScan,
    this.onUploadBill,
  });

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      activeBackgroundColor: Colors.red,
      activeForegroundColor: Colors.white,
      spacing: 12,
      spaceBetweenChildren: 12,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.qr_code_scanner),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          label: 'Scan QR',
          labelStyle: const TextStyle(color: Colors.white),
          labelBackgroundColor: Colors.purple.shade700,
          onTap: onScan,
        ),
        if (onUploadBill != null)
          SpeedDialChild(
            child: const Icon(Icons.upload_file),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            label: 'Upload Bill',
            labelStyle: const TextStyle(color: Colors.white),
            labelBackgroundColor: Colors.orange.shade700,
            onTap: onUploadBill,
          ),
        SpeedDialChild(
          child: const Icon(Icons.receipt_long),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          label: 'Add Expense',
          labelStyle: const TextStyle(color: Colors.white),
          labelBackgroundColor: Colors.green.shade700,
          onTap: onAddExpense,
        ),
      ],
    );
  }
}

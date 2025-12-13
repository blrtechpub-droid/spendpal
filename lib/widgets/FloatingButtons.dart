import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../theme/app_theme.dart';

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
      backgroundColor: AppTheme.tealAccent,
      foregroundColor: AppTheme.primaryBackground,
      activeBackgroundColor: AppTheme.errorColor,
      activeForegroundColor: Colors.white,
      spacing: AppTheme.spacingM,
      spaceBetweenChildren: AppTheme.spacingM,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.qr_code_scanner),
          backgroundColor: AppTheme.purpleAccent,
          foregroundColor: AppTheme.primaryBackground,
          label: 'Scan QR',
          labelStyle: const TextStyle(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.w500,
          ),
          labelBackgroundColor: AppTheme.purpleAccent.withValues(alpha: 0.9),
          onTap: onScan,
        ),
        if (onUploadBill != null)
          SpeedDialChild(
            child: const Icon(Icons.upload_file),
            backgroundColor: AppTheme.orangeAccent,
            foregroundColor: AppTheme.primaryBackground,
            label: 'Upload Bill',
            labelStyle: const TextStyle(
              color: AppTheme.primaryText,
              fontWeight: FontWeight.w500,
            ),
            labelBackgroundColor: AppTheme.orangeAccent.withValues(alpha: 0.9),
            onTap: onUploadBill,
          ),
        SpeedDialChild(
          child: const Icon(Icons.receipt_long),
          backgroundColor: AppTheme.greenAccent,
          foregroundColor: AppTheme.primaryBackground,
          label: 'Add Expense',
          labelStyle: const TextStyle(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.w500,
          ),
          labelBackgroundColor: AppTheme.greenAccent.withValues(alpha: 0.9),
          onTap: onAddExpense,
        ),
      ],
    );
  }
}

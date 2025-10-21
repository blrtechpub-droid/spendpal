import 'dart:io';
import 'package:flutter/material.dart';
import 'package:spendpal/theme/app_theme.dart';
import 'package:spendpal/services/bill_upload_service.dart';
import 'package:spendpal/models/bill_parsing_response.dart';
import 'package:spendpal/screens/personal/transaction_review_screen.dart';

class BillUploadScreen extends StatefulWidget {
  const BillUploadScreen({super.key});

  @override
  State<BillUploadScreen> createState() => _BillUploadScreenState();
}

class _BillUploadScreenState extends State<BillUploadScreen> {
  final BillUploadService _billService = BillUploadService();

  File? _selectedFile;
  String? _selectedBankName;
  String? _selectedMonth;
  String? _selectedYear;
  bool _isUploading = false;
  String _uploadPhase = '';
  double _uploadProgress = 0.0;

  // Bank options
  final List<String> _banks = [
    'HDFC Bank',
    'ICICI Bank',
    'SBI',
    'Axis Bank',
    'Kotak Mahindra',
    'IDFC First',
    'Yes Bank',
    'Other',
  ];

  // Month options
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  // Generate last 3 years
  List<String> get _years {
    int currentYear = DateTime.now().year;
    return List.generate(3, (index) => (currentYear - index).toString());
  }

  Future<void> _pickFile() async {
    try {
      File? file = await _billService.pickBillFile();
      if (file != null) {
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePicture() async {
    try {
      File? file = await _billService.takeBillPhoto();
      if (file != null) {
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      File? file = await _billService.pickBillImage();
      if (file != null) {
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadAndParse() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a bill file first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await for (final status in _billService.uploadAndParseBill(
        file: _selectedFile!,
        bankName: _selectedBankName,
        month: _selectedMonth,
        year: _selectedYear,
      )) {
        setState(() {
          _uploadPhase = status.message ?? '';
          _uploadProgress = status.progress;
        });

        if (status.phase == 'completed' && status.result != null) {
          // Log extracted transactions for analysis
          print('═══════════════════════════════════════════════════');
          print('📊 BILL PARSING RESULTS');
          print('═══════════════════════════════════════════════════');
          print('Total Transactions: ${status.result!.transactions.length}');
          print('Parsed By: ${status.result!.parsedBy}');
          print('Bank: ${status.result!.bankName}');
          print('Status: ${status.result!.status}');
          print('───────────────────────────────────────────────────');
          print('EXTRACTED TRANSACTIONS:');
          print('───────────────────────────────────────────────────');
          for (var i = 0; i < status.result!.transactions.length; i++) {
            final t = status.result!.transactions[i];
            print('${i + 1}. ${t.date} | ${t.merchant.padRight(25)} | ₹${t.amount.toStringAsFixed(2).padLeft(10)} | ${t.category}');
          }
          print('═══════════════════════════════════════════════════');

          // Navigate to transaction review screen
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionReviewScreen(
                parsingResponse: status.result!,
                billImageUrl: null, // Will be set after upload
              ),
            ),
          );
          return;
        } else if (status.phase == 'error') {
          throw Exception(status.message);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBackground,
        title: const Text(
          'Upload Bill',
          style: TextStyle(color: AppTheme.primaryText),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isUploading ? _buildUploadingUI() : _buildFormUI(),
    );
  }

  Widget _buildUploadingUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.tealAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              value: _uploadProgress,
              strokeWidth: 6,
              color: AppTheme.tealAccent,
              backgroundColor: AppTheme.dividerColor,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _uploadPhase,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(_uploadProgress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.tealAccent,
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Please wait while we extract and parse your bill...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File selection section
          _buildFileSelectionSection(),

          const SizedBox(height: 24),

          // Bill details section
          if (_selectedFile != null) ...[
            _buildBillDetailsSection(),
            const SizedBox(height: 32),
          ],

          // Upload button
          if (_selectedFile != null)
            ElevatedButton(
              onPressed: _uploadAndParse,
              style: AppTheme.primaryButtonStyle.copyWith(
                minimumSize: MaterialStateProperty.all(const Size.fromHeight(50)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload),
                  SizedBox(width: 12),
                  Text(
                    'Upload & Parse Bill',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Bill',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 16),

          if (_selectedFile == null) ...[
            _buildPickerButton(
              icon: Icons.attach_file,
              label: 'Choose PDF/Image',
              subtitle: 'Select from device storage',
              onTap: _pickFile,
            ),
            const SizedBox(height: 12),
            _buildPickerButton(
              icon: Icons.camera_alt,
              label: 'Take Picture',
              subtitle: 'Capture with camera',
              onTap: _takePicture,
            ),
            const SizedBox(height: 12),
            _buildPickerButton(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              subtitle: 'Select image from gallery',
              onTap: _pickImage,
            ),
          ] else ...[
            _buildSelectedFilePreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.dividerColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.tealAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.tealAccent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFilePreview() {
    final fileName = _selectedFile!.path.split('/').last;
    final fileSize = _selectedFile!.lengthSync();
    final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.tealAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.tealAccent.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.tealAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$fileSizeMB MB',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.redAccent),
            onPressed: () {
              setState(() {
                _selectedFile = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBillDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Details (Optional)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Help us parse your bill more accurately',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryText,
            ),
          ),
          const SizedBox(height: 20),

          _buildDropdownField(
            label: 'Bank Name',
            value: _selectedBankName,
            items: _banks,
            onChanged: (value) {
              setState(() {
                _selectedBankName = value;
              });
            },
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildDropdownField(
                  label: 'Month',
                  value: _selectedMonth,
                  items: _months,
                  onChanged: (value) {
                    setState(() {
                      _selectedMonth = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  label: 'Year',
                  value: _selectedYear,
                  items: _years,
                  onChanged: (value) {
                    setState(() {
                      _selectedYear = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.secondaryBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.tealAccent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          dropdownColor: AppTheme.cardBackground,
          style: const TextStyle(color: AppTheme.primaryText, fontSize: 15),
          hint: Text(
            'Select $label',
            style: const TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

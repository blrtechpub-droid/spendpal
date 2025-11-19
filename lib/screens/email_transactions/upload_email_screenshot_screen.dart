import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'pattern_management_screen.dart';

/// Screen to upload email screenshot for pattern extraction
/// Uses Vision API + Gemini AI to generate parsing patterns
class UploadEmailScreenshotScreen extends StatefulWidget {
  const UploadEmailScreenshotScreen({super.key});

  @override
  State<UploadEmailScreenshotScreen> createState() =>
      _UploadEmailScreenshotScreenState();
}

class _UploadEmailScreenshotScreenState
    extends State<UploadEmailScreenshotScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;
  bool _isSuccess = false;
  String? _statusMessage;
  Map<String, dynamic>? _generatedPattern;

  @override
  Widget build(BuildContext context) {
    print('=== BUILD METHOD CALLED ===');
    print('_isSuccess: $_isSuccess');
    print('_isUploading: $_isUploading');
    print('_statusMessage: $_statusMessage');
    print('_generatedPattern: $_generatedPattern');
    print('_selectedImage: $_selectedImage');
    print('Rendering condition check:');
    print('  - _isSuccess && _generatedPattern != null = ${_isSuccess && _generatedPattern != null}');
    print('  - _isUploading = $_isUploading');
    print('  - _statusMessage != null && !_isSuccess = ${_statusMessage != null && !_isSuccess}');
    print('  - _selectedImage != null = ${_selectedImage != null}');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Upload Email Screenshot',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions card - always visible
            _buildInstructionsCard(),
            const SizedBox(height: 24),

            // Main content area - changes based on state
            if (_isSuccess && _generatedPattern != null)
              _buildSuccessView()
            else if (_isUploading)
              _buildLoadingView()
            else if (_statusMessage != null && !_isSuccess)
              _buildErrorView()
            else if (_selectedImage != null)
              _buildImagePreviewView()
            else
              _buildUploadButtonsView(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'How it works',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Take or upload a screenshot of a bank transaction email\n'
              '2. AI will analyze the email and create a parsing pattern\n'
              '3. Review the pattern and activate it for future emails\n'
              '4. Future emails from the same bank will be auto-parsed',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButtonsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pickImage(ImageSource.gallery),
          icon: const Icon(Icons.photo_library),
          label: const Text('Choose from Gallery'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            foregroundColor: Colors.black87,
            side: BorderSide(color: Colors.grey.shade400, width: 2),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Take Photo'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            foregroundColor: Colors.black87,
            side: BorderSide(color: Colors.grey.shade400, width: 2),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreviewView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_selectedImage!.path),
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: _clearImage,
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _uploadAndParse,
          icon: const Icon(Icons.upload),
          label: const Text('Upload & Analyze'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Card(
      color: Colors.red.shade50,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red.shade700,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _statusMessage ?? 'An error occurred',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: Colors.red.shade900,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _clearImage,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300, width: 2),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    // SIMPLIFIED VERSION - Prevent crashes from malformed data
    return Container(
      color: Colors.green.shade100,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 50),
          const SizedBox(height: 20),
          Text(
            'SUCCESS!',
            style: TextStyle(fontSize: 30, color: Colors.green.shade900, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'Pattern generated and saved!',
            style: TextStyle(fontSize: 18, color: Colors.green.shade800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_generatedPattern != null) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300, width: 2),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pattern Details:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_generatedPattern',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedImage = null;
                _statusMessage = null;
                _generatedPattern = null;
                _isSuccess = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.all(16),
            ),
            child: const Text('Upload Another', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Uploading and analyzing screenshot...',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternRow_UNUSED(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
          _statusMessage = null;
          _generatedPattern = null;
          _isSuccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error picking image: ${e.toString()}';
          _isSuccess = false;
        });
      }
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _statusMessage = null;
      _generatedPattern = null;
      _isSuccess = false;
    });
  }

  Future<void> _uploadAndParse() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploading = true;
      _statusMessage = null;
      _generatedPattern = null;
      _isSuccess = false;
    });

    try {
      // Read image as bytes
      final imageBytes = await File(_selectedImage!.path).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Call Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable(
        'parseEmailScreenshot',
      );

      final result = await callable.call({
        'imageBase64': base64Image,
        'userId': user.uid,
      });

      final data = Map<String, dynamic>.from(result.data as Map);

      // === COMPREHENSIVE LOGGING ===
      print('=== CLOUD FUNCTION RESPONSE RECEIVED ===');
      print('Full response data: $data');
      print('success field: ${data['success']}');
      print('pattern field: ${data['pattern']}');
      print('pattern type: ${data['pattern']?.runtimeType}');

      if (mounted) {
        if (data['success'] == true) {
          print('=== SUCCESS CASE ===');

          final pattern = data['pattern'];
          if (pattern == null) {
            print('❌ ERROR: pattern is null!');
          } else {
            print('✅ Pattern data exists');
            print('Pattern type: ${pattern.runtimeType}');
            print('Pattern keys: ${pattern.keys}');
            print('bankName: ${pattern['bankName']}');
            print('bankDomain: ${pattern['bankDomain']}');
            print('confidence: ${pattern['confidence']}');
          }

          print('=== BEFORE setState ===');
          print('_generatedPattern: $_generatedPattern');
          print('_isSuccess: $_isSuccess');
          print('_statusMessage: $_statusMessage');

          setState(() {
            _generatedPattern = Map<String, dynamic>.from(data['pattern'] as Map);
            _isSuccess = true;
            _statusMessage = null;

            print('=== AFTER setState ===');
            print('_generatedPattern: $_generatedPattern');
            print('_isSuccess: $_isSuccess');
            print('_statusMessage: $_statusMessage');
          });

          print('=== setState completed ===');
        } else {
          final errorMsg = data['error'] ?? 'Unknown error';
          setState(() {
            _statusMessage = 'Failed to generate pattern: $errorMsg\n\nPlease ensure the screenshot clearly shows a bank transaction email.';
            _isSuccess = false;
            _generatedPattern = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error uploading screenshot: $e');
      if (mounted) {
        final String errorMessage;
        if (e.toString().contains('PERMISSION_DENIED')) {
          errorMessage = 'Permission denied. Please ensure you are logged in.';
        } else if (e.toString().contains('UNAVAILABLE')) {
          errorMessage = 'Service temporarily unavailable. Please check your internet connection and try again.';
        } else if (e.toString().contains('UNAUTHENTICATED')) {
          errorMessage = 'Authentication error. Please log in again.';
        } else {
          errorMessage = 'Error: ${e.toString()}\n\nPlease try again or contact support if the problem persists.';
        }
        setState(() {
          _statusMessage = errorMessage;
          _isSuccess = false;
          _generatedPattern = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
}

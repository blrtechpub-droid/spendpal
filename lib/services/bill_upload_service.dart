import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path/path.dart' as path;
import 'package:spendpal/models/bill_parsing_response.dart';

class BillUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // Constants
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

  // Set to true to use mock data for testing (without deploying Cloud Functions)
  static const bool _useMockData = false;

  /// Pick a file from device storage (PDF or image)
  Future<File?> pickBillFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);

        // Validate file size
        int fileSize = await file.length();
        if (fileSize > maxFileSizeBytes) {
          throw Exception('File size exceeds 10 MB limit');
        }

        return file;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick file: $e');
    }
  }

  /// Pick an image from camera
  Future<File?> takeBillPhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        File file = File(photo.path);

        // Validate file size
        int fileSize = await file.length();
        if (fileSize > maxFileSizeBytes) {
          throw Exception('Image size exceeds 10 MB limit');
        }

        return file;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to capture photo: $e');
    }
  }

  /// Pick an image from gallery
  Future<File?> pickBillImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        File file = File(image.path);

        // Validate file size
        int fileSize = await file.length();
        if (fileSize > maxFileSizeBytes) {
          throw Exception('Image size exceeds 10 MB limit');
        }

        return file;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Upload bill file to Firebase Storage
  /// Returns the download URL
  Future<String> uploadBillToStorage(
    File file, {
    required void Function(double) onProgress,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique filename
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = path.extension(file.path);
      final String fileName = 'bill_$timestamp$extension';
      final String filePath = 'bills/${user.uid}/$fileName';

      // Create reference
      final Reference ref = _storage.ref().child(filePath);

      // Upload with progress tracking
      final UploadTask uploadTask = ref.putFile(file);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });

      // Wait for upload to complete
      await uploadTask;

      // Get download URL
      final String downloadURL = await ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      throw Exception('Failed to upload bill: $e');
    }
  }

  /// Parse bill using Firebase Cloud Functions
  Future<BillParsingResponse> parseBill({
    required String fileUrl,
    String? bankName,
    String? month,
    String? year,
  }) async {
    try {
      // For testing without backend
      if (_useMockData) {
        // Simulate network delay
        await Future.delayed(const Duration(seconds: 2));
        return _getMockParsingResponse();
      }

      // Call Firebase Cloud Function
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('parseBill');

      final result = await callable.call({
        'fileUrl': fileUrl,
        'bankName': bankName,
        'month': month,
        'year': year,
      });

      // Convert the result.data to a proper Map<String, dynamic>
      final Map<String, dynamic> responseData = Map<String, dynamic>.from(result.data as Map);

      return BillParsingResponse.fromJson(responseData);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Function error: ${e.message}');
    } catch (e) {
      throw Exception('Error parsing bill: $e');
    }
  }

  /// Mock data for testing (remove when backend is ready)
  BillParsingResponse _getMockParsingResponse() {
    return BillParsingResponse.fromJson({
      'status': 'success',
      'parsedBy': 'mock',
      'transactions': [
        {
          'id': '1',
          'date': '2025-01-10',
          'merchant': 'Amazon India',
          'amount': 1520.50,
          'category': 'Shopping',
        },
        {
          'id': '2',
          'date': '2025-01-12',
          'merchant': 'Swiggy',
          'amount': 450.00,
          'category': 'Food',
        },
        {
          'id': '3',
          'date': '2025-01-15',
          'merchant': 'Uber',
          'amount': 280.75,
          'category': 'Travel',
        },
        {
          'id': '4',
          'date': '2025-01-18',
          'merchant': 'Reliance Digital',
          'amount': 3499.00,
          'category': 'Shopping',
        },
        {
          'id': '5',
          'date': '2025-01-20',
          'merchant': 'Zomato',
          'amount': 680.50,
          'category': 'Food',
        },
      ],
      'metadata': {
        'bankName': 'HDFC Bank',
        'month': 'January',
        'year': '2025',
      },
    });
  }

  /// Complete flow: Pick file, upload, and parse
  Stream<BillUploadStatus> uploadAndParseBill({
    required File file,
    String? bankName,
    String? month,
    String? year,
  }) async* {
    try {
      // Phase 1: Uploading
      yield BillUploadStatus.uploading(0.0);

      String fileUrl = await uploadBillToStorage(
        file,
        onProgress: (progress) {
          // This is called during upload but stream already moved on
          // For better UX, consider using a StateNotifier or similar
        },
      );

      yield BillUploadStatus.uploading(1.0);

      // Phase 2: Extracting text
      yield BillUploadStatus.extracting();

      // Phase 3: Parsing
      yield BillUploadStatus.parsing();

      BillParsingResponse result = await parseBill(
        fileUrl: fileUrl,
        bankName: bankName,
        month: month,
        year: year,
      );

      // Phase 4: Completed
      yield BillUploadStatus.completed(result);
    } catch (e) {
      yield BillUploadStatus.error(e.toString());
    }
  }

  /// Validate file extension
  bool isValidFileType(File file) {
    String extension = path.extension(file.path).toLowerCase().replaceFirst('.', '');
    return allowedExtensions.contains(extension);
  }

  /// Get file extension
  String getFileExtension(File file) {
    return path.extension(file.path).toLowerCase();
  }
}

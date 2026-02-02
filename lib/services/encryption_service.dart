import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// Service for encrypting sensitive transaction data
///
/// Encrypts:
/// - Raw SMS/email text
/// - Account information
/// - Any other sensitive PII
///
/// Uses AES-256 encryption with device-specific key
class EncryptionService {
  static Encrypter? _encrypter;
  static IV? _iv;
  static bool _initialized = false;

  /// Initialize encryption with device-specific key
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Get or generate encryption key (256 bits)
      String? keyString = prefs.getString('encryption_key');
      if (keyString == null) {
        // Generate new random key
        keyString = _generateSecureKey();
        await prefs.setString('encryption_key', keyString);
        print('✅ Generated new encryption key');
      }

      // Get or generate IV (128 bits)
      String? ivString = prefs.getString('encryption_iv');
      if (ivString == null) {
        // Generate new random IV
        ivString = _generateSecureIV();
        await prefs.setString('encryption_iv', ivString);
        print('✅ Generated new encryption IV');
      }

      // Create encrypter
      final key = Key.fromBase64(keyString);
      _iv = IV.fromBase64(ivString);
      _encrypter = Encrypter(AES(key));

      _initialized = true;
      print('✅ Encryption service initialized');
    } catch (e) {
      print('❌ Error initializing encryption: $e');
      rethrow;
    }
  }

  /// Generate secure random key (32 bytes = 256 bits)
  static String _generateSecureKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }

  /// Generate secure random IV (16 bytes = 128 bits)
  static String _generateSecureIV() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }

  /// Encrypt plain text
  static String encrypt(String plainText) {
    if (!_initialized) {
      throw StateError('EncryptionService not initialized. Call initialize() first.');
    }

    if (plainText.isEmpty) {
      return '';
    }

    try {
      final encrypted = _encrypter!.encrypt(plainText, iv: _iv!);
      return encrypted.base64;
    } catch (e) {
      print('❌ Error encrypting data: $e');
      // Return original text if encryption fails (fallback)
      // In production, you might want to throw instead
      return plainText;
    }
  }

  /// Decrypt encrypted text
  static String decrypt(String encryptedText) {
    if (!_initialized) {
      throw StateError('EncryptionService not initialized. Call initialize() first.');
    }

    if (encryptedText.isEmpty) {
      return '';
    }

    try {
      final decrypted = _encrypter!.decrypt64(encryptedText, iv: _iv!);
      return decrypted;
    } catch (e) {
      print('❌ Error decrypting data: $e');
      // Return encrypted text if decryption fails (fallback)
      // This might happen if key was changed
      return encryptedText;
    }
  }

  /// Hash sensitive data (one-way, for duplicate detection)
  /// Use this for checking duplicates without storing actual data
  static String hash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Clear encryption keys (use with caution - will make existing data unreadable)
  static Future<void> clearKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('encryption_key');
    await prefs.remove('encryption_iv');
    _encrypter = null;
    _iv = null;
    _initialized = false;
    print('⚠️ Encryption keys cleared');
  }

  /// Check if encryption is initialized
  static bool get isInitialized => _initialized;

  /// Export encryption key for backup (use carefully!)
  /// User can backup this key to restore access if they change devices
  static Future<String?> exportKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('encryption_key');
    final iv = prefs.getString('encryption_iv');

    if (key == null || iv == null) {
      return null;
    }

    // Combine key and IV for backup
    final combined = '$key:$iv';
    return base64.encode(utf8.encode(combined));
  }

  /// Import encryption key from backup
  /// Used when restoring data on new device
  static Future<bool> importKey(String exportedKey) async {
    try {
      final decoded = utf8.decode(base64.decode(exportedKey));
      final parts = decoded.split(':');

      if (parts.length != 2) {
        print('❌ Invalid backup key format');
        return false;
      }

      final key = parts[0];
      final iv = parts[1];

      // Validate key and IV
      if (key.isEmpty || iv.isEmpty) {
        print('❌ Invalid key or IV');
        return false;
      }

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('encryption_key', key);
      await prefs.setString('encryption_iv', iv);

      // Reinitialize
      _initialized = false;
      await initialize();

      print('✅ Encryption key imported successfully');
      return true;
    } catch (e) {
      print('❌ Error importing encryption key: $e');
      return false;
    }
  }
}

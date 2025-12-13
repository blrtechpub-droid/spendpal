/// Stub implementation for non-Android platforms (iOS, Web, etc.)
/// Provides empty implementations that do nothing
class SmsListenerService {
  /// Initialize SMS listener (stub - does nothing on non-Android platforms)
  static Future<bool> initialize() async {
    return false; // SMS not supported
  }

  /// Request SMS permissions (stub)
  static Future<bool> requestPermissions() async {
    return false;
  }

  /// Check if SMS permissions are granted (stub)
  static Future<bool> hasPermissions() async {
    return false;
  }

  /// Process recent SMS messages (stub)
  static Future<int> processRecentMessages({int days = 7}) async {
    return 0; // No messages processed
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// Service to track regex pattern usage statistics
class RegexPatternTracker {
  static const String _keyPrefix = 'regex_pattern_hit_';

  /// Record a pattern hit
  static Future<void> recordHit(String category, int patternIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix${category}_$patternIndex';
    final currentCount = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, currentCount + 1);
  }

  /// Get hit count for a specific pattern
  static Future<int> getHitCount(String category, int patternIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix${category}_$patternIndex';
    return prefs.getInt(key) ?? 0;
  }

  /// Get all hit counts for a category
  static Future<Map<int, int>> getCategoryHitCounts(String category, int patternCount) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<int, int> counts = {};

    for (int i = 0; i < patternCount; i++) {
      final key = '$_keyPrefix${category}_$i';
      counts[i] = prefs.getInt(key) ?? 0;
    }

    return counts;
  }

  /// Reset all hit counts
  static Future<void> resetAllCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_keyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Reset hit counts for a specific category
  static Future<void> resetCategoryCounts(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('$_keyPrefix$category'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

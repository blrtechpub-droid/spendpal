import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/email_pattern_model.dart';
import 'email_transaction_parser_service.dart';

/// Service to parse emails using cloud-based patterns
/// Loads patterns from Firestore and applies them dynamically
class SmartEmailParserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Pattern cache
  static Map<String, EmailPattern>? _cachedPatterns;
  static DateTime? _cacheExpiry;
  static String? _cachedUserId;

  /// Load active patterns for user (with caching)
  static Future<List<EmailPattern>> getActivePatterns(String userId) async {
    // Check if cache is valid
    if (_cachedPatterns != null &&
        _cacheExpiry != null &&
        _cachedUserId == userId &&
        DateTime.now().isBefore(_cacheExpiry!)) {
      debugPrint('Using cached patterns (${_cachedPatterns!.length} patterns)');
      return _cachedPatterns!.values.toList();
    }

    debugPrint('Loading email patterns from Firestore for user: $userId');

    final patterns = <EmailPattern>[];

    try {
      // 1. Load user's custom patterns (highest priority)
      final userPatterns = await _firestore
          .collection('users')
          .doc(userId)
          .collection('customEmailPatterns')
          .where('active', isEqualTo: true)
          .orderBy('priority', descending: true)
          .get();

      debugPrint('Found ${userPatterns.docs.length} active user patterns');

      for (final doc in userPatterns.docs) {
        try {
          patterns.add(EmailPattern.fromFirestore(doc));
        } catch (e) {
          debugPrint('Error parsing user pattern ${doc.id}: $e');
        }
      }

      // 2. Load global verified patterns
      final globalPatterns = await _firestore
          .collection('emailParsingPatterns')
          .where('verified', isEqualTo: true)
          .where('active', isEqualTo: true)
          .orderBy('confidence', descending: true)
          .limit(50)
          .get();

      debugPrint('Found ${globalPatterns.docs.length} global patterns');

      for (final doc in globalPatterns.docs) {
        try {
          final pattern = EmailPattern.fromFirestore(doc);

          // Skip if user has custom override for this bank domain
          if (!patterns.any((p) => p.bankDomain == pattern.bankDomain)) {
            patterns.add(pattern);
          }
        } catch (e) {
          debugPrint('Error parsing global pattern ${doc.id}: $e');
        }
      }

      // Cache patterns for 1 hour
      _cachedPatterns = {for (var p in patterns) p.id: p};
      _cacheExpiry = DateTime.now().add(const Duration(hours: 1));
      _cachedUserId = userId;

      debugPrint('Loaded ${patterns.length} total email patterns');

      return patterns;
    } catch (e) {
      debugPrint('Error loading email patterns: $e');
      return [];
    }
  }

  /// Clear the pattern cache (force reload)
  static void clearCache() {
    _cachedPatterns = null;
    _cacheExpiry = null;
    _cachedUserId = null;
    debugPrint('Email pattern cache cleared');
  }

  /// Parse email using smart patterns from Firestore
  static Future<Map<String, dynamic>?> parseEmailSmart({
    required String userId,
    required String senderEmail,
    required String subject,
    required String body,
    required DateTime receivedAt,
  }) async {
    debugPrint('Smart parsing email from: $senderEmail');

    // 1. Load active patterns for this user
    final patterns = await getActivePatterns(userId);

    if (patterns.isEmpty) {
      debugPrint('No patterns loaded, falling back to hardcoded parsing');
      return EmailTransactionParserService.parseEmail(
        senderEmail: senderEmail,
        subject: subject,
        body: body,
        receivedAt: receivedAt,
      );
    }

    // 2. Extract sender domain
    final domain = _extractDomain(senderEmail);
    debugPrint('Sender domain: $domain');

    // 3. Find matching patterns for this sender
    final matchingPatterns = patterns
        .where((p) => p.bankDomain.toLowerCase() == domain.toLowerCase())
        .toList();

    if (matchingPatterns.isEmpty) {
      debugPrint('No patterns found for $domain, using fallback parsing');
      return EmailTransactionParserService.parseEmail(
        senderEmail: senderEmail,
        subject: subject,
        body: body,
        receivedAt: receivedAt,
      );
    }

    debugPrint('Found ${matchingPatterns.length} matching patterns');

    // 4. Sort by priority and confidence
    matchingPatterns.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      return b.actualConfidence.compareTo(a.actualConfidence);
    });

    // 5. Try each pattern in order
    final content = '$subject\n$body';

    for (final pattern in matchingPatterns) {
      debugPrint(
          'Trying pattern: ${pattern.bankName} (priority: ${pattern.priority}, confidence: ${pattern.actualConfidence.toStringAsFixed(2)})');

      final result = await _tryPattern(pattern, content, receivedAt);

      if (result != null) {
        debugPrint('✅ Successfully parsed with pattern: ${pattern.id}');

        // Update pattern stats in the background
        _updatePatternStats(pattern.id, userId, success: true);

        return result;
      }
    }

    // 6. All patterns failed - update stats and fallback
    debugPrint('All patterns failed for $domain');

    for (final pattern in matchingPatterns) {
      _updatePatternStats(pattern.id, userId, success: false);
    }

    // Fallback to hardcoded parsing
    return EmailTransactionParserService.parseEmail(
      senderEmail: senderEmail,
      subject: subject,
      body: body,
      receivedAt: receivedAt,
    );
  }

  /// Try to parse email with a specific pattern
  static Future<Map<String, dynamic>?> _tryPattern(
    EmailPattern pattern,
    String content,
    DateTime receivedAt,
  ) async {
    try {
      final patterns = pattern.patterns;

      // Extract amount (required)
      final amountPattern = patterns['amount'] as Map<String, dynamic>?;
      if (amountPattern == null) return null;

      final amountRegex = RegExp(
        amountPattern['regex'] as String,
        caseSensitive: false,
      );
      final amountMatch = amountRegex.firstMatch(content);

      if (amountMatch == null) {
        debugPrint('  ❌ Amount pattern did not match');
        return null;
      }

      final captureGroup = amountPattern['captureGroup'] as int? ?? 1;
      if (captureGroup > amountMatch.groupCount) {
        debugPrint('  ❌ Invalid capture group for amount');
        return null;
      }

      final amountStr =
          amountMatch.group(captureGroup)?.replaceAll(',', '').trim();
      if (amountStr == null || amountStr.isEmpty) {
        debugPrint('  ❌ Amount string is empty');
        return null;
      }

      final amount = double.tryParse(amountStr);
      if (amount == null || amount <= 0) {
        debugPrint('  ❌ Invalid amount: $amountStr');
        return null;
      }

      debugPrint('  ✓ Amount extracted: $amount');

      // Extract merchant (optional)
      String? merchant;
      final merchantPattern = patterns['merchant'] as Map<String, dynamic>?;
      if (merchantPattern != null) {
        final merchantRegex = RegExp(
          merchantPattern['regex'] as String,
          caseSensitive: false,
        );
        final merchantMatch = merchantRegex.firstMatch(content);
        final merchantGroup = merchantPattern['captureGroup'] as int? ?? 1;

        if (merchantMatch != null && merchantGroup <= merchantMatch.groupCount) {
          merchant = merchantMatch.group(merchantGroup)?.trim();
          debugPrint('  ✓ Merchant extracted: $merchant');
        }
      }

      // Extract date (optional)
      DateTime? transactionDate;
      final datePattern = patterns['date'] as Map<String, dynamic>?;
      if (datePattern != null) {
        transactionDate = _extractDateWithPattern(content, datePattern);
        if (transactionDate != null) {
          debugPrint('  ✓ Date extracted: $transactionDate');
        }
      }

      // Build result
      return {
        'type': amountPattern['type'] ?? 'debit',
        'amount': amount,
        'merchant': merchant,
        'transactionDate': transactionDate ?? receivedAt,
        'rawText': content,
        'senderEmail': pattern.bankDomain,
        'patternId': pattern.id,
        'confidence': pattern.actualConfidence,
      };
    } catch (e) {
      debugPrint('  ❌ Error applying pattern ${pattern.id}: $e');
      return null;
    }
  }

  /// Extract date using pattern
  static DateTime? _extractDateWithPattern(
    String content,
    Map<String, dynamic> datePattern,
  ) {
    try {
      final regex = RegExp(
        datePattern['regex'] as String,
        caseSensitive: false,
      );
      final match = regex.firstMatch(content);

      if (match == null) return null;

      final format = datePattern['format'] as String? ?? 'DD-MM-YYYY';

      // Extract day, month, year from capture groups
      String? day;
      String? month;
      String? year;

      if (format.contains('DD') && format.contains('MM') && format.contains('YYYY')) {
        // Assuming capture groups: 1=day, 2=month, 3=year
        day = match.group(1);
        month = match.group(2);
        year = match.group(3);
      }

      if (day == null || month == null || year == null) return null;

      // Handle 2-digit year
      if (year.length == 2) {
        final yearInt = int.tryParse(year);
        if (yearInt == null) return null;
        year = yearInt > 50 ? '19$year' : '20$year';
      }

      return DateTime(
        int.parse(year),
        int.parse(month),
        int.parse(day),
      );
    } catch (e) {
      debugPrint('Error extracting date: $e');
      return null;
    }
  }

  /// Extract domain from email address
  static String _extractDomain(String email) {
    final match = RegExp(r'@([a-zA-Z0-9.-]+)').firstMatch(email);
    return match?.group(1)?.toLowerCase() ?? '';
  }

  /// Update pattern success/failure statistics (runs in background)
  static Future<void> _updatePatternStats(
    String patternId,
    String userId, {
    required bool success,
  }) async {
    // Don't block the parsing - run in background
    Future.microtask(() async {
      try {
        // Check if this is a user pattern or global pattern
        final userPatternRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('customEmailPatterns')
            .doc(patternId);

        final userPatternDoc = await userPatternRef.get();

        DocumentReference patternRef;
        if (userPatternDoc.exists) {
          patternRef = userPatternRef;
        } else {
          patternRef =
              _firestore.collection('emailParsingPatterns').doc(patternId);
        }

        // Update stats
        await patternRef.update({
          'usageCount': FieldValue.increment(1),
          if (success) 'successCount': FieldValue.increment(1),
          if (!success) 'failureCount': FieldValue.increment(1),
        });

        debugPrint('Updated stats for pattern $patternId: ${success ? "success" : "failure"}');

        // Clear cache to reload updated patterns
        clearCache();
      } catch (e) {
        debugPrint('Error updating pattern stats: $e');
      }
    });
  }
}

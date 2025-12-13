import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

/// Service for Gmail API integration
/// Handles authentication, email fetching, and parsing
/// All processing happens client-side for maximum privacy
class GmailService {
  // Gmail scopes - read-only access to emails
  static final List<String> _scopes = [
    'email',
    gmail.GmailApi.gmailReadonlyScope,  // Read-only access
    gmail.GmailApi.gmailLabelsScope,    // Manage labels
  ];

  static bool _initialized = false;
  static gmail.GmailApi? _cachedGmailApi;
  static DateTime? _cacheExpiry;

  /// Get Google Sign-In instance
  static GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  /// Initialize Google Sign-In
  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _googleSignIn.initialize();
      _initialized = true;
    }
  }

  /// Check if user has granted Gmail access
  static Future<bool> hasGmailAccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('gmail_access_granted') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request Gmail access from user
  static Future<bool> requestGmailAccess() async {
    try {
      await _ensureInitialized();

      debugPrint('Requesting Gmail scopes for current user...');

      // Get current account
      final account = await _googleSignIn.attemptLightweightAuthentication();
      if (account == null) {
        debugPrint('ERROR: No account signed in');
        return false;
      }

      debugPrint('Account: ${account.email}');

      // Request Gmail scopes - this will show account picker ONCE
      final authorization = await account.authorizationClient.authorizeScopes(_scopes);

      if (authorization == null) {
        debugPrint('ERROR: User denied Gmail scope authorization');
        return false;
      }

      debugPrint('Gmail scopes authorized successfully');

      // Save access status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('gmail_access_granted', true);

      debugPrint('Gmail access granted');
      return true;
    } catch (e) {
      debugPrint('Error requesting Gmail access: $e');
      return false;
    }
  }

  /// Revoke Gmail access
  static Future<void> revokeGmailAccess() async {
    try {
      await _ensureInitialized();
      await _googleSignIn.signOut();

      // Clear cache
      _cachedGmailApi = null;
      _cacheExpiry = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('gmail_access_granted', false);
      await prefs.remove('last_email_sync');
    } catch (e) {
      debugPrint('Error revoking Gmail access: $e');
    }
  }

  /// Get Gmail API client
  static Future<gmail.GmailApi?> _getGmailClient() async {
    try {
      // Return cached client if still valid (cache for 5 minutes)
      if (_cachedGmailApi != null && _cacheExpiry != null && DateTime.now().isBefore(_cacheExpiry!)) {
        debugPrint('Using cached Gmail API client');
        return _cachedGmailApi;
      }

      debugPrint('=== Starting Gmail client authentication ===');
      await _ensureInitialized();

      // Get account via lightweight authentication (user already signed in via Firebase)
      debugPrint('Attempting lightweight authentication...');
      final account = await _googleSignIn.attemptLightweightAuthentication();
      debugPrint('Lightweight auth result: ${account?.email ?? "null"}');

      if (account == null) {
        lastSearchError = 'No Google account signed in - user must sign in first';
        debugPrint('ERROR: No account available after lightweight auth');
        return null;
      }

      debugPrint('Account found: ${account.email}');

      // Try to get existing authorization first
      debugPrint('Checking existing authorization for scopes: $_scopes');
      var authorization = await account.authorizationClient.authorizationForScopes(_scopes);
      debugPrint('Existing authorization: ${authorization != null ? "Success" : "null"}');

      // If no existing authorization, request scopes
      if (authorization == null) {
        debugPrint('Requesting new scopes authorization...');
        authorization = await account.authorizationClient.authorizeScopes(_scopes);
        debugPrint('New authorization result: ${authorization != null ? "Success" : "null"}');
      }

      if (authorization == null) {
        lastSearchError = 'Failed to get authorization for Gmail scopes - user may have denied access';
        debugPrint('ERROR: Authorization is null after scope request');
        return null;
      }

      debugPrint('Authorization token: ${authorization.accessToken.substring(0, 10)}...');

      // Use the extension method to get authenticated client
      debugPrint('Creating authenticated client...');
      final authClient = authorization.authClient(scopes: _scopes);
      debugPrint('Auth client created successfully');

      // Cache the client for 5 minutes
      _cachedGmailApi = gmail.GmailApi(authClient);
      _cacheExpiry = DateTime.now().add(const Duration(minutes: 5));
      debugPrint('Gmail API client cached until ${_cacheExpiry!.toIso8601String()}');

      return _cachedGmailApi;
    } catch (e, stackTrace) {
      lastSearchError = 'Error getting Gmail client: $e';
      debugPrint('ERROR getting Gmail client: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Last search query used (for debugging)
  static String? lastSearchQuery;
  static int? lastSearchResultCount;
  static String? lastSearchError;

  /// Search for transaction emails from banks
  static Future<List<gmail.Message>> searchTransactionEmails({
    DateTime? after,
    DateTime? before,
    int maxResults = 50,
  }) async {
    final api = await _getGmailClient();
    if (api == null) {
      lastSearchError = 'Failed to get Gmail client';
      return [];
    }

    try {
      // Build search query for transaction emails
      final List<String> queryParts = [];

      // From known banks (same as EmailTransactionParserService)
      // Made broader to catch statement emails that may not have explicit transaction keywords
      // Note: HDFC uses both .com and .net domains for different types of alerts
      queryParts.add('from:(hdfcbank.com OR hdfcbank.net OR icicibank.com OR sbi.co.in OR axisbank.com OR kotak.com OR yesbank.in OR indusind.com OR pnbindia.in OR sc.com OR standardchartered.com)');

      // Date filters
      if (after != null) {
        final dateStr = '${after.year}/${after.month.toString().padLeft(2, '0')}/${after.day.toString().padLeft(2, '0')}';
        queryParts.add('after:$dateStr');
      }
      if (before != null) {
        final dateStr = '${before.year}/${before.month.toString().padLeft(2, '0')}/${before.day.toString().padLeft(2, '0')}';
        queryParts.add('before:$dateStr');
      }

      final query = queryParts.join(' ');
      lastSearchQuery = query;
      lastSearchError = null;

      final response = await api.users.messages.list(
        'me',
        q: query,
        maxResults: maxResults,
      );

      lastSearchResultCount = response.messages?.length ?? 0;
      return response.messages ?? [];
    } catch (e) {
      lastSearchError = e.toString();
      lastSearchResultCount = 0;
      return [];
    }
  }

  /// Search for credit card statement emails
  static Future<List<gmail.Message>> searchStatementEmails({
    DateTime? after,
    DateTime? before,
    int maxResults = 20,
  }) async {
    final api = await _getGmailClient();
    if (api == null) return [];

    try {
      // Build search query for statements
      final List<String> queryParts = [];

      // From known banks
      queryParts.add('from:(hdfcbank.com OR icicibank.com OR sbi.co.in OR axisbank.com OR kotak.com OR amexnetwork.com OR citibank.com OR sc.com)');

      // Subject patterns for statements
      queryParts.add('subject:(credit card statement OR monthly statement OR e-statement OR billing statement)');

      // Date filters
      if (after != null) {
        final dateStr = '${after.year}/${after.month.toString().padLeft(2, '0')}/${after.day.toString().padLeft(2, '0')}';
        queryParts.add('after:$dateStr');
      }
      if (before != null) {
        final dateStr = '${before.year}/${before.month.toString().padLeft(2, '0')}/${before.day.toString().padLeft(2, '0')}';
        queryParts.add('before:$dateStr');
      }

      final query = queryParts.join(' ');

      final response = await api.users.messages.list(
        'me',
        q: query,
        maxResults: maxResults,
      );

      return response.messages ?? [];
    } catch (e) {
      debugPrint('Error searching statement emails: $e');
      return [];
    }
  }

  /// Search for investment emails (Zerodha, Groww, etc.)
  static Future<List<gmail.Message>> searchInvestmentEmails({
    DateTime? after,
    DateTime? before,
    int maxResults = 50,
  }) async {
    final api = await _getGmailClient();
    if (api == null) return [];

    try {
      // Build search query for investment emails
      final List<String> queryParts = [];

      // From known investment platforms
      queryParts.add('from:(zerodha.com OR groww.in OR angelbroking.com OR upstox.com OR 5paisa.com OR npscan.com)');

      // Keywords for investment transactions
      queryParts.add('(purchased OR sold OR dividend OR SIP OR mutual fund OR stock OR shares)');

      // Date filters
      if (after != null) {
        final dateStr = '${after.year}/${after.month.toString().padLeft(2, '0')}/${after.day.toString().padLeft(2, '0')}';
        queryParts.add('after:$dateStr');
      }
      if (before != null) {
        final dateStr = '${before.year}/${before.month.toString().padLeft(2, '0')}/${before.day.toString().padLeft(2, '0')}';
        queryParts.add('before:$dateStr');
      }

      final query = queryParts.join(' ');

      final response = await api.users.messages.list(
        'me',
        q: query,
        maxResults: maxResults,
      );

      return response.messages ?? [];
    } catch (e) {
      debugPrint('Error searching investment emails: $e');
      return [];
    }
  }

  /// Fetch full email details with retry logic
  static Future<gmail.Message?> getEmailDetails(String messageId, {int maxRetries = 3}) async {
    final api = await _getGmailClient();
    if (api == null) return null;

    int retryCount = 0;
    Duration retryDelay = const Duration(seconds: 1);

    while (retryCount <= maxRetries) {
      try {
        final message = await api.users.messages.get('me', messageId, format: 'full');
        if (retryCount > 0) {
          debugPrint('Successfully fetched email after $retryCount ${retryCount == 1 ? "retry" : "retries"}');
        }
        return message;
      } catch (e) {
        retryCount++;
        if (retryCount > maxRetries) {
          debugPrint('Error getting email details after $maxRetries retries: $e');
          return null;
        }

        // Check if it's a network error
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('socketexception') ||
            errorStr.contains('failed host lookup') ||
            errorStr.contains('network') ||
            errorStr.contains('connection')) {
          debugPrint('Network error on attempt $retryCount/$maxRetries, retrying in ${retryDelay.inSeconds}s...');
          await Future.delayed(retryDelay);
          // Exponential backoff: 1s, 2s, 4s
          retryDelay *= 2;
        } else {
          // Non-network error, don't retry
          debugPrint('Non-network error getting email details: $e');
          return null;
        }
      }
    }

    return null;
  }

  /// Extract sender email from message
  static String? extractSender(gmail.Message message) {
    final headers = message.payload?.headers ?? [];
    for (final header in headers) {
      if (header.name?.toLowerCase() == 'from') {
        // Extract email from "Name <email@domain.com>" format
        final emailMatch = RegExp(r'<([^>]+)>').firstMatch(header.value ?? '');
        if (emailMatch != null) {
          return emailMatch.group(1);
        }
        // If no angle brackets, assume the whole value is the email
        return header.value;
      }
    }
    return null;
  }

  /// Extract subject from message
  static String? extractSubject(gmail.Message message) {
    final headers = message.payload?.headers ?? [];
    for (final header in headers) {
      if (header.name?.toLowerCase() == 'subject') {
        return header.value;
      }
    }
    return null;
  }

  /// Extract date from message
  static DateTime? extractDate(gmail.Message message) {
    if (message.internalDate != null) {
      try {
        final timestamp = int.parse(message.internalDate!);
        return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
      } catch (e) {
        // Ignore parse errors
      }
    }
    return null;
  }

  /// Extract plain text body from email
  static String extractTextBody(gmail.Message message) {
    final buffer = StringBuffer();

    void extractFromPart(gmail.MessagePart? part) {
      if (part == null) return;

      // If this part has body data
      if (part.body?.data != null) {
        final mimeType = part.mimeType?.toLowerCase() ?? '';

        // Only extract from text parts
        if (mimeType.contains('text/plain')) {
          try {
            final decoded = utf8.decode(base64Url.decode(part.body!.data!));
            buffer.writeln(decoded);
          } catch (e) {
            debugPrint('Error decoding body: $e');
          }
        } else if (mimeType.contains('text/html')) {
          // Convert HTML to plain text (basic conversion)
          try {
            final decoded = utf8.decode(base64Url.decode(part.body!.data!));
            final plainText = _htmlToPlainText(decoded);
            buffer.writeln(plainText);
          } catch (e) {
            debugPrint('Error decoding HTML: $e');
          }
        }
      }

      // Recursively process parts
      if (part.parts != null) {
        for (final subPart in part.parts!) {
          extractFromPart(subPart);
        }
      }
    }

    extractFromPart(message.payload);
    return buffer.toString();
  }

  /// Basic HTML to plain text conversion
  static String _htmlToPlainText(String html) {
    String text = html;

    // Remove script and style tags
    text = text.replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '');
    text = text.replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');

    // Convert common HTML entities
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");

    // Replace <br> with newlines
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');

    // Remove all remaining HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // Clean up whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.trim();

    return text;
  }

  /// Get last sync timestamp
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_email_sync');
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Update last sync timestamp
  static Future<void> updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_email_sync', DateTime.now().millisecondsSinceEpoch);
  }

  /// Extract PDF attachments from email
  static List<gmail.MessagePartBody> extractPdfAttachments(gmail.Message message) {
    final attachments = <gmail.MessagePartBody>[];

    void extractFromPart(gmail.MessagePart? part) {
      if (part == null) return;

      // Check if this part is a PDF attachment
      final mimeType = part.mimeType?.toLowerCase() ?? '';
      final filename = part.filename?.toLowerCase() ?? '';

      if (mimeType.contains('pdf') || filename.endsWith('.pdf')) {
        if (part.body != null) {
          attachments.add(part.body!);
        }
      }

      // Recursively process parts
      if (part.parts != null) {
        for (final subPart in part.parts!) {
          extractFromPart(subPart);
        }
      }
    }

    extractFromPart(message.payload);
    return attachments;
  }

  /// Download attachment data
  static Future<String?> downloadAttachment(String messageId, String attachmentId) async {
    final api = await _getGmailClient();
    if (api == null) return null;

    try {
      final attachment = await api.users.messages.attachments.get('me', messageId, attachmentId);
      return attachment.data;
    } catch (e) {
      debugPrint('Error downloading attachment: $e');
      return null;
    }
  }
}

/// Helper to add debugPrint
void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}

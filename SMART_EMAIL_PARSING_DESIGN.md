# Smart Email Parsing System - Design Document

## Overview

This document outlines the architecture for SpendPal's intelligent, user-customizable email transaction parsing system. The goal is to allow users to improve parsing accuracy through two methods:

1. **Visual Filter Builder**: Upload email screenshot → Extract patterns via Vision API
2. **Learning from Corrections**: Manually correct unparsed emails → Auto-generate patterns

## Architecture Components

### 1. Cloud-Based Pattern Storage (Firestore)

#### Global Patterns Collection
```
emailParsingPatterns/ (Crowdsourced, verified patterns)
  {patternId}/
    - bankDomain: "hdfcbank.com"
    - bankName: "HDFC Bank"
    - patterns: {
        amount: {
          regex: "(debited|spent).*?Rs\\.?\\s*(\\d+(?:,\\d+)*(?:\\.\\d{2})?)"
          captureGroup: 1
          type: "debit"
        }
        merchant: {
          regex: "at\\s+([A-Z][A-Za-z\\s&]{2,30})"
          captureGroup: 1
        }
        date: {
          regex: "on[:\\s]+(\\d{1,2})[/-](\\d{1,2})[/-](\\d{4})"
          format: "DD-MM-YYYY"
        }
      }
    - gmailFilter: {
        from: "hdfcbank.com"
        keywords: ["debited", "credited", "transaction"]
      }
    - metadata: {
        confidence: 0.95 (success rate)
        usageCount: 1523 (users who validated)
        successCount: 1448
        failureCount: 75
      }
    - createdBy: "user123"
    - createdAt: Timestamp
    - verified: true (admin-approved)
    - tags: ["upi", "debit", "india"]
```

#### User-Specific Patterns
```
users/{userId}/
  customEmailPatterns/
    {patternId}/
      - (Same structure as global patterns)
      - priority: 10 (higher = used first)
      - overridesGlobal: "pattern_abc123" (optional)
      - active: true

  emailLearningData/ (Manual corrections for pattern generation)
    {learningId}/
      - emailMetadata: {
          messageId: "gmail_msg_123"
          subject: "HDFC Bank: You have spent Rs 1,234.56"
          sender: "alerts@hdfcbank.com"
          receivedAt: Timestamp
        }
      - rawEmailText: "Full email body..."
      - userCorrectedData: {
          amount: 1234.56
          merchant: "Swiggy"
          transactionDate: "2024-11-17"
          type: "upi"
          category: "Food & Dining"
        }
      - autoExtractedPatterns: {
          amount: {
            matchedText: "spent Rs 1,234.56"
            proposedRegex: "spent Rs\\.?\\s*(\\d+(?:,\\d+)*(?:\\.\\d{2})?)"
          }
          merchant: {
            matchedText: "at Swiggy"
            proposedRegex: "at\\s+([A-Z][a-z]+)"
          }
        }
      - patternGenerationStatus: "pending" | "generated" | "approved" | "rejected"
      - generatedPatternId: "pattern_xyz789"
      - createdAt: Timestamp
```

### 2. Vision API Integration Flow

**User Journey:**
1. User taps "Improve Parsing" → "Upload Email Screenshot"
2. Takes screenshot or uploads image
3. App sends to Cloud Function with Vision API
4. Vision API extracts text from image
5. LLM (Gemini/GPT) analyzes extracted text:
   - Identifies sender domain
   - Finds amount patterns
   - Detects transaction keywords
   - Extracts merchant patterns
6. Generates Gmail filter + regex patterns
7. User reviews and saves pattern

**Cloud Function (Firebase Functions):**
```javascript
// functions/src/visionEmailParser.ts
export const parseEmailScreenshot = functions.https.onCall(async (data, context) => {
  const { imageBase64, userId } = data;

  // 1. Extract text with Vision API
  const visionClient = new vision.ImageAnnotatorClient();
  const [result] = await visionClient.textDetection({
    image: { content: imageBase64 }
  });
  const extractedText = result.fullTextAnnotation.text;

  // 2. Use Gemini to analyze and extract patterns
  const geminiPrompt = `
    Analyze this bank transaction email and extract:
    1. Sender email domain
    2. Transaction amount pattern (regex)
    3. Merchant name pattern (regex)
    4. Transaction type (debit/credit/UPI)
    5. Date format pattern
    6. Gmail search query to find similar emails

    Email text: ${extractedText}

    Return JSON format:
    {
      "bankDomain": "...",
      "patterns": { ... },
      "gmailFilter": "..."
    }
  `;

  const aiResponse = await callGeminiAPI(geminiPrompt);

  // 3. Save to user's custom patterns
  await admin.firestore()
    .collection('users').doc(userId)
    .collection('customEmailPatterns')
    .add({
      ...aiResponse,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'vision_api',
      active: false, // User must review first
    });

  return { success: true, patternId: docRef.id };
});
```

### 3. Learning from Manual Corrections

**User Journey:**
1. User sees unparsed email in queue
2. Taps "This is a transaction"
3. Fills in form: Amount, Merchant, Date, Type
4. Taps "Save & Learn"
5. App analyzes email + user data
6. Generates regex patterns automatically
7. Asks: "Use this pattern for future emails from HDFC Bank?"

**Pattern Generation Logic:**
```dart
// lib/services/pattern_learning_service.dart
class PatternLearningService {
  static Future<Map<String, dynamic>> generatePatternFromCorrection({
    required String emailSubject,
    required String emailBody,
    required String senderEmail,
    required Map<String, dynamic> userCorrection,
  }) async {
    final content = '$emailSubject\n$emailBody';

    // 1. Find amount in text
    final amountPattern = _extractAmountPattern(
      content,
      userCorrection['amount']
    );

    // 2. Find merchant in text
    final merchantPattern = _extractMerchantPattern(
      content,
      userCorrection['merchant']
    );

    // 3. Find date pattern
    final datePattern = _extractDatePattern(
      content,
      userCorrection['transactionDate']
    );

    // 4. Detect transaction type keywords
    final typeKeywords = _detectTypeKeywords(content);

    return {
      'bankDomain': _extractDomain(senderEmail),
      'patterns': {
        'amount': amountPattern,
        'merchant': merchantPattern,
        'date': datePattern,
      },
      'gmailFilter': {
        'from': _extractDomain(senderEmail),
        'keywords': typeKeywords,
      },
      'confidence': 0.5, // Low confidence for user-generated patterns
    };
  }

  static String _extractAmountPattern(String text, double amount) {
    // Find the amount in text (e.g., "Rs 1,234.56" or "INR 1234.56")
    final amountStr = amount.toStringAsFixed(2);
    final amountWithCommas = _formatWithCommas(amount);

    // Search for context around the amount
    final contexts = [
      'debited.*?$amountWithCommas',
      'spent.*?$amountWithCommas',
      'paid.*?$amountWithCommas',
      'Rs\\.?\\s*$amountWithCommas',
    ];

    for (final context in contexts) {
      if (RegExp(context, caseSensitive: false).hasMatch(text)) {
        // Generalize the pattern
        return context.replaceAll(
          amountWithCommas,
          r'(\d+(?:,\d+)*(?:\.\d{2})?)'
        );
      }
    }

    return r'(?:Rs\.?|INR|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)';
  }

  static Map<String, dynamic> _extractMerchantPattern(String text, String? merchant) {
    if (merchant == null) return {};

    // Find merchant in text with context
    final merchantUpper = merchant.toUpperCase();
    final merchantCapitalized = _capitalize(merchant);

    final contexts = [
      'at\\s+$merchant',
      'to\\s+$merchant',
      'from\\s+$merchant',
      'merchant[:\\s]+$merchant',
    ];

    for (final context in contexts) {
      final regex = RegExp(context, caseSensitive: false);
      if (regex.hasMatch(text)) {
        // Generalize: "at Swiggy" → "at ([A-Z][a-z]+)"
        return {
          'regex': context.replaceAll(merchant, r'([A-Z][A-Za-z\s&]{2,30})'),
          'captureGroup': 1,
        };
      }
    }

    return {};
  }
}
```

### 4. Dynamic Pattern Loading & Caching

**Current System (Hardcoded):**
```dart
static final List<RegExp> bankSenderPatterns = [
  RegExp(r'@hdfcbank\.com'),
  // ... 20+ hardcoded patterns
];
```

**New System (Cloud-based):**
```dart
class SmartEmailParserService {
  static final _firestore = FirebaseFirestore.instance;
  static Map<String, EmailPattern>? _cachedPatterns;
  static DateTime? _cacheExpiry;

  /// Load patterns (global + user-specific) with caching
  static Future<List<EmailPattern>> getActivePatterns(String userId) async {
    // Cache for 1 hour
    if (_cachedPatterns != null &&
        _cacheExpiry != null &&
        DateTime.now().isBefore(_cacheExpiry!)) {
      return _cachedPatterns!.values.toList();
    }

    final patterns = <EmailPattern>[];

    // 1. Load user's custom patterns (highest priority)
    final userPatterns = await _firestore
      .collection('users').doc(userId)
      .collection('customEmailPatterns')
      .where('active', isEqualTo: true)
      .orderBy('priority', descending: true)
      .get();

    for (final doc in userPatterns.docs) {
      patterns.add(EmailPattern.fromFirestore(doc));
    }

    // 2. Load global verified patterns
    final globalPatterns = await _firestore
      .collection('emailParsingPatterns')
      .where('verified', isEqualTo: true)
      .orderBy('confidence', descending: true)
      .limit(50)
      .get();

    for (final doc in globalPatterns.docs) {
      // Skip if user has custom override
      if (!patterns.any((p) => p.bankDomain == doc['bankDomain'])) {
        patterns.add(EmailPattern.fromFirestore(doc));
      }
    }

    // Cache patterns
    _cachedPatterns = {for (var p in patterns) p.id: p};
    _cacheExpiry = DateTime.now().add(Duration(hours: 1));

    return patterns;
  }

  /// Parse email using dynamic patterns
  static Future<Map<String, dynamic>?> parseEmailSmart({
    required String userId,
    required String senderEmail,
    required String subject,
    required String body,
    required DateTime receivedAt,
  }) async {
    final patterns = await getActivePatterns(userId);
    final domain = _extractDomain(senderEmail);

    // Find matching patterns for this sender
    final matchingPatterns = patterns.where(
      (p) => p.bankDomain == domain
    ).toList();

    if (matchingPatterns.isEmpty) {
      // Fall back to hardcoded patterns
      return EmailTransactionParserService.parseEmail(
        senderEmail: senderEmail,
        subject: subject,
        body: body,
        receivedAt: receivedAt,
      );
    }

    // Try each pattern (sorted by confidence/priority)
    for (final pattern in matchingPatterns) {
      final result = _tryPattern(pattern, '$subject\n$body', receivedAt);
      if (result != null) {
        // Update pattern success stats
        await _updatePatternStats(pattern.id, success: true);
        return result;
      }
    }

    // All patterns failed
    for (final pattern in matchingPatterns) {
      await _updatePatternStats(pattern.id, success: false);
    }

    return null;
  }

  static Map<String, dynamic>? _tryPattern(
    EmailPattern pattern,
    String content,
    DateTime receivedAt,
  ) {
    try {
      // Extract amount
      final amountRegex = RegExp(pattern.patterns['amount']['regex']);
      final amountMatch = amountRegex.firstMatch(content);
      if (amountMatch == null) return null;

      final amountStr = amountMatch.group(
        pattern.patterns['amount']['captureGroup']
      )!.replaceAll(',', '');
      final amount = double.tryParse(amountStr);
      if (amount == null) return null;

      // Extract merchant (optional)
      String? merchant;
      if (pattern.patterns.containsKey('merchant')) {
        final merchantRegex = RegExp(pattern.patterns['merchant']['regex']);
        final merchantMatch = merchantRegex.firstMatch(content);
        merchant = merchantMatch?.group(
          pattern.patterns['merchant']['captureGroup']
        );
      }

      // Extract date (optional)
      DateTime? transactionDate;
      if (pattern.patterns.containsKey('date')) {
        transactionDate = _extractDateWithPattern(
          content,
          pattern.patterns['date']
        );
      }

      return {
        'type': pattern.patterns['amount']['type'] ?? 'debit',
        'amount': amount,
        'merchant': merchant,
        'transactionDate': transactionDate ?? receivedAt,
        'rawText': content,
        'senderEmail': pattern.bankDomain,
        'patternId': pattern.id,
        'confidence': pattern.confidence,
      };
    } catch (e) {
      debugPrint('Error applying pattern ${pattern.id}: $e');
      return null;
    }
  }
}
```

### 5. User Interface Flows

#### Flow 1: Upload Screenshot to Improve Parsing
```
EmailTransactionsScreen
  └─> "Improve Parsing" button
      └─> UploadEmailScreenshotScreen
          ├─> Take Photo / Choose from Gallery
          ├─> Upload to Cloud Function (Vision API)
          ├─> Show loading: "Analyzing email..."
          ├─> Show extracted pattern preview
          │   - Bank: HDFC Bank
          │   - Gmail Filter: from:(hdfcbank.com) (debited OR spent)
          │   - Amount Pattern: debited Rs (number)
          │   - Merchant Pattern: at (MERCHANT_NAME)
          ├─> User reviews and edits patterns
          └─> Save to customEmailPatterns
```

#### Flow 2: Manual Correction & Learning
```
EmailTransactionsScreen (Queue Tab)
  └─> Unparsed Email Card
      ├─> Shows: Subject, Sender, Date
      ├─> "This is a transaction" button
      └─> ManualTransactionFormScreen
          ├─> Amount: [TextField]
          ├─> Merchant: [TextField]
          ├─> Date: [DatePicker]
          ├─> Type: [Dropdown: Debit/Credit/UPI]
          ├─> Category: [Dropdown]
          ├─> "Save & Learn" button
          └─> Backend:
              ├─> Save to emailLearningData collection
              ├─> Generate patterns automatically
              └─> Ask: "Use this pattern for future @hdfcbank.com emails?"
                  ├─> Yes → Save to customEmailPatterns (active: true)
                  └─> No → Keep in learningData only
```

### 6. Pattern Confidence & Ranking

**Confidence Score Calculation:**
```dart
confidence = (successCount / (successCount + failureCount)) *
             (usageCount weight) *
             (verified bonus)

where:
  - successCount: Times pattern successfully parsed
  - failureCount: Times pattern failed to parse
  - usageCount weight: min(usageCount / 100, 1.0)  // More usage = more confident
  - verified bonus: 1.2 if admin-verified, 1.0 otherwise
```

**Pattern Priority:**
1. User custom patterns (priority field)
2. Global verified patterns (confidence > 0.8)
3. Community patterns (confidence > 0.6)
4. Hardcoded fallback patterns

### 7. Migration Path

**Phase 1: Dual System** (Current + New)
- Keep hardcoded patterns as fallback
- Add cloud-based pattern loading
- Users opt-in to smart parsing

**Phase 2: Gradual Migration**
- Migrate hardcoded patterns to Firestore
- Mark as verified with high confidence
- All users use cloud patterns

**Phase 3: Full Smart System**
- Remove hardcoded patterns
- All parsing is cloud-based
- Community-driven pattern database

## Implementation Checklist

- [ ] Create Firestore collections & security rules
- [ ] Implement EmailPattern model class
- [ ] Build SmartEmailParserService
- [ ] Create Cloud Function for Vision API
- [ ] Implement pattern learning from corrections
- [ ] Add UI for screenshot upload
- [ ] Add UI for manual correction
- [ ] Add pattern management screen
- [ ] Implement confidence scoring
- [ ] Add analytics for pattern performance
- [ ] Create admin dashboard for pattern verification

## Cost Estimation

**Google Vision API:**
- Text Detection: $1.50 per 1000 images
- Expected usage: ~10 images/user/month
- Cost per user: $0.015/month

**Firestore:**
- Pattern reads: ~50 patterns/sync
- Write on pattern updates: ~5 writes/month/user
- Estimated: $0.01/month/user

**Cloud Functions (Vision + Gemini):**
- ~10 invocations/user/month
- Estimated: $0.02/month/user

**Total: ~$0.045/month/user** for smart parsing features

## Privacy & Security

1. **Email Privacy**: All email content stays on-device or in user's Firestore subcollection
2. **Pattern Sharing**: Users opt-in to share patterns with community
3. **Anonymization**: Patterns anonymized before adding to global collection
4. **Vision API**: Screenshots processed server-side, not stored permanently

## Future Enhancements

1. **Gemini-powered NER** (Named Entity Recognition) for merchant extraction
2. **Multi-language support** (Hindi, regional languages)
3. **PDF attachment parsing** for credit card statements
4. **Pattern marketplace** where users can rate/review patterns
5. **Auto-categorization** based on merchant patterns
6. **Duplicate detection** using email message IDs

---

**Version**: 1.0
**Last Updated**: 2025-11-17
**Author**: SpendPal Development Team

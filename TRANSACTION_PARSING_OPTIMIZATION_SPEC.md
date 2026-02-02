# Transaction Parsing & Tracker Optimization - Technical Specification

**Project:** SpendPal
**Document Version:** 1.0
**Date:** January 6, 2026
**Status:** Planning

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current System Analysis](#current-system-analysis)
3. [Problems & Pain Points](#problems--pain-points)
4. [Proposed Solution](#proposed-solution)
5. [Architecture Changes](#architecture-changes)
6. [Data Flow](#data-flow)
7. [Implementation Plan](#implementation-plan)
8. [Testing Strategy](#testing-strategy)
9. [Success Metrics](#success-metrics)
10. [Appendix](#appendix)

---

## Executive Summary

### Objective
Unify SMS and Email transaction parsing systems into a single, privacy-first, account-number-based tracker matching architecture.

### Key Changes
1. **Consolidate storage**: Move from dual system (Firestore + SQLite) to 100% local SQLite
2. **Account-based matching**: Use account number (last 4 digits) instead of sender/domain for tracker assignment
3. **Unified parsing**: Single code path for SMS and Email with consistent regex pattern usage
4. **Smart filtering**: Pre-filter OTP, promotional, and non-financial messages before AI processing
5. **Learning system**: AI generates patterns on first parse; future messages use free regex matching

### Expected Outcomes
- ✅ 100% local storage (privacy-first)
- ✅ Accurate tracker matching (account-based)
- ✅ 90%+ cost reduction (self-learning patterns)
- ✅ Consistent UX for SMS and Email
- ✅ Clean codebase (remove old Firestore code)

---

## Current System Analysis

### System 1: Background SMS Listener (OLD - Firestore)

**Location:** `lib/services/sms_listener_service_android.dart` → `lib/services/ai_sms_parser_service.dart`

**Flow:**
```
SMS Arrives → Filter by sender → Match tracker (sender-based) →
Parse (Regex or AI) → Save to Firestore sms_expenses → User reviews
```

**Storage:**
- Transactions: Firestore `sms_expenses` collection
- Patterns: Firestore `regex_patterns/sms_patterns` document
- Tracker matching: By SMS sender (VM-HDFCBK, etc.)

**Issues:**
- ❌ Cloud storage (not privacy-first)
- ❌ Sender-based tracker matching (ambiguous when user has multiple accounts)
- ❌ Old code path still in use

### System 2: Manual Email Import (NEW - SQLite)

**Location:** `lib/screens/email_transactions/email_transactions_screen.dart` → `lib/services/generic_transaction_parser_service.dart`

**Flow:**
```
User triggers sync → Fetch emails via Gmail API →
Parse (AI only, no regex) → Save to Local SQLite transactions → User reviews
```

**Storage:**
- Transactions: Local SQLite `transactions` table
- Patterns: Local SQLite `patterns` table (but not used for emails!)
- Tracker matching: **NOT IMPLEMENTED** ❌

**Issues:**
- ❌ No tracker matching for email transactions
- ❌ No pattern matching (always uses AI - expensive)
- ❌ Inconsistent with SMS flow

---

## Problems & Pain Points

### 1. Dual Storage System ⚠️ CRITICAL

**Problem:**
```
SMS → Firestore (cloud)
Email → SQLite (local)
```

**Impact:**
- Data fragmentation
- Inconsistent privacy model
- User confusion (two different review screens)
- Complex migration required (but user approved deletion)

**Solution:** Migrate SMS to use SQLite, delete Firestore data

---

### 2. Tracker Matching Inconsistency ⚠️ CRITICAL

**Problem:**
```
Current (Flawed):
SMS sender "VM-HDFCBK" → Could be any HDFC account
Email domain "hdfcbank.com" → Could be any HDFC account

User has:
- HDFC Savings (XX1234)
- HDFC Credit Card (XX5678)

Which tracker should be used? → First match wins (arbitrary!)
```

**Impact:**
- Wrong tracker assignment
- Money Tracker feature shows incorrect balances
- User loses trust in automated tracking

**Solution:** Extract account number (XX1234) from transaction, match to tracker.accountNumber

---

### 3. Missing Features

| Feature | SMS (Old) | Email (New) | Status |
|---------|-----------|-------------|--------|
| Tracker matching | ✅ (by sender) | ❌ Not implemented | **Needs fix** |
| Pattern storage | ✅ Firestore | ✅ SQLite | **Needs unification** |
| Pattern matching | ✅ Regex first | ❌ AI only | **Needs implementation** |
| Local storage | ❌ Firestore | ✅ SQLite | **SMS needs migration** |
| Account extraction | ⚠️ Sometimes | ⚠️ Sometimes | **Needs enforcement** |

---

### 4. Pattern Storage Fragmentation

**Current State:**
```
Built-in Patterns (50+)
├── Location: lib/services/sms_parser_service.dart
├── Storage: Hardcoded in code
└── Source: Manual

AI-Generated Patterns (SMS)
├── Location: Firestore regex_patterns/sms_patterns
├── Storage: Cloud (one document with all patterns as fields)
└── Source: AI after first parse

AI-Generated Patterns (Email)
├── Location: Local SQLite patterns table
├── Storage: Local (but never queried for emails!)
└── Source: AI after first parse

Issue: Three different pattern sources, no unified lookup!
```

---

### 5. Cost Inefficiency for Emails

**Current:** Emails always use AI (no pattern matching)

**Cost Analysis:**
```
User syncs 100 emails from HDFC Bank (same format)
Current: 100 AI calls × ₹0.13 = ₹13.00
Optimal: 1 AI call (generates pattern) + 99 regex matches = ₹0.13

Savings: 99%! 💰
```

---

## Proposed Solution

### Core Principles

1. **Privacy-First**: 100% local SQLite storage, encrypted raw content
2. **Account-Based Matching**: Use accountLast4 as primary tracker identifier
3. **Unified Code Path**: Single parser for SMS and Email
4. **Self-Learning**: AI generates patterns; future transactions use regex (free)
5. **Smart Filtering**: Block OTP/promo messages before AI processing

---

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    MESSAGE ARRIVES                          │
│                   (SMS or Email)                            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│              FILTER 1: OTP/Info/Promo                       │
│  • Skip non-financial messages                              │
│  • Cost: ₹0 (filtered before AI)                            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│          FILTER 2: Financial Sender Check                   │
│  • Known bank format? Transaction keywords?                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│              FILTER 3: Duplicate Check                      │
│  • By transaction ID or raw text hash                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│            PATTERN MATCHING (Sender-based)                  │
│                                                              │
│  Query: SELECT * FROM patterns                              │
│         WHERE sender_hash = SHA256(sender)                  │
│           AND source = 'sms' or 'email'                     │
│                                                              │
│  Tier 1: Tracker-specific patterns (optional)               │
│  Tier 2: Shared sender patterns                             │
│  Tier 3: Built-in hardcoded patterns                        │
│                                                              │
│  Result: Extract amount, merchant, accountLast4 ⭐          │
│  Cost: ₹0 (FREE!)                                            │
└─────────────────────────────────────────────────────────────┘
          ↓ (if pattern found)            ↓ (if no pattern)
┌─────────────────────────┐    ┌──────────────────────────────┐
│   EXTRACTED DATA        │    │    AI FALLBACK (Cloud)       │
│   • amount              │    │  • Gemini 1.5 Flash          │
│   • merchant            │    │  • Extract all fields        │
│   • accountLast4 ⭐     │    │  • Generate regex pattern    │
│   • transactionId       │    │  • Return in 2-3s            │
│   • category            │    │  Cost: ~₹0.13                │
└─────────────────────────┘    └──────────────────────────────┘
          ↓                                ↓
          └────────────┬───────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│         TRACKER MATCHING (Account-based) ⭐                 │
│                                                              │
│  Tier 1: Exact Account Match (PRIMARY)                      │
│    if (accountLast4 matches tracker.accountNumber)          │
│      → trackerId, confidence: 1.0 ✅                        │
│                                                              │
│  Tier 2: Sender Match (FALLBACK)                            │
│    if (sender matches tracker SMS/email domains)            │
│      → trackerId, confidence: 0.5 ⚠️                        │
│                                                              │
│  Tier 3: No Match                                           │
│    → trackerId: null, confidence: 0.0                       │
│    → User assigns during review                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│              SAVE TO LOCAL SQLITE                           │
│                                                              │
│  LocalTransactionModel(                                     │
│    trackerId: "...",      // May be null                    │
│    trackerConfidence: 0.0-1.0,                              │
│    amount: ...,                                             │
│    merchant: ...,                                           │
│    accountInfo: "XX1234", // Used for matching              │
│    rawContent: "...",     // Encrypted!                     │
│    status: pending,                                         │
│  )                                                           │
│                                                              │
│  + Save AI-generated pattern (if any)                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                   USER REVIEW                               │
│                                                              │
│  If trackerId = null OR confidence < 0.8:                   │
│    • Show "No tracker" warning                              │
│    • Suggest creating tracker (if unknown sender)           │
│    • Let user assign/create                                 │
│                                                              │
│  If confidence >= 0.8:                                      │
│    • Show matched tracker                                   │
│    • Quick confirm button                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Architecture Changes

### 1. Data Models

#### 1.1 BulkTransactionItem (NEW FIELD)

**File:** `lib/models/local_transaction_model.dart`

```dart
class BulkTransactionItem {
  final int index;
  final String text;
  final String sender;
  final DateTime date;
  final TransactionSource source;
  final String? trackerId;  // ✅ ADD THIS

  BulkTransactionItem({
    required this.index,
    required this.text,
    required this.sender,
    required this.date,
    required this.source,
    this.trackerId,  // ✅ ADD THIS
  });
}
```

**Reason:** Allow pre-matching of tracker before bulk processing

---

#### 1.2 LocalTransactionModel (NEW FIELDS)

**File:** `lib/models/local_transaction_model.dart`

```dart
class LocalTransactionModel {
  final String id;
  final TransactionSource source;
  final String? sourceIdentifier;

  // ✅ ADD THESE FIELDS
  final String? trackerId;              // Link to tracker
  final double? trackerConfidence;      // 0.0 to 1.0 match confidence

  final double amount;
  final String merchant;
  final String category;
  final DateTime transactionDate;

  final String? accountInfo;            // ⭐ CRITICAL: XX1234
  final String? transactionId;
  final String? notes;
  final String? rawContent;             // Encrypted

  final TransactionStatus status;
  final bool isDebit;

  final DateTime parsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final String? deviceId;

  final ParseMethod parsedBy;
  final String? patternId;
  final double? confidence;

  LocalTransactionModel({
    required this.id,
    required this.source,
    this.sourceIdentifier,
    this.trackerId,              // ✅ ADD
    this.trackerConfidence,      // ✅ ADD
    required this.amount,
    required this.merchant,
    required this.category,
    required this.transactionDate,
    this.accountInfo,
    this.transactionId,
    this.notes,
    this.rawContent,
    this.status = TransactionStatus.pending,
    this.isDebit = true,
    DateTime? parsedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.userId,
    this.deviceId,
    this.parsedBy = ParseMethod.manual,
    this.patternId,
    this.confidence,
  }) : parsedAt = parsedAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': source.name,
      'source_identifier': sourceIdentifier,
      'tracker_id': trackerId,              // ✅ ADD
      'tracker_confidence': trackerConfidence,  // ✅ ADD
      'amount': amount,
      'merchant': merchant,
      'category': category,
      'transaction_date': transactionDate.toIso8601String(),
      'account_info': accountInfo,
      'transaction_id': transactionId,
      'notes': notes,
      'raw_content': rawContent,
      'status': status.name,
      'is_debit': isDebit ? 1 : 0,
      'parsed_at': parsedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_id': userId,
      'device_id': deviceId,
      'parsed_by': parsedBy.name,
      'pattern_id': patternId,
      'confidence': confidence,
    };
  }

  factory LocalTransactionModel.fromMap(Map<String, dynamic> map) {
    return LocalTransactionModel(
      id: map['id'] as String,
      source: TransactionSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => TransactionSource.manual,
      ),
      sourceIdentifier: map['source_identifier'] as String?,
      trackerId: map['tracker_id'] as String?,              // ✅ ADD
      trackerConfidence: (map['tracker_confidence'] as num?)?.toDouble(),  // ✅ ADD
      amount: (map['amount'] as num).toDouble(),
      merchant: map['merchant'] as String,
      category: map['category'] as String,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      accountInfo: map['account_info'] as String?,
      transactionId: map['transaction_id'] as String?,
      notes: map['notes'] as String?,
      rawContent: map['raw_content'] as String?,
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TransactionStatus.pending,
      ),
      isDebit: (map['is_debit'] as int) == 1,
      parsedAt: DateTime.parse(map['parsed_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      userId: map['user_id'] as String,
      deviceId: map['device_id'] as String?,
      parsedBy: ParseMethod.values.firstWhere(
        (e) => e.name == map['parsed_by'],
        orElse: () => ParseMethod.manual,
      ),
      patternId: map['pattern_id'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble(),
    );
  }
}
```

---

#### 1.3 LocalPatternModel (OPTIONAL FIELD)

**File:** `lib/models/local_pattern_model.dart`

```dart
class LocalPatternModel {
  final String id;
  final String senderHash;        // SHA256(sender) for privacy
  final TransactionSource source; // 'sms' or 'email'
  final String? trackerId;        // ✅ OPTIONAL: tracker-specific pattern

  final String pattern;           // Regex pattern
  final Map<String, dynamic> extractionMap;  // field → capture group
  final String category;
  final bool isDebit;

  final String? sampleText;       // Encrypted sample
  final String? description;

  final double accuracy;          // 0-100
  final int matchCount;
  final int failCount;
  final DateTime? lastMatchDate;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final bool isActive;

  LocalPatternModel({
    required this.id,
    required this.senderHash,
    required this.source,
    this.trackerId,  // ✅ OPTIONAL for tracker-specific patterns
    required this.pattern,
    required this.extractionMap,
    required this.category,
    required this.isDebit,
    this.sampleText,
    this.description,
    required this.accuracy,
    required this.matchCount,
    required this.failCount,
    this.lastMatchDate,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    this.isActive = true,
  });

  // ... toMap() and fromMap() methods
}
```

**Pattern Matching Priority:**
1. Try tracker-specific patterns first (`trackerId != null`)
2. Fall back to shared patterns (`trackerId == null`)
3. Fall back to built-in patterns (hardcoded)

---

### 2. Database Schema Changes

#### 2.1 Transactions Table - Add Columns

**File:** `lib/services/local_db_service.dart`

```sql
ALTER TABLE transactions ADD COLUMN tracker_id TEXT;
ALTER TABLE transactions ADD COLUMN tracker_confidence REAL;

CREATE INDEX idx_transactions_tracker_id
  ON transactions(tracker_id);

CREATE INDEX idx_transactions_account_info
  ON transactions(account_info);
```

**Migration:**
```dart
Future<void> _migrateToV2(Database db) async {
  await db.execute('''
    ALTER TABLE transactions ADD COLUMN tracker_id TEXT
  ''');

  await db.execute('''
    ALTER TABLE transactions ADD COLUMN tracker_confidence REAL
  ''');

  await db.execute('''
    CREATE INDEX idx_transactions_tracker_id
    ON transactions(tracker_id)
  ''');

  await db.execute('''
    CREATE INDEX idx_transactions_account_info
    ON transactions(account_info)
  ''');

  print('✅ Database migrated to v2: Added tracker fields');
}
```

---

#### 2.2 Patterns Table - Add Column (Optional)

```sql
ALTER TABLE patterns ADD COLUMN tracker_id TEXT;

CREATE INDEX idx_patterns_tracker_sender
  ON patterns(tracker_id, sender_hash, source);
```

**Usage:** Allow tracker-specific patterns for fine-tuned matching

---

### 3. New Services

#### 3.1 TrackerMatchingService (NEW)

**File:** `lib/services/tracker_matching_service.dart`

```dart
import 'package:spendpal/models/account_tracker_model.dart';
import 'package:spendpal/models/local_transaction_model.dart';
import 'package:spendpal/services/account_tracker_service.dart';
import 'package:spendpal/config/tracker_registry.dart';

/// Service for matching transactions to trackers
///
/// Uses 3-tier matching:
/// 1. Account number match (highest confidence)
/// 2. Sender/domain match (medium confidence)
/// 3. No match (user assigns)
class TrackerMatchingService {
  /// Match transaction to tracker
  /// Returns (trackerId, confidence)
  static Future<(String?, double)> matchTracker({
    required String userId,
    required String? accountLast4,
    required String sender,
    required TransactionSource source,
  }) async {
    final trackers = await AccountTrackerService.getActiveTrackers(userId);

    if (trackers.isEmpty) {
      print('⚠️  No active trackers configured');
      return (null, 0.0);
    }

    // ====================================================================
    // TIER 1: Exact account match (PRIMARY - HIGHEST CONFIDENCE)
    // ====================================================================
    if (accountLast4 != null && accountLast4.isNotEmpty) {
      for (final tracker in trackers) {
        if (tracker.accountNumber == accountLast4) {
          print('✅ Exact tracker match: ${tracker.name} (XX$accountLast4)');
          return (tracker.id, 1.0);  // 100% confidence
        }
      }

      print('⚠️  Account XX$accountLast4 not found in configured trackers');
    }

    // ====================================================================
    // TIER 2: Sender/domain match (FALLBACK - MEDIUM CONFIDENCE)
    // ====================================================================
    final matched = <AccountTrackerModel>[];

    for (final tracker in trackers) {
      bool matches = false;

      if (source == TransactionSource.sms) {
        matches = TrackerRegistry.matchesSmsSender(
          tracker.category,
          sender,
        );
      } else if (source == TransactionSource.email) {
        matches = TrackerRegistry.matchesEmailDomain(
          tracker.category,
          sender,
        );
      }

      if (matches) {
        matched.add(tracker);
      }
    }

    if (matched.isEmpty) {
      print('❌ No tracker match found for sender: $sender');
      return (null, 0.0);
    }

    if (matched.length == 1) {
      print('⚠️  Fallback match: ${matched[0].name} (by sender, no account)');
      return (matched[0].id, 0.5);  // 50% confidence
    }

    // Multiple matches - pick most recently used
    matched.sort((a, b) {
      final aTime = a.lastSyncedAt ?? DateTime(2000);
      final bTime = b.lastSyncedAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    print('⚠️  Multiple matches (${matched.length}), using most recent: ${matched[0].name}');
    return (matched[0].id, 0.3);  // 30% confidence (very uncertain)
  }

  /// Check if sender looks like a bank/financial institution
  static bool isLikelyFinancialSender(String sender, String text) {
    // Bank sender format (VM-XXX, AD-XXX, etc.)
    if (RegExp(r'^(VM|AD|AX|BK|TX|TM|AM|BP|DP|GP|HP|JP|KP|LP|MP|NP|OP|PP|QP|RP|SP|TP|UP|VP|WP|XP|YP|ZP)-').hasMatch(sender)) {
      return true;
    }

    // Transaction keywords
    final transactionKeywords = [
      'debited', 'credited', 'withdrawn', 'deposited',
      'balance', 'transaction', 'txn', 'payment',
      'purchase', 'transfer', 'INR', 'Rs', 'A/c'
    ];

    for (final keyword in transactionKeywords) {
      if (text.toLowerCase().contains(keyword.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  /// Check if message is OTP or informational (not transaction)
  static bool isOtpOrInfoMessage(String text) {
    final textLower = text.toLowerCase();

    // OTP keywords
    final otpKeywords = [
      'otp', 'one time password', 'verification code',
      'otp is', 'your otp', 'enter otp',
      'valid for', 'do not share', 'verify',
      'authentication', 'passcode', 'pin is'
    ];

    for (final keyword in otpKeywords) {
      if (textLower.contains(keyword)) {
        return true;
      }
    }

    // Info keywords (not transactions)
    final infoKeywords = [
      'available balance', 'credit limit', 'minimum due',
      'statement generated', 'bill due on', 'autopay',
      'thank you for', 'welcome to', 'registered successfully',
      'congratulations', 'activated', 'service request'
    ];

    bool hasInfoKeyword = false;
    for (final keyword in infoKeywords) {
      if (textLower.contains(keyword)) {
        hasInfoKeyword = true;
        break;
      }
    }

    // If has info keyword but NO transaction keyword, it's info
    if (hasInfoKeyword) {
      final hasTransactionKeyword =
        textLower.contains('debited') || textLower.contains('credited');

      if (!hasTransactionKeyword) {
        return true;
      }
    }

    return false;
  }
}
```

---

#### 3.2 TrackerRegistry Enhancement (ADD METHOD)

**File:** `lib/config/tracker_registry.dart`

```dart
/// Match email sender against tracker's email domains
/// Example: "alerts@hdfcbank.com" matches ["hdfcbank.com", "hdfcbank.net"]
static bool matchesEmailDomain(TrackerCategory category, String emailSender) {
  final template = templates[category];
  if (template == null || template.emailDomains.isEmpty) {
    return false;
  }

  final normalizedEmail = emailSender.toLowerCase();

  return template.emailDomains.any((domain) {
    final normalizedDomain = domain.toLowerCase();
    return normalizedEmail.contains('@$normalizedDomain') ||
           normalizedEmail.endsWith(normalizedDomain);
  });
}

/// Get email domains for a specific category
static List<String> getEmailDomainsForCategory(TrackerCategory category) {
  return templates[category]?.emailDomains ?? [];
}
```

---

### 4. Service Updates

#### 4.1 GenericTransactionParserService Updates

**File:** `lib/services/generic_transaction_parser_service.dart`

**Changes:**

1. **After extracting data (regex or AI), match tracker:**

```dart
// Around line 195, after creating transaction from AI result:

// ✅ ADD: Match tracker using account number
final (trackerId, trackerConfidence) = await TrackerMatchingService.matchTracker(
  userId: userId,
  accountLast4: data['accountLast4'] as String?,
  sender: originalItem.sender,
  source: originalItem.source,
);

final transaction = LocalTransactionModel(
  id: const Uuid().v4(),
  source: originalItem.source,
  sourceIdentifier: originalItem.sender,

  // ✅ ADD: Tracker link
  trackerId: trackerId,
  trackerConfidence: trackerConfidence,

  amount: (data['amount'] as num).toDouble(),
  merchant: data['merchant'] as String,
  category: data['category'] as String,
  transactionDate: DateTime.parse(data['date']),
  accountInfo: data['accountLast4'] != null
      ? 'XX${data['accountLast4']}'
      : null,
  transactionId: data['transactionId'] as String?,
  rawContent: originalItem.text,
  status: TransactionStatus.pending,
  isDebit: true,
  userId: userId,
  deviceId: deviceId,
  parsedBy: ParseMethod.ai,
  confidence: 0.95,
);
```

2. **Add filtering before processing:**

```dart
// Around line 52, enhance filtering:

// Filter out OTP and informational messages
print('🔍 Filtering OTP and informational messages...');
final validItems = items.where((item) {
  if (TrackerMatchingService.isOtpOrInfoMessage(item.text)) {
    return false;
  }

  if (!TrackerMatchingService.isLikelyFinancialSender(item.sender, item.text)) {
    return false;
  }

  return true;
}).toList();

final filteredCount = items.length - validItems.length;
if (filteredCount > 0) {
  print('⚠️  Filtered out $filteredCount OTP/info/non-financial messages');
}
```

---

#### 4.2 LocalDBService Updates

**File:** `lib/services/local_db_service.dart`

**Changes:**

1. **Update database version and add migration:**

```dart
static const int _databaseVersion = 2;  // Increment version

Future<void> _onCreate(Database db, int version) async {
  // ... existing table creation ...

  await db.execute('''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      source TEXT NOT NULL,
      source_identifier TEXT,
      tracker_id TEXT,              -- ✅ NEW
      tracker_confidence REAL,      -- ✅ NEW
      amount REAL NOT NULL,
      merchant TEXT NOT NULL,
      category TEXT NOT NULL,
      transaction_date TEXT NOT NULL,
      transaction_id TEXT,
      account_info TEXT,
      notes TEXT,
      raw_content TEXT,
      status TEXT DEFAULT 'pending',
      is_debit INTEGER DEFAULT 1,
      parsed_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      user_id TEXT NOT NULL,
      device_id TEXT,
      parsed_by TEXT,
      pattern_id TEXT,
      confidence REAL
    )
  ''');

  await db.execute('''
    CREATE INDEX idx_transactions_user_status
    ON transactions(user_id, status)
  ''');

  await db.execute('''
    CREATE INDEX idx_transactions_tracker_id
    ON transactions(tracker_id)
  ''');

  await db.execute('''
    CREATE INDEX idx_transactions_account_info
    ON transactions(account_info)
  ''');

  // ... rest of indexes ...
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // Add tracker fields
    await db.execute('ALTER TABLE transactions ADD COLUMN tracker_id TEXT');
    await db.execute('ALTER TABLE transactions ADD COLUMN tracker_confidence REAL');

    await db.execute('''
      CREATE INDEX idx_transactions_tracker_id
      ON transactions(tracker_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_account_info
      ON transactions(account_info)
    ''');

    print('✅ Database upgraded to v2: Added tracker fields');
  }
}
```

2. **Update insert methods to include tracker fields** (already handled by `toMap()`)

3. **Add query method to get transactions by tracker:**

```dart
/// Get transactions for a specific tracker
Future<List<LocalTransactionModel>> getTransactionsByTracker({
  required String userId,
  required String trackerId,
  TransactionStatus? status,
}) async {
  final db = await database;

  String whereClause = 'user_id = ? AND tracker_id = ?';
  List<dynamic> whereArgs = [userId, trackerId];

  if (status != null) {
    whereClause += ' AND status = ?';
    whereArgs.add(status.name);
  }

  final maps = await db.query(
    'transactions',
    where: whereClause,
    whereArgs: whereArgs,
    orderBy: 'transaction_date DESC',
  );

  return maps.map((map) => LocalTransactionModel.fromMap(map)).toList();
}

/// Get transactions without tracker (needs review)
Future<List<LocalTransactionModel>> getTransactionsWithoutTracker({
  required String userId,
}) async {
  final db = await database;

  final maps = await db.query(
    'transactions',
    where: 'user_id = ? AND tracker_id IS NULL AND status = ?',
    whereArgs: [userId, TransactionStatus.pending.name],
    orderBy: 'transaction_date DESC',
  );

  return maps.map((map) => LocalTransactionModel.fromMap(map)).toList();
}
```

---

#### 4.3 SMS Listener Migration

**File:** `lib/services/sms_listener_service_android.dart`

**Replace** `AiSmsParserService.parseSmsWithAI()` with `GenericTransactionParserService.parseBulkTransactions()`

```dart
// OLD CODE (lines 256-271):
AiSmsParserService.parseSmsWithAI(
  smsText: smsBody,
  sender: sender,
  date: receivedAt,
  trackerId: matchedTrackerId,  // This was being passed but not used correctly
).then((smsExpense) {
  if (smsExpense != null) {
    print('💰 Transaction detected:');
    // ...
  }
});

// ✅ NEW CODE:
GenericTransactionParserService.parseBulkTransactions(
  items: [
    BulkTransactionItem(
      index: 0,
      text: smsBody,
      sender: sender,
      date: receivedAt,
      source: TransactionSource.sms,
      trackerId: null,  // Don't pre-assign; let account matching decide
    )
  ],
  userId: userId,
).then((transactions) {
  if (transactions.isNotEmpty) {
    final transaction = transactions.first;
    print('💰 Transaction detected:');
    print('   Amount: ₹${transaction.amount}');
    print('   Merchant: ${transaction.merchant}');
    print('   Category: ${transaction.category}');
    print('   Tracker: ${transaction.trackerId ?? "Not assigned"}');
    print('   Confidence: ${transaction.trackerConfidence ?? 0.0}');
    print('✅ SMS transaction saved to local SQLite');
  }
}).catchError((e) {
  print('❌ Error processing SMS: $e');
});
```

**Remove** old tracker matching code (lines 212-227) since `TrackerMatchingService` handles it now.

---

#### 4.4 Email Import Updates

**File:** `lib/screens/email_transactions/email_transactions_screen.dart`

**No tracker matching code exists currently**, but `GenericTransactionParserService` will handle it automatically after our updates.

**Optional enhancement:** Add email filtering before creating `BulkTransactionItem` to skip obvious non-transaction emails.

---

### 5. Cloud Function Updates

**File:** `functions/src/index.ts`

**Update AI prompt to emphasize account extraction:**

```typescript
const AI_PROMPT = `
You are a financial transaction parser for Indian banks and financial institutions.

CRITICAL REQUIREMENT: You MUST extract the account number (last 4 digits).
This is essential for identifying which bank account the transaction belongs to.

Look for these patterns:
- "A/c XX1234" or "A/c ****1234" or "account ending 1234"
- "Card ending 5678" or "Card XX5678"
- "****9012" (masked format)
- Any 4-digit number associated with account/card/wallet

REQUIRED OUTPUT FIELDS:
{
  "data": {
    "amount": number,              // Required
    "merchant": string,            // Required
    "accountLast4": string,        // ⭐ REQUIRED! (if not found, return null)
    "category": string,            // Required
    "isDebit": boolean,            // Required
    "transactionId": string | null,
    "date": "YYYY-MM-DD",
    "balance": number | null,

    // Optional: Bank detection for unknown senders
    "detectedBank": string | null,     // e.g., "Bandhan Bank"
    "senderType": "bank" | "wallet" | "merchant" | "unknown"
  },
  "regexPattern": {
    "pattern": string,             // Regex with capture groups
    "extractionMap": {
      "amount": number,            // Capture group number
      "accountLast4": number,      // ⭐ MUST INCLUDE!
      "merchant": number,
      "transactionId": number | null
    },
    "description": string,
    "confidence": number           // 0-100
  }
}

IMPORTANT:
- Account number extraction is TOP PRIORITY
- Pattern MUST extract account number to a capture group
- If account number not found in text, return null (don't guess)
- Pattern should be specific to this sender's format
`;
```

---

## Data Flow

### Complete Flow: SMS Transaction

```
┌─────────────────────────────────────────────────────────────────┐
│  1. SMS ARRIVES                                                  │
│     Sender: VM-HDFCBK                                            │
│     Text: "Rs 1234.56 debited from A/c XX1234 at AMAZON"       │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  2. BACKGROUND LISTENER                                          │
│     lib/services/sms_listener_service_android.dart               │
│     Method: _processSms()                                        │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  3. PRE-FILTERING                                                │
│     TrackerMatchingService.isOtpOrInfoMessage()                  │
│     ✅ Not OTP, not info → Continue                              │
│                                                                  │
│     TrackerMatchingService.isLikelyFinancialSender()             │
│     ✅ Bank format (VM-HDFCBK) + keywords → Continue             │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  4. CREATE BULK ITEM                                             │
│     BulkTransactionItem(                                         │
│       index: 0,                                                  │
│       text: "Rs 1234.56...",                                    │
│       sender: "VM-HDFCBK",                                       │
│       date: DateTime.now(),                                      │
│       source: TransactionSource.sms,                             │
│       trackerId: null,  // Don't pre-assign                      │
│     )                                                             │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  5. GENERIC PARSER                                               │
│     GenericTransactionParserService.parseBulkTransactions()      │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  6. PATTERN MATCHING                                             │
│     senderHash = SHA256("VM-HDFCBK")                             │
│     patterns = Query local SQLite patterns table                 │
│                                                                  │
│     Found pattern:                                               │
│       pattern: Rs\s([\d,]+\.\\d{2}).*XX(\d{4}).*at\s(.+)       │
│       extractionMap: {amount: 1, accountLast4: 2, merchant: 3}  │
│                                                                  │
│     ✅ MATCH! Extract:                                           │
│       amount: 1234.56                                            │
│       accountLast4: "1234"  ⭐                                   │
│       merchant: "AMAZON"                                         │
│                                                                  │
│     Cost: ₹0 (FREE!)                                             │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  7. TRACKER MATCHING                                             │
│     TrackerMatchingService.matchTracker(                         │
│       userId: "user123",                                         │
│       accountLast4: "1234",  ⭐                                  │
│       sender: "VM-HDFCBK",                                       │
│       source: TransactionSource.sms,                             │
│     )                                                             │
│                                                                  │
│     User's trackers:                                             │
│       1. HDFC Savings (accountNumber: "1234") ✅ MATCH!         │
│       2. HDFC Credit Card (accountNumber: "5678")                │
│                                                                  │
│     Result:                                                      │
│       trackerId: "hdfc_savings_123"                              │
│       confidence: 1.0 (exact match)                              │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  8. SAVE TO SQLITE                                               │
│     LocalDBService.insertBatch([transaction])                    │
│                                                                  │
│     LocalTransactionModel(                                       │
│       trackerId: "hdfc_savings_123",  ✅                         │
│       trackerConfidence: 1.0,                                    │
│       amount: 1234.56,                                           │
│       merchant: "AMAZON",                                        │
│       accountInfo: "XX1234",                                     │
│       parsedBy: ParseMethod.regex,                               │
│       status: TransactionStatus.pending,                         │
│     )                                                             │
│                                                                  │
│     Database: Local SQLite (encrypted)                           │
│     Table: transactions                                          │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  9. USER REVIEW                                                  │
│     Screen: PendingTransactionsReviewScreen                      │
│                                                                  │
│     Transaction shows:                                           │
│       💳 AMAZON - ₹1234.56                                      │
│       🏦 HDFC Savings (XX1234) ✅ Confidence: 100%              │
│       [Quick Confirm] [Edit] [Ignore]                           │
│                                                                  │
│     User clicks "Quick Confirm"                                  │
│       → status: confirmed                                        │
│       → Appears in Money Tracker with correct account            │
└─────────────────────────────────────────────────────────────────┘
```

---

### Complete Flow: Email Transaction (Unknown Sender)

```
┌─────────────────────────────────────────────────────────────────┐
│  1. USER TRIGGERS SYNC                                           │
│     Screen: EmailTransactionsScreen                              │
│     Button: "Sync Emails"                                        │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  2. FETCH EMAILS                                                 │
│     GmailService.searchTransactionEmails()                       │
│     Query: from:(*bandhanbank.com) AND (debited OR credited)    │
│                                                                  │
│     Found email:                                                 │
│       From: alerts@bandhanbank.com                               │
│       Subject: "Transaction Alert"                               │
│       Body: "INR 890.50 debited from A/c XX4567 at             │
│              RELIANCE FRESH"                                     │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  3. CREATE BULK ITEMS                                            │
│     BulkTransactionItem(                                         │
│       sender: "alerts@bandhanbank.com",                          │
│       text: "INR 890.50 debited...",                            │
│       source: TransactionSource.email,                           │
│     )                                                             │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  4. PATTERN MATCHING                                             │
│     senderHash = SHA256("alerts@bandhanbank.com")                │
│     patterns = Query local SQLite                                │
│                                                                  │
│     ❌ NO PATTERNS FOUND (new sender!)                           │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  5. AI FALLBACK                                                  │
│     Call Cloud Function: parseBulkTransactions                   │
│     Model: Gemini 1.5 Flash                                      │
│                                                                  │
│     AI Response:                                                 │
│     {                                                             │
│       "data": {                                                  │
│         "amount": 890.50,                                        │
│         "merchant": "RELIANCE FRESH",                            │
│         "accountLast4": "4567",  ⭐                              │
│         "category": "Groceries",                                 │
│         "isDebit": true,                                         │
│         "detectedBank": "Bandhan Bank",  ⭐                      │
│         "senderType": "bank"                                     │
│       },                                                          │
│       "regexPattern": {                                          │
│         "pattern": "INR\\s([\\d,]+\\.\\d{2}).*A/c\\sXX(\\d{4}).*at\\s([A-Z\\s]+)",
│         "extractionMap": {                                       │
│           "amount": 1,                                           │
│           "accountLast4": 2,  ⭐                                 │
│           "merchant": 3                                          │
│         },                                                        │
│         "confidence": 88                                         │
│       }                                                           │
│     }                                                             │
│                                                                  │
│     Cost: ₹0.13                                                  │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  6. SAVE PATTERN (LEARNING!)                                     │
│     LocalDBService.insertPattern(                                │
│       LocalPatternModel(                                         │
│         senderHash: SHA256("alerts@bandhanbank.com"),            │
│         source: TransactionSource.email,                         │
│         pattern: "INR\\s([\\d,]+)...",                          │
│         extractionMap: {amount: 1, accountLast4: 2, ...},       │
│       )                                                           │
│     )                                                             │
│                                                                  │
│     ✅ Next email from Bandhan Bank will use regex (FREE!)       │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  7. TRACKER MATCHING                                             │
│     TrackerMatchingService.matchTracker(                         │
│       accountLast4: "4567",  ⭐                                  │
│       sender: "alerts@bandhanbank.com",                          │
│       source: TransactionSource.email,                           │
│     )                                                             │
│                                                                  │
│     User's trackers:                                             │
│       1. HDFC Savings (accountNumber: "1234")                    │
│       2. HDFC Credit Card (accountNumber: "5678")                │
│                                                                  │
│     ❌ NO MATCH (user doesn't have Bandhan tracker)              │
│                                                                  │
│     Result:                                                      │
│       trackerId: null                                            │
│       confidence: 0.0                                            │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  8. SAVE TO SQLITE                                               │
│     LocalTransactionModel(                                       │
│       trackerId: null,  ⚠️                                       │
│       trackerConfidence: 0.0,                                    │
│       amount: 890.50,                                            │
│       merchant: "RELIANCE FRESH",                                │
│       accountInfo: "XX4567",                                     │
│       parsedBy: ParseMethod.ai,                                  │
│       status: TransactionStatus.pending,                         │
│       metadata: {                                                │
│         "detectedBank": "Bandhan Bank",  // From AI              │
│         "needsTracker": true                                     │
│       }                                                           │
│     )                                                             │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  9. USER REVIEW - TRACKER SUGGESTION                             │
│     Screen: PendingTransactionsReviewScreen                      │
│                                                                  │
│     Shows:                                                       │
│       💳 RELIANCE FRESH - ₹890.50                               │
│       ⚠️  No Tracker Assigned                                   │
│                                                                  │
│       💡 This looks like a Bandhan Bank transaction             │
│          Would you like to add this account?                     │
│                                                                  │
│          🏦 Bandhan Bank                                         │
│          Account ending: 4567                                    │
│                                                                  │
│          Account Name:                                           │
│          [Bandhan Savings_____________]                          │
│                                                                  │
│          [✓ Add Tracker & Confirm Transaction]                  │
│                                                                  │
│     User clicks "Add Tracker"                                    │
│       1. Create new AccountTrackerModel                          │
│          - name: "Bandhan Savings"                               │
│          - accountNumber: "4567"                                 │
│          - category: TrackerCategory.bandhanBank                 │
│          - emailDomains: ["bandhanbank.com"]                     │
│                                                                  │
│       2. Update transaction.trackerId                            │
│       3. Update transaction.status = confirmed                   │
│                                                                  │
│       ✅ Future Bandhan Bank transactions auto-match!            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Foundation (Week 1 - Priority 1)

**Goal:** Add tracker support to data models and database

#### Tasks:
1. ✅ **Add `trackerId` to `BulkTransactionItem`** (30 min)
   - File: `lib/models/local_transaction_model.dart`
   - Add optional `trackerId` field
   - Update constructor and `toJson()`

2. ✅ **Add `trackerId` and `trackerConfidence` to `LocalTransactionModel`** (30 min)
   - File: `lib/models/local_transaction_model.dart`
   - Add fields to model
   - Update `toMap()` and `fromMap()`

3. ✅ **Add SQLite columns with migration** (1 hour)
   - File: `lib/services/local_db_service.dart`
   - Increment database version to 2
   - Add `tracker_id` and `tracker_confidence` columns
   - Create indexes for performance
   - Write migration logic in `_onUpgrade()`

4. ✅ **Update `LocalDBService` methods** (30 min)
   - File: `lib/services/local_db_service.dart`
   - Add `getTransactionsByTracker()` method
   - Add `getTransactionsWithoutTracker()` method
   - Test insert/query with new fields

**Testing:**
```bash
flutter test test/unit/local_transaction_model_test.dart
flutter test test/unit/local_db_service_test.dart
```

**Deliverable:** Models and database ready for tracker data

---

### Phase 2: Tracker Matching Logic (Week 1 - Priority 1)

**Goal:** Implement account-number-based tracker matching

#### Tasks:
1. ✅ **Create `TrackerMatchingService`** (2 hours)
   - File: `lib/services/tracker_matching_service.dart` (NEW)
   - Implement `matchTracker()` with 3-tier logic
   - Implement `isLikelyFinancialSender()` filtering
   - Implement `isOtpOrInfoMessage()` filtering
   - Add comprehensive logging

2. ✅ **Add `matchesEmailDomain()` to `TrackerRegistry`** (30 min)
   - File: `lib/config/tracker_registry.dart`
   - Add method to match email domains
   - Add `getEmailDomainsForCategory()` helper

3. ✅ **Unit Tests** (1 hour)
   - Test exact account matching
   - Test sender fallback matching
   - Test filtering (OTP, info, promotional)
   - Test email domain matching

**Testing:**
```bash
flutter test test/unit/tracker_matching_service_test.dart
flutter test test/unit/tracker_registry_test.dart
```

**Deliverable:** Complete tracker matching logic with tests

---

### Phase 3: Integrate Matching into Parser (Week 1-2 - Priority 1)

**Goal:** Make parser use tracker matching

#### Tasks:
1. ✅ **Update `GenericTransactionParserService`** (2 hours)
   - File: `lib/services/generic_transaction_parser_service.dart`
   - Add pre-filtering (Step 1)
   - Call `TrackerMatchingService.matchTracker()` after extraction
   - Pass `trackerId` and `trackerConfidence` to `LocalTransactionModel`
   - Update pattern matching to work for emails (already works, just needs testing)

2. ✅ **Test with sample data** (1 hour)
   - Create test SMS/email samples
   - Mock user with multiple trackers
   - Verify correct tracker assignment
   - Verify confidence scores

**Testing:**
```bash
flutter test test/integration/generic_transaction_parser_test.dart
```

**Manual Testing:**
- Import test emails → Check trackerId assigned correctly
- Send test SMS → Check trackerId assigned correctly

**Deliverable:** Parser correctly assigns trackers based on account number

---

### Phase 4: SMS Listener Migration (Week 2 - Priority 1)

**Goal:** Migrate background SMS listener to new system

#### Tasks:
1. ✅ **Update SMS listener service** (2 hours)
   - File: `lib/services/sms_listener_service_android.dart`
   - Replace `AiSmsParserService.parseSmsWithAI()` call
   - Use `GenericTransactionParserService.parseBulkTransactions()`
   - Remove old tracker matching code (now handled by `TrackerMatchingService`)
   - Update logging

2. ✅ **Test background SMS processing** (1 hour)
   - Send test SMS to device
   - Verify saved to SQLite (not Firestore)
   - Verify tracker assigned correctly
   - Check notification/logging

**Testing:**
- Real device testing with actual bank SMS
- Check `adb logcat` for correct flow
- Query SQLite to verify data

**Deliverable:** Background SMS saves to SQLite with correct tracker

---

### Phase 5: UI Updates (Week 2 - Priority 2)

**Goal:** Update review UI to show tracker confidence and allow assignment

#### Tasks:
1. ✅ **Update `PendingTransactionsReviewScreen`** (3 hours)
   - File: `lib/screens/personal/pending_transactions_review_screen.dart`
   - Show tracker name if assigned
   - Show confidence score (visual indicator: ✅ 100%, ⚠️ 50%, ❌ 0%)
   - Add "Change Tracker" button
   - Add tracker suggestion for `trackerId == null`

2. ✅ **Create tracker selection dialog** (2 hours)
   - Allow user to pick from existing trackers
   - Option to create new tracker
   - Pre-fill account number from transaction
   - Show suggested tracker (if AI detected bank)

3. ✅ **Test user flows** (1 hour)
   - Review with confident match → Quick confirm
   - Review with uncertain match → Change tracker
   - Review with no match → Assign or create tracker

**Deliverable:** User can review and assign trackers easily

---

### Phase 6: Cleanup & Deprecation (Week 2-3 - Priority 2)

**Goal:** Remove old Firestore code, clean codebase

#### Tasks:
1. ✅ **Delete Firestore collections** (10 min)
   - Firebase Console → Firestore
   - Delete `sms_expenses` collection
   - Delete `regex_patterns` collection
   - Confirm with user first

2. ✅ **Remove old services** (1 hour)
   - Delete `lib/services/ai_sms_parser_service.dart`
   - Delete `lib/services/regex_pattern_service.dart`
   - Remove imports across codebase
   - Remove `SmsExpenseModel` (if only used by old system)

3. ✅ **Update Firestore rules** (30 min)
   - File: `firestore.rules`
   - Remove rules for `sms_expenses`
   - Remove rules for `regex_patterns`

4. ✅ **Remove old screens** (if any) (30 min)
   - Check for `SmsExpensesScreen` or similar
   - Remove if it only queries Firestore

**Testing:**
- Full app smoke test
- Verify no references to deleted code
- Check for compilation errors

**Deliverable:** Clean codebase with single unified system

---

### Phase 7: Pattern Storage Optimization (Week 3 - Priority 3)

**Goal:** Ensure patterns work for both SMS and Email

#### Tasks:
1. ✅ **Verify pattern matching for emails** (1 hour)
   - Current code should work, just needs testing
   - Import emails from known banks
   - Verify patterns created and reused
   - Check cost reduction

2. ✅ **Add pattern analytics** (2 hours)
   - Count patterns per sender
   - Track accuracy over time
   - Show cost savings (AI calls avoided)
   - Display in settings or debug screen

3. ✅ **Pattern management UI** (optional) (3 hours)
   - List all patterns
   - Show accuracy, match count
   - Allow manual disable/enable
   - Option to delete low-accuracy patterns

**Deliverable:** Patterns work seamlessly for SMS and Email

---

### Phase 8: Enhancements (Week 3-4 - Priority 3)

**Goal:** Additional features for better UX

#### Tasks:
1. ✅ **Merchant normalization** (3 hours)
   - Create `MerchantNormalizationService`
   - Build common merchant aliases map
   - Apply during parsing and display
   - User-editable mappings

2. ✅ **Improved duplicate detection** (2 hours)
   - Add transaction time to duplicate check
   - Fuzzy merchant matching
   - User confirmation for suspected duplicates

3. ✅ **Cost/usage dashboard** (3 hours)
   - Show AI calls this month
   - Show regex hits and savings
   - Pattern accuracy stats
   - Per-tracker transaction counts

4. ✅ **Secure encryption storage** (2 hours)
   - Android: Use EncryptedSharedPreferences
   - iOS: Use Keychain
   - Migrate existing keys

**Deliverable:** Enhanced features for power users

---

## Testing Strategy

### Unit Tests

**Location:** `test/unit/`

1. **Model Tests**
   - `local_transaction_model_test.dart`
     - Test `toMap()` includes `trackerId`
     - Test `fromMap()` loads `trackerId`
     - Test null handling

2. **Service Tests**
   - `tracker_matching_service_test.dart`
     - Test exact account matching
     - Test sender fallback
     - Test no match scenario
     - Test filtering methods

   - `tracker_registry_test.dart`
     - Test `matchesSmsSender()`
     - Test `matchesEmailDomain()`
     - Test edge cases

3. **Database Tests**
   - `local_db_service_test.dart`
     - Test migration v1 → v2
     - Test insert with `trackerId`
     - Test queries by tracker

### Integration Tests

**Location:** `test/integration/`

1. **Parser Integration**
   - `generic_transaction_parser_test.dart`
     - Test SMS parsing with pattern → tracker match
     - Test email parsing with AI → tracker match
     - Test unknown sender → no tracker
     - Test filtering pipeline

2. **End-to-End Flow**
   - `sms_to_sqlite_test.dart`
     - Mock SMS arrival
     - Verify saved to SQLite
     - Verify trackerId assigned

   - `email_to_sqlite_test.dart`
     - Mock email fetch
     - Verify bulk processing
     - Verify trackerId assigned

### Manual Testing Checklist

**Scenarios to test:**

- [ ] **Known SMS, known account**
  - Send SMS from HDFC with XX1234
  - Verify auto-matched to "HDFC Savings"
  - Confidence should be 1.0

- [ ] **Known SMS, new account**
  - Send SMS from HDFC with XX5678 (not configured)
  - Verify trackerId = null
  - Review UI shows "No tracker"
  - User can assign manually

- [ ] **New SMS sender**
  - Send SMS from unknown bank
  - Verify AI parses correctly
  - Verify pattern saved
  - Next SMS from same sender uses regex

- [ ] **Email sync**
  - Sync emails from Gmail
  - Verify parsed correctly
  - Verify trackers assigned by account number
  - Check pattern reuse on second sync

- [ ] **OTP/Info filtering**
  - Send OTP SMS
  - Verify completely ignored
  - Not saved to database

- [ ] **Multiple HDFC accounts**
  - User has 2 HDFC trackers
  - Send SMS with XX1234 → matches first account
  - Send SMS with XX5678 → matches second account
  - No confusion!

- [ ] **Unknown sender suggestion**
  - Email from new bank
  - Verify "Add tracker" suggestion shown
  - Create tracker from suggestion
  - Verify pre-filled fields

---

## Success Metrics

### Technical Metrics

1. **Storage Consolidation**
   - ✅ 0 transactions in Firestore `sms_expenses`
   - ✅ All transactions in Local SQLite
   - ✅ Old services deleted

2. **Tracker Accuracy**
   - ✅ 95%+ exact account match rate
   - ✅ <5% null tracker assignments (unknown senders only)
   - ✅ <1% wrong tracker assignments

3. **Cost Reduction**
   - ✅ 90%+ of transactions use regex (free)
   - ✅ <10% use AI (first-time senders)
   - ✅ Month-over-month cost decrease

4. **Performance**
   - ✅ Regex parsing: <50ms per transaction
   - ✅ AI parsing: <3s per transaction
   - ✅ Bulk processing: 10-20 emails in <10s

### User Experience Metrics

1. **Automation Rate**
   - ✅ 80%+ transactions auto-matched to tracker
   - ✅ <20% require user review for tracker assignment

2. **Review Time**
   - ✅ <5 seconds to review confident match
   - ✅ <30 seconds to assign tracker manually

3. **Error Rate**
   - ✅ <1% user corrections needed
   - ✅ <0.1% duplicate transactions

---

## Appendix

### A. File Checklist

**Files to Create:**
- [ ] `lib/services/tracker_matching_service.dart`
- [ ] `test/unit/tracker_matching_service_test.dart`
- [ ] `test/integration/generic_transaction_parser_test.dart`

**Files to Modify:**
- [ ] `lib/models/local_transaction_model.dart`
- [ ] `lib/services/local_db_service.dart`
- [ ] `lib/config/tracker_registry.dart`
- [ ] `lib/services/generic_transaction_parser_service.dart`
- [ ] `lib/services/sms_listener_service_android.dart`
- [ ] `lib/screens/personal/pending_transactions_review_screen.dart`
- [ ] `functions/src/index.ts` (Cloud Function)

**Files to Delete:**
- [ ] `lib/services/ai_sms_parser_service.dart`
- [ ] `lib/services/regex_pattern_service.dart`
- [ ] `lib/models/regex_pattern_model.dart` (if only used by old system)
- [ ] `lib/screens/sms_expenses/sms_expenses_screen.dart` (if exists)

---

### B. Database Schema Reference

**Transactions Table (After Migration):**
```sql
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL,                  -- 'sms', 'email', 'manual'
  source_identifier TEXT,                -- SMS sender or email address
  tracker_id TEXT,                       -- ✅ NEW: Link to tracker
  tracker_confidence REAL,               -- ✅ NEW: 0.0 to 1.0

  amount REAL NOT NULL,
  merchant TEXT NOT NULL,
  category TEXT NOT NULL,
  transaction_date TEXT NOT NULL,

  transaction_id TEXT,                   -- Bank txn ID
  account_info TEXT,                     -- XX1234 (used for matching)
  notes TEXT,
  raw_content TEXT,                      -- Encrypted SMS/email

  status TEXT DEFAULT 'pending',         -- pending, confirmed, ignored
  is_debit INTEGER DEFAULT 1,

  parsed_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  user_id TEXT NOT NULL,
  device_id TEXT,

  parsed_by TEXT,                        -- 'ai', 'regex', 'manual'
  pattern_id TEXT,                       -- Pattern used
  confidence REAL                        -- AI confidence
);

-- Indexes
CREATE INDEX idx_transactions_user_status
  ON transactions(user_id, status);

CREATE INDEX idx_transactions_tracker_id
  ON transactions(tracker_id);

CREATE INDEX idx_transactions_account_info
  ON transactions(account_info);

CREATE INDEX idx_transactions_date
  ON transactions(transaction_date);
```

---

### C. AI Prompt Reference

**Complete Prompt for Cloud Function:**

```
You are a financial transaction parser for Indian banks and financial institutions.

CRITICAL REQUIREMENT: Extract the account number (last 4 digits). This is essential for identifying which bank account the transaction belongs to.

Look for these patterns:
- "A/c XX1234" or "A/c ****1234" or "account ending 1234"
- "Card ending 5678" or "Card XX5678"
- "****9012" (masked format)
- Any 4-digit number associated with account/card

REQUIRED OUTPUT:
{
  "data": {
    "amount": number,
    "merchant": string,
    "accountLast4": string,        // ⭐ REQUIRED!
    "category": string,
    "isDebit": boolean,
    "transactionId": string | null,
    "date": "YYYY-MM-DD",
    "balance": number | null,

    // Optional: Bank detection
    "detectedBank": string | null,
    "senderType": "bank" | "wallet" | "merchant" | "unknown"
  },
  "regexPattern": {
    "pattern": string,
    "extractionMap": {
      "amount": number,
      "accountLast4": number,      // ⭐ MUST INCLUDE!
      "merchant": number,
      "transactionId": number | null
    },
    "description": string,
    "confidence": number (0-100)
  }
}

IMPORTANT:
- Account extraction is TOP PRIORITY
- Pattern MUST extract account to a capture group
- If account not found, return null (don't guess)
- Pattern should be specific to sender's format
- Handle variations: XX1234, ****1234, ending 1234, etc.
```

---

### D. Migration Notes

**Firestore Deletion:**
Since user approved deletion of Firestore data, no migration tool needed. Simply:

1. Backup current Firestore data (optional, for safety):
```bash
firebase firestore:export gs://your-backup-bucket/backup-2026-01-06
```

2. Delete collections via Firebase Console:
   - Navigate to Firestore
   - Select `sms_expenses` collection
   - Click "Delete collection"
   - Confirm deletion
   - Repeat for `regex_patterns`

3. Update Firestore rules to remove old collection rules

**No user data loss:** New system starts fresh with local SQLite

---

### E. Rollout Plan

**Week 1:**
- Internal testing with dev team
- Fix critical bugs
- Verify tracker matching accuracy

**Week 2:**
- Beta release to 10-20 users
- Monitor logs for errors
- Collect feedback on UX

**Week 3:**
- Fix issues from beta
- Add polish based on feedback
- Prepare for full rollout

**Week 4:**
- Full release to all users
- Monitor error rates
- Be ready for hotfixes

---

## Implementation Status

**Last Updated:** January 6, 2026

### Phase 1: Tracker Integration in Data Models ✅ COMPLETED

#### 1.1 BulkTransactionItem Model Updates
- ✅ Added `trackerId` field to `BulkTransactionItem` class
- ✅ Updated `toJson()` method to include tracker ID
- **File:** `lib/models/local_transaction_model.dart:267-288`

#### 1.2 LocalTransactionModel Updates
- ✅ Added `trackerId` and `trackerConfidence` fields
- ✅ Updated `fromMap()` serialization to parse tracker fields
- ✅ Updated `toMap()` serialization to include tracker fields
- ✅ Updated `copyWith()` method for tracker field updates
- **File:** `lib/models/local_transaction_model.dart:15-16, 85-88, 124-125, 152-153, 177-178`

#### 1.3 SQLite Database Schema Migration
- ✅ Incremented database version from 2 to 3
- ✅ Added `tracker_id TEXT` column to transactions table
- ✅ Added `tracker_confidence REAL` column to transactions table
- ✅ Created index on `tracker_id` for fast lookups
- ✅ Implemented migration logic in `_onUpgrade()` for existing databases
- ✅ Updated `_onCreate()` for new database installations
- **File:** `lib/services/local_db_service.dart:17, 61-62, 98, 181-189`

#### 1.4 LocalDBService Query Methods
- ✅ Added `getTransactionsByTracker()` method for querying by tracker ID
- ✅ Supports date range filtering and pagination
- ✅ Includes encryption/decryption for raw content
- **File:** `lib/services/local_db_service.dart:469-513`

### Phase 2: Tracker Matching System ✅ COMPLETED

#### 2.1 TrackerRegistry Email Domain Matching
- ✅ Added `getEmailDomainsForCategory()` helper method
- ✅ Implemented `matchesEmailDomain()` for email sender matching
- ✅ Supports exact domain and subdomain matching
- ✅ Added `findMatchingCategoriesForSms()` bulk finder
- ✅ Added `findMatchingCategoriesForEmail()` bulk finder
- **File:** `lib/config/tracker_registry.dart:328-371`

#### 2.2 TrackerMatchingService Implementation
- ✅ Created new service for transaction-to-tracker matching
- ✅ Implemented SMS sender matching with 0.9 confidence
- ✅ Implemented email domain matching with confidence scoring:
  - 1.0: Exact custom domain match
  - 0.95: Subdomain of custom domain
  - 0.8: Exact template domain match
  - 0.7: Subdomain of template domain
- ✅ Added `matchTransaction()` for single transaction matching
- ✅ Added `matchBatch()` for bulk transaction matching
- ✅ Integrates with AccountTrackerService for active tracker lookup
- **File:** `lib/services/tracker_matching_service.dart` (new file)

### Implementation Notes

**Design Decisions:**
1. **Confidence Scoring:** Custom domains get higher confidence (1.0) than template matches (0.8-0.9) to prioritize user-configured trackers
2. **Subdomain Support:** Email matching supports both exact matches and subdomains (e.g., `noreply.hdfcbank.com` matches `hdfcbank.com`)
3. **SMS Normalization:** SMS senders are normalized (uppercase, alphanumeric only) for consistent matching
4. **Database Migration:** Backwards-compatible migration ensures existing users don't lose data

**Files Modified:**
- `lib/models/local_transaction_model.dart`
- `lib/services/local_db_service.dart`
- `lib/config/tracker_registry.dart`

**Files Created:**
- `lib/services/tracker_matching_service.dart`

### Phase 3: Integration with SMS/Email Services ✅ COMPLETED

#### 3.1 SMS Bulk Parsing Integration
- ✅ Added TrackerMatchingService import to `ai_sms_parser_service.dart`
- ✅ Integrated bulk tracker matching in `parseBulkSmsWithAI()` method
- ✅ Converts SMS items to BulkTransactionItem for matching
- ✅ Matches all SMS messages before AI parsing
- ✅ Assigns trackerId and displays confidence logs
- **File:** `lib/services/ai_sms_parser_service.dart:8-9, 383-398, 448-455`

#### 3.2 SMS Individual Parsing Integration
- ✅ Added auto-tracker matching to `parseSmsWithRegexOnly()` method
- ✅ Added auto-tracker matching to `parseSmsWithAI()` method
- ✅ Automatically matches tracker when trackerId not provided
- ✅ Logs tracker match confidence for debugging
- **File:** `lib/services/ai_sms_parser_service.dart:55-66, 174-185`

#### 3.3 Email Bulk Parsing Integration
- ✅ Added TrackerMatchingService import to `generic_transaction_parser_service.dart`
- ✅ Integrated bulk tracker matching for AI-parsed transactions
- ✅ Matches trackers before Cloud Function call
- ✅ Assigns trackerId and trackerConfidence to LocalTransactionModel
- ✅ Logs tracker match results for each transaction
- **File:** `lib/services/generic_transaction_parser_service.dart:9, 89-95, 185-192`

#### 3.4 Email Pattern Matching Integration
- ✅ Added tracker matching to `_tryPatternMatch()` method
- ✅ Matches tracker for each pattern-matched transaction
- ✅ Assigns trackerId and trackerConfidence to transaction
- ✅ Enhanced logging to show both pattern and tracker confidence
- **File:** `lib/services/generic_transaction_parser_service.dart:500-535`

### Implementation Highlights - Phase 3

**Automatic Tracker Assignment:**
- SMS and email transactions automatically get matched to trackers
- No manual intervention required from users
- Works for both bulk and individual parsing

**Confidence Tracking:**
- All tracker matches include confidence scores
- Logged for debugging and monitoring
- Stored in database for future analysis

**Performance Optimization:**
- Bulk matching reduces database queries
- Single tracker fetch for all transactions in batch
- Minimal overhead added to parsing pipeline

### Next Steps (Not Yet Implemented)

**Phase 4: UI Integration**
- ⏳ Update transaction list UI to display tracker information
- ⏳ Add tracker filter in transaction screens
- ⏳ Show tracker badge/icon on transaction cards
- ⏳ Add tracker-based grouping in Money Tracker screen

**Phase 5: Firestore to SQLite Migration**
- ⏳ Implement SMS transaction migration from Firestore to SQLite
- ⏳ Update SMS listener to save directly to SQLite
- ⏳ Remove Firestore SMS code after migration
- ⏳ Clean up old Firestore collections

**Phase 6: Testing & Validation**
- ⏳ Unit tests for TrackerMatchingService
- ⏳ Integration tests for SMS/Email matching
- ⏳ Database migration testing
- ⏳ End-to-end transaction flow testing

---

**Document End**

*This specification should be reviewed and approved before implementation begins.*

*Questions or clarifications: Contact development team*

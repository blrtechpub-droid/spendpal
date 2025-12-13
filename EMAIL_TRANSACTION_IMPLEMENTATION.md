# Email Transaction Implementation Guide

This document explains exactly how SpendPal fetches and processes bank transaction emails from Gmail.

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Stage 1: Gmail API Filtering](#stage-1-gmail-api-filtering)
3. [Stage 2: Email Parsing with Regex](#stage-2-email-parsing-with-regex)
4. [Stage 3: Firestore Storage](#stage-3-firestore-storage)
5. [Complete Flow Diagram](#complete-flow-diagram)
6. [Supported Banks & Patterns](#supported-banks--patterns)

---

## Architecture Overview

The email transaction system works in **3 stages**:

1. **Gmail API Filtering** (Server-side) - Fetch only relevant emails from Gmail
2. **Regex Parsing** (Client-side) - Extract transaction details using pattern matching
3. **Firestore Storage** (Cloud) - Save parsed transactions to queue for user review

**Privacy Note**: All email processing happens on-device. Email content is never sent to SpendPal servers.

---

## Stage 1: Gmail API Filtering

### Location
`lib/services/gmail_service.dart:111-152`

### How It Works

The Gmail API search query filters emails **at Google's servers** before fetching them:

```dart
final query = 'from:(hdfcbank.com OR icicibank.com OR sbi.co.in OR axisbank.com OR kotak.com OR yesbank.in OR indusind.com OR pnbindia.in) (debited OR credited OR transaction OR payment OR spent) after:2024/10/16';
```

### Query Components

| Component | Purpose | Example |
|-----------|---------|---------|
| **from:** | Filter by bank domains | `from:(hdfcbank.com OR icicibank.com)` |
| **Keywords** | Match transaction terms | `(debited OR credited OR payment)` |
| **after:** | Date filter | `after:2024/10/16` (last 30 days) |
| **before:** | Date filter (optional) | `before:2024/11/16` |

### Supported Banks (Stage 1)

- HDFC Bank (`@hdfcbank.com`)
- ICICI Bank (`@icicibank.com`)
- State Bank of India (`@sbi.co.in`)
- Axis Bank (`@axisbank.com`)
- Kotak Mahindra Bank (`@kotak.com`)
- Yes Bank (`@yesbank.in`)
- IndusInd Bank (`@indusind.com`)
- Punjab National Bank (`@pnbindia.in`)

### API Call

```dart
static Future<List<gmail.Message>> searchTransactionEmails({
  DateTime? after,
  DateTime? before,
  int maxResults = 50,
}) async {
  final api = await _getGmailClient();

  final response = await api.users.messages.list(
    'me',
    q: query,
    maxResults: maxResults,
  );

  return response.messages ?? [];
}
```

**Returns**: List of email message IDs (not full content, just metadata)

---

## Stage 2: Email Parsing with Regex

### Location
`lib/services/email_transaction_parser_service.dart:1-248`

### How It Works

For each email fetched from Gmail:

1. **Download full email content** (subject + body)
2. **Verify sender domain** matches known banks
3. **Apply regex patterns** to extract:
   - Transaction amount
   - Transaction type (UPI, debit, credit, credit card)
   - Merchant name
   - Transaction date
4. **Return parsed data** or `null` if no match

### parseEmail() Function

```dart
static Map<String, dynamic>? parseEmail({
  required String senderEmail,
  required String subject,
  required String body,
  required DateTime receivedAt,
}) {
  // Check if from known bank
  if (!isFromBank(senderEmail)) {
    return null;
  }

  // Combine subject and body for parsing
  final content = '$subject\n$body';

  // Try UPI patterns
  for (final pattern in transactionPatterns['upi']!) {
    final match = pattern.firstMatch(content);
    if (match != null) {
      return {
        'type': 'upi',
        'amount': double.parse(match.group(1)!),
        'merchant': extractMerchant(content),
        'transactionDate': extractTransactionDate(content) ?? receivedAt,
        'rawText': content,
        'senderEmail': senderEmail,
        'subject': subject,
      };
    }
  }

  // Try credit card, debit, credit patterns...
  // Returns null if no pattern matches
  return null;
}
```

### Regex Pattern Categories

#### 1. UPI Transactions
```dart
// Pattern: "UPI paid Rs 1234.56"
RegExp(r'UPI.*?(?:paid|sent|debited)[:\s]+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)')

// Pattern: "paid via UPI Rs 1234.56"
RegExp(r'paid.*?UPI.*?(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)')
```

#### 2. Debit Transactions
```dart
// Pattern: "Debited INR 1234.56"
RegExp(r'(?:debited|spent|paid|withdrawn)[:\s]+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)')

// Pattern: "Amount debited: 1234.56"
RegExp(r'amount\s+(?:debited|paid|spent)[:\s]+(?:INR|Rs\.?|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)')

// Pattern: "has been debited with Rs 1234.56"
RegExp(r'(?:has\s+been\s+)?debited\s+with\s+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)')
```

#### 3. Credit Transactions
```dart
// Pattern: "Credited INR 1234.56"
RegExp(r'(?:credited|received|refund(?:ed)?|deposited)[:\s]+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)')

// Pattern: "Amount credited: 1234.56"
RegExp(r'amount\s+(?:credited|received|deposited)[:\s]+(?:INR|Rs\.?|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)')
```

#### 4. Credit Card Transactions
```dart
// Pattern: "credit card charged Rs 1234.56"
RegExp(r'credit\s+card.*?(?:charged|paid|spent|billed)[:\s]+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)')

// Pattern: "card ending 1234 debited Rs 1234.56"
RegExp(r'card\s+(?:ending|no\.|number).*?debited[:\s]+(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)')
```

### Merchant Extraction

```dart
static String? extractMerchant(String emailContent) {
  // Pattern: "at MERCHANT_NAME" or "to MERCHANT_NAME"
  final patterns = [
    RegExp(r'(?:at|to|from)\s+([A-Z][A-Za-z\s&]{2,30})'),
    RegExp(r'merchant[:\s]+([A-Za-z\s&]{3,30})'),
    RegExp(r'(?:store|shop|vendor)[:\s]+([A-Za-z\s&]{3,30})'),
  ];

  // Returns first match or null
}
```

### Date Extraction

```dart
static DateTime? extractTransactionDate(String emailContent) {
  // Pattern: "Date: 16/11/2024" or "on 16-11-2024"
  RegExp(r'(?:date|on)[:\s]+(\d{1,2})[/-](\d{1,2})[/-](\d{4})')

  // Pattern: "16 Nov 2024"
  RegExp(r'(\d{1,2})\s+(Jan|Feb|Mar|...|Dec)[a-z]*\s+(\d{4})')

  // Falls back to email receivedAt date if not found
}
```

---

## Stage 3: Firestore Storage

### Location
`lib/services/email_transaction_parser_service.dart:229-248`

### How It Works

Parsed transactions are saved to a **subcollection** under the user's document:

```
Firestore Structure:
users/{userId}/
  └── emailTransactionQueue/{queueId}
      ├── type: "upi" | "debit" | "credit" | "credit_card"
      ├── amount: 1234.56
      ├── merchant: "Swiggy" | null
      ├── transactionDate: Timestamp
      ├── senderEmail: "alerts@hdfcbank.com"
      ├── subject: "You have spent Rs 1234.56"
      ├── rawText: "Full email content..."
      ├── status: "pending" | "approved" | "ignored"
      └── createdAt: Timestamp
```

### addToQueue() Function

```dart
static Future<bool> addToQueue({
  required String userId,
  required Map<String, dynamic> parsedData,
}) async {
  try {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('emailTransactionQueue')
        .add({
      ...parsedData,
      'status': 'pending',  // User must review and approve
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  } catch (e) {
    print('Error adding email to queue: $e');
    return false;
  }
}
```

### Security Rules

From `firestore.rules:65-69`:

```javascript
match /emailTransactionQueue/{queueId} {
  // Users can only access their own email transactions
  allow read, write: if isOwner(userId);
}
```

### Firestore Index

From `firestore.indexes.json:3-16`:

```json
{
  "collectionGroup": "emailTransactionQueue",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "status",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "createdAt",
      "order": "DESCENDING"
    }
  ]
}
```

This index allows efficient queries like:
```dart
.where('status', isEqualTo: 'pending')
.orderBy('createdAt', descending: true)
```

---

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ User: Tap "Email Transactions" → "Connect Gmail"                │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ STAGE 1: Gmail API Filtering (gmail_service.dart:111-152)       │
├─────────────────────────────────────────────────────────────────┤
│ 1. Build search query:                                          │
│    from:(hdfcbank.com OR icicibank.com OR ...)                  │
│    (debited OR credited OR ...)                                 │
│    after:2024/10/16                                             │
│                                                                  │
│ 2. Call Gmail API:                                              │
│    api.users.messages.list('me', q: query, maxResults: 50)      │
│                                                                  │
│ 3. Returns: List<gmail.Message> (just IDs)                      │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ For each message ID:                                            │
│   1. Fetch full email: GmailService.getEmailDetails(id)         │
│   2. Extract subject, body, sender, date                        │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ STAGE 2: Regex Parsing (email_transaction_parser_service.dart)  │
├─────────────────────────────────────────────────────────────────┤
│ 1. Check sender: isFromBank(senderEmail)                        │
│    → Return null if not from known bank                         │
│                                                                  │
│ 2. Try UPI patterns → Match? Extract amount, return data        │
│    ↓ No match                                                   │
│ 3. Try credit card patterns → Match? Extract amount, return     │
│    ↓ No match                                                   │
│ 4. Try debit patterns → Match? Extract amount, return           │
│    ↓ No match                                                   │
│ 5. Try credit patterns → Match? Extract amount, return          │
│    ↓ No match                                                   │
│ 6. Return null (email doesn't match any pattern)                │
│                                                                  │
│ If matched:                                                      │
│   - Extract merchant: extractMerchant(content)                  │
│   - Extract date: extractTransactionDate(content)               │
│   - Return parsed data Map                                      │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ STAGE 3: Firestore Storage (addToQueue)                         │
├─────────────────────────────────────────────────────────────────┤
│ Save to: users/{userId}/emailTransactionQueue/                  │
│                                                                  │
│ Document fields:                                                │
│   - type: "upi" | "debit" | "credit" | "credit_card"            │
│   - amount: 1234.56                                             │
│   - merchant: "Swiggy" | null                                   │
│   - transactionDate: Timestamp                                  │
│   - senderEmail: "alerts@hdfcbank.com"                          │
│   - subject: "You have spent Rs 1234.56"                        │
│   - rawText: "Full email content..."                            │
│   - status: "pending"                                           │
│   - createdAt: serverTimestamp()                                │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ User Interface (email_transactions_screen.dart)                 │
├─────────────────────────────────────────────────────────────────┤
│ Display transactions in queue:                                  │
│   - Show pending transactions                                   │
│   - User can approve → Create expense                           │
│   - User can ignore → Mark as ignored                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Supported Banks & Patterns

### Banks with Email Filtering (Stage 1)

| Bank | Email Domain | Status |
|------|--------------|--------|
| HDFC Bank | @hdfcbank.com | ✅ Supported |
| ICICI Bank | @icicibank.com | ✅ Supported |
| State Bank of India | @sbi.co.in | ✅ Supported |
| Axis Bank | @axisbank.com | ✅ Supported |
| Kotak Mahindra | @kotak.com | ✅ Supported |
| Yes Bank | @yesbank.in | ✅ Supported |
| IndusInd Bank | @indusind.com | ✅ Supported |
| Punjab National Bank | @pnbindia.in | ✅ Supported |

### Additional Senders (Stage 2 Parsing Only)

| Service | Email Pattern | Type |
|---------|---------------|------|
| Amazon | @alerts.amazon.* | E-commerce |
| Flipkart | @flipkart.com | E-commerce |
| Paytm | @paytm.com | Payment platform |
| Razorpay | @razorpay.com | Payment gateway |

### Example Email Patterns

#### HDFC Bank UPI Email
```
From: alerts@hdfcbank.com
Subject: You have spent Rs 1,234.56 using UPI

Dear Customer,

Your A/c XX1234 has been debited with Rs 1,234.56 on 16-Nov-2024
via UPI to SWIGGY.

Available Balance: Rs 50,000.00

HDFC Bank
```

**Parsed as**:
```dart
{
  'type': 'upi',
  'amount': 1234.56,
  'merchant': 'SWIGGY',
  'transactionDate': DateTime(2024, 11, 16),
  'senderEmail': 'alerts@hdfcbank.com',
  'subject': 'You have spent Rs 1,234.56 using UPI',
  'status': 'pending',
}
```

---

## File References

| File | Lines | Description |
|------|-------|-------------|
| `lib/services/gmail_service.dart` | 111-152 | Gmail API search and email fetching |
| `lib/services/gmail_service.dart` | 296-337 | Email body extraction (HTML to plain text) |
| `lib/services/email_transaction_parser_service.dart` | 9-22 | Bank sender patterns |
| `lib/services/email_transaction_parser_service.dart` | 24-67 | Transaction regex patterns |
| `lib/services/email_transaction_parser_service.dart` | 131-226 | parseEmail() main function |
| `lib/services/email_transaction_parser_service.dart` | 229-248 | addToQueue() Firestore storage |
| `lib/screens/email_transactions/email_transactions_screen.dart` | 86-239 | _syncEmails() orchestration |
| `firestore.rules` | 65-69 | Security rules for email queue |
| `firestore.indexes.json` | 3-16 | Composite index for querying |

---

**Last Updated**: November 16, 2024
**Version**: 1.0
**Author**: SpendPal Development Team

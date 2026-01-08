# Google Play Transaction Analysis - Logic Improvements Needed

**Date:** January 7, 2026
**Transaction:** Google Play ₹1950.00 (06 Jan 2026, 09:50 AM)
**SMS Sender:** CP-AXISBK-S
**Status:** ❌ Multiple Logic Issues Identified

---

## Transaction Data Extracted

### ✅ What's Working

| Field | Value | Status |
|-------|-------|--------|
| **Merchant** | Google Play | ✅ Correct |
| **Amount** | ₹1950.00 | ✅ Correct |
| **Date** | 06 Jan 2026, 09:50 AM | ✅ Correct |
| **Transaction ID** | 687803b61111425dabcdfda0975fdeb4 | ✅ Extracted |
| **Sender** | CP-AXISBK-S | ✅ Extracted |

### ❌ What's Broken or Needs Improvement

| Field | Current Value | Issue | Should Be |
|-------|---------------|-------|-----------|
| **Category** | Utilities | ❌ Wrong category | Shopping or Entertainment |
| **Account** | Full SMS text dump | ❌ Not parsed | "Axis Bank ****xxxx" or UPI ID |
| **Tracker Badge** | Not showing | ❌ Sender not matched | Axis Bank badge |
| **Bank Identification** | Not extracted | ❌ Mixed in text | "Axis Bank" |
| **UPI ID** | Not extracted | ❌ Mixed with txn ID | "687803b61...@okax" |
| **Account Number** | Not extracted | ❌ Not in SMS | N/A (UPI transaction) |

---

## Critical Issues Identified

### 🔴 Issue #1: Missing Tracker Badge (HIGH PRIORITY)

**Problem:**
- SMS Sender: `CP-AXISBK-S`
- TrackerRegistry has: `['VM-AXISBK', 'AD-AXISBK', 'AXISBK', 'AXIS']`
- **Missing:** `CP-AXISBK-S` pattern

**Impact:**
- User can't see which bank account this transaction is from
- Defeats the purpose of tracker matching system
- No auto-categorization by account

**Root Cause:**
```dart
// lib/config/tracker_registry.dart:75
smsSenders: ['VM-AXISBK', 'AD-AXISBK', 'AXISBK', 'AXIS']
```

**Missing sender patterns:**
- `CP-AXISBK-S` (Credit/Payment)
- `CP-AXISBK` (generic)
- `TX-AXISBK` (Transaction alerts)
- `AX-AXISBK` (alternate prefix)

**Fix Required:**
```dart
smsSenders: [
  'VM-AXISBK',    // Existing
  'AD-AXISBK',    // Existing
  'AXISBK',       // Existing
  'AXIS',         // Existing
  'CP-AXISBK-S',  // NEW: Credit/Payment with suffix
  'CP-AXISBK',    // NEW: Credit/Payment
  'TX-AXISBK',    // NEW: Transaction alerts
  'AX-AXISBK',    // NEW: Alternate prefix
]
```

**Verification Needed:**
Check other banks for missing sender patterns:
- HDFC: CP-HDFCBK, TX-HDFCBK?
- ICICI: CP-ICICIB, TX-ICICIB?
- SBI: CP-SBIINB, TX-SBIINB?

---

### 🟠 Issue #2: Wrong Category Classification (MEDIUM PRIORITY)

**Problem:**
- Google Play → Category: "Utilities"
- This is incorrect categorization

**Expected:**
- Google Play → "Shopping" (for app purchases)
- OR "Entertainment" (for media content)
- OR "Subscriptions" (for recurring)

**Root Cause:**
Likely using generic category inference without merchant-specific rules.

**SMS Text:**
```
Your A/c has been debited towards Google Play for INR 1950.00
```

**Keyword Analysis:**
- "towards Google Play" → Should trigger Shopping/Entertainment category
- No utility-related keywords present

**Fix Required:**

1. **Add Merchant-to-Category Mapping:**
```dart
// Category inference improvements
static const Map<String, String> merchantCategoryOverrides = {
  'google play': 'Shopping',
  'play store': 'Shopping',
  'netflix': 'Entertainment',
  'spotify': 'Entertainment',
  'amazon': 'Shopping',
  'swiggy': 'Food & Dining',
  'zomato': 'Food & Dining',
  'uber': 'Transportation',
  'ola': 'Transportation',
  // ... etc
};
```

2. **Improve Category Inference Logic:**
```dart
// Check merchant name first
if (merchantCategoryOverrides.containsKey(merchant.toLowerCase())) {
  return merchantCategoryOverrides[merchant.toLowerCase()];
}

// Then check SMS keywords
if (smsText.contains('electricity') || smsText.contains('water bill')) {
  return 'Utilities';
}
```

**Test Cases Needed:**
- ✅ Google Play → Shopping
- ✅ Netflix → Entertainment
- ✅ Electricity Bill → Utilities
- ✅ Amazon → Shopping
- ✅ Swiggy → Food & Dining

---

### 🟠 Issue #3: Account Field Shows Raw SMS Text (MEDIUM PRIORITY)

**Problem:**
Account field displays:
```
"Your A/c has been debited towards Google Play for INR 1950.00
on 06-01-26. 687803b61111425dabcdfda0975fdeb4@okax is - Axis Bank"
```

This is unparsed SMS text dumped into the field.

**Expected:**
```
"Axis Bank (UPI: 687803...@okax)"
```

OR if account number was present:
```
"Axis Bank ****1234"
```

**Root Cause:**
Regex patterns not extracting:
1. Bank name
2. Account number (or lack thereof for UPI)
3. UPI ID

**SMS Structure Analysis:**
```
Your A/c has been debited towards Google Play
for INR 1950.00
on 06-01-26.
687803b61111425dabcdfda0975fdeb4@okax is - Axis Bank
```

**Key Components:**
- `687803b61111425dabcdfda0975fdeb4@okax` = UPI ID
- `Axis Bank` = Bank name
- No account number (UPI transaction)

**Fix Required:**

1. **Extract Bank Name:**
```dart
RegExp(r'(?:is\s*-\s*)?([A-Z][a-z]+\s+Bank)', caseSensitive: false)
// Matches: "Axis Bank", "HDFC Bank", "ICICI Bank"
```

2. **Extract UPI ID:**
```dart
RegExp(r'([a-zA-Z0-9]+@[a-z]+)')
// Matches: xxx@okax, xxx@paytm, xxx@ybl
```

3. **Account Field Logic:**
```dart
String getAccountDisplay(ParsedSMS sms) {
  if (sms.upiId != null && sms.bankName != null) {
    return '${sms.bankName} (UPI: ${sms.upiId.substring(0, 10)}...@${sms.upiId.split('@').last})';
  } else if (sms.accountNumber != null && sms.bankName != null) {
    return '${sms.bankName} ****${sms.accountNumber}';
  } else if (sms.bankName != null) {
    return sms.bankName;
  } else {
    return 'Unknown Account';
  }
}
```

**Expected Output:**
```
"Axis Bank (UPI: 687803b611...@okax)"
```

---

### 🟡 Issue #4: UPI ID Not Extracted as Separate Field (LOW PRIORITY)

**Problem:**
- UPI ID `687803b61111425dabcdfda0975fdeb4@okax` is mixed with transaction ID
- Not displayed as a separate, identifiable field

**Current State:**
- Transaction ID: `687803b61111425dabcdfda0975fdeb4`
- UPI ID: Not extracted (buried in account text)

**Expected:**
- Transaction ID: (actual bank txn ref if available)
- UPI ID: `687803b61...@okax`
- Account: `Axis Bank (UPI)`

**SMS Patterns to Handle:**

1. **Okaxis UPI:**
   ```
   687803b61111425dabcdfda0975fdeb4@okax
   ```

2. **Paytm UPI:**
   ```
   merchantname.merchant@paytm
   ```

3. **Google Pay UPI:**
   ```
   phonenumber@okicici, phonenumber@okhdfcbank
   ```

4. **PhonePe UPI:**
   ```
   phonenumber@ybl
   ```

**Regex Pattern:**
```dart
// Extract UPI ID
static final upiIdPattern = RegExp(
  r'([a-zA-Z0-9.]+@(?:okaxis|okicici|okhdfcbank|paytm|ybl|axl))',
  caseSensitive: false,
);
```

**UI Display:**
```dart
if (transaction.upiId != null) {
  Row(
    children: [
      Icon(Icons.account_balance_wallet, size: 16),
      SizedBox(width: 4),
      Text('UPI: ${_truncateUpiId(transaction.upiId)}'),
    ],
  )
}

String _truncateUpiId(String upiId) {
  final parts = upiId.split('@');
  if (parts[0].length > 12) {
    return '${parts[0].substring(0, 12)}...@${parts[1]}';
  }
  return upiId;
}
```

---

### 🟡 Issue #5: Bank Name Extraction Missing (LOW PRIORITY)

**Problem:**
- SMS clearly states: "Axis Bank"
- Not extracted as a separate field
- Can't use for validation or display

**SMS Pattern:**
```
... 687803b61111425dabcdfda0975fdeb4@okax is - Axis Bank
```

**Common Bank Name Patterns in SMS:**

1. **Suffix pattern:** `is - [Bank Name]`
2. **Prefix pattern:** `-[Bank Name]` (at end of SMS)
3. **Embedded:** `from your [Bank Name] account`

**Regex Patterns:**
```dart
// Pattern 1: "is - Bank Name"
RegExp(r'is\s*-\s*([A-Z][a-zA-Z\s]+Bank)', caseSensitive: false)

// Pattern 2: "- Bank Name" at end
RegExp(r'-\s*([A-Z][a-zA-Z\s]+Bank)\s*$', caseSensitive: false)

// Pattern 3: "from your [Bank] account"
RegExp(r'from\s+your\s+([A-Z][a-zA-Z\s]+(?:Bank|Card))\s+(?:account|a/c)',
    caseSensitive: false)
```

**Usage:**
- Validate against sender (CP-AXISBK-S → Axis Bank)
- Display in account field
- Cross-reference with tracker matching

---

### 🟡 Issue #6: Transaction vs Reference Number Confusion (LOW PRIORITY)

**Problem:**
- Current "Transaction ID": `687803b61111425dabcdfda0975fdeb4`
- This appears to be the UPI transaction reference, not a bank transaction ID

**SMS Structure:**
```
687803b61111425dabcdfda0975fdeb4@okax
```

The part before `@` is the UPI reference number.

**What should be extracted:**

1. **UPI Reference:** `687803b61111425dabcdfda0975fdeb4`
2. **UPI Handle:** `@okax` (Okaxis)
3. **Bank Transaction ID:** (May not be in SMS - different field)

**Expected Fields:**
```
Transaction ID: <bank-specific-id-if-available>
UPI Reference: 687803b61...
UPI Handle: @okax
```

**Common SMS Formats:**

1. **With separate IDs:**
   ```
   Ref No: 123456789012
   UPI: 687803b61...@okax
   ```

2. **UPI reference only:**
   ```
   687803b61111425dabcdfda0975fdeb4@okax
   ```

**Parsing Strategy:**
```dart
// Extract both if available
final refMatch = RegExp(r'(?:ref|txn)\s*(?:no|id|num)?:?\s*(\d+)',
    caseSensitive: false).firstMatch(smsText);
final upiMatch = RegExp(r'([a-zA-Z0-9]+)@([a-z]+)',
    caseSensitive: false).firstMatch(smsText);

if (refMatch != null) {
  transaction.transactionId = refMatch.group(1);
}
if (upiMatch != null) {
  transaction.upiReference = upiMatch.group(1);
  transaction.upiHandle = '@${upiMatch.group(2)}';
}
```

---

## Missing Data Fields

### Fields That Could Be Extracted But Aren't

1. **UPI App Name**
   - SMS: "towards Google Play"
   - Could extract: App/service where payment was made
   - Use: Better merchant identification

2. **Transaction Type**
   - SMS: "has been debited towards"
   - Types: Purchase, Bill Payment, Transfer, Withdrawal
   - Use: Better categorization

3. **Payment Method**
   - Current: Inferred as UPI (from @okax)
   - Explicit extraction would help
   - Types: UPI, Card, Net Banking, ATM

4. **Transaction Status**
   - SMS: "debited" (implies successful)
   - Could track: Success, Pending, Failed
   - Use: Filter out failed transactions

---

## Recommended Parsing Improvements

### Priority 1: Fix Tracker Badge (CRITICAL)

**File:** `lib/config/tracker_registry.dart`

**Change:**
```dart
TrackerCategory.axisBank: TrackerTemplate(
  name: 'Axis Bank',
  emoji: '🏦',
  category: TrackerCategory.axisBank,
  emailDomains: ['axisbank.com'],
  smsSenders: [
    'VM-AXISBK',
    'AD-AXISBK',
    'AXISBK',
    'AXIS',
    'CP-AXISBK-S',  // ADD THIS
    'CP-AXISBK',    // ADD THIS
    'TX-AXISBK',    // ADD THIS
    'AX-AXISBK',    // ADD THIS
  ],
  // ...
),
```

**Do this for ALL banks:**
- Check actual SMS senders users receive
- Add CP-, TX-, AX- prefixes systematically
- Test with real user SMS data

---

### Priority 2: Add Merchant-Category Mapping

**File:** `lib/services/sms_parser_service.dart` or new file

**Add:**
```dart
class MerchantCategories {
  static const Map<String, String> merchantToCategory = {
    // Digital Services
    'google play': 'Shopping',
    'play store': 'Shopping',
    'app store': 'Shopping',
    'netflix': 'Entertainment',
    'amazon prime': 'Entertainment',
    'spotify': 'Entertainment',
    'youtube premium': 'Entertainment',
    'disney hotstar': 'Entertainment',

    // Shopping
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'meesho': 'Shopping',
    'ajio': 'Shopping',

    // Food & Dining
    'swiggy': 'Food & Dining',
    'zomato': 'Food & Dining',
    'dunzo': 'Food & Dining',
    'zepto': 'Shopping',
    'blinkit': 'Shopping',

    // Transportation
    'uber': 'Transportation',
    'ola': 'Transportation',
    'rapido': 'Transportation',
    'metro': 'Transportation',

    // Utilities
    'electricity': 'Utilities',
    'water bill': 'Utilities',
    'gas bill': 'Utilities',
    'broadband': 'Utilities',
    'mobile recharge': 'Utilities',
    'dth recharge': 'Utilities',

    // Healthcare
    'apollo pharmacy': 'Healthcare',
    'pharmeasy': 'Healthcare',
    'practo': 'Healthcare',

    // Education
    'udemy': 'Education',
    'coursera': 'Education',
    'unacademy': 'Education',
  };

  static String? getCategoryForMerchant(String merchant) {
    final lowerMerchant = merchant.toLowerCase();

    // Exact match
    if (merchantToCategory.containsKey(lowerMerchant)) {
      return merchantToCategory[lowerMerchant];
    }

    // Partial match
    for (var entry in merchantToCategory.entries) {
      if (lowerMerchant.contains(entry.key) || entry.key.contains(lowerMerchant)) {
        return entry.value;
      }
    }

    return null;
  }
}
```

**Usage:**
```dart
// In SMS parsing
category = MerchantCategories.getCategoryForMerchant(merchant)
           ?? inferCategoryFromKeywords(smsText)
           ?? 'Other';
```

---

### Priority 3: Improve Account Field Parsing

**File:** `lib/services/sms_parser_service.dart`

**Add new extraction methods:**

```dart
class SmsParserService {

  /// Extract bank name from SMS
  static String? extractBankName(String smsText) {
    // Pattern 1: "is - Bank Name"
    var match = RegExp(r'is\s*-\s*([A-Z][a-zA-Z\s]+Bank)',
        caseSensitive: false).firstMatch(smsText);
    if (match != null) return match.group(1)?.trim();

    // Pattern 2: "- Bank Name" at end
    match = RegExp(r'-\s*([A-Z][a-zA-Z\s]+Bank)\s*$',
        caseSensitive: false).firstMatch(smsText);
    if (match != null) return match.group(1)?.trim();

    // Pattern 3: Common bank names
    final banks = ['HDFC Bank', 'ICICI Bank', 'Axis Bank', 'SBI',
                   'Kotak Bank', 'Yes Bank'];
    for (var bank in banks) {
      if (smsText.toLowerCase().contains(bank.toLowerCase())) {
        return bank;
      }
    }

    return null;
  }

  /// Extract UPI ID from SMS
  static String? extractUpiId(String smsText) {
    final match = RegExp(
      r'([a-zA-Z0-9.]+@(?:okaxis|okicici|okhdfcbank|okaxisbank|paytm|ybl|axl|oksbi|ibl))',
      caseSensitive: false,
    ).firstMatch(smsText);

    return match?.group(1);
  }

  /// Extract account number (last 4 digits or masked)
  static String? extractAccountNumber(String smsText) {
    // Pattern: XX1234, XXXX1234, ****1234
    var match = RegExp(r'(?:XX|x{2,4}|\*{2,4})(\d{4})',
        caseSensitive: false).firstMatch(smsText);
    if (match != null) return match.group(1);

    // Pattern: a/c 1234, account 1234
    match = RegExp(r'(?:a/c|acct|account)\s*(\d{4})',
        caseSensitive: false).firstMatch(smsText);
    if (match != null) return match.group(1);

    return null;
  }

  /// Format account display string
  static String formatAccountDisplay({
    String? bankName,
    String? accountNumber,
    String? upiId,
  }) {
    if (upiId != null && bankName != null) {
      // Truncate long UPI IDs
      final truncated = upiId.length > 20
          ? '${upiId.substring(0, 17)}...'
          : upiId;
      return '$bankName (UPI: $truncated)';
    } else if (accountNumber != null && bankName != null) {
      return '$bankName ****$accountNumber';
    } else if (bankName != null) {
      return bankName;
    } else if (upiId != null) {
      return 'UPI: $upiId';
    } else if (accountNumber != null) {
      return 'Account ****$accountNumber';
    } else {
      return 'Unknown Account';
    }
  }
}
```

**Update ParsedTransaction model:**
```dart
class ParsedTransaction {
  // Existing fields...

  String? bankName;
  String? upiId;
  String? upiHandle;  // @okax, @paytm, etc.

  // Computed property
  String get accountDisplay => SmsParserService.formatAccountDisplay(
    bankName: bankName,
    accountNumber: accountNumber,
    upiId: upiId,
  );
}
```

---

## Test Cases Needed

### Test Case 1: Google Play Transaction (This one)
```
SMS: "Your A/c has been debited towards Google Play for INR 1950.00
      on 06-01-26. 687803b61111425dabcdfda0975fdeb4@okax is - Axis Bank"
Sender: CP-AXISBK-S

Expected:
- Merchant: Google Play
- Amount: ₹1950.00
- Category: Shopping
- Bank: Axis Bank
- UPI: 687803b61...@okax
- Account: "Axis Bank (UPI: 687803b61...@okax)"
- Tracker Badge: Axis Bank (visible)
```

### Test Case 2: Card Transaction with Account Number
```
SMS: "Your Card XX1234 has been debited by INR 2500.00 at Amazon India.
      Avl bal: 45000.00. -HDFC Bank"
Sender: VM-HDFCBK

Expected:
- Merchant: Amazon India
- Amount: ₹2500.00
- Category: Shopping
- Bank: HDFC Bank
- Account: "HDFC Bank ****1234"
- Tracker Badge: HDFC Bank (visible)
```

### Test Case 3: Utility Bill Payment
```
SMS: "Rs.1200 debited from a/c XX5678 for electricity bill payment.
      Txn ID: 123456789012"
Sender: VM-ICICIB

Expected:
- Merchant: Electricity
- Amount: ₹1200.00
- Category: Utilities
- Bank: ICICI Bank
- Account: "ICICI Bank ****5678"
- Tracker Badge: ICICI Bank (visible)
```

---

## Implementation Priority

### Sprint 1: Critical Fixes (This Week)
1. ✅ Add missing SMS sender patterns to TrackerRegistry
   - CP-AXISBK-S for Axis Bank
   - CP-HDFCBK for HDFC Bank
   - CP-ICICIB for ICICI Bank
   - Similar for all banks

2. ✅ Add merchant-category mapping
   - Google Play → Shopping
   - Netflix → Entertainment
   - Swiggy → Food & Dining
   - Top 50 common merchants

### Sprint 2: Enhanced Parsing (Next Week)
3. ✅ Implement bank name extraction
4. ✅ Implement UPI ID extraction
5. ✅ Improve account field display formatting
6. ✅ Add extracted fields to LocalTransactionModel

### Sprint 3: Validation & Testing (Week After)
7. ✅ Create comprehensive test cases
8. ✅ Validate with real user SMS data
9. ✅ A/B test category accuracy
10. ✅ Monitor tracker matching success rate

---

## Success Metrics

After implementing these fixes, measure:

1. **Tracker Badge Match Rate:**
   - Current: ~70% (estimated, CP- patterns missing)
   - Target: >95%

2. **Category Accuracy:**
   - Current: Unknown (Google Play as Utilities = wrong)
   - Target: >90% for top merchants

3. **Account Field Quality:**
   - Current: Raw SMS text (unusable)
   - Target: Formatted "Bank Name ****1234" or "Bank (UPI)"

4. **User-Reported Issues:**
   - Track: "Wrong bank", "Wrong category", "Can't identify account"
   - Target: <5% of transactions

---

## Files Requiring Changes

### High Priority
1. ✅ `lib/config/tracker_registry.dart`
   - Add CP-, TX-, AX- sender patterns for all banks

2. ✅ `lib/services/sms_parser_service.dart`
   - Add merchant-category mapping
   - Add bank name extraction
   - Add UPI ID extraction
   - Improve account field formatting

3. ✅ `lib/models/local_transaction_model.dart`
   - Add bankName field
   - Add upiId field
   - Add upiHandle field

### Medium Priority
4. ⏳ `lib/services/ai_sms_parser_service.dart`
   - Update AI prompts to extract new fields
   - Validate extracted bank name vs sender

5. ⏳ `lib/widgets/transaction_card.dart` (if exists)
   - Display formatted account field
   - Show UPI badge for UPI transactions

### Low Priority
6. ⏳ Create `lib/utils/merchant_categories.dart`
   - Centralize merchant-category mapping
   - Make it easy to add new merchants

7. ⏳ Create `lib/utils/bank_patterns.dart`
   - Centralize bank-specific regex patterns
   - Easier maintenance and testing

---

## Conclusion

The Google Play transaction reveals **6 significant logic issues**:

1. 🔴 **CRITICAL:** Missing tracker badge (CP-AXISBK-S not in registry)
2. 🟠 **HIGH:** Wrong category (Utilities instead of Shopping)
3. 🟠 **MEDIUM:** Account field shows raw SMS text
4. 🟡 **LOW:** UPI ID not extracted separately
5. 🟡 **LOW:** Bank name not extracted
6. 🟡 **LOW:** Transaction ID vs UPI reference confusion

**Immediate Action Required:**
1. Add missing SMS sender patterns to TrackerRegistry
2. Implement merchant-category mapping
3. Improve account field parsing and display

These changes will significantly improve data quality, user experience, and the usefulness of the transaction tracking system.

---

**Analyzed by:** Claude Code
**Date:** January 7, 2026

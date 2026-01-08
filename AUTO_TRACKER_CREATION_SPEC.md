# Auto-Tracker Creation Specification

**Date:** January 7, 2026
**Problem:** Transactions from known banks don't get tracker badges unless user manually creates the tracker first
**Solution:** Automatically create trackers when we detect transactions from known banks

---

## Problem Statement

### Current Flow (BROKEN)

```
User receives SMS from CP-AXISBK-S (Axis Bank)
     ↓
TrackerMatchingService.matchTransaction():
  - Checks user's existing trackers
  - User has no Axis Bank tracker
  - Returns null
     ↓
Transaction saved with trackerId = null
     ↓
No badge shows ❌
```

### Expected Flow (FIXED)

```
User receives SMS from CP-AXISBK-S (Axis Bank)
     ↓
TrackerMatchingService.matchTransaction():
  - Checks user's existing trackers
  - User has no Axis Bank tracker
  - Detects sender matches Axis Bank category in TrackerRegistry
  - AUTO-CREATES Axis Bank tracker for user
  - Returns new tracker ID
     ↓
Transaction saved with trackerId = "tracker_auto_123"
     ↓
Badge shows "Axis Bank" ✅
```

---

## Architecture

### Option 1: Auto-Create Immediately (RECOMMENDED)

**Pros:**
- Zero user friction
- Works automatically
- Tracker badges show immediately

**Cons:**
- Creates trackers user might not want
- No user control

**Implementation:**

```dart
// In TrackerMatchingService.matchTransaction()

static Future<TrackerMatch?> matchTransaction({
  required String userId,
  required TransactionSource source,
  required String sender,
  bool autoCreateTracker = true, // NEW parameter
}) async {
  // Step 1: Try to match against existing user trackers
  final existingMatch = await _matchAgainstUserTrackers(userId, source, sender);
  if (existingMatch != null) {
    return existingMatch;
  }

  // Step 2: If no match and auto-create enabled, detect category and create
  if (autoCreateTracker) {
    final category = _detectCategory(source, sender);
    if (category != null) {
      final newTracker = await _autoCreateTracker(userId, category, sender);
      if (newTracker != null) {
        return TrackerMatch(
          trackerId: newTracker.id,
          confidence: 0.85, // Auto-created = slightly lower confidence
        );
      }
    }
  }

  return null;
}

/// Detect tracker category from sender/email
static TrackerCategory? _detectCategory(TransactionSource source, String sender) {
  if (source == TransactionSource.sms) {
    final matches = TrackerRegistry.findMatchingCategoriesForSms(sender);
    return matches.isNotEmpty ? matches.first : null;
  } else if (source == TransactionSource.email) {
    final matches = TrackerRegistry.findMatchingCategoriesForEmail(sender);
    return matches.isNotEmpty ? matches.first : null;
  }
  return null;
}

/// Auto-create tracker for user
static Future<AccountTrackerModel?> _autoCreateTracker(
  String userId,
  TrackerCategory category,
  String sender,
) async {
  final template = TrackerRegistry.getTemplate(category);
  if (template == null) return null;

  // Create tracker from template
  final tracker = AccountTrackerModel(
    id: '', // Firestore will generate
    userId: userId,
    name: template.name,
    displayName: template.name,
    category: category,
    type: template.type,
    smsSenders: template.smsSenders,
    emailDomains: template.emailDomains,
    colorHex: template.colorHex,
    emoji: template.emoji,
    isActive: true,
    autoCreated: true, // NEW FLAG
    detectedFrom: sender, // Track what triggered creation
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  // Save to Firestore
  final savedTracker = await AccountTrackerService.addTracker(tracker);

  if (savedTracker != null) {
    print('✅ Auto-created tracker: ${template.name} for user $userId');
  }

  return savedTracker;
}
```

**Update AccountTrackerModel:**

```dart
class AccountTrackerModel {
  // ... existing fields

  final bool autoCreated;        // NEW: Was this auto-created?
  final String? detectedFrom;    // NEW: What sender triggered creation?

  AccountTrackerModel({
    // ... existing params
    this.autoCreated = false,
    this.detectedFrom,
  });
}
```

---

### Option 2: Suggest and Ask User (CONSERVATIVE)

**Pros:**
- User has full control
- No unwanted trackers

**Cons:**
- Requires user action
- More friction

**Implementation:**

```dart
// Store suggestions in Firestore
class TrackerSuggestion {
  final String userId;
  final TrackerCategory category;
  final String detectedFrom;
  final int transactionCount;
  final DateTime firstSeen;
  final bool dismissed;
}

// In UI, show banner:
"We detected 5 transactions from Axis Bank.
[Create Tracker] [Dismiss]"
```

---

### Option 3: Hybrid Approach (BEST)

**Auto-create for major banks, suggest for others:**

```dart
static const List<TrackerCategory> autoCreateCategories = [
  TrackerCategory.hdfcBank,
  TrackerCategory.iciciBank,
  TrackerCategory.axisBank,
  TrackerCategory.sbiBank,
  TrackerCategory.paytm,
  TrackerCategory.phonePe,
  TrackerCategory.googlePay,
];

static Future<TrackerMatch?> matchTransaction(...) async {
  final category = _detectCategory(source, sender);

  if (category != null) {
    // Auto-create for major banks/wallets
    if (autoCreateCategories.contains(category)) {
      final tracker = await _autoCreateTracker(userId, category, sender);
      return TrackerMatch(trackerId: tracker.id, confidence: 0.85);
    } else {
      // Suggest for others
      await _recordSuggestion(userId, category, sender);
      return null;
    }
  }

  return null;
}
```

---

## User Experience Flow

### First Transaction from New Bank

**With Auto-Create:**

```
User scans SMS
     ↓
Transaction detected: CP-AXISBK-S
     ↓
System auto-creates "Axis Bank" tracker
     ↓
Transaction shows badge: "Axis Bank" 🏦
     ↓
User sees in Money Tracker:
  "Axis Bank (Auto-detected)"
  [5 transactions tracked]
```

**User can later:**
- Rename: "Axis Bank" → "Axis Savings Primary"
- Edit details
- Disable auto-tracking
- Delete tracker (if not wanted)

---

## Migration Strategy

### For Existing Users

1. **One-time migration on app update:**
   ```dart
   Future<void> migrateExistingTransactions(String userId) async {
     // Get all pending transactions without trackers
     final unmatched = await LocalDBService.instance.getTransactions(
       userId: userId,
       status: TransactionStatus.pending,
     );

     // Match and auto-create trackers
     for (var txn in unmatched) {
       if (txn.trackerId == null) {
         final match = await TrackerMatchingService.matchTransaction(
           userId: userId,
           source: txn.source,
           sender: txn.sourceIdentifier ?? '',
           autoCreateTracker: true,
         );

         if (match != null) {
           await LocalDBService.instance.updateTransaction(
             txn.copyWith(
               trackerId: match.trackerId,
               trackerConfidence: match.confidence,
             ),
           );
         }
       }
     }
   }
   ```

2. **Show summary:**
   ```
   "We found transactions from:
   - Axis Bank (12 transactions)
   - HDFC Bank (8 transactions)
   - Paytm (15 transactions)

   Auto-created 3 trackers for you!"
   ```

---

## Settings & Controls

### User Preferences

```dart
class TrackerSettings {
  final bool autoCreateTrackers;        // Enable/disable feature
  final bool autoCreateBanks;           // Auto for banks
  final bool autoCreateWallets;         // Auto for wallets
  final bool autoCreateInvestments;     // Auto for investments
  final bool showSuggestions;           // Show suggestion banners
}
```

### UI in Settings

```
Tracker Settings

  ☑ Auto-create trackers for known banks
      Automatically create trackers when we detect
      transactions from recognized banks

  ☑ Auto-create for digital wallets
  ☑ Auto-create for investment platforms

  ☑ Show tracker suggestions
      Show suggestions for unknown accounts

  [Manage Auto-Created Trackers] →
```

---

## Database Schema Changes

### AccountTrackerModel Updates

```dart
class AccountTrackerModel {
  // NEW FIELDS
  final bool autoCreated;              // Was this auto-created?
  final String? detectedFrom;          // Original sender that triggered creation
  final DateTime? firstTransactionDate; // When first txn was seen
  final int transactionCount;          // How many txns matched

  // ... existing fields
}
```

### TrackerSuggestions Collection (Optional)

```dart
// Firestore: trackerSuggestions/{suggestionId}
{
  "userId": "user_123",
  "category": "axisBank",
  "detectedFrom": "CP-AXISBK-S",
  "transactionCount": 5,
  "firstSeen": Timestamp,
  "dismissed": false,
  "createdTrackerId": "tracker_456" // If user accepted
}
```

---

## Implementation Plan

### Phase 1: Core Auto-Creation (Week 1)

1. ✅ Add `autoCreated` field to AccountTrackerModel
2. ✅ Implement `_detectCategory()` method
3. ✅ Implement `_autoCreateTracker()` method
4. ✅ Add auto-create logic to matchTransaction()
5. ✅ Test with CP-AXISBK-S example

### Phase 2: User Controls (Week 2)

6. ✅ Add settings screen for tracker preferences
7. ✅ Add "Auto-Created" badge in tracker list
8. ✅ Allow users to edit/delete auto-created trackers
9. ✅ Add migration for existing transactions

### Phase 3: Suggestions & Polish (Week 3)

10. ✅ Implement suggestion system for non-major banks
11. ✅ Add suggestion banners in UI
12. ✅ Track acceptance/dismissal rates
13. ✅ Analytics and monitoring

---

## Testing Strategy

### Test Cases

**Test 1: First Axis Bank Transaction**
```
Given: User has no Axis Bank tracker
When: SMS arrives from CP-AXISBK-S
Then:
  - Axis Bank tracker auto-created
  - Transaction assigned trackerId
  - Badge shows "Axis Bank"
```

**Test 2: Subsequent Transactions**
```
Given: User has auto-created Axis Bank tracker
When: SMS arrives from VM-AXISBK (different sender)
Then:
  - Uses existing tracker (no duplicate)
  - Badge shows correctly
```

**Test 3: Multiple Banks Same Day**
```
Given: User has no trackers
When: Receives SMS from HDFC, ICICI, Axis
Then:
  - 3 trackers auto-created
  - All transactions matched
  - All badges show
```

**Test 4: User Disables Auto-Create**
```
Given: User disabled auto-create in settings
When: SMS arrives from unknown bank
Then:
  - No tracker created
  - Transaction has trackerId = null
  - No badge shows
```

---

## Success Metrics

After implementation, measure:

1. **Auto-Creation Rate:**
   - Target: >80% of bank transactions auto-matched

2. **User Deletions:**
   - Monitor: % of auto-created trackers deleted
   - Target: <10% deletion rate

3. **Tracker Badge Visibility:**
   - Before: ~30% transactions show badges
   - After: >90% transactions show badges

4. **User Satisfaction:**
   - Survey: "Did auto-tracker creation help?"
   - Target: >85% positive

---

## Risks & Mitigation

### Risk 1: Too Many Trackers

**Problem:** User ends up with 20 auto-created trackers

**Mitigation:**
- Only auto-create for categories with 3+ transactions
- Allow bulk delete of auto-created trackers
- Add "Merge Trackers" feature

### Risk 2: Wrong Category Detection

**Problem:** CP-AXISBK-S misidentified as different bank

**Mitigation:**
- High confidence threshold (>0.8) for auto-creation
- Show "Auto-detected" badge so user knows
- Easy edit/fix option

### Risk 3: Duplicate Trackers

**Problem:** User already has "Axis Bank" manually created

**Mitigation:**
- Check for existing trackers with same category before creating
- Fuzzy match on name ("Axis Savings" vs "Axis Bank")
- Suggest merge if near-duplicate detected

---

## Conclusion

Auto-tracker creation solves the core problem: **tracker badges won't show unless user creates trackers first.**

**Recommended Implementation:**
- ✅ Enable auto-creation for major banks/wallets (Option 3)
- ✅ Add user controls in settings
- ✅ Show "Auto-detected" badge for transparency
- ✅ Allow easy edit/delete of auto-created trackers

This will make the tracker matching system **actually useful** out of the box, instead of requiring manual setup first.

---

**Next Steps:**
1. Implement auto-creation logic in TrackerMatchingService
2. Update AccountTrackerModel with new fields
3. Add settings UI for user control
4. Test with real SMS data
5. Deploy and monitor metrics

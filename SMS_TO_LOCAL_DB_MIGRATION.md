# SMS Listener → Local DB Migration Guide

**Goal:** Migrate SMS parsing from Firestore to local SQLite storage

---

## Current Flow (Privacy Issue)

```
SMS Listener
    ↓
AI Parser Service
    ↓
Firestore ❌ (cloud storage)
    ↓
UI (StreamBuilder)
```

## New Flow (Privacy-First)

```
SMS Listener
    ↓
Generic Transaction Parser
    ↓
Local SQLite ✅ (encrypted, on-device)
    ↓
UI (FutureBuilder)
```

---

## Changes Required

### 1. SMS Listener Service Updates

**File:** `lib/services/sms_listener_service_android.dart`

#### Change #1: Import Generic Parser
```dart
// OLD imports
import 'ai_sms_parser_service.dart';

// NEW imports
import 'generic_transaction_parser_service.dart';
import '../models/local_transaction_model.dart';
```

#### Change #2: Replace Bulk AI Call
**Location:** Line ~500-600 (in bulk processing section)

```dart
// OLD: Call AiSmsParserService
final parsedExpenses = await AiSmsParserService.parseBulkSmsWithAI(
  smsItems: smsNeedingAI,
  onProgress: (count) {
    // Update progress
  },
);

// NEW: Call GenericTransactionParserService
final currentUser = FirebaseAuth.instance.currentUser;
final deviceId = await _getDeviceId();

final parsedTransactions = await GenericTransactionParserService.parseBulkTransactions(
  items: smsNeedingAI.map((sms) => BulkTransactionItem(
    index: sms.index,
    text: sms.smsText,
    sender: sms.sender,
    date: sms.date,
    source: TransactionSource.sms,  // Specify source
  )).toList(),
  userId: currentUser!.uid,
  deviceId: deviceId,
  onProgress: (count) {
    // Update progress
  },
);

// Data is already saved to local SQLite by generic parser!
// No need to save to Firestore ✅
```

####Change #3: Remove Firestore Saves
```dart
// DELETE these lines - no longer needed:
// await _saveBulkExpenses(parsedExpenses);
// await FirebaseFirestore.instance.collection('sms_expenses').add(...);

// Data is automatically saved to local SQLite by GenericTransactionParserService
```

#### Change #4: Update Progress Messages
```dart
// Update final message
print('✅ Found ${parsedTransactions.length} transactions');
print('💾 Saved to local database (encrypted)');
```

---

### 2. Remove Old AI Parser Dependency

**After migration is complete:**

The old `ai_sms_parser_service.dart` can be:
- Kept for reference
- Deprecated with comments
- Removed if no longer needed

**Note:** The Cloud Function (`parseBulkSmsWithAI`) remains unchanged - it's still used by the generic parser, just saves to SQLite instead of Firestore.

---

### 3. SMS Expenses UI Updates

**File:** `lib/screens/sms_expenses/sms_expenses_screen.dart`

#### Change #1: Import Local DB Service
```dart
// ADD imports
import '../../services/local_db_service.dart';
import '../../models/local_transaction_model.dart';
```

#### Change #2: Replace StreamBuilder with FutureBuilder
```dart
// OLD: Firestore StreamBuilder
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('sms_expenses')
      .where('userId', isEqualTo: currentUser.uid)
      .where('status', isEqualTo: 'pending')
      .orderBy('date', descending: true)
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();

    final expenses = snapshot.data!.docs
        .map((doc) => SmsExpenseModel.fromFirestore(doc))
        .toList();

    return ListView.builder(...);
  },
)

// NEW: Local SQLite FutureBuilder
FutureBuilder<List<LocalTransactionModel>>(
  future: LocalDBService.instance.getTransactions(
    userId: currentUser.uid,
    source: TransactionSource.sms,
    status: TransactionStatus.pending,
  ),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();

    final transactions = snapshot.data!;

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return TransactionCard(transaction: transaction);
      },
    );
  },
)
```

#### Change #3: Add Refresh Method
```dart
// Local data needs manual refresh (no real-time streams)
Future<void> _refreshTransactions() async {
  setState(() {
    // Trigger FutureBuilder rebuild
  });
}

// Call after actions:
// - After confirming transaction
// - After deleting transaction
// - After pull-to-refresh
```

#### Change #4: Update Transaction Actions
```dart
// Confirm transaction
Future<void> _confirmTransaction(LocalTransactionModel transaction) async {
  final updated = transaction.copyWith(
    status: TransactionStatus.confirmed,
  );

  final success = await LocalDBService.instance.updateTransaction(updated);

  if (success) {
    _refreshTransactions();
    // Optionally: Create expense in group/personal expenses
  }
}

// Delete transaction
Future<void> _deleteTransaction(String id) async {
  final success = await LocalDBService.instance.deleteTransaction(id);

  if (success) {
    _refreshTransactions();
  }
}
```

---

### 4. Add Pull-to-Refresh

**Since local data doesn't auto-update:**

```dart
RefreshIndicator(
  onRefresh: _refreshTransactions,
  child: FutureBuilder<List<LocalTransactionModel>>(...),
)
```

---

### 5. Testing Checklist

#### Test SMS Scanning
- [ ] SMS permissions granted
- [ ] Scan SMS (last 7 days)
- [ ] AI Mode ON
- [ ] Verify progress shows
- [ ] Check console logs:
  - "Parsing X transactions with AI (sms source)"
  - "Saved X/X transactions locally"
  - "Storage: Local SQLite (encrypted)"

#### Test Local Database
- [ ] Open SQLite database file (via device file explorer)
- [ ] Verify transactions table exists
- [ ] Check data is encrypted (rawContent field)
- [ ] Verify indexes created

#### Test UI
- [ ] SMS Expenses screen loads
- [ ] Transactions display properly
- [ ] Can confirm transactions
- [ ] Can delete transactions
- [ ] Pull-to-refresh works
- [ ] Search/filter works

#### Test Privacy
- [ ] No data in Firestore `sms_expenses` collection
- [ ] All data in local SQLite file
- [ ] Raw SMS encrypted in database
- [ ] Works offline

---

### 6. Migration Strategy for Existing Users

**If users have existing Firestore data:**

#### Option A: One-Time Migration
```dart
Future<void> migrateFirestoreToLocal() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  // 1. Check if already migrated
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('sms_migrated_to_local') == true) {
    return; // Already migrated
  }

  // 2. Download from Firestore
  print('📥 Migrating SMS expenses to local database...');
  final snapshot = await FirebaseFirestore.instance
      .collection('sms_expenses')
      .where('userId', isEqualTo: currentUser.uid)
      .get();

  // 3. Convert to local transactions
  final transactions = snapshot.docs.map((doc) {
    final data = doc.data();
    return LocalTransactionModel(
      id: doc.id,
      source: TransactionSource.sms,
      sourceIdentifier: data['smsSender'],
      amount: (data['amount'] as num).toDouble(),
      merchant: data['merchant'],
      category: data['category'],
      transactionDate: (data['date'] as Timestamp).toDate(),
      transactionId: data['transactionId'],
      accountInfo: data['accountInfo'],
      rawContent: data['rawSms'], // Will be encrypted
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TransactionStatus.pending,
      ),
      isDebit: true,
      userId: currentUser.uid,
      parsedBy: ParseMethod.ai,
    );
  }).toList();

  // 4. Save to local SQLite
  final saved = await LocalDBService.instance.insertBatch(transactions);
  print('✅ Migrated $saved transactions to local database');

  // 5. Mark as migrated
  await prefs.setBool('sms_migrated_to_local', true);

  // 6. Optionally: Delete from Firestore
  final shouldDelete = await _askUserToDeleteCloudData();
  if (shouldDelete) {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    print('🗑️ Deleted cloud data');
  }
}
```

#### Option B: Start Fresh
```dart
// Show dialog
showDialog(
  title: "Privacy Update",
  message: "Your SMS expenses will now be stored privately on your device. "
           "Existing cloud data will remain untouched. "
           "Future scans will save to local storage only.",
  actions: ["OK"],
);
```

---

### 7. Key Benefits

#### Privacy
- ✅ No financial data in cloud
- ✅ Encrypted at rest
- ✅ User owns data

#### Performance
- ✅ Faster queries (local vs network)
- ✅ Works offline
- ✅ No network latency

#### Cost
- ✅ No Firestore read/write costs
- ✅ Only AI parsing costs remain

---

### 8. Rollback Plan

**If issues occur:**

1. **Keep old code commented:**
```dart
// OLD Firestore code (keep temporarily)
// final parsedExpenses = await AiSmsParserService.parseBulkSmsWithAI(...);
// await _saveBulkExpenses(parsedExpenses);

// NEW Local DB code
final parsedTransactions = await GenericTransactionParserService...
```

2. **Feature flag:**
```dart
final useLocalStorage = prefs.getBool('use_local_storage') ?? false;

if (useLocalStorage) {
  // Use GenericTransactionParserService
} else {
  // Use old AiSmsParserService
}
```

---

### 9. Timeline

**Phase 1:** ✅ Foundation (Complete)
- Local DB service
- Encryption service
- Generic parser

**Phase 2:** 🚧 Migration (In Progress)
- Update SMS listener
- Update UI
- Test thoroughly

**Phase 3:** 📅 Rollout (Next)
- Deploy to testers
- Monitor for issues
- Gradual rollout to all users

---

## Summary

**What Changes:**
- SMS parsing saves to local SQLite (not Firestore)
- UI queries local database (not Firestore)
- Data encrypted on device

**What Stays:**
- Cloud Function (parseBulkSmsWithAI)
- AI parsing logic
- SMS permissions & scanning
- UI design & layout

**End Result:**
- Maximum privacy 🔒
- Faster performance ⚡
- Lower costs 💰
- User control 🎯

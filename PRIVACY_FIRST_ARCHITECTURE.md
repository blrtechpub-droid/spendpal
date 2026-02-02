# Privacy-First Architecture - Local Transaction Storage

**Goal:** Keep all personal financial data on-device, never in Firebase.

---

## 1. Architecture Overview

### Current (Privacy Issue)
```
SMS → AI Parsing → Firebase Firestore → App UI
                      ❌ Merchant data in cloud
                      ❌ Raw SMS in cloud
                      ❌ Account info in cloud
```

### New (Privacy-First)
```
SMS → AI Parsing → Local SQLite → App UI
                      ✓ All data stays on device
                      ✓ Encrypted at rest
                      ✓ No cloud storage of transactions
```

---

## 2. Local Database Schema (SQLite)

### Transactions Table
```sql
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  source TEXT NOT NULL,              -- 'sms', 'email', 'manual'
  source_identifier TEXT,            -- SMS sender or email sender

  -- Transaction details
  amount REAL NOT NULL,
  merchant TEXT NOT NULL,
  category TEXT NOT NULL,
  transaction_date TEXT NOT NULL,    -- ISO 8601 format

  -- Optional details
  transaction_id TEXT,               -- Bank transaction ID
  account_info TEXT,                 -- Last 4 digits (XX1234)
  notes TEXT,

  -- Original content (encrypted)
  raw_content TEXT,                  -- Original SMS/email text (encrypted)

  -- Status
  status TEXT DEFAULT 'pending',     -- 'pending', 'confirmed', 'ignored', 'duplicate'
  is_debit INTEGER DEFAULT 1,        -- 1 = expense, 0 = income/investment

  -- Metadata
  parsed_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  user_id TEXT NOT NULL,             -- For multi-user support
  device_id TEXT NOT NULL,

  -- AI/Pattern info
  parsed_by TEXT,                    -- 'ai', 'regex', 'manual'
  pattern_id TEXT,                   -- If parsed by regex
  confidence REAL                    -- AI confidence score
);

CREATE INDEX idx_transactions_date ON transactions(transaction_date DESC);
CREATE INDEX idx_transactions_user ON transactions(user_id);
CREATE INDEX idx_transactions_category ON transactions(category);
CREATE INDEX idx_transactions_merchant ON transactions(merchant);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_source ON transactions(source);
```

### Regex Patterns Table (No Personal Data)
```sql
CREATE TABLE regex_patterns (
  id TEXT PRIMARY KEY,
  sender TEXT NOT NULL,              -- Bank/sender identifier
  pattern TEXT NOT NULL,
  description TEXT,

  -- Extraction mapping
  amount_group INTEGER,              -- Capture group for amount
  merchant_group INTEGER,            -- Capture group for merchant
  transaction_id_group INTEGER,      -- Capture group for txn ID
  account_info_group INTEGER,        -- Capture group for account

  -- Pattern metadata
  confidence INTEGER NOT NULL,       -- 0-100
  category_hint TEXT,                -- Suggested category
  source TEXT DEFAULT 'ai',          -- 'ai', 'manual'

  -- Usage stats
  success_count INTEGER DEFAULT 0,
  failure_count INTEGER DEFAULT 0,
  last_used TEXT,

  -- Status
  active INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  user_id TEXT NOT NULL
);

CREATE INDEX idx_patterns_sender ON regex_patterns(sender);
CREATE INDEX idx_patterns_confidence ON regex_patterns(confidence DESC);
CREATE INDEX idx_patterns_active ON regex_patterns(active);
```

### Email Patterns Table
```sql
CREATE TABLE email_patterns (
  id TEXT PRIMARY KEY,
  bank_domain TEXT NOT NULL,         -- 'amazon.com', 'bank.com'
  sender_email TEXT NOT NULL,

  -- JSON patterns (flexible)
  subject_pattern TEXT,
  body_pattern TEXT,
  extraction_rules TEXT,             -- JSON: field extraction rules

  -- Metadata
  confidence INTEGER NOT NULL,
  category_hint TEXT,
  active INTEGER DEFAULT 1,

  -- Usage stats
  success_count INTEGER DEFAULT 0,
  failure_count INTEGER DEFAULT 0,

  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  user_id TEXT NOT NULL
);

CREATE INDEX idx_email_patterns_domain ON email_patterns(bank_domain);
CREATE INDEX idx_email_patterns_active ON email_patterns(active);
```

### Sync Metadata Table (Optional - for backup)
```sql
CREATE TABLE sync_metadata (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  last_backup_at TEXT,
  last_restore_at TEXT,
  backup_location TEXT,              -- 'google_drive', 'icloud', 'local_file'
  encrypted INTEGER DEFAULT 1,
  user_id TEXT NOT NULL
);
```

---

## 3. Privacy Guarantees

### ✅ What Stays Local (On Device)
- All transaction amounts
- All merchant names
- All raw SMS/email text
- All account information
- All transaction IDs
- All personal financial data

### ✅ What Can Go to Firebase (Non-Sensitive)
- User profile (name, email, photo)
- Friends list
- Group memberships
- **Group expenses only** (shared with group members)
- Anonymous regex patterns (no transaction data)
- Last sync timestamp

### ✅ AI Processing Privacy
- SMS/email text sent to Cloud Function temporarily
- AI extracts data and returns immediately
- **Cloud Function does NOT store any transaction data**
- Function forgets everything after response
- Optional: Use on-device AI (future enhancement)

---

## 4. Implementation Steps

### Step 1: Add SQLite Dependencies
```yaml
# pubspec.yaml
dependencies:
  sqflite: ^2.3.0
  path: ^1.8.3
  path_provider: ^2.1.1
  encrypt: ^5.0.3  # For encrypting raw SMS/email text
```

### Step 2: Create Database Service
```
lib/services/local_db_service.dart
├── initDatabase()
├── insertTransaction()
├── getTransactions()
├── updateTransaction()
├── deleteTransaction()
├── insertPattern()
└── getPatterns()
```

### Step 3: Migrate SMS Parser
**Current:** `ai_sms_parser_service.dart` → Firestore
**New:** `ai_sms_parser_service.dart` → Local SQLite

Changes:
- Replace `_saveBulkExpenses()` Firestore writes with SQLite writes
- Keep AI parsing logic unchanged
- Cloud Function returns data but doesn't store

### Step 4: Migrate Email Parser
Same approach as SMS - save to local SQLite

### Step 5: Update UI
**Current:** StreamBuilder with Firestore queries
**New:** StreamBuilder with SQLite queries (or ValueNotifier)

```dart
// Before (Firestore)
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('sms_expenses')
    .snapshots(),
)

// After (Local SQLite)
StreamBuilder<List<Transaction>>(
  stream: LocalDBService.watchTransactions(),
)
```

---

## 5. Data Encryption

### Encrypt Sensitive Fields
```dart
import 'package:encrypt/encrypt.dart';

class EncryptionService {
  static final _key = Key.fromSecureRandom(32);
  static final _iv = IV.fromSecureRandom(16);
  static final _encrypter = Encrypter(AES(_key));

  static String encrypt(String plainText) {
    return _encrypter.encrypt(plainText, iv: _iv).base64;
  }

  static String decrypt(String encrypted) {
    return _encrypter.decrypt64(encrypted, iv: _iv);
  }
}

// Encrypt raw SMS before storing
final encryptedSms = EncryptionService.encrypt(rawSmsText);
await db.insert('transactions', {
  'raw_content': encryptedSms,
  // ...
});
```

---

## 6. Backup Strategy (Optional)

### Option A: Encrypted Local Backup
- Export to encrypted file
- User manually backs up to cloud/USB

### Option B: Google Drive / iCloud
- Encrypt database
- Upload encrypted file to user's personal cloud
- User controls their own data

### Option C: No Cloud Backup
- Data stays on device only
- User responsible for device backups
- Most private option

---

## 7. Migration Plan

### For Existing Users with Firestore Data

**Step 1:** Check if user has existing Firestore data
```dart
final hasCloudData = await checkFirestoreTransactions();
```

**Step 2:** Offer one-time migration
```dart
if (hasCloudData) {
  showDialog(
    title: "Privacy Update",
    message: "Your transaction data will now be stored locally on your device for better privacy. Migrate existing data?",
    actions: [
      "Migrate & Delete from Cloud",  // ← Recommended
      "Start Fresh (Keep Cloud Data)",
      "Cancel"
    ]
  );
}
```

**Step 3:** Migrate and delete
```dart
// 1. Download all transactions from Firestore
final cloudTransactions = await downloadFromFirestore();

// 2. Save to local SQLite
await LocalDBService.insertBatch(cloudTransactions);

// 3. Delete from Firestore (after confirmation)
await deleteFromFirestore();

// 4. Mark migration complete
await prefs.setBool('migrated_to_local', true);
```

---

## 8. Group Expenses (Exception)

**Shared expenses must stay in Firebase** (by design - shared with group)

```
Personal Transactions → Local SQLite ✓
Group Transactions → Firebase Firestore (necessary for sharing)
```

User sees both:
- Personal: Local SQLite
- Groups: Firestore (only group-shared expenses)

---

## 9. Benefits

### ✅ Privacy
- Financial data never leaves device
- No cloud provider can access transaction data
- Compliant with data privacy regulations

### ✅ Performance
- Faster queries (local database)
- Works offline completely
- No network latency

### ✅ Cost
- No Firestore read/write costs for transactions
- Only AI parsing costs remain

### ✅ Control
- User owns their data
- Easy to export/delete
- Can backup to their own cloud

---

## 10. Code Structure

```
lib/
├── services/
│   ├── local_db_service.dart          # NEW: SQLite operations
│   ├── transaction_service.dart       # NEW: Business logic
│   ├── encryption_service.dart        # NEW: Encrypt sensitive data
│   ├── ai_parser_service.dart         # MODIFIED: Save to SQLite
│   └── backup_service.dart            # NEW: Optional backup
├── models/
│   └── transaction_model.dart         # NEW: Unified transaction model
└── screens/
    ├── personal/
    │   └── personal_screen.dart       # MODIFIED: Query SQLite
    └── sms_expenses/
        └── sms_expenses_screen.dart   # MODIFIED: Query SQLite
```

---

## 11. Testing Checklist

- [ ] SQLite database creation
- [ ] Insert transactions locally
- [ ] Query transactions (all, by date, by category)
- [ ] Update transaction status
- [ ] Delete transactions
- [ ] Encryption/decryption of raw content
- [ ] Migration from Firestore to SQLite
- [ ] AI parsing still works (sends to Cloud Function)
- [ ] Offline functionality
- [ ] Export transactions to CSV/JSON
- [ ] Backup and restore

---

## 12. Future Enhancements

### On-Device AI (Ultimate Privacy)
- Use TensorFlow Lite or ML Kit
- Parse SMS/email entirely on device
- Zero data sent to cloud
- Slower but 100% private

### Multi-Device Sync
- Encrypted sync between user's devices
- P2P sync (no cloud intermediary)
- Or encrypted sync via user's personal cloud

---

## Summary

**Before:**
```
Device → Cloud Function → Firebase ❌
         (AI parsing)      (stores data)
```

**After:**
```
Device → Cloud Function → Device ✓
         (AI parsing)      (local SQLite)
         (temporary,       (encrypted,
          no storage)       private)
```

**Privacy Level: Maximum** 🔒

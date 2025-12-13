# Database Migration Guide

> **Critical**: This guide explains how to safely modify Firestore database schemas without losing data.

## Table of Contents
- [Golden Rules](#golden-rules)
- [Migration Strategies](#migration-strategies)
- [Safety Mechanisms](#safety-mechanisms)
- [Step-by-Step Migration Process](#step-by-step-migration-process)
- [Emergency Rollback](#emergency-rollback)
- [Examples](#examples)

---

## Golden Rules

### ❌ NEVER Do This
```
1. Delete collection in Firebase Console
2. Create new structure
3. Hope for the best
Result: ALL DATA LOST 💀
```

### ✅ ALWAYS Do This
```
1. Backup existing data
2. Create migration script
3. Test on staging environment
4. Run migration in batches
5. Verify new data
6. Deploy updated app
7. Keep old data for 2-4 weeks
8. Delete old data only after confirmation
```

---

## Migration Strategies

### Strategy 1: Additive Changes (Easiest)

**Use when**: Adding new optional fields

**Example**: Adding `storeLocation` to receipts

```dart
// Old model
class ReceiptModel {
  final String merchant;
  final double totalAmount;
}

// New model - Just add nullable fields!
class ReceiptModel {
  final String merchant;
  final double totalAmount;
  final String? storeLocation;  // NEW - nullable
  final int? loyaltyPoints;     // NEW - nullable

  factory ReceiptModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReceiptModel(
      merchant: data['merchant'] as String,
      totalAmount: (data['totalAmount'] as num).toDouble(),
      storeLocation: data['storeLocation'] as String?,  // ✅ Handles old docs
      loyaltyPoints: data['loyaltyPoints'] as int?,     // ✅ Handles old docs
    );
  }
}
```

**Benefits**:
- ✅ No migration script needed
- ✅ Old documents work with new code
- ✅ Zero downtime
- ✅ Zero risk

**Limitations**:
- ❌ New fields must be nullable
- ❌ Can't change existing field types
- ❌ Can't rename fields

---

### Strategy 2: Schema Versioning (Recommended)

**Use when**: Making breaking changes (renaming fields, changing types)

**Implementation**:

```dart
class ReceiptModel {
  final int schemaVersion;  // Track version
  final String merchant;
  final String? merchantId;  // v2 only

  factory ReceiptModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final version = data['schemaVersion'] as int? ?? 1;  // Default v1

    switch (version) {
      case 1:
        return _fromV1(doc);
      case 2:
        return _fromV2(doc);
      default:
        throw Exception('Unknown schema version: $version');
    }
  }

  static ReceiptModel _fromV1(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReceiptModel(
      schemaVersion: 1,
      merchant: data['merchant'] as String,  // String in v1
      merchantId: null,  // Doesn't exist in v1
      totalAmount: (data['totalAmount'] as num).toDouble(),
    );
  }

  static ReceiptModel _fromV2(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final merchantData = data['merchant'] as Map<String, dynamic>;
    return ReceiptModel(
      schemaVersion: 2,
      merchant: merchantData['name'] as String,
      merchantId: merchantData['id'] as String,  // New in v2
      totalAmount: (data['totalAmount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'schemaVersion': 2,  // Always write latest version
      'merchant': {
        'id': merchantId,
        'name': merchant,
      },
      'totalAmount': totalAmount,
    };
  }
}
```

**Benefits**:
- ✅ App handles both old and new formats
- ✅ Gradual migration possible
- ✅ Easy to track migration progress
- ✅ Can add more versions later

---

### Strategy 3: Background Migration (For Large Collections)

**Use when**: Need to transform 10,000+ documents

**Create Cloud Function** (`functions/src/migrations/migrateReceipts.ts`):

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Migrate receipts from v1 to v2 schema
 *
 * v1: merchant is string
 * v2: merchant is object with id and name
 *
 * Call multiple times until all documents migrated:
 * curl https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/migrateReceipts
 */
export const migrateReceipts = functions
  .runWith({
    timeoutSeconds: 540,  // 9 minutes max
    memory: '1GB',
  })
  .https.onRequest(async (req, res) => {
    const firestore = admin.firestore();
    const BATCH_SIZE = 500;  // Firestore batch limit

    try {
      // Query documents that need migration
      const oldDocs = await firestore
        .collection('receipts')
        .where('schemaVersion', '==', 1)  // Or check field structure
        .limit(BATCH_SIZE)
        .get();

      if (oldDocs.empty) {
        return res.json({
          status: 'complete',
          message: 'All documents migrated!'
        });
      }

      // Migrate in batch
      const batch = firestore.batch();
      let migratedCount = 0;

      oldDocs.docs.forEach(doc => {
        const oldData = doc.data();

        // Transform data structure
        const newData = {
          ...oldData,
          schemaVersion: 2,
          merchant: {
            id: generateMerchantId(oldData.merchant as string),
            name: oldData.merchant,
          },
          migratedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        batch.update(doc.ref, newData);
        migratedCount++;
      });

      await batch.commit();

      console.log(`✅ Migrated ${migratedCount} receipts`);

      res.json({
        status: 'progress',
        migratedCount,
        hasMore: oldDocs.size === BATCH_SIZE,
        message: `Migrated ${migratedCount} documents. Call again to continue.`
      });

    } catch (error: any) {
      console.error('❌ Migration error:', error);
      res.status(500).json({
        status: 'error',
        error: error.message
      });
    }
  });

function generateMerchantId(merchantName: string): string {
  return merchantName
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '_')
    .replace(/_+/g, '_');
}
```

**Run migration**:

```bash
# Deploy migration function
firebase deploy --only functions:migrateReceipts

# Run migration (call multiple times until complete)
curl https://us-central1-YOUR_PROJECT.cloudfunctions.net/migrateReceipts

# Response: {"status":"progress","migratedCount":500,"hasMore":true}
# Call again...
curl https://us-central1-YOUR_PROJECT.cloudfunctions.net/migrateReceipts

# Response: {"status":"complete","message":"All documents migrated!"}
```

**Monitor progress**:

```bash
# Check Firebase Console logs
firebase functions:log --only migrateReceipts

# Or create progress tracking
firebase firestore:query receipts --where schemaVersion==1 --limit 1
```

---

### Strategy 4: Dual-Write (Zero Downtime)

**Use when**: Need zero downtime during migration

**Implementation**:

```dart
class ReceiptService {
  static bool _migrationInProgress = true;  // Feature flag

  Future<void> saveReceipt(ReceiptModel receipt) async {
    if (_migrationInProgress) {
      // Write to BOTH old and new structures during transition
      await _dualWrite(receipt);
    } else {
      // After migration complete, write only to new structure
      await _writeToNewStructure(receipt);
    }
  }

  Future<void> _dualWrite(ReceiptModel receipt) async {
    final batch = _firestore.batch();

    // Write to NEW structure (v2)
    final newRef = _firestore.collection('receipts_v2').doc();
    batch.set(newRef, receipt.toFirestoreV2());

    // ALSO write to OLD structure (v1) for backwards compatibility
    final oldRef = _firestore.collection('receipts').doc();
    batch.set(oldRef, receipt.toFirestoreV1());

    await batch.commit();
  }

  Stream<List<ReceiptModel>> getReceipts() {
    final collection = _migrationInProgress
      ? 'receipts'      // Read from old during migration
      : 'receipts_v2';  // Read from new after migration

    return _firestore
      .collection(collection)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ReceiptModel.fromDocument(doc))
          .toList());
  }
}
```

**Migration steps**:
1. Deploy dual-write code
2. Run background migration to copy old → new
3. Verify new collection has all data
4. Switch feature flag to read from new collection
5. Remove dual-write after confirmation

---

## Safety Mechanisms

### 1. Always Backup Before Migration

**Create backup Cloud Function** (`functions/src/migrations/backup.ts`):

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Backup a Firestore collection to Cloud Storage
 *
 * Usage:
 * curl "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/backupCollection?collection=receipts"
 */
export const backupCollection = functions.https.onRequest(async (req, res) => {
  const collectionName = req.query.collection as string;

  if (!collectionName) {
    return res.status(400).json({ error: 'Missing collection parameter' });
  }

  const firestore = admin.firestore();
  const storage = admin.storage().bucket();

  try {
    console.log(`📦 Starting backup of collection: ${collectionName}`);

    // Get all documents
    const snapshot = await firestore.collection(collectionName).get();

    const data = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Save to Cloud Storage
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const fileName = `backups/${collectionName}_${timestamp}.json`;
    const file = storage.file(fileName);

    await file.save(JSON.stringify(data, null, 2), {
      metadata: {
        contentType: 'application/json',
        metadata: {
          collection: collectionName,
          documentCount: data.length.toString(),
          backupDate: new Date().toISOString(),
        }
      }
    });

    console.log(`✅ Backup created: ${fileName}`);

    res.json({
      success: true,
      message: 'Backup created successfully',
      file: fileName,
      documentCount: data.length,
      downloadUrl: `gs://${storage.name}/${fileName}`
    });

  } catch (error: any) {
    console.error('❌ Backup error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});
```

**Use it**:

```bash
# Backup before migration
curl "https://us-central1-YOUR_PROJECT.cloudfunctions.net/backupCollection?collection=receipts"

# Download backup from Firebase Console → Storage → backups/
```

### 2. Test on Staging Environment

```bash
# Use separate Firebase project for staging
firebase use staging

# Deploy migration function to staging
firebase deploy --only functions:migrateReceipts

# Test migration on staging data
curl https://us-central1-YOUR_PROJECT-staging.cloudfunctions.net/migrateReceipts

# Verify results in Firebase Console (staging project)

# Only after successful staging test:
firebase use production
firebase deploy --only functions:migrateReceipts
```

### 3. Gradual Rollout with Feature Flags

```dart
class MigrationFlags {
  // Use Firebase Remote Config or hardcode during transition
  static bool get useNewReceiptSchema {
    return false;  // Start with old schema
  }

  static bool get enableDualWrite {
    return true;  // Write to both during migration
  }
}

// In your service
Future<void> saveReceipt(ReceiptModel receipt) async {
  if (MigrationFlags.enableDualWrite) {
    // Write to both old and new
    await _saveToOldStructure(receipt);
    await _saveToNewStructure(receipt);
  } else if (MigrationFlags.useNewReceiptSchema) {
    // Write only to new
    await _saveToNewStructure(receipt);
  } else {
    // Write only to old
    await _saveToOldStructure(receipt);
  }
}
```

---

## Step-by-Step Migration Process

### Example: Migrating Receipt Schema from v1 to v2

**Scenario**: Change `merchant` from `String` to `Map<String, dynamic>`

#### Phase 1: Preparation (Week 1)

```bash
# 1. Create backup
curl "https://YOUR_PROJECT.cloudfunctions.net/backupCollection?collection=receipts"

# 2. Add schemaVersion field to existing documents
# Run this migration first to add version field
curl "https://YOUR_PROJECT.cloudfunctions.net/addVersionField"

# 3. Verify all documents have schemaVersion
# Check in Firebase Console
```

#### Phase 2: Deploy Dual-Support Code (Week 1-2)

```dart
// Update Flutter app to support BOTH v1 and v2
class ReceiptModel {
  factory ReceiptModel.fromDocument(DocumentSnapshot doc) {
    final version = doc.data()['schemaVersion'] as int? ?? 1;
    return version == 2 ? _fromV2(doc) : _fromV1(doc);
  }

  // Always write new version
  Map<String, dynamic> toFirestore() {
    return {
      'schemaVersion': 2,
      'merchant': {'id': merchantId, 'name': merchant},
      // ... other fields
    };
  }
}

// Deploy to production
flutter build apk --release
# Upload to Play Store
```

#### Phase 3: Run Migration (Week 2)

```bash
# Deploy migration function
firebase deploy --only functions:migrateReceipts

# Run migration in batches
# Call this endpoint multiple times until complete
while true; do
  response=$(curl -s "https://YOUR_PROJECT.cloudfunctions.net/migrateReceipts")
  echo $response

  # Check if complete
  if echo $response | grep -q "complete"; then
    echo "Migration finished!"
    break
  fi

  # Wait before next batch
  sleep 5
done
```

#### Phase 4: Verification (Week 2-3)

```bash
# Check migration status
firebase firestore:query receipts --where schemaVersion==1 --limit 5
# Should return empty or very few results

firebase firestore:query receipts --where schemaVersion==2 --limit 5
# Should return documents with new structure

# Verify in Firebase Console:
# All receipts should have schemaVersion: 2
# All merchants should be objects: {id: "...", name: "..."}
```

#### Phase 5: Cleanup (Week 4-6)

```dart
// Remove backward compatibility code after 4-6 weeks

class ReceiptModel {
  factory ReceiptModel.fromDocument(DocumentSnapshot doc) {
    // Remove version check - assume all documents are v2
    final data = doc.data() as Map<String, dynamic>;
    final merchantData = data['merchant'] as Map<String, dynamic>;

    return ReceiptModel(
      merchant: merchantData['name'] as String,
      merchantId: merchantData['id'] as String,
      // ... other fields
    );
  }
}

// Deploy simplified code
```

---

## Emergency Rollback

If migration fails or causes issues:

### 1. Restore from Backup

**Create restore function** (`functions/src/migrations/restore.ts`):

```typescript
export const restoreFromBackup = functions.https.onRequest(async (req, res) => {
  const backupFile = req.query.file as string;

  if (!backupFile) {
    return res.status(400).json({ error: 'Missing file parameter' });
  }

  const firestore = admin.firestore();
  const storage = admin.storage().bucket();

  try {
    console.log(`📥 Restoring from: ${backupFile}`);

    // Download backup
    const [data] = await storage.file(backupFile).download();
    const docs = JSON.parse(data.toString());

    console.log(`Found ${docs.length} documents to restore`);

    // Restore in batches (Firestore limit: 500 operations per batch)
    const BATCH_SIZE = 500;
    let restored = 0;

    for (let i = 0; i < docs.length; i += BATCH_SIZE) {
      const batch = firestore.batch();
      const chunk = docs.slice(i, i + BATCH_SIZE);

      chunk.forEach((doc: any) => {
        const { id, ...data } = doc;
        const ref = firestore.collection('receipts').doc(id);
        batch.set(ref, data);
      });

      await batch.commit();
      restored += chunk.length;
      console.log(`Restored ${restored}/${docs.length} documents`);
    }

    console.log(`✅ Restore complete`);

    res.json({
      success: true,
      message: 'Backup restored successfully',
      documentCount: docs.length
    });

  } catch (error: any) {
    console.error('❌ Restore error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});
```

**Use it**:

```bash
# Find backup file in Cloud Storage
# backups/receipts_2025-11-02T10-30-00-000Z.json

# Restore
curl "https://YOUR_PROJECT.cloudfunctions.net/restoreFromBackup?file=backups/receipts_2025-11-02T10-30-00-000Z.json"
```

### 2. Revert Code Changes

```bash
# If migration went wrong, revert to previous app version
git checkout v1.2.0  # Or commit hash before migration
flutter build apk --release
# Upload to Play Store as urgent update
```

---

## Examples

### Example 1: Add Optional Field (Simple)

**Change**: Add `notes` field to receipts

```dart
// ✅ No migration needed - just add nullable field

class ReceiptModel {
  final String merchant;
  final double totalAmount;
  final String? notes;  // NEW - nullable

  factory ReceiptModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReceiptModel(
      merchant: data['merchant'] as String,
      totalAmount: (data['totalAmount'] as num).toDouble(),
      notes: data['notes'] as String?,  // ✅ Works with old docs
    );
  }
}
```

### Example 2: Change Field Type (Complex)

**Change**: Change `items` from `List<String>` to `List<Map>`

**Before**:
```json
{
  "items": ["Milk", "Bread", "Eggs"]
}
```

**After**:
```json
{
  "items": [
    {"name": "Milk", "quantity": 1},
    {"name": "Bread", "quantity": 2},
    {"name": "Eggs", "quantity": 12}
  ]
}
```

**Migration**:

```typescript
// functions/src/migrations/migrateReceiptItems.ts
export const migrateReceiptItems = functions.https.onRequest(async (req, res) => {
  const firestore = admin.firestore();

  const oldDocs = await firestore
    .collection('receipts')
    .where('schemaVersion', '==', 1)
    .limit(500)
    .get();

  const batch = firestore.batch();

  oldDocs.docs.forEach(doc => {
    const data = doc.data();
    const oldItems = data.items as string[];

    // Transform string[] to object[]
    const newItems = oldItems.map(itemName => ({
      name: itemName,
      quantity: 1,  // Default quantity
      category: inferCategory(itemName),
    }));

    batch.update(doc.ref, {
      items: newItems,
      schemaVersion: 2,
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await batch.commit();

  res.json({ migrated: oldDocs.size });
});
```

---

## Best Practices Checklist

Before any migration:

- [ ] Create backup of collection
- [ ] Add `schemaVersion` field to all documents (if not present)
- [ ] Test migration on staging environment
- [ ] Deploy code that supports BOTH old and new formats
- [ ] Run migration in batches (500 docs at a time)
- [ ] Verify migration success in Firebase Console
- [ ] Monitor error logs during migration
- [ ] Keep old and new code running in parallel for 2-4 weeks
- [ ] Have rollback plan ready
- [ ] Document migration in CHANGELOG

After migration:

- [ ] Verify all documents migrated successfully
- [ ] Test app with real users (beta group)
- [ ] Monitor crash reports and user feedback
- [ ] Keep backup files for at least 1 month
- [ ] Remove backward compatibility code after 4-6 weeks
- [ ] Update documentation

---

## Common Pitfalls to Avoid

### ❌ Pitfall 1: Deleting Data First
```dart
// WRONG - deletes all data!
await _firestore.collection('receipts').delete();
await _createNewStructure();
```

### ❌ Pitfall 2: Migrating All at Once
```typescript
// WRONG - times out, no progress tracking
const allDocs = await firestore.collection('receipts').get();  // 100,000 docs!
const batch = firestore.batch();
allDocs.docs.forEach(doc => batch.update(doc.ref, {...}));
await batch.commit();  // ❌ Fails - too many operations
```

### ❌ Pitfall 3: No Backward Compatibility
```dart
// WRONG - breaks for old documents
factory ReceiptModel.fromDocument(DocumentSnapshot doc) {
  final merchantData = doc.data()['merchant'] as Map;  // ❌ Crashes on old docs
  return ReceiptModel(merchant: merchantData['name']);
}
```

### ❌ Pitfall 4: No Rollback Plan
```
Migration fails → No backup → Data lost → Users angry 💀
```

---

## Summary

1. **Always backup first** - Use Cloud Functions to export data
2. **Test on staging** - Never test migrations in production
3. **Add versioning** - Track schema versions in documents
4. **Migrate in batches** - 500 documents at a time max
5. **Support both versions** - App works with old and new formats
6. **Keep backups** - Store for at least 1 month after migration
7. **Monitor closely** - Watch logs and user reports
8. **Remove old code gradually** - After 4-6 weeks of stability

**Remember**: Data loss is permanent. Slow and safe is always better than fast and risky.

---

**Related Files**:
- `functions/src/migrations/` - Migration Cloud Functions
- `lib/models/*_model.dart` - Schema version handling
- `.github/workflows/migrate.yml` - Automated migration scripts (if using CI/CD)

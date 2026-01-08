import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/account_tracker_model.dart';
import '../config/tracker_registry.dart';

/// Service for managing account trackers
///
/// Handles CRUD operations for user's configured account trackers
class AccountTrackerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  /// Get all trackers for a user
  static Future<List<AccountTrackerModel>> getAllTrackers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('accountTrackers')
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => AccountTrackerModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting all trackers: $e');
      return [];
    }
  }

  /// Get only active trackers for a user
  static Future<List<AccountTrackerModel>> getActiveTrackers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('accountTrackers')
          .where('isActive', isEqualTo: true)
          .get();

      // Sort in memory (no Firestore index needed)
      final trackers = snapshot.docs
          .map((doc) => AccountTrackerModel.fromFirestore(doc))
          .toList();

      trackers.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return trackers;
    } catch (e) {
      print('❌ Error getting active trackers: $e');
      return [];
    }
  }

  /// Get trackers by type
  static Future<List<AccountTrackerModel>> getTrackersByType(
    String userId,
    TrackerType type,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('accountTrackers')
          .where('type', isEqualTo: type.name)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => AccountTrackerModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting trackers by type: $e');
      return [];
    }
  }

  /// Get single tracker by ID
  static Future<AccountTrackerModel?> getTracker(String userId, String trackerId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('accountTrackers')
          .doc(trackerId)
          .get();

      if (!doc.exists) return null;

      return AccountTrackerModel.fromFirestore(doc);
    } catch (e) {
      print('❌ Error getting tracker: $e');
      return null;
    }
  }

  /// Add a new tracker from template
  static Future<AccountTrackerModel?> addTrackerFromTemplate({
    required String userId,
    required TrackerCategory category,
    String? customName,
    String? accountNumber,
  }) async {
    try {
      final template = TrackerRegistry.getTemplate(category);
      if (template == null) {
        print('❌ Template not found for category: $category');
        return null;
      }

      // Check if tracker already exists
      final existingTrackers = await getAllTrackers(userId);
      final alreadyExists = existingTrackers.any((t) => t.category == category);

      if (alreadyExists) {
        print('⚠️ Tracker already exists for category: $category');
        return null;
      }

      final tracker = AccountTrackerModel(
        id: _uuid.v4(),
        name: customName ?? template.name,
        type: template.type,
        category: category,
        emailDomains: template.emailDomains,
        smsSenders: template.smsSenders,
        accountNumber: accountNumber,
        isActive: true,
        iconUrl: null, // Can add later if we have icon assets
        colorHex: template.colorHex,
        emoji: template.emoji,
        createdAt: DateTime.now(),
        userId: userId,
        autoCreated: true, // Mark as auto-created
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('accountTrackers')
          .doc(tracker.id)
          .set(tracker.toMap());

      print('✅ Tracker added: ${tracker.name}');
      return tracker;
    } catch (e) {
      print('❌ Error adding tracker: $e');
      return null;
    }
  }

  /// Add a custom tracker (user-defined email domains)
  static Future<AccountTrackerModel?> addCustomTracker({
    required String userId,
    required String name,
    required TrackerType type,
    required List<String> emailDomains,
    String? accountNumber,
  }) async {
    try {
      if (emailDomains.isEmpty) {
        print('❌ Email domains cannot be empty');
        return null;
      }

      final tracker = AccountTrackerModel(
        id: _uuid.v4(),
        name: name,
        type: type,
        category: TrackerCategory.hdfcBank, // Default, not used for custom trackers
        emailDomains: emailDomains,
        accountNumber: accountNumber,
        isActive: true,
        colorHex: '757575', // Default gray
        createdAt: DateTime.now(),
        userId: userId,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('accountTrackers')
          .doc(tracker.id)
          .set(tracker.toMap());

      print('✅ Custom tracker added: ${tracker.name}');
      return tracker;
    } catch (e) {
      print('❌ Error adding custom tracker: $e');
      return null;
    }
  }

  /// Update tracker
  static Future<bool> updateTracker(AccountTrackerModel tracker) async {
    try {
      await _firestore
          .collection('users')
          .doc(tracker.userId)
          .collection('accountTrackers')
          .doc(tracker.id)
          .update(tracker.toMap());

      print('✅ Tracker updated: ${tracker.name}');
      return true;
    } catch (e) {
      print('❌ Error updating tracker: $e');
      return false;
    }
  }

  /// Toggle tracker active status
  static Future<bool> toggleTracker(String userId, String trackerId) async {
    try {
      final tracker = await getTracker(userId, trackerId);
      if (tracker == null) return false;

      final updatedTracker = tracker.copyWith(isActive: !tracker.isActive);
      return await updateTracker(updatedTracker);
    } catch (e) {
      print('❌ Error toggling tracker: $e');
      return false;
    }
  }

  /// Delete tracker
  static Future<bool> deleteTracker(String userId, String trackerId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('accountTrackers')
          .doc(trackerId)
          .delete();

      print('✅ Tracker deleted: $trackerId');
      return true;
    } catch (e) {
      print('❌ Error deleting tracker: $e');
      return false;
    }
  }

  /// Update last synced time for tracker
  static Future<bool> updateLastSyncTime(String userId, String trackerId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('accountTrackers')
          .doc(trackerId)
          .update({
        'lastSyncedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('❌ Error updating last sync time: $e');
      return false;
    }
  }

  /// Increment emails fetched count
  static Future<bool> incrementEmailsFetched(
    String userId,
    String trackerId,
    int count,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('accountTrackers')
          .doc(trackerId)
          .update({
        'emailsFetched': FieldValue.increment(count),
      });

      return true;
    } catch (e) {
      print('❌ Error incrementing emails fetched: $e');
      return false;
    }
  }

  /// Get tracker count for a user
  static Future<int> getTrackerCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('accountTrackers')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Error getting tracker count: $e');
      return 0;
    }
  }

  /// Check if user has any trackers configured
  static Future<bool> hasTrackers(String userId) async {
    final count = await getTrackerCount(userId);
    return count > 0;
  }

  /// Stream of all trackers (for real-time updates in UI)
  static Stream<List<AccountTrackerModel>> streamTrackers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('accountTrackers')
        .snapshots()
        .map((snapshot) {
      // Sort in memory (no Firestore index needed)
      final trackers = snapshot.docs
          .map((doc) => AccountTrackerModel.fromFirestore(doc))
          .toList();
      trackers.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return trackers;
    });
  }

  /// Stream of active trackers only
  static Stream<List<AccountTrackerModel>> streamActiveTrackers(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('accountTrackers')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      // Sort in memory (no Firestore index needed)
      final trackers = snapshot.docs
          .map((doc) => AccountTrackerModel.fromFirestore(doc))
          .toList();
      trackers.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return trackers;
    });
  }

  /// Get trackers grouped by type
  static Future<Map<TrackerType, List<AccountTrackerModel>>> getGroupedTrackers(
    String userId,
  ) async {
    try {
      final trackers = await getAllTrackers(userId);
      final grouped = <TrackerType, List<AccountTrackerModel>>{};

      for (final type in TrackerType.values) {
        grouped[type] = trackers.where((t) => t.type == type).toList();
      }

      return grouped;
    } catch (e) {
      print('❌ Error getting grouped trackers: $e');
      return {};
    }
  }
}

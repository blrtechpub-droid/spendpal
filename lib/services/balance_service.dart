import 'package:cloud_firestore/cloud_firestore.dart';

class BalanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate balance between two users
  /// Returns positive if currentUser is owed money, negative if they owe money
  static Future<double> calculateBalanceBetweenUsers(
    String currentUserId,
    String otherUserId,
    String? groupId,
  ) async {
    double balance = 0.0;

    // Query expenses involving both users
    Query query = _firestore
        .collection('expenses')
        .where('splitWith', arrayContains: currentUserId);

    // Filter by group if specified
    if (groupId != null) {
      query = query.where('groupId', isEqualTo: groupId);
    }

    final snapshot = await query.get();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final paidBy = data['paidBy'] as String?;
      final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});
      final splitWith = List<String>.from(data['splitWith'] ?? []);

      // Skip if other user is not involved
      if (!splitWith.contains(otherUserId)) continue;

      final currentUserShare = (splitDetails[currentUserId] as num?)?.toDouble() ?? 0.0;
      final otherUserShare = (splitDetails[otherUserId] as num?)?.toDouble() ?? 0.0;

      if (paidBy == currentUserId) {
        // Current user paid, they are owed by other user
        balance += otherUserShare;
      } else if (paidBy == otherUserId) {
        // Other user paid, current user owes them
        balance -= currentUserShare;
      }
    }

    return balance;
  }

  /// Calculate all balances for a group
  /// Returns map of userId -> balance (positive = owed to current user, negative = owes)
  static Future<Map<String, double>> calculateGroupBalances(
    String currentUserId,
    String groupId,
  ) async {
    Map<String, double> balances = {};

    final snapshot = await _firestore
        .collection('expenses')
        .where('groupId', isEqualTo: groupId)
        .where('splitWith', arrayContains: currentUserId)
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final paidBy = data['paidBy'] as String?;
      final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});
      final currentUserShare = (splitDetails[currentUserId] as num?)?.toDouble() ?? 0.0;

      if (paidBy == currentUserId) {
        // Current user paid - they are owed by others
        splitDetails.forEach((userId, share) {
          if (userId != currentUserId) {
            balances[userId] = (balances[userId] ?? 0.0) + (share as num).toDouble();
          }
        });
      } else {
        // Someone else paid - current user owes them
        if (paidBy != null && paidBy.isNotEmpty) {
          balances[paidBy] = (balances[paidBy] ?? 0.0) - currentUserShare;
        }
      }
    }

    return balances;
  }

  /// Calculate net balance for a group (total you owe or are owed)
  static Future<double> calculateGroupNetBalance(
    String currentUserId,
    String groupId,
  ) async {
    final balances = await calculateGroupBalances(currentUserId, groupId);
    double netBalance = 0.0;
    for (var balance in balances.values) {
      netBalance += balance;
    }
    return netBalance;
  }

  /// Calculate balances for non-group (friend-to-friend) expenses
  static Future<Map<String, double>> calculateNonGroupBalances(
    String currentUserId,
  ) async {
    Map<String, double> balances = {};

    final snapshot = await _firestore
        .collection('expenses')
        .where('splitWith', arrayContains: currentUserId)
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final groupId = data['groupId'];

      // Skip group expenses
      if (groupId != null && groupId.toString().isNotEmpty) continue;

      final paidBy = data['paidBy'] as String?;
      final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});
      final currentUserShare = (splitDetails[currentUserId] as num?)?.toDouble() ?? 0.0;

      if (paidBy == currentUserId) {
        // Current user paid - they are owed by others
        splitDetails.forEach((userId, share) {
          if (userId != currentUserId) {
            balances[userId] = (balances[userId] ?? 0.0) + (share as num).toDouble();
          }
        });
      } else {
        // Someone else paid - current user owes them
        if (paidBy != null && paidBy.isNotEmpty) {
          balances[paidBy] = (balances[paidBy] ?? 0.0) - currentUserShare;
        }
      }
    }

    return balances;
  }

  /// Calculate overall balance (across all groups and non-group expenses)
  static Future<double> calculateOverallBalance(String currentUserId) async {
    double totalBalance = 0.0;

    final snapshot = await _firestore
        .collection('expenses')
        .where('splitWith', arrayContains: currentUserId)
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final paidBy = data['paidBy'] as String?;
      final splitDetails = Map<String, dynamic>.from(data['splitDetails'] ?? {});
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final currentUserShare = (splitDetails[currentUserId] as num?)?.toDouble() ?? 0.0;

      if (paidBy == currentUserId) {
        // Current user paid - they are owed (amount - their share)
        totalBalance += (amount - currentUserShare);
      } else {
        // Someone else paid - current user owes their share
        totalBalance -= currentUserShare;
      }
    }

    return totalBalance;
  }

  /// Get user name from Firestore
  static Future<String> getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        return userData?['name'] ?? 'Unknown';
      }
    } catch (e) {
      print('Error getting user name: $e');
    }
    return 'Unknown';
  }
}

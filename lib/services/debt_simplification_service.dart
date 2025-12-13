import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spendpal/models/expense_model.dart';
import 'package:spendpal/models/simplified_debt_model.dart';
import 'package:spendpal/models/user_model.dart';

/// Service for debt simplification using optimal transaction minimization
///
/// This implements a greedy algorithm that:
/// 1. Calculates net balance for each person
/// 2. Separates creditors (owed money) and debtors (owe money)
/// 3. Matches largest debtor with largest creditor
/// 4. Minimizes number of transactions needed to settle all debts
class DebtSimplificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Simplify debts for a specific group
  /// Returns list of simplified debts showing who owes whom
  Future<List<SimplifiedDebt>> simplifyGroupDebts(String groupId) async {
    try {
      // Get all expenses for this group
      final expensesSnapshot = await _firestore
          .collection('expenses')
          .where('groupId', isEqualTo: groupId)
          .get();

      if (expensesSnapshot.docs.isEmpty) {
        return [];
      }

      // Get group details for display
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupName = groupDoc.data()?['name'] as String?;

      // Calculate net balances
      final netBalances = await _calculateNetBalances(
        expensesSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return ExpenseModel.fromMap(data);
        }).toList(),
      );

      // Apply simplification algorithm
      return _simplifyDebts(netBalances, groupId: groupId, groupName: groupName);
    } catch (e) {
      print('Error simplifying group debts: $e');
      return [];
    }
  }

  /// Simplify all friend-to-friend debts (non-group expenses)
  Future<List<SimplifiedDebt>> simplifyFriendDebts() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return [];

      // Get all non-group expenses involving current user
      final expensesSnapshot = await _firestore
          .collection('expenses')
          .where('groupId', isEqualTo: null)
          .get();

      // Filter to only include expenses involving current user
      final userExpenses = expensesSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return ExpenseModel.fromMap(data);
          })
          .where((expense) =>
              expense.paidBy == user.uid ||
              expense.sharedWith.contains(user.uid))
          .toList();

      if (userExpenses.isEmpty) {
        return [];
      }

      // Calculate net balances
      final netBalances = await _calculateNetBalances(userExpenses);

      // Filter to only include current user's balances
      final relevantBalances = <String, double>{};
      netBalances.forEach((userId, balance) {
        if (userId == user.uid || balance != 0) {
          relevantBalances[userId] = balance;
        }
      });

      // Apply simplification algorithm
      return _simplifyDebts(relevantBalances);
    } catch (e) {
      print('Error simplifying friend debts: $e');
      return [];
    }
  }

  /// Get complete debt summary for current user
  Future<DebtSummary> getUserDebtSummary() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get all simplified debts (groups + friends)
      final groupDebts = await _getAllGroupDebts();
      final friendDebts = await simplifyFriendDebts();

      final allDebts = [...groupDebts, ...friendDebts];

      // Separate debts owed by user and debts owed to user
      final debtsOwed = allDebts
          .where((debt) => debt.fromUserId == user.uid)
          .toList();

      final debtsOwedToUser = allDebts
          .where((debt) => debt.toUserId == user.uid)
          .toList();

      // Calculate totals
      final totalOwed = debtsOwed.fold<double>(
        0.0,
        (sum, debt) => sum + debt.amount,
      );

      final totalOwedToUser = debtsOwedToUser.fold<double>(
        0.0,
        (sum, debt) => sum + debt.amount,
      );

      return DebtSummary(
        userId: user.uid,
        totalOwed: totalOwed,
        totalOwedToUser: totalOwedToUser,
        debtsOwed: debtsOwed,
        debtsOwedToUser: debtsOwedToUser,
      );
    } catch (e) {
      print('Error getting user debt summary: $e');
      rethrow;
    }
  }

  /// Get all group debts for current user
  Future<List<SimplifiedDebt>> _getAllGroupDebts() async {
    final User? user = _auth.currentUser;
    if (user == null) return [];

    // Get all groups user is a member of
    final groupsSnapshot = await _firestore
        .collection('groups')
        .where('members', arrayContains: user.uid)
        .get();

    final allDebts = <SimplifiedDebt>[];

    for (final groupDoc in groupsSnapshot.docs) {
      final groupDebts = await simplifyGroupDebts(groupDoc.id);
      allDebts.addAll(groupDebts);
    }

    return allDebts;
  }

  /// Calculate net balances for a list of expenses
  /// Returns map of userId -> net balance (positive = owed to them, negative = they owe)
  Future<Map<String, double>> _calculateNetBalances(
    List<ExpenseModel> expenses,
  ) async {
    final balances = <String, double>{};

    for (final expense in expenses) {
      // Add amount paid by payer
      balances[expense.paidBy] = (balances[expense.paidBy] ?? 0) + expense.amount;

      // Subtract share from each person (including payer)
      final sharePerPerson = expense.amount / expense.sharedWith.length;
      for (final userId in expense.sharedWith) {
        balances[userId] = (balances[userId] ?? 0) - sharePerPerson;
      }
    }

    // Account for any settlements
    await _applySettlements(balances);

    return balances;
  }

  /// Apply recorded settlements to balances
  Future<void> _applySettlements(Map<String, double> balances) async {
    // Get recent settlements (last 6 months)
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));

    final settlementsSnapshot = await _firestore
        .collection('settlements')
        .where('settledAt', isGreaterThan: Timestamp.fromDate(sixMonthsAgo))
        .where('isVerified', isEqualTo: true)
        .get();

    for (final doc in settlementsSnapshot.docs) {
      final settlement = SettlementModel.fromDocument(doc);

      // Payer's balance increases (they paid off debt)
      balances[settlement.fromUserId] =
          (balances[settlement.fromUserId] ?? 0) + settlement.amount;

      // Receiver's balance decreases (they received payment)
      balances[settlement.toUserId] =
          (balances[settlement.toUserId] ?? 0) - settlement.amount;
    }
  }

  /// Core debt simplification algorithm
  /// Uses greedy approach: match largest debtor with largest creditor
  List<SimplifiedDebt> _simplifyDebts(
    Map<String, double> netBalances, {
    String? groupId,
    String? groupName,
  }) {
    // Separate creditors and debtors
    final creditors = <_Person>[];
    final debtors = <_Person>[];

    netBalances.forEach((userId, balance) {
      if (balance > 0.01) {
        // This person is owed money
        creditors.add(_Person(userId, balance));
      } else if (balance < -0.01) {
        // This person owes money
        debtors.add(_Person(userId, balance.abs()));
      }
      // If balance is ~0, person is settled - skip
    });

    // Sort by amount (largest first) for optimal matching
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    debtors.sort((a, b) => b.amount.compareTo(a.amount));

    // Generate simplified debts using greedy matching
    final simplifiedDebts = <SimplifiedDebt>[];
    int creditorIdx = 0;
    int debtorIdx = 0;

    while (creditorIdx < creditors.length && debtorIdx < debtors.length) {
      final creditor = creditors[creditorIdx];
      final debtor = debtors[debtorIdx];

      // Match the minimum of what creditor is owed and what debtor owes
      final amount = creditor.amount < debtor.amount
          ? creditor.amount
          : debtor.amount;

      // Note: We'll fetch user names later in batch for efficiency
      simplifiedDebts.add(SimplifiedDebt(
        fromUserId: debtor.userId,
        fromUserName: 'User ${debtor.userId.substring(0, 8)}', // Placeholder
        toUserId: creditor.userId,
        toUserName: 'User ${creditor.userId.substring(0, 8)}', // Placeholder
        amount: amount,
        groupId: groupId,
        groupName: groupName,
      ));

      // Update remaining balances
      creditor.amount -= amount;
      debtor.amount -= amount;

      // Move to next creditor/debtor if fully settled
      if (creditor.amount < 0.01) creditorIdx++;
      if (debtor.amount < 0.01) debtorIdx++;
    }

    return simplifiedDebts;
  }

  /// Fetch user names for simplified debts
  /// This is done in a separate step for efficiency
  Future<List<SimplifiedDebt>> enrichWithUserNames(
    List<SimplifiedDebt> debts,
  ) async {
    if (debts.isEmpty) return debts;

    // Get unique user IDs
    final userIds = <String>{};
    for (final debt in debts) {
      userIds.add(debt.fromUserId);
      userIds.add(debt.toUserId);
    }

    // Fetch user data in batch
    final userNames = <String, String>{};
    for (final userId in userIds) {
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final user = UserModel.fromFirestore(userDoc);
          userNames[userId] = user.name;
        }
      } catch (e) {
        print('Error fetching user $userId: $e');
        userNames[userId] = 'Unknown User';
      }
    }

    // Create new debts with enriched names
    return debts.map((debt) {
      return SimplifiedDebt(
        fromUserId: debt.fromUserId,
        fromUserName: userNames[debt.fromUserId] ?? debt.fromUserName,
        toUserId: debt.toUserId,
        toUserName: userNames[debt.toUserId] ?? debt.toUserName,
        amount: debt.amount,
        groupId: debt.groupId,
        groupName: debt.groupName,
      );
    }).toList();
  }

  /// Record a settlement/payment between users
  Future<SettlementModel> recordSettlement({
    required String toUserId,
    required String toUserName,
    required double amount,
    String? groupId,
    String? groupName,
    String? paymentMethod,
    String? transactionId,
    String? notes,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get current user's name
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final currentUser = UserModel.fromFirestore(userDoc);

      final settlement = SettlementModel(
        id: '', // Will be set by Firestore
        fromUserId: user.uid,
        fromUserName: currentUser.name,
        toUserId: toUserId,
        toUserName: toUserName,
        amount: amount,
        settledAt: DateTime.now(),
        groupId: groupId,
        groupName: groupName,
        paymentMethod: paymentMethod,
        transactionId: transactionId,
        notes: notes,
        isVerified: false, // Needs receiver confirmation
      );

      final docRef = await _firestore
          .collection('settlements')
          .add(settlement.toFirestore());

      return settlement.copyWith(id: docRef.id);
    } catch (e) {
      print('Error recording settlement: $e');
      rethrow;
    }
  }

  /// Verify a settlement (receiver confirms they received payment)
  Future<void> verifySettlement(String settlementId) async {
    try {
      await _firestore.collection('settlements').doc(settlementId).update({
        'isVerified': true,
        'verifiedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error verifying settlement: $e');
      rethrow;
    }
  }

  /// Get settlements for current user
  Stream<List<SettlementModel>> getUserSettlements() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // Get settlements where user is sender or receiver
    return _firestore
        .collection('settlements')
        .where('fromUserId', isEqualTo: user.uid)
        .orderBy('settledAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SettlementModel.fromDocument(doc))
            .toList());
  }

  /// Get pending settlements (not yet verified) for current user
  Stream<List<SettlementModel>> getPendingSettlements() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // Get settlements where current user is receiver and not verified
    return _firestore
        .collection('settlements')
        .where('toUserId', isEqualTo: user.uid)
        .where('isVerified', isEqualTo: false)
        .orderBy('settledAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SettlementModel.fromDocument(doc))
            .toList());
  }
}

/// Internal helper class for debt simplification algorithm
class _Person {
  final String userId;
  double amount;

  _Person(this.userId, this.amount);

  @override
  String toString() => 'Person($userId, ₹$amount)';
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/sms_expense_model.dart';

/// Service to detect and manage duplicate transactions across SMS and Email
class TransactionDeduplicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if an SMS transaction has a duplicate in Email transactions
  /// Returns the duplicate email transaction ID if found, null otherwise
  Future<String?> findEmailDuplicate({
    required String userId,
    required String amount,
    required DateTime date,
    required String merchant,
    String? transactionId,
  }) async {
    try {
      // Check by transaction ID first (exact match)
      if (transactionId != null && transactionId.isNotEmpty) {
        final exactMatch = await _firestore
            .collection('email_transactions')
            .where('userId', isEqualTo: userId)
            .where('transactionId', isEqualTo: transactionId)
            .limit(1)
            .get();

        if (exactMatch.docs.isNotEmpty) {
          return exactMatch.docs.first.id;
        }
      }

      // Fuzzy match: same amount + same date (within 24 hours) + similar merchant
      final startDate = date.subtract(const Duration(hours: 24));
      final endDate = date.add(const Duration(hours: 24));

      final fuzzyMatches = await _firestore
          .collection('email_transactions')
          .where('userId', isEqualTo: userId)
          .where('amount', isEqualTo: double.parse(amount))
          .get();

      for (final doc in fuzzyMatches.docs) {
        final data = doc.data();
        final emailDate = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final emailMerchant = (data['merchant'] ?? '').toString().toLowerCase();
        final smsmerchant = merchant.toLowerCase();

        // Check if date is within 24 hours and merchant matches (fuzzy)
        if (emailDate.isAfter(startDate) &&
            emailDate.isBefore(endDate) &&
            _isMerchantSimilar(emailMerchant, smsmerchant)) {
          return doc.id;
        }
      }

      return null;
    } catch (e) {
      print('Error finding email duplicate: $e');
      return null;
    }
  }

  /// Check if an Email transaction has a duplicate in SMS transactions
  /// Returns the duplicate SMS transaction ID if found, null otherwise
  Future<String?> findSmsDuplicate({
    required String userId,
    required double amount,
    required DateTime date,
    required String merchant,
    String? transactionId,
  }) async {
    try {
      // Check by transaction ID first (exact match)
      if (transactionId != null && transactionId.isNotEmpty) {
        final exactMatch = await _firestore
            .collection('sms_expenses')
            .where('userId', isEqualTo: userId)
            .where('transactionId', isEqualTo: transactionId)
            .limit(1)
            .get();

        if (exactMatch.docs.isNotEmpty) {
          return exactMatch.docs.first.id;
        }
      }

      // Fuzzy match: same amount + same date (within 24 hours) + similar merchant
      final startDate = date.subtract(const Duration(hours: 24));
      final endDate = date.add(const Duration(hours: 24));

      final fuzzyMatches = await _firestore
          .collection('sms_expenses')
          .where('userId', isEqualTo: userId)
          .where('amount', isEqualTo: amount)
          .get();

      for (final doc in fuzzyMatches.docs) {
        final data = doc.data();
        final smsDate = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final smsMerchant = (data['merchant'] ?? '').toString().toLowerCase();
        final emailMerchant = merchant.toLowerCase();

        // Check if date is within 24 hours and merchant matches (fuzzy)
        if (smsDate.isAfter(startDate) &&
            smsDate.isBefore(endDate) &&
            _isMerchantSimilar(smsMerchant, emailMerchant)) {
          return doc.id;
        }
      }

      return null;
    } catch (e) {
      print('Error finding SMS duplicate: $e');
      return null;
    }
  }

  /// Check if two merchant names are similar (fuzzy match)
  bool _isMerchantSimilar(String merchant1, String merchant2) {
    // Remove common words and special characters
    final clean1 = _cleanMerchantName(merchant1);
    final clean2 = _cleanMerchantName(merchant2);

    // Exact match
    if (clean1 == clean2) return true;

    // Contains match (one contains the other)
    if (clean1.contains(clean2) || clean2.contains(clean1)) return true;

    // Calculate simple similarity score (Jaccard similarity)
    final words1 = clean1.split(' ').where((w) => w.isNotEmpty).toSet();
    final words2 = clean2.split(' ').where((w) => w.isNotEmpty).toSet();

    if (words1.isEmpty || words2.isEmpty) return false;

    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;

    final similarity = intersection / union;

    // Consider similar if 60% or more words match
    return similarity >= 0.6;
  }

  /// Clean merchant name for comparison
  String _cleanMerchantName(String merchant) {
    return merchant
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Mark a transaction as duplicate
  Future<void> markAsDuplicate({
    required String collection,
    required String transactionId,
    required String duplicateOfId,
    required String duplicateSource, // 'sms' or 'email'
  }) async {
    try {
      await _firestore.collection(collection).doc(transactionId).update({
        'isDuplicate': true,
        'duplicateOf': duplicateOfId,
        'duplicateSource': duplicateSource,
      });
    } catch (e) {
      print('Error marking as duplicate: $e');
    }
  }

  /// Unmark a transaction as duplicate
  Future<void> unmarkAsDuplicate({
    required String collection,
    required String transactionId,
  }) async {
    try {
      await _firestore.collection(collection).doc(transactionId).update({
        'isDuplicate': false,
        'duplicateOf': null,
        'duplicateSource': null,
      });
    } catch (e) {
      print('Error unmarking duplicate: $e');
    }
  }

  /// Get duplicate transaction details
  Future<Map<String, dynamic>?> getDuplicateDetails({
    required String collection,
    required String transactionId,
  }) async {
    try {
      final doc = await _firestore.collection(collection).doc(transactionId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting duplicate details: $e');
      return null;
    }
  }
}

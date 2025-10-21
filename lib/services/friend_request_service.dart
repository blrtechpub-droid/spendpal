import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spendpal/models/friend_request_model.dart';

class FriendRequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send a friend request
  static Future<void> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
    String? nickname,
  }) async {
    // Check if already friends
    final fromUserDoc = await _firestore.collection('users').doc(fromUserId).get();
    final friends = Map<String, dynamic>.from(fromUserDoc.data()?['friends'] ?? {});

    if (friends.containsKey(toUserId)) {
      throw Exception('Already friends with this user');
    }

    // Check if request already exists
    final existingRequest = await _firestore
        .collection('friendRequests')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception('Friend request already sent');
    }

    // Check if reverse request exists (they sent you a request)
    final reverseRequest = await _firestore
        .collection('friendRequests')
        .where('fromUserId', isEqualTo: toUserId)
        .where('toUserId', isEqualTo: fromUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (reverseRequest.docs.isNotEmpty) {
      throw Exception('This user has already sent you a friend request. Check your pending requests.');
    }

    // Create friend request
    final request = FriendRequestModel(
      requestId: '',
      fromUserId: fromUserId,
      toUserId: toUserId,
      status: 'pending',
      nickname: nickname,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('friendRequests').add(request.toMap());
  }

  /// Accept a friend request
  /// [receiverNickname] is the optional nickname the receiver wants to give to the sender
  static Future<void> acceptFriendRequest(String requestId, {String? receiverNickname}) async {
    await _firestore.runTransaction((transaction) async {
      // READS FIRST: Get all documents before any writes
      final requestRef = _firestore.collection('friendRequests').doc(requestId);
      final requestDoc = await transaction.get(requestRef);

      if (!requestDoc.exists) {
        throw Exception('Friend request not found');
      }

      final request = FriendRequestModel.fromFirestore(requestDoc);

      if (request.status != 'pending') {
        throw Exception('This request has already been ${request.status}');
      }

      final fromUserRef = _firestore.collection('users').doc(request.fromUserId);
      final toUserRef = _firestore.collection('users').doc(request.toUserId);

      final fromUserDoc = await transaction.get(fromUserRef);
      final toUserDoc = await transaction.get(toUserRef);

      final toUserName = toUserDoc.data()?['name'] ?? '';
      final fromUserName = fromUserDoc.data()?['name'] ?? '';

      // Add receiver to sender's friends list
      // Use the nickname the sender originally provided (or receiver's name if no nickname)
      Map<String, dynamic> fromUserFriends =
          Map<String, dynamic>.from(fromUserDoc.data()?['friends'] ?? {});
      fromUserFriends[request.toUserId] = request.nickname ?? toUserName;

      // Add sender to receiver's friends list
      // Use the nickname the receiver provides when accepting (or sender's name if no nickname)
      Map<String, dynamic> toUserFriends =
          Map<String, dynamic>.from(toUserDoc.data()?['friends'] ?? {});
      toUserFriends[request.fromUserId] = receiverNickname ?? fromUserName;

      // WRITES SECOND: Now perform all updates
      transaction.update(requestRef, {
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(fromUserRef, {'friends': fromUserFriends});
      transaction.update(toUserRef, {'friends': toUserFriends});
    });
  }

  /// Reject a friend request
  static Future<void> rejectFriendRequest(String requestId) async {
    final requestDoc = await _firestore.collection('friendRequests').doc(requestId).get();

    if (!requestDoc.exists) {
      throw Exception('Friend request not found');
    }

    final request = FriendRequestModel.fromFirestore(requestDoc);

    if (request.status != 'pending') {
      throw Exception('This request has already been ${request.status}');
    }

    await requestDoc.reference.update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel a sent friend request
  static Future<void> cancelFriendRequest(String requestId) async {
    final requestDoc = await _firestore.collection('friendRequests').doc(requestId).get();

    if (!requestDoc.exists) {
      throw Exception('Friend request not found');
    }

    final request = FriendRequestModel.fromFirestore(requestDoc);

    if (request.status != 'pending') {
      throw Exception('Cannot cancel a ${request.status} request');
    }

    await requestDoc.reference.delete();
  }

  /// Get pending friend requests sent to current user
  static Stream<List<FriendRequestModel>> getPendingReceivedRequests(String userId) {
    return _firestore
        .collection('friendRequests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => FriendRequestModel.fromFirestore(doc))
              .toList();
          // Sort in memory to avoid needing Firestore index
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        });
  }

  /// Get pending friend requests sent by current user
  static Stream<List<FriendRequestModel>> getPendingSentRequests(String userId) {
    return _firestore
        .collection('friendRequests')
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => FriendRequestModel.fromFirestore(doc))
              .toList();
          // Sort in memory to avoid needing Firestore index
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        });
  }

  /// Get count of pending received requests
  static Future<int> getPendingRequestCount(String userId) async {
    final snapshot = await _firestore
        .collection('friendRequests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    return snapshot.docs.length;
  }
}

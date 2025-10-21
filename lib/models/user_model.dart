import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? photoURL;
  final Map<String, String> friends; // UID → Nickname

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.photoURL,
    required this.friends,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'],
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      photoURL: data['photoURL'],
      friends: Map<String, String>.from(data['friends'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'photoURL': photoURL,
      'friends': friends,
    };
  }
}
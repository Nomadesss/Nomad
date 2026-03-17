import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {

  static Future<List<String>> getFollowing(String userId) async {

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .get();

    final data = doc.data();

    if (data == null) return [];

    return List<String>.from(data["following"] ?? []);
  }
}
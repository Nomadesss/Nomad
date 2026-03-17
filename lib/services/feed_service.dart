import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class FeedService {

  static Future<List<Map<String, dynamic>>> getFeed(
    String city,
    String userId,
  ) async {

    final normalizedCity = city.trim().toLowerCase();

    List<Map<String, dynamic>> feed = [];

    /// 1. Usuarios que sigo
    final following = await UserService.getFollowing(userId);

    /// 2. POSTS DE USUARIOS SEGUIDOS
    if (following.isNotEmpty) {

      final followingPosts = await FirebaseFirestore.instance
          .collection("posts")
          .where("userId", whereIn: following)
          .limit(10)
          .get();

      for (var doc in followingPosts.docs) {
        final data = doc.data();

        feed.add({
          "type": "post",
          "username": data["username"],
          "images": List<String>.from(data["images"] ?? []),
          "caption": data["caption"],
          "likes": data["likes"] ?? 0,
        });
      }
    }

    /// 3. POSTS CERCANOS
    final nearbyPosts = await FirebaseFirestore.instance
        .collection("posts")
        .where("city", isEqualTo: normalizedCity)
        .limit(10)
        .get();

    for (var doc in nearbyPosts.docs) {
      final data = doc.data();

      feed.add({
        "type": "post",
        "username": data["username"],
        "images": List<String>.from(data["images"] ?? []),
        "caption": data["caption"],
        "likes": data["likes"] ?? 0,
      });
    }

    /// 4. EVENTOS
    final events = await FirebaseFirestore.instance
        .collection("events")
        .where("city", isEqualTo: normalizedCity)
        .limit(5)
        .get();

    for (var doc in events.docs) {
      final data = doc.data();

      feed.add({
        "type": "event",
        "title": data["title"],
        "location": data["city"],
        "date": data["date"],
      });
    }

    /// Mezclar contenido
    feed.shuffle();

    return feed;
  }
}
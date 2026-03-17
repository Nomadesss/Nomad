import 'package:cloud_firestore/cloud_firestore.dart';

class FeedService {

  /// Traer contenido por ciudad
  static Future<List<Map<String, dynamic>>> getFeedByCity(String city) async {

    try {

      final normalizedCity = city.trim().toLowerCase();

      /// POSTS
      final postsSnapshot = await FirebaseFirestore.instance
          .collection("posts")
          .where("city", isEqualTo: normalizedCity)
          .limit(10)
          .get();

      /// EVENTOS
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection("events")
          .where("city", isEqualTo: normalizedCity)
          .limit(5)
          .get();

      List<Map<String, dynamic>> feed = [];

      /// MAPEAR POSTS
      for (var doc in postsSnapshot.docs) {

        final data = doc.data();

        feed.add({
          "type": "post",
          "username": data["username"] ?? "Usuario",
          "images": List<String>.from(data["images"] ?? []),
          "caption": data["caption"] ?? "",
          "likes": data["likes"] ?? 0,
        });
      }

      /// MAPEAR EVENTOS
      for (var doc in eventsSnapshot.docs) {

        final data = doc.data();

        feed.add({
          "type": "event",
          "title": data["title"] ?? "Evento",
          "location": data["city"] ?? "",
          "date": data["date"] ?? "",
        });
      }

      /// MEZCLAR CONTENIDO (simple shuffle)
      feed.shuffle();

      return feed;

    } catch (e) {

      print("Error en FeedService: $e");
      return [];
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class FeedService {

  static Future<List<Map<String, dynamic>>> getFeed(
    String city,
    String userId,
  ) async {

    final normalizedCity = city.trim().toLowerCase();
    final db = FirebaseFirestore.instance;

    List<Map<String, dynamic>> feed = [];
    final Set<String> addedDocIds = {}; // evitar duplicados entre secciones

    // ── 1. Posts de usuarios seguidos ─────────────────────────────────────
    final following = await UserService.getFollowing(userId);

    if (following.isNotEmpty) {
      // orderBy("createdAt") requiere índice compuesto en Firestore.
      // Crearlo en: Firebase Console → Firestore → Índices → Agregar índice
      // Campos: authorId (ASC) + createdAt (DESC)
      // Mientras el índice se construye, la query funciona sin ordenamiento.
      final followingPosts = await db
          .collection("posts")
          .where("authorId", whereIn: following)
          .limit(10)
          .get();

      for (final doc in followingPosts.docs) {
        if (addedDocIds.contains(doc.id)) continue;
        addedDocIds.add(doc.id);
        feed.add(_mapPost(doc));
      }
    }

    // ── 2. Posts cercanos (misma ciudad) ──────────────────────────────────
    // orderBy requiere índice compuesto city + createdAt (ya habilitado en Firebase).
    // Re-activar una vez confirmado que el índice está en estado "Habilitado".
    final nearbyPosts = await db
        .collection("posts")
        .where("city", isEqualTo: normalizedCity)
        .limit(10)
        .get();

    for (final doc in nearbyPosts.docs) {
      if (addedDocIds.contains(doc.id)) continue;
      addedDocIds.add(doc.id);
      feed.add(_mapPost(doc));
    }

    // ── 3. Eventos cercanos ────────────────────────────────────────────────
    final events = await db
        .collection("events")
        .where("city", isEqualTo: normalizedCity)
        .limit(5)
        .get();

    for (final doc in events.docs) {
      feed.add({
        "type":     "event",
        "title":    doc.data()["title"]    ?? "",
        "location": doc.data()["city"]     ?? "",
        "date":     doc.data()["date"]     ?? "",
      });
    }

    // Mezclar manteniendo eventos intercalados
    feed.shuffle();

    return feed;
  }

  // ── Helper: mapea un documento de Firestore al formato del feed ──────────
  static Map<String, dynamic> _mapPost(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return {
      "type":        "post",
      "docId":       doc.id,                              // ID real del documento
      "authorId":    data["authorId"] as String? ?? "",   // UID de Firebase Auth
      "username":    data["username"] as String? ?? "usuario",
      "images":      List<String>.from(data["images"] ?? []),
      "caption":     data["caption"]  as String? ?? "",
      "city":        data["city"]     as String?,
      "countryFlag": data["countryFlag"] as String?,
      "bio":         data["bio"]      as String?,
      // likesCount viene del stream en LikeButton, no lo necesitamos aquí
    };
  }
}
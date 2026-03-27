import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Corré esta función una sola vez desde cualquier pantalla de la app.
/// Por ejemplo, agregá en initState() de FeedScreen:
///   SeedPosts.run();
/// Y después de verlos en el feed, quitalo.

class SeedPosts {
  // ── Migrar posts existentes sin campo visibility ───────────────────────────
  // Llamar una sola vez desde initState() junto a run(), luego quitar.
  // Solo toca documentos que no tienen el campo — no sobreescribe nada.
  static Future<void> migrate() async {
    final db = FirebaseFirestore.instance;
    final snap = await db.collection('posts').get();

    int updated = 0;
    for (final doc in snap.docs) {
      if (doc.data().containsKey('visibility')) continue;
      await doc.reference.update({'visibility': 'public'});
      updated++;
    }
    print('✅ Migración: $updated posts actualizados con visibility=public');
  }

  static Future<void> run() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ No hay usuario logueado");
      return;
    }

    final uid = user.uid;
    final db = FirebaseFirestore.instance;
    final userDoc = await db.collection("users").doc(uid).get();
    final username = userDoc.data()?["username"] ?? "nomad_user";
    final flag = userDoc.data()?["countryFlag"] ?? "🌍";
    final bio = userDoc.data()?["bio"] ?? "";
    final city =
        (userDoc.data()?["location"]?["gps"]?["city"] ??
                userDoc.data()?["location"]?["ip"]?["city"] ??
                "montevideo")
            as String;

    final normalizedCity = city.trim().toLowerCase();

    final posts = [
      {
        "authorId": uid,
        "username": username,
        "caption":
            "Primera semana en Madrid y ya extraño el mate ☕🇺🇾 Pero la ciudad es increíble, cada rincón tiene historia.",
        "city": normalizedCity,
        "countryFlag": flag,
        "bio": bio,
        "visibility": "public",
        "images": [
          "https://images.unsplash.com/photo-1539037116277-4db20889f2d4?w=800&q=80",
        ],
        "likesCount": 12,
        "createdAt": FieldValue.serverTimestamp(),
      },
      {
        "authorId": uid,
        "username": username,
        "caption":
            "Encontré una comunidad de compatriotas aquí 🙌 Si estás en la misma ciudad escribime!",
        "city": normalizedCity,
        "countryFlag": flag,
        "bio": bio,
        "visibility": "public",
        "images": [
          "https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800&q=80",
        ],
        "likesCount": 34,
        "createdAt": FieldValue.serverTimestamp(),
      },
      {
        "authorId": uid,
        "username": username,
        "caption":
            "Trámites de residencia completados ✅ Después de 3 meses por fin! Si alguien necesita ayuda con el proceso, con gusto comparto mi experiencia.",
        "city": normalizedCity,
        "countryFlag": flag,
        "bio": bio,
        "visibility": "public",
        "images": [
          "https://images.unsplash.com/photo-1450101499163-c8848c66ca85?w=800&q=80",
        ],
        "likesCount": 56,
        "createdAt": FieldValue.serverTimestamp(),
      },
      {
        "authorId": uid,
        "username": username,
        "caption":
            "El asado del domingo nunca falla, aunque sea lejos de casa 🔥🥩",
        "city": normalizedCity,
        "countryFlag": flag,
        "bio": bio,
        "visibility": "public",
        "images": [
          "https://images.unsplash.com/photo-1544025162-d76694265947?w=800&q=80",
        ],
        "likesCount": 89,
        "createdAt": FieldValue.serverTimestamp(),
      },
      {
        "authorId": uid,
        "username": username,
        "caption":
            "Vista desde mi nuevo departamento 🏙️ Todavía no puedo creer que vivo acá.",
        "city": normalizedCity,
        "countryFlag": flag,
        "bio": bio,
        "visibility": "public",
        "images": [
          "https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800&q=80",
        ],
        "likesCount": 145,
        "createdAt": FieldValue.serverTimestamp(),
      },
    ];

    for (final post in posts) {
      await db.collection("posts").add(post);
      print("✅ Post creado: ${post["caption"].toString().substring(0, 30)}...");
    }

    print(
      "🎉 ${posts.length} posts de prueba creados en ciudad: $normalizedCity",
    );
  }
}

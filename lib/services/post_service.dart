import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'location_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PostService — crear y leer publicaciones en Firestore
//
// Colección: 'posts'
//
// Documento de un post:
// {
//   authorId:    String,
//   username:    String,
//   caption:     String,
//   images:      List<String>,   ← URLs de Storage (o placeholders por ahora)
//   location:    String?,
//   lat:         double?,        ← coordenada GPS del autor al publicar
//   lng:         double?,        ← coordenada GPS del autor al publicar
//   visibility:  String,         ← 'public' | 'friends'
//   spotifyTrackId:   String?,
//   spotifyTrackName: String?,
//   spotifyArtist:    String?,
//   spotifyPreviewUrl: String?,
//   likesCount:  int,
//   commentsCount: int,
//   countryFlag: String?,
//   city:        String?,
//   bio:         String?,
//   createdAt:   Timestamp,
// }
// ─────────────────────────────────────────────────────────────────────────────

class PostService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const _postsCollection = 'posts';
  static const _usersCollection = 'users';

  // ── Crear publicación ──────────────────────────────────────────────────────

  static Future<({String? postId, String? error})> createPost({
    required List<File> imagenes,
    required String caption,
    String? location,
    LocationData? locationData,

    // Spotify
    String? spotifyTrackId,
    String? spotifyTrackName,
    String? spotifyArtist,
    String? spotifyPreviewUrl,
    String? spotifyAlbumArt,
  }) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        return (postId: null, error: 'No hay sesión activa.');
      }

      // obtener datos usuario
      final userDoc = await _db
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      final bool isPrivate = userData['esPrivada'] ?? false;

      // definir visibilidad automaticamente
      final String visibility = isPrivate ? 'followers' : 'public';

      // placeholder imagenes
      final List<String> imageUrls = imagenes.isNotEmpty
          ? List.generate(
              imagenes.length,
              (i) =>
                  'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch + i}/800/800',
            )
          : ['https://picsum.photos/seed/nomad/800/800'];

      final docRef = _db.collection(_postsCollection).doc();

      final Map<String, dynamic> data = {
        'authorId': user.uid,

        'username':
            userData['username'] ?? userData['nombreCompleto'] ?? 'usuario',

        'caption': caption.trim(),

        'images': imageUrls,

        'likesCount': 0,

        'commentsCount': 0,

        'countryFlag': userData['countryFlag'],

        'city': userData['city'],

        'bio': userData['bio'],

        'visibility': visibility,

        'createdAt': FieldValue.serverTimestamp(),

        if (location != null && location.isNotEmpty) 'location': location,

        if (locationData?.lat != null) 'lat': locationData!.lat,

        if (locationData?.lng != null) 'lng': locationData!.lng,

        if (spotifyTrackId != null) ...{
          'spotifyTrackId': spotifyTrackId,

          'spotifyTrackName': spotifyTrackName,

          'spotifyArtist': spotifyArtist,

          'spotifyPreviewUrl': spotifyPreviewUrl,

          'spotifyAlbumArt': spotifyAlbumArt,
        },
      };

      await docRef.set(data);

      return (postId: docRef.id, error: null);
    } catch (e) {
      return (postId: null, error: 'No se pudo publicar.');
    }
  }

  // ── Eliminar publicación ───────────────────────────────────────────────────

  static Future<String?> deletePost(String postId) async {
    try {
      await _db.collection(_postsCollection).doc(postId).delete();
      return null;
    } catch (e) {
      return 'No se pudo eliminar la publicación.';
    }
  }

  static Stream<List<Map<String, dynamic>>> getUserPosts(String userId) {
    return _db
        .collection(_postsCollection)
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc
                .id; // Guardamos el ID por si lo necesitás para borrar o editar
            return data;
          }).toList(),
        );
  }
}

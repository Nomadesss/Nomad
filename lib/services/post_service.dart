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
    LocationData? locationData, // ← coordenadas GPS para ordenar por distancia
    String visibility = 'public', // ← 'public' | 'friends'
    // Spotify
    String? spotifyTrackId,
    String? spotifyTrackName,
    String? spotifyArtist,
    String? spotifyPreviewUrl,
    String? spotifyAlbumArt,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return (postId: null, error: 'No hay sesión activa.');

      // ── Leer perfil del autor desde Firestore ────────────────────────────
      final userDoc = await _db
          .collection(_usersCollection)
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};

      // ── Subir imágenes a Firebase Storage ────────────────────────────────
      // TODO (producción): descomentar cuando Storage esté activo.
      //
      // final storageRef = FirebaseStorage.instance.ref();
      // final List<String> imageUrls = [];
      // for (int i = 0; i < imagenes.length; i++) {
      //   final ref = storageRef
      //       .child('posts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
      //   await ref.putFile(imagenes[i]);
      //   final url = await ref.getDownloadURL();
      //   imageUrls.add(url);
      // }

      // Placeholder mientras Storage no está activo:
      final List<String> imageUrls = List.generate(
        imagenes.length,
        (i) =>
            'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch + i}/800/800',
      );

      // ── Crear documento en Firestore ─────────────────────────────────────
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
        // Coordenadas GPS: permiten ordenar por distancia en el feed.
        // Se guardan solo si el usuario otorgó permiso de ubicación.
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
      return (postId: null, error: 'No se pudo publicar. Intentá de nuevo.');
    }
  }

  // ── Eliminar publicación ───────────────────────────────────────────────────

  static Future<String?> deletePost(String postId) async {
    try {
      // TODO (producción): eliminar imágenes de Storage también.
      await _db.collection(_postsCollection).doc(postId).delete();
      return null;
    } catch (e) {
      return 'No se pudo eliminar la publicación.';
    }
  }
}

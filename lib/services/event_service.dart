import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EventService — crear y leer eventos en Firestore
//
// Colección: 'events'
//
// Documento de un evento:
// {
//   authorId:    String,
//   username:    String,
//   title:       String,
//   description: String,
//   location:    String,
//   locationPlaceId: String?,   ← Google Places ID para el mapa
//   date:        Timestamp,
//   tipo:        String,         ← Meetup | Cultural | Gastronómico | Deportivo | Otro
//   capacidad:   int?,
//   coverImageUrl: String?,
//   attendeesCount: int,
//   createdAt:   Timestamp,
// }
// ─────────────────────────────────────────────────────────────────────────────

class EventService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const _eventsCollection = 'events';
  static const _usersCollection  = 'users';

  // ── Crear evento ───────────────────────────────────────────────────────────

  static Future<({String? eventId, String? error})> createEvent({
    required String title,
    required String description,
    required String location,
    String? locationPlaceId,
    required DateTime fecha,
    required String tipo,
    int? capacidad,
    File? coverImage,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return (eventId: null, error: 'No hay sesión activa.');

      final userDoc = await _db.collection(_usersCollection).doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // ── Subir imagen de portada ───────────────────────────────────────────
      // TODO (producción): descomentar cuando Storage esté activo.
      //
      // String? coverImageUrl;
      // if (coverImage != null) {
      //   final ref = FirebaseStorage.instance
      //       .ref()
      //       .child('events/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      //   await ref.putFile(coverImage);
      //   coverImageUrl = await ref.getDownloadURL();
      // }

      // Placeholder mientras Storage no está activo:
      final String? coverImageUrl = coverImage != null
          ? 'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/800/400'
          : null;

      // ── Crear documento ───────────────────────────────────────────────────
      final docRef = _db.collection(_eventsCollection).doc();

      final Map<String, dynamic> data = {
        'authorId':    user.uid,
        'username':    userData['username'] ?? userData['nombreCompleto'] ?? 'usuario',
        'title':       title.trim(),
        'description': description.trim(),
        'location':    location.trim(),
        'date':        Timestamp.fromDate(fecha),
        'tipo':        tipo,
        'attendeesCount': 0,
        'createdAt':   FieldValue.serverTimestamp(),
        if (locationPlaceId != null) 'locationPlaceId': locationPlaceId,
        if (capacidad != null)       'capacidad':       capacidad,
        if (coverImageUrl != null)   'coverImageUrl':   coverImageUrl,
      };

      await docRef.set(data);

      return (eventId: docRef.id, error: null);
    } catch (e) {
      return (eventId: null, error: 'No se pudo crear el evento. Intentá de nuevo.');
    }
  }
}
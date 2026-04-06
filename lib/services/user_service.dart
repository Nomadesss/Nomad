import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_model.dart';
import 'location_service.dart';
import 'trust_score_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UserService — operaciones de perfil de usuario en Nomad
//
// Colección principal: 'users/{uid}'
// Subcolecciones relacionadas (manejadas por SocialService):
//   follows, post_likes, notifications
//
// Patrón de uso:
//   - streamPerfil()  → para widgets que necesitan reactividad en tiempo real.
//   - getPerfil()     → para lecturas puntuales (ej: abrir perfil de otro usuario).
//   - update*()       → para mutaciones parciales del documento.
// ─────────────────────────────────────────────────────────────────────────────

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _usersCollection = 'users';

  // ── UID del usuario actual ─────────────────────────────────────────────────
  //
  // CORRECCIÓN respecto a SocialService: no usamos ! directamente.
  // _requireUid() lanza una excepción con mensaje claro en lugar de
  // un NullPointerException críptico.

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError(
        'UserService: no hay sesión activa. '
        'Verificá que el usuario esté logueado antes de llamar este método.',
      );
    }
    return uid;
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
    return doc.data() as Map<String, dynamic>?;
  }

  // Actualizar datos del usuario
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  DocumentReference _userRef(String uid) =>
      _db.collection(_usersCollection).doc(uid);

  // ── LEER PERFIL ────────────────────────────────────────────────────────────

  /// Stream en tiempo real del perfil del usuario actual.
  ///
  /// Usalo en widgets con StreamBuilder o en un provider/bloc.
  /// Se actualiza automáticamente cuando otro dispositivo modifica el perfil
  /// o cuando SocialService incrementa followersCount.
  ///
  /// Emite null si el documento no existe (caso edge: usuario eliminado).
  Stream<UserModel?> streamPerfil() {
    final uid = _requireUid();
    return _userRef(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromDoc(snap);
    });
  }

  /// Stream del perfil de cualquier usuario por UID.
  /// Útil para mostrar el perfil de otro usuario en tiempo real.
  Stream<UserModel?> streamPerfilDeUsuario(String uid) {
    return _userRef(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromDoc(snap);
    });
  }

  /// Consulta puntual del perfil del usuario actual.
  ///
  /// Preferí streamPerfil() en widgets. Usá getPerfil() solo cuando
  /// necesitás el dato una sola vez sin suscripción (ej: al iniciar la app
  /// para pre-cargar datos antes de mostrar la UI).
  Future<UserModel?> getPerfil() async {
    final uid = _requireUid();
    final snap = await _userRef(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromDoc(snap);
  }

  /// Consulta puntual del perfil de cualquier usuario por UID.
  Future<UserModel?> getPerfilDeUsuario(String uid) async {
    final snap = await _userRef(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromDoc(snap);
  }

  // ── ACTUALIZAR PERFIL ──────────────────────────────────────────────────────

  /// Actualiza campos del perfil del usuario actual.
  ///
  /// Recibe un UserModel con los campos nuevos y usa toUpdateMap()
  /// para escribir solo los campos no-null. No pisa followersCount
  /// ni creadoEn ni ningún campo que no deba cambiar.
  ///
  /// Ejemplo de uso:
  ///   await userService.updatePerfil(
  ///     currentUser.copyWith(bio: 'Nueva bio', username: 'nuevo_username'),
  ///   );
  Future<String?> updatePerfil(UserModel updatedUser) async {
    try {
      final uid = _requireUid();
      await _userRef(uid).update(updatedUser.toUpdateMap());
      return null; // éxito
    } on FirebaseException catch (e) {
      return 'Error al actualizar el perfil: ${e.message}';
    } catch (e) {
      return 'Error inesperado. Intentá de nuevo.';
    }
  }

  /// Actualiza solo la foto de perfil.
  /// Llamar después de subir la imagen a Storage y obtener la URL.
  Future<String?> updateFoto(String fotoUrl) async {
    try {
      final uid = _requireUid();
      await _userRef(uid).update({
        'fotoUrl': fotoUrl,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      // Sincronizar también en Firebase Auth para que displayName y photoURL
      // estén consistentes en toda la plataforma.
      await _auth.currentUser?.updatePhotoURL(fotoUrl);
      return null;
    } catch (e) {
      return 'No se pudo actualizar la foto. Intentá de nuevo.';
    }
  }

  // ── UBICACIÓN ──────────────────────────────────────────────────────────────

  /// Actualiza la ubicación del usuario con los datos de LocationService.
  ///
  /// Llamar después de LocationService.collect() en el onboarding
  /// o cuando el usuario actualiza su ubicación manualmente.
  ///
  /// Ejemplo de uso:
  ///   final location = await LocationService.collect();
  ///   await userService.updateUbicacion(location);
  Future<String?> updateUbicacion(LocationData location) async {
    try {
      final uid = _requireUid();
      await _userRef(uid).update({
        'ubicacionActual': location.toMap(),
        // Si el GPS tiene ciudad y país, los promovemos al nivel raíz
        // para que feed_service y social_service puedan filtrar por ciudad
        // sin navegar dentro del objeto ubicacionActual.
        if (location.city != null)
          'ciudad': location.city!.trim().toLowerCase(),
        if (location.country != null) 'pais': location.country,
        if (location.countryCode != null) 'paisCode': location.countryCode,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'No se pudo actualizar la ubicación. Intentá de nuevo.';
    }
  }

  // ── TRUST SCORE ────────────────────────────────────────────────────────────

  /// Calcula y guarda el trust score del usuario actual.
  ///
  /// Llamar después de updateUbicacion() en el onboarding,
  /// ya que TrustScoreService necesita LocationData.
  ///
  /// Ejemplo de uso:
  ///   final location = await LocationService.collect();
  ///   await userService.updateUbicacion(location);
  ///   await userService.calcularYGuardarTrustScore(location);
  Future<String?> calcularYGuardarTrustScore(LocationData location) async {
    try {
      final uid = _requireUid();
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return 'No hay sesión activa.';

      final result = TrustScoreService.calculate(
        location: location,
        user: firebaseUser,
      );

      await _userRef(uid).update({
        'trustScore': result.toMap(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'No se pudo calcular el score de confianza.';
    }
  }

  // ── PERFIL MIGRATORIO ──────────────────────────────────────────────────────
  //
  // Este es el núcleo del Community Hub.
  // Se llama desde el onboarding extendido o desde la pantalla de Perfil.

  /// Actualiza el perfil migratorio del usuario.
  ///
  /// Todos los parámetros son opcionales — solo se escriben en Firestore
  /// los que se pasan. Así podés actualizar un solo campo sin pisar los demás.
  ///
  /// Ejemplo — el usuario elige su país destino desde el perfil:
  ///   await userService.updateMigrationStatus(
  ///     destinationCountry: 'España',
  ///     destinationCountryCode: 'ES',
  ///   );
  ///
  /// Ejemplo — completa el onboarding migratorio completo:
  ///   await userService.updateMigrationStatus(
  ///     destinationCountry: 'España',
  ///     destinationCountryCode: 'ES',
  ///     migrationStatus: MigrationStatus.arrived,
  ///     hasChildren: true,
  ///     profession: 'Desarrollador de software',
  ///     arrivedAt: DateTime(2024, 3, 15),
  ///   );
  Future<String?> updateMigrationStatus({
    String? destinationCountry,
    String? destinationCountryCode,
    MigrationStatus? migrationStatus,
    String? visaType,
    bool? hasChildren,
    String? profession,
    DateTime? arrivedAt,
  }) async {
    try {
      final uid = _requireUid();

      // Construimos el map de update solo con los campos que se pasaron.
      // Si un parámetro es null, no se incluye → no pisa el valor existente.
      final updates = <String, dynamic>{
        'actualizadoEn': FieldValue.serverTimestamp(),
      };

      if (destinationCountry != null) {
        updates['destinationCountry'] = destinationCountry;
      }
      if (destinationCountryCode != null) {
        updates['destinationCountryCode'] = destinationCountryCode;
      }
      if (migrationStatus != null) {
        updates['migrationStatus'] = migrationStatus.toFirestoreString();
      }
      if (visaType != null) {
        updates['visaType'] = visaType;
      }
      if (hasChildren != null) {
        updates['hasChildren'] = hasChildren;
      }
      if (profession != null) {
        updates['profession'] = profession;
      }
      if (arrivedAt != null) {
        updates['arrivedAt'] = Timestamp.fromDate(arrivedAt);
      }

      await _userRef(uid).update(updates);
      return null;
    } on FirebaseException catch (e) {
      return 'Error al guardar el perfil migratorio: ${e.message}';
    } catch (e) {
      return 'Error inesperado. Intentá de nuevo.';
    }
  }

  // ── GRAFO SOCIAL ───────────────────────────────────────────────────────────
  //
  // CORRECCIÓN respecto al original:
  //   - getFollowing() devolvía List<String> (solo IDs).
  //   - Ahora getFollowing() y getFollowers() devuelven List<UserModel>
  //     para que la UI tenga el perfil completo sin hacer N queries adicionales.
  //   - Se mantiene getFollowingIds() para los casos donde solo se necesitan
  //     los IDs (como en FeedService).

  /// Devuelve los IDs de los usuarios que sigue el usuario dado.
  /// Mantenido por compatibilidad con FeedService que solo necesita los IDs.
  static Future<List<String>> getFollowingIds(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .get();
    return snap.docs
        .map((doc) => doc.data()['followingId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Devuelve los perfiles completos de los usuarios que sigue el usuario actual.
  Future<List<UserModel>> getFollowing(String userId) async {
    final ids = await getFollowingIds(userId);
    if (ids.isEmpty) return [];
    return _getUsersByIds(ids);
  }

  /// Devuelve los perfiles completos de los seguidores del usuario dado.
  Future<List<UserModel>> getFollowers(String userId) async {
    final snap = await _db
        .collection('follows')
        .where('followingId', isEqualTo: userId)
        .get();

    final followerIds = snap.docs
        .map((doc) => doc.data()['followerId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (followerIds.isEmpty) return [];
    return _getUsersByIds(followerIds);
  }

  /// Busca usuarios por nombre o username.
  /// Útil para el buscador del feed y para agregar miembros a grupos.
  Future<List<UserModel>> buscarUsuarios(String query) async {
    if (query.trim().isEmpty) return [];

    final q = query.trim().toLowerCase();

    // Firestore no tiene full-text search nativo.
    // Esta query devuelve usuarios cuyo nombreCompleto empieza con la búsqueda.
    // Para búsqueda más avanzada, usar Elasticsearch en v2.0.
    final snap = await _db
        .collection(_usersCollection)
        .where('nombreCompleto', isGreaterThanOrEqualTo: q)
        .where('nombreCompleto', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(20)
        .get();

    return snap.docs.map(UserModel.fromDoc).toList();
  }

  // ── GDPR ───────────────────────────────────────────────────────────────────

  /// Derecho al olvido — Art. 17 GDPR.
  ///
  /// Marca la cuenta para borrado. El borrado real de datos se ejecuta
  /// en una Cloud Function programada (30 días de gracia para arrepentirse).
  /// Durante esos 30 días el usuario puede cancelar el borrado.
  ///
  /// El borrado inmediato de datos sensibles (trustScore, ubicación)
  /// se hace acá directamente.
  Future<String?> solicitarBorradoDeCuenta() async {
    try {
      final uid = _requireUid();
      await _userRef(uid).update({
        // Marcar para borrado diferido (30 días).
        'dataDeletionRequestedAt': FieldValue.serverTimestamp(),
        // Borrado inmediato de datos sensibles.
        'ubicacionActual': FieldValue.delete(),
        'trustScore': FieldValue.delete(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'No se pudo procesar la solicitud. Contactá a soporte.';
    }
  }

  /// Cancela una solicitud de borrado activa (dentro de los 30 días de gracia).
  Future<String?> cancelarBorradoDeCuenta() async {
    try {
      final uid = _requireUid();
      await _userRef(uid).update({
        'dataDeletionRequestedAt': FieldValue.delete(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'No se pudo cancelar el borrado. Intentá de nuevo.';
    }
  }

  /// Actualizacion tras cambio en tipo de perfil.
  static Future syncPostsVisibility({
    required String userId,
    required bool esPrivada,
  }) async {
    final db = FirebaseFirestore.instance;

    final posts = await db
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .get();

    final batch = db.batch();

    final newVisibility = esPrivada ? 'followers' : 'public';

    for (final doc in posts.docs) {
      batch.update(doc.reference, {'visibility': newVisibility});
    }

    await batch.commit();
  }

  /// Derecho de acceso — Art. 15 GDPR.
  ///
  /// Devuelve todos los datos del usuario en un Map exportable.
  /// En v2.0 esto genera un ZIP descargable. Por ahora devuelve el Map
  /// que la UI puede mostrar o compartir como JSON.
  Future<Map<String, dynamic>?> exportarDatos() async {
    try {
      final uid = _requireUid();

      // Datos del perfil.
      final perfilSnap = await _userRef(uid).get();

      // Posts del usuario.
      final postsSnap = await _db
          .collection('posts')
          .where('authorId', isEqualTo: uid)
          .get();

      // Follows.
      final followingSnap = await _db
          .collection('follows')
          .where('followerId', isEqualTo: uid)
          .get();

      // Notificaciones.
      final notifSnap = await _db
          .collection('notifications')
          .where('toUserId', isEqualTo: uid)
          .limit(100)
          .get();

      return {
        'exportadoEn': DateTime.now().toIso8601String(),
        'version': '1.0',
        'perfil': perfilSnap.data(),
        'posts': postsSnap.docs.map((d) => d.data()).toList(),
        'siguiendo': followingSnap.docs.map((d) => d.data()).toList(),
        'notificaciones': notifSnap.docs.map((d) => d.data()).toList(),
      };
    } catch (e) {
      return null;
    }
  }

  // ── Helper privado ─────────────────────────────────────────────────────────

  /// Obtiene múltiples perfiles por lista de IDs.
  ///
  /// Firestore limita whereIn a 30 elementos. Si hay más de 30 follows,
  /// los divide en chunks. En v2.0 con Elasticsearch esto desaparece.
  Future<List<UserModel>> _getUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final List<UserModel> results = [];

    // Dividir en chunks de 30 (límite de Firestore para whereIn).
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);

      final snap = await _db
          .collection(_usersCollection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      results.addAll(snap.docs.map(UserModel.fromDoc));
    }

    return results;
  }
}

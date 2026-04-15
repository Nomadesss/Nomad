// ─────────────────────────────────────────────────────────────────────────────
// discover_service.dart  –  Nomad App
// Ubicación: lib/services/discover_service.dart
//
// Estructura Firestore:
//   /discover_likes/{myUid}_{targetUid}
//     fromUid:   String
//     toUid:     String
//     createdAt: Timestamp
//
//   /matches/{matchId}   (matchId = UIDs ordenados + "_")
//     uids:      [uid1, uid2]
//     createdAt: Timestamp
//     chatId:    String   ← mismo formato que los chats
//
//   /users/{uid}
//     discoverFilters: {
//       paisOrigen: String?
//       ciudad:     String?
//       objetivo:   String?
//       edadMin:    int?
//       edadMax:    int?
//     }
//     discoverVisible: bool  ← el usuario puede ocultarse del discover
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DiscoverService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _myUid => _auth.currentUser!.uid;

  // ── matchId determinístico ─────────────────────────────────────────────────
  static String _matchId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Cargar perfiles para el discover ──────────────────────────────────────
  //
  // 1. Trae todos los usuarios con discoverVisible == true (o sin ese campo)
  // 2. Excluye: yo mismo, ya likeados, ya descartados, ya matches
  // 3. Aplica los filtros opcionales del usuario
  // 4. Devuelve máximo 30 perfiles ordenados por compatibilidad de país

  static Future<List<Map<String, dynamic>>> loadProfiles({
    String? filterPaisOrigen,
    String? filterCiudad,
    String? filterObjetivo,
    int? filterEdadMin,
    int? filterEdadMax,
    String? filterGenero,
  }) async {
    final myUid = _myUid;

    // IDs ya vistos (likeados o descartados)
    final seenSnap = await _db
        .collection('discover_seen')
        .where('fromUid', isEqualTo: myUid)
        .get();
    final seenIds = seenSnap.docs
        .map((d) => d.data()['toUid'] as String)
        .toSet();

    // IDs con match ya existente
    final matchSnap = await _db
        .collection('matches')
        .where('uids', arrayContains: myUid)
        .get();
    final matchedIds = matchSnap.docs
        .expand((d) => List<String>.from(d.data()['uids'] as List? ?? []))
        .where((id) => id != myUid)
        .toSet();

    // Mi propio perfil (para comparar país)
    final myDoc = await _db.collection('users').doc(myUid).get();
    final myData = myDoc.data() ?? {};
    final myPais = _extractPais(myData);

    // Query base
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .where('discoverVisible', isNotEqualTo: false)
        .limit(80);

    // Filtro por país de origen
    if (filterPaisOrigen != null && filterPaisOrigen.isNotEmpty) {
      query = query.where('paisOrigen', isEqualTo: filterPaisOrigen);
    }

    // Filtro por ciudad actual
    if (filterCiudad != null && filterCiudad.isNotEmpty) {
      query = query.where('ciudadActual', isEqualTo: filterCiudad);
    }

    // Filtro por objetivo migratorio
    if (filterObjetivo != null && filterObjetivo.isNotEmpty) {
      query = query.where('migracionObjetivo', isEqualTo: filterObjetivo);
    }

    final snap = await query.get();

    final profiles = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final uid = doc.id;
      if (uid == myUid) continue;
      if (seenIds.contains(uid)) continue;
      if (matchedIds.contains(uid)) continue;

      final data = Map<String, dynamic>.from(doc.data());
      data['uid'] = uid;

      // Filtros client-side (Firestore no soporta múltiples range/inequality sin índices compuestos)
      if (filterEdadMin != null || filterEdadMax != null) {
        final edad = data['edad'] as int?;
        if (edad == null) continue;
        if (filterEdadMin != null && edad < filterEdadMin) continue;
        if (filterEdadMax != null && edad > filterEdadMax) continue;
      }

      if (filterGenero != null && filterGenero.isNotEmpty) {
        final genero = data['genero'] as String?;
        if (genero == null || genero != filterGenero) continue;
      }

      // Score de compatibilidad: mismo país = primero
      final perfilPais = _extractPais(data);
      data['_compatScore'] = (myPais != null && perfilPais == myPais) ? 1 : 0;

      profiles.add(data);
    }

    // Ordenar: compatriotas primero, luego el resto
    profiles.sort(
      (a, b) => (b['_compatScore'] as int).compareTo(a['_compatScore'] as int),
    );

    return profiles.take(30).toList();
  }

  // ── Dar like ───────────────────────────────────────────────────────────────

  static Future<bool> like(String targetUid) async {
    final myUid = _myUid;
    final batch = _db.batch();

    // Registrar like
    final likeRef = _db.collection('discover_likes').doc('${myUid}_$targetUid');
    batch.set(likeRef, {
      'fromUid': myUid,
      'toUid': targetUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Registrar como visto
    batch.set(_db.collection('discover_seen').doc('${myUid}_$targetUid'), {
      'fromUid': myUid,
      'toUid': targetUid,
      'action': 'like',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // ¿El otro también me dio like? → match
    final theirLike = await _db
        .collection('discover_likes')
        .doc('${targetUid}_$myUid')
        .get();

    if (theirLike.exists) {
      await _createMatch(myUid, targetUid);
      return true; // es un match
    }
    return false;
  }

  // ── Descartar (pasar) ──────────────────────────────────────────────────────

  static Future<void> dislike(String targetUid) async {
    final myUid = _myUid;
    await _db.collection('discover_seen').doc('${myUid}_$targetUid').set({
      'fromUid': myUid,
      'toUid': targetUid,
      'action': 'dislike',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Crear match ────────────────────────────────────────────────────────────

  static Future<void> _createMatch(String uid1, String uid2) async {
    final mId = _matchId(uid1, uid2);
    final chatId = mId; // mismo formato
    final batch = _db.batch();

    // Documento del match
    batch.set(_db.collection('matches').doc(mId), {
      'uids': [uid1, uid2],
      'chatId': chatId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Crear el chat si no existe
    final chatRef = _db.collection('chats').doc(chatId);
    batch.set(chatRef, {
      'participantIds': [uid1, uid2],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount': {uid1: 0, uid2: 0},
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Notificación para el otro
    for (final uid in [uid1, uid2]) {
      final other = uid == uid1 ? uid2 : uid1;
      batch.set(_db.collection('notifications').doc(), {
        'recipientId': uid,
        'type': 'match',
        'fromUid': other,
        'matchId': mId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ── Stream de matches del usuario ──────────────────────────────────────────

  static Stream<QuerySnapshot<Map<String, dynamic>>> matchesStream() {
    return _db
        .collection('matches')
        .where('uids', arrayContains: _myUid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ── Guardar filtros del usuario ────────────────────────────────────────────

  static Future<void> saveFilters({
    String? paisOrigen,
    String? ciudad,
    String? objetivo,
    int? edadMin,
    int? edadMax,
    String? genero,
  }) async {
    await _db.collection('users').doc(_myUid).update({
      'discoverFilters': {
        'paisOrigen': paisOrigen,
        'ciudad': ciudad,
        'objetivo': objetivo,
        'edadMin': edadMin,
        'edadMax': edadMax,
        'genero': genero,
      },
    });
  }

  // ── Cargar filtros guardados ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> loadFilters() async {
    final doc = await _db.collection('users').doc(_myUid).get();
    final data = doc.data() ?? {};
    return Map<String, dynamic>.from(data['discoverFilters'] as Map? ?? {});
  }

  // ── Toggle visibilidad en el discover ─────────────────────────────────────

  static Future<void> setVisible(bool visible) async {
    await _db.collection('users').doc(_myUid).update({
      'discoverVisible': visible,
    });
  }

  // ── Super like ─────────────────────────────────────────────────────────────

  static Future<bool> superLike(String targetUid) async {
    final myUid = _myUid;
    final batch = _db.batch();

    // Registrar como visto (acción superlike)
    batch.set(
      _db.collection('discover_seen').doc('${myUid}_$targetUid'),
      {
        'fromUid': myUid,
        'toUid': targetUid,
        'action': 'superlike',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    // Registrar like con flag isSuperLike (reutiliza la misma colección y reglas)
    batch.set(
      _db.collection('discover_likes').doc('${myUid}_$targetUid'),
      {
        'fromUid': myUid,
        'toUid': targetUid,
        'isSuperLike': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    final theirLike = await _db
        .collection('discover_likes')
        .doc('${targetUid}_$myUid')
        .get();

    if (theirLike.exists) {
      await _createMatch(myUid, targetUid);
      return true;
    }
    return false;
  }

  // ── Onboarding ────────────────────────────────────────────────────────────

  static Future<bool> isOnboardingDone() async {
    final doc = await _db.collection('users').doc(_myUid).get();
    return (doc.data()?['discoverOnboardingDone'] as bool?) ?? false;
  }

  static Future<void> markOnboardingDone() async {
    await _db.collection('users').doc(_myUid).update({
      'discoverOnboardingDone': true,
    });
  }

  // ── Helper: extraer país de origen ────────────────────────────────────────

  static String? _extractPais(Map<String, dynamic> data) {
    final direct = data['paisOrigen'] as String?;
    if (direct != null && direct.isNotEmpty) return direct.toLowerCase();
    final ciudades = data['ciudadesVividas'] as List?;
    if (ciudades != null && ciudades.isNotEmpty) {
      final pais = (ciudades.first as Map?)?['pais'] as String?;
      return pais?.toLowerCase();
    }
    return null;
  }
}

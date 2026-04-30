import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'feed_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ExploreService — recomendación de contenido basada en comportamiento
//
// Algoritmo de scoring (hybrid content-based + engagement):
//   score(post) =
//     0.35 * recency(createdAt)          ← posts recientes tienen más peso
//     0.35 * engagement(likes, comments) ← contenido popular se prioriza
//     0.30 * affinity(countryFlag)       ← preferencia por país del usuario
//
// Las interacciones se almacenan en Firestore para aprender preferencias.
// Colección: explore_interactions/{userId}_{contentId}_{type}
// ─────────────────────────────────────────────────────────────────────────────

class ExploreService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _myUid => _auth.currentUser?.uid ?? '';

  // ── Registrar interacción ─────────────────────────────────────────────────

  static Future<void> recordInteraction({
    required String contentId,
    required String type, // 'view' | 'like' | 'save' | 'share'
    String? countryFlag,
  }) async {
    if (_myUid.isEmpty) return;
    try {
      final docId = '${_myUid}_${contentId}_$type';
      await _db.collection('explore_interactions').doc(docId).set({
        'userId': _myUid,
        'contentId': contentId,
        'type': type,
        'weight': _weight(type),
        'countryFlag': countryFlag,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static double _weight(String type) => switch (type) {
        'like' => 1.0,
        'save' => 1.5,
        'share' => 1.2,
        'view' => 0.1,
        _ => 0.1,
      };

  // ── Feed personalizado ────────────────────────────────────────────────────
  //
  // 1. Carga historial de interacciones del usuario → mapa de afinidad por país
  // 2. Trae hasta `fetchLimit` posts públicos recientes
  // 3. Puntúa cada post con la fórmula híbrida
  // 4. Devuelve los `limit` más relevantes

  static Future<List<PostModel>> getPersonalizedFeed({
    int limit = 30,
    int fetchLimit = 80,
  }) async {
    final countryAffinity = await _buildCountryAffinity();
    final posts = await _fetchPublicPosts(fetchLimit);
    _scorePosts(posts, countryAffinity);
    posts.sort(
      (a, b) => ((b['_score'] as double?) ?? 0)
          .compareTo((a['_score'] as double?) ?? 0),
    );
    return posts.take(limit).map(_mapToPostModel).toList();
  }

  // Feed reciente sin personalización (tab "Recientes")
  static Future<List<PostModel>> getRecentFeed({int limit = 30}) async {
    final posts = await _fetchPublicPosts(limit);
    return posts.map(_mapToPostModel).toList();
  }

  // ── Búsqueda ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    try {
      final snap = await _db
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: q)
          .where('username', isLessThanOrEqualTo: '$q')
          .limit(10)
          .get();
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['uid'] = doc.id;
        data['resultType'] = 'user';
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<PostModel>> searchPosts(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    try {
      final snap = await _db
          .collection('posts')
          .where('visibility', isEqualTo: 'public')
          .where('caption', isGreaterThanOrEqualTo: q)
          .where('caption', isLessThanOrEqualTo: '$q')
          .limit(15)
          .get();
      return snap.docs.map(PostModel.fromDoc).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Usuarios sugeridos ────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSuggestedUsers({
    int limit = 12,
  }) async {
    try {
      final snap = await _db
          .collection('users')
          .where('username', isNull: false)
          .limit(limit)
          .get();
      return snap.docs
          .where((doc) => doc.id != _myUid)
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['uid'] = doc.id;
            return data;
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  static Future<Map<String, double>> _buildCountryAffinity() async {
    final affinity = <String, double>{};
    if (_myUid.isEmpty) return affinity;
    try {
      final snap = await _db
          .collection('explore_interactions')
          .where('userId', isEqualTo: _myUid)
          .orderBy('createdAt', descending: true)
          .limit(150)
          .get();
      for (final doc in snap.docs) {
        final flag = doc.data()['countryFlag'] as String?;
        final w = (doc.data()['weight'] as num?)?.toDouble() ?? 0.1;
        if (flag != null && flag.isNotEmpty) {
          affinity[flag] = (affinity[flag] ?? 0) + w;
        }
      }
    } catch (_) {}
    return affinity;
  }

  static Future<List<Map<String, dynamic>>> _fetchPublicPosts(
    int limit,
  ) async {
    try {
      final snap = await _db
          .collection('posts')
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['_docId'] = doc.id;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static void _scorePosts(
    List<Map<String, dynamic>> posts,
    Map<String, double> countryAffinity,
  ) {
    final now = DateTime.now();
    final maxAffinity =
        countryAffinity.values.fold(0.0, (a, b) => math.max(a, b));

    for (final post in posts) {
      // Recencia: decaimiento exponencial; half-life ≈ 6 días
      final ts = (post['createdAt'] as Timestamp?)?.toDate() ?? now;
      final hoursOld = now.difference(ts).inHours.clamp(0, 720).toDouble();
      final recencyScore = math.exp(-0.005 * hoursOld);

      // Engagement: normalizado a [0, 1]
      final likes = (post['likesCount'] as int? ?? 0).toDouble();
      final comments = (post['commentsCount'] as int? ?? 0).toDouble();
      final engagementScore = math.min(1.0, (likes + comments * 2) / 100.0);

      // Afinidad por país
      final flag = post['countryFlag'] as String?;
      final raw = flag != null ? (countryAffinity[flag] ?? 0) : 0.0;
      final affinityScore =
          maxAffinity > 0 ? (raw / maxAffinity).clamp(0.0, 1.0) : 0.2;

      post['_score'] = recencyScore * 0.35 +
          engagementScore * 0.35 +
          affinityScore * 0.30;
    }
  }

  static PostModel _mapToPostModel(Map<String, dynamic> data) {
    return PostModel(
      docId: data['_docId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      username: data['username'] as String? ?? '',
      images: List<String>.from(data['images'] as List? ?? []),
      caption: data['caption'] as String? ?? '',
      city: data['city'] as String?,
      countryFlag: data['countryFlag'] as String?,
      bio: data['bio'] as String?,
      likesCount: data['likesCount'] as int? ?? 0,
      commentsCount: data['commentsCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      type: data['type'] as String? ?? 'post',
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      visibility: data['visibility'] as String? ?? 'public',
    );
  }
}

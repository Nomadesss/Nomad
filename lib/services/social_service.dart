import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SocialService — operaciones de Firestore para el grafo social de Nomad
//
// Colecciones que maneja:
//   follows        → {followerId}_{followingId}
//   post_likes     → {postId}_{userId}
//   posts          → likesCount, commentsCount (contadores denormalizados)
//   comments       → subcolección de posts
//   notifications  → colección raíz, ordenada por createdAt desc
// ─────────────────────────────────────────────────────────────────────────────

class SocialService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _me => _auth.currentUser!.uid;

  // ── FOLLOWS ────────────────────────────────────────────────────────────────

  /// Sigue a un usuario. Crea el documento de follow y la notificación.
  static Future<void> follow(String targetUserId) async {
    final followId = '${_me}_$targetUserId';
    final batch = _db.batch();

    // Documento de follow
    batch.set(_db.collection('follows').doc(followId), {
      'followerId':  _me,
      'followingId': targetUserId,
      'createdAt':   FieldValue.serverTimestamp(),
    });

    // Contadores en ambos perfiles
    batch.update(_db.collection('users').doc(_me), {
      'followingCount': FieldValue.increment(1),
    });
    batch.update(_db.collection('users').doc(targetUserId), {
      'followersCount': FieldValue.increment(1),
    });

    // Notificación al usuario seguido
    batch.set(_db.collection('notifications').doc(), {
      'toUserId':   targetUserId,
      'fromUserId': _me,
      'type':       'follow',
      'refId':      _me,
      'read':       false,
      'createdAt':  FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Deja de seguir a un usuario. Elimina el documento y ajusta contadores.
  static Future<void> unfollow(String targetUserId) async {
    final followId = '${_me}_$targetUserId';
    final batch = _db.batch();

    batch.delete(_db.collection('follows').doc(followId));

    batch.update(_db.collection('users').doc(_me), {
      'followingCount': FieldValue.increment(-1),
    });
    batch.update(_db.collection('users').doc(targetUserId), {
      'followersCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  /// Stream que emite true/false según si el usuario actual sigue a [targetUserId].
  static Stream<bool> followingStream(String targetUserId) {
    final followId = '${_me}_$targetUserId';
    return _db
        .collection('follows')
        .doc(followId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Consulta puntual: ¿sigo a este usuario ahora mismo?
  static Future<bool> isFollowing(String targetUserId) async {
    final snap = await _db
        .collection('follows')
        .doc('${_me}_$targetUserId')
        .get();
    return snap.exists;
  }

  // ── LIKES ──────────────────────────────────────────────────────────────────

  /// Da like a un post. Usa transacción para evitar race conditions en el contador.
  static Future<void> likePost(String postId, String postAuthorId) async {
    final likeId  = '${postId}_$_me';
    final likeRef = _db.collection('post_likes').doc(likeId);
    final postRef = _db.collection('posts').doc(postId);

    await _db.runTransaction((txn) async {
      final likeSnap = await txn.get(likeRef);
      if (likeSnap.exists) return; // ya dio like, no hacer nada

      txn.set(likeRef, {
        'postId':    postId,
        'userId':    _me,
        'createdAt': FieldValue.serverTimestamp(),
      });

      txn.update(postRef, {
        'likesCount': FieldValue.increment(1),
      });
    });

    // Notificación fuera de la transacción (no es crítico si falla)
    if (postAuthorId != _me) {
      await _db.collection('notifications').add({
        'toUserId':   postAuthorId,
        'fromUserId': _me,
        'type':       'like',
        'refId':      postId,
        'read':       false,
        'createdAt':  FieldValue.serverTimestamp(),
      });
    }
  }

  /// Quita el like de un post.
  static Future<void> unlikePost(String postId) async {
    final likeId  = '${postId}_$_me';
    final likeRef = _db.collection('post_likes').doc(likeId);
    final postRef = _db.collection('posts').doc(postId);

    await _db.runTransaction((txn) async {
      final likeSnap = await txn.get(likeRef);
      if (!likeSnap.exists) return;

      txn.delete(likeRef);
      txn.update(postRef, {
        'likesCount': FieldValue.increment(-1),
      });
    });
  }

  /// Stream: emite true/false según si el usuario actual likeó el post.
  static Stream<bool> likedStream(String postId) {
    final likeId = '${postId}_$_me';
    return _db
        .collection('post_likes')
        .doc(likeId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Stream del contador de likes de un post (se actualiza en tiempo real).
  static Stream<int> likesCountStream(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map((snap) => (snap.data()?['likesCount'] as int?) ?? 0);
  }

  // ── COMENTARIOS ────────────────────────────────────────────────────────────

  /// Agrega un comentario a un post. Incrementa commentsCount en el post.
  static Future<void> addComment({
    required String postId,
    required String postAuthorId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    final batch = _db.batch();

    // Subcolección comments dentro del post
    final commentRef = _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc();

    batch.set(commentRef, {
      'postId':    postId,
      'authorId':  _me,
      'text':      text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Incrementar contador en el post
    batch.update(_db.collection('posts').doc(postId), {
      'commentsCount': FieldValue.increment(1),
    });

    await batch.commit();

    // Notificación (fuera del batch, no bloquea)
    if (postAuthorId != _me) {
      await _db.collection('notifications').add({
        'toUserId':   postAuthorId,
        'fromUserId': _me,
        'type':       'comment',
        'refId':      postId,
        'read':       false,
        'createdAt':  FieldValue.serverTimestamp(),
      });
    }
  }

  /// Stream de comentarios de un post, ordenados por fecha.
  static Stream<List<Map<String, dynamic>>> commentsStream(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  // ── NOTIFICACIONES ─────────────────────────────────────────────────────────

  /// Stream de notificaciones no leídas del usuario actual.
  static Stream<List<Map<String, dynamic>>> notificationsStream() {
    return _db
        .collection('notifications')
        .where('toUserId', isEqualTo: _me)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Stream del conteo de notificaciones no leídas (para el badge).
  static Stream<int> unreadNotificationsCount() {
    return _db
        .collection('notifications')
        .where('toUserId', isEqualTo: _me)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Marca una notificación como leída.
  static Future<void> markNotificationRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({
      'read': true,
    });
  }

  /// Marca todas las notificaciones del usuario como leídas.
  static Future<void> markAllNotificationsRead() async {
    final snap = await _db
        .collection('notifications')
        .where('toUserId', isEqualTo: _me)
        .where('read', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
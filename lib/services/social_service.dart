import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SocialService — operaciones de Firestore para el grafo social de Nomad
//
// Colecciones que maneja:
//
//   GRAFO SOCIAL (sin cambios respecto al original):
//     follows        → {followerId}_{followingId}
//     post_likes     → {postId}_{userId}
//     posts          → likesCount, commentsCount (contadores denormalizados)
//     comments       → subcolección de posts/{postId}/comments
//     notifications  → colección raíz, ordenada por createdAt desc
//
//   GRUPOS (nuevo — Community Hub):
//     groups              → documento por grupo
//     group_members       → {groupId}_{userId}
//     group_messages      → subcolección de groups/{groupId}/messages
//     events              → colección raíz, referenciada por groupId
//
// CORRECCIÓN respecto al original:
//   _me usaba currentUser!.uid con ! desnudo.
//   Reemplazado por _requireMe() que lanza StateError con mensaje claro
//   en lugar de un NullPointerException críptico.
// ─────────────────────────────────────────────────────────────────────────────

// ══════════════════════════════════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════════════════════════════════

// ── GroupModel ────────────────────────────────────────────────────────────────

enum GroupCategory {
  sport,
  art,
  food,
  language,
  talks,
  other;

  static GroupCategory fromString(String? value) {
    switch (value) {
      case 'sport':    return GroupCategory.sport;
      case 'art':      return GroupCategory.art;
      case 'food':     return GroupCategory.food;
      case 'language': return GroupCategory.language;
      case 'talks':    return GroupCategory.talks;
      default:         return GroupCategory.other;
    }
  }

  String toFirestoreString() => name;

  String get label {
    switch (this) {
      case GroupCategory.sport:    return 'Deporte';
      case GroupCategory.art:      return 'Arte y cultura';
      case GroupCategory.food:     return 'Gastronomía';
      case GroupCategory.language: return 'Idiomas';
      case GroupCategory.talks:    return 'Charlas';
      case GroupCategory.other:    return 'Otro';
    }
  }

  String get emoji {
    switch (this) {
      case GroupCategory.sport:    return '⚽';
      case GroupCategory.art:      return '🎨';
      case GroupCategory.food:     return '🍳';
      case GroupCategory.language: return '🗣️';
      case GroupCategory.talks:    return '💬';
      case GroupCategory.other:    return '🤝';
    }
  }
}

class GroupModel {
  final String        docId;
  final String        name;
  final String        description;
  final GroupCategory category;
  final String        country;
  final String        city;
  final String        coverEmoji;
  final bool          isPrivate;
  final int?          maxMembers;
  final String        createdBy;
  final int           memberCount;
  final DateTime?     nextEventAt;
  final DateTime?     createdAt;

  const GroupModel({
    required this.docId,
    required this.name,
    required this.description,
    required this.category,
    required this.country,
    required this.city,
    required this.createdBy,
    this.coverEmoji  = '🤝',
    this.isPrivate   = false,
    this.maxMembers,
    this.memberCount = 0,
    this.nextEventAt,
    this.createdAt,
  });

  factory GroupModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return GroupModel(
      docId:       doc.id,
      name:        d['name']        as String? ?? '',
      description: d['description'] as String? ?? '',
      category:    GroupCategory.fromString(d['category'] as String?),
      country:     d['country']     as String? ?? '',
      city:        d['city']        as String? ?? '',
      coverEmoji:  d['coverEmoji']  as String? ?? '🤝',
      isPrivate:   d['isPrivate']   as bool?   ?? false,
      maxMembers:  (d['maxMembers'] as num?)?.toInt(),
      createdBy:   d['createdBy']   as String? ?? '',
      memberCount: (d['memberCount'] as num?)?.toInt() ?? 0,
      nextEventAt: _ts(d['nextEventAt']),
      createdAt:   _ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':        name,
    'description': description,
    'category':    category.toFirestoreString(),
    'country':     country,
    'city':        city.trim().toLowerCase(),
    'coverEmoji':  coverEmoji,
    'isPrivate':   isPrivate,
    'maxMembers':  maxMembers,
    'createdBy':   createdBy,
    'memberCount': memberCount,
    'nextEventAt': nextEventAt != null ? Timestamp.fromDate(nextEventAt!) : null,
    'createdAt':   FieldValue.serverTimestamp(),
    'updatedAt':   FieldValue.serverTimestamp(),
  };

  /// True si el grupo tiene cupo disponible.
  bool get hasCapacity =>
      maxMembers == null || memberCount < maxMembers!;
}

// ── GroupMemberModel ──────────────────────────────────────────────────────────

class GroupMemberModel {
  final String    docId;
  final String    groupId;
  final String    userId;
  final bool      isAdmin;
  final DateTime? joinedAt;

  const GroupMemberModel({
    required this.docId,
    required this.groupId,
    required this.userId,
    this.isAdmin  = false,
    this.joinedAt,
  });

  factory GroupMemberModel.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupMemberModel(
      docId:    doc.id,
      groupId:  d['groupId']  as String? ?? '',
      userId:   d['userId']   as String? ?? '',
      isAdmin:  d['isAdmin']  as bool?   ?? false,
      joinedAt: _ts(d['joinedAt']),
    );
  }
}

// ── GroupMessageModel ─────────────────────────────────────────────────────────

class GroupMessageModel {
  final String    docId;
  final String    groupId;
  final String    authorId;
  final String    text;
  final DateTime? createdAt;

  const GroupMessageModel({
    required this.docId,
    required this.groupId,
    required this.authorId,
    required this.text,
    this.createdAt,
  });

  factory GroupMessageModel.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupMessageModel(
      docId:     doc.id,
      groupId:   d['groupId']  as String? ?? '',
      authorId:  d['authorId'] as String? ?? '',
      text:      d['text']     as String? ?? '',
      createdAt: _ts(d['createdAt']),
    );
  }

  /// True si el mensaje pertenece al usuario actual.
  bool isMine(String myUid) => authorId == myUid;
}

// ── EventModel (grupos) ───────────────────────────────────────────────────────

class GroupEventModel {
  final String    docId;
  final String    groupId;
  final String    title;
  final String?   description;
  final String    city;
  final String?   place;
  final DateTime? eventDate;
  final int       attendeesCount;
  final DateTime? createdAt;

  const GroupEventModel({
    required this.docId,
    required this.groupId,
    required this.title,
    required this.city,
    this.description,
    this.place,
    this.eventDate,
    this.attendeesCount = 0,
    this.createdAt,
  });

  factory GroupEventModel.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupEventModel(
      docId:          doc.id,
      groupId:        d['groupId']      as String? ?? '',
      title:          d['title']        as String? ?? '',
      description:    d['description']  as String?,
      city:           d['city']         as String? ?? '',
      place:          d['place']        as String?,
      eventDate:      _ts(d['eventDate']),
      attendeesCount: (d['attendeesCount'] as num?)?.toInt() ?? 0,
      createdAt:      _ts(d['createdAt']),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SocialService
// ══════════════════════════════════════════════════════════════════════════════

class SocialService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Guard de sesión ────────────────────────────────────────────────────────
  //
  // CORRECCIÓN: el original tenía _me => _auth.currentUser!.uid
  // El ! lanzaba NullPointerException sin contexto si no había sesión.
  // _requireMe() lanza StateError con mensaje legible en los logs.

  static String _requireMe() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError(
        'SocialService: no hay sesión activa. '
        'Verificá que el usuario esté logueado antes de llamar este método.',
      );
    }
    return uid;
  }

  // Atajo interno — mismo resultado, nombre corto para uso frecuente.
  static String get _me => _requireMe();

  // ══════════════════════════════════════════════════════════════════════════
  // FOLLOWS — sin cambios de lógica, solo _me protegido
  // ══════════════════════════════════════════════════════════════════════════

  /// Sigue a un usuario. Crea el documento de follow y la notificación.
  static Future<void> follow(String targetUserId) async {
    final me       = _requireMe();
    final followId = '${me}_$targetUserId';
    final batch    = _db.batch();

    batch.set(_db.collection('follows').doc(followId), {
      'followerId':  me,
      'followingId': targetUserId,
      'createdAt':   FieldValue.serverTimestamp(),
    });

    batch.update(_db.collection('users').doc(me), {
      'followingCount': FieldValue.increment(1),
    });
    batch.update(_db.collection('users').doc(targetUserId), {
      'followersCount': FieldValue.increment(1),
    });

    batch.set(_db.collection('notifications').doc(), {
      'toUserId':   targetUserId,
      'fromUserId': me,
      'type':       'follow',
      'refId':      me,
      'read':       false,
      'createdAt':  FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Deja de seguir a un usuario.
  static Future<void> unfollow(String targetUserId) async {
    final me       = _requireMe();
    final followId = '${me}_$targetUserId';
    final batch    = _db.batch();

    batch.delete(_db.collection('follows').doc(followId));

    batch.update(_db.collection('users').doc(me), {
      'followingCount': FieldValue.increment(-1),
    });
    batch.update(_db.collection('users').doc(targetUserId), {
      'followersCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  /// Stream: ¿el usuario actual sigue a [targetUserId]?
  static Stream<bool> followingStream(String targetUserId) {
    final me       = _requireMe();
    final followId = '${me}_$targetUserId';
    return _db
        .collection('follows')
        .doc(followId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Consulta puntual: ¿sigo a este usuario?
  static Future<bool> isFollowing(String targetUserId) async {
    final me = _requireMe();
    final snap = await _db
        .collection('follows')
        .doc('${me}_$targetUserId')
        .get();
    return snap.exists;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIKES — sin cambios de lógica
  // ══════════════════════════════════════════════════════════════════════════

  /// Da like a un post. Transacción para evitar race conditions.
  static Future<void> likePost(String postId, String postAuthorId) async {
    final me      = _requireMe();
    final likeId  = '${postId}_$me';
    final likeRef = _db.collection('post_likes').doc(likeId);
    final postRef = _db.collection('posts').doc(postId);

    await _db.runTransaction((txn) async {
      final likeSnap = await txn.get(likeRef);
      if (likeSnap.exists) return;

      txn.set(likeRef, {
        'postId':    postId,
        'userId':    me,
        'createdAt': FieldValue.serverTimestamp(),
      });
      txn.update(postRef, {'likesCount': FieldValue.increment(1)});
    });

    if (postAuthorId != me) {
      await _db.collection('notifications').add({
        'toUserId':   postAuthorId,
        'fromUserId': me,
        'type':       'like',
        'refId':      postId,
        'read':       false,
        'createdAt':  FieldValue.serverTimestamp(),
      });
    }
  }

  /// Quita el like de un post.
  static Future<void> unlikePost(String postId) async {
    final me      = _requireMe();
    final likeId  = '${postId}_$me';
    final likeRef = _db.collection('post_likes').doc(likeId);
    final postRef = _db.collection('posts').doc(postId);

    await _db.runTransaction((txn) async {
      final likeSnap = await txn.get(likeRef);
      if (!likeSnap.exists) return;

      txn.delete(likeRef);
      txn.update(postRef, {'likesCount': FieldValue.increment(-1)});
    });
  }

  /// Stream: ¿el usuario actual likeó este post?
  static Stream<bool> likedStream(String postId) {
    final me     = _requireMe();
    final likeId = '${postId}_$me';
    return _db
        .collection('post_likes')
        .doc(likeId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Stream del contador de likes en tiempo real.
  static Stream<int> likesCountStream(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map((snap) => (snap.data()?['likesCount'] as int?) ?? 0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMENTARIOS — sin cambios de lógica
  // ══════════════════════════════════════════════════════════════════════════

  /// Agrega un comentario. Incrementa commentsCount en el post.
  static Future<void> addComment({
    required String postId,
    required String postAuthorId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    final me         = _requireMe();
    final batch      = _db.batch();
    final commentRef = _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc();

    batch.set(commentRef, {
      'postId':    postId,
      'authorId':  me,
      'text':      text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(_db.collection('posts').doc(postId), {
      'commentsCount': FieldValue.increment(1),
    });

    await batch.commit();

    if (postAuthorId != me) {
      await _db.collection('notifications').add({
        'toUserId':   postAuthorId,
        'fromUserId': me,
        'type':       'comment',
        'refId':      postId,
        'read':       false,
        'createdAt':  FieldValue.serverTimestamp(),
      });
    }
  }

  /// Stream de comentarios de un post, ordenados por fecha ascendente.
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

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICACIONES — sin cambios de lógica
  // ══════════════════════════════════════════════════════════════════════════

  /// Stream de notificaciones del usuario actual.
  static Stream<List<Map<String, dynamic>>> notificationsStream() {
    final me = _requireMe();
    return _db
        .collection('notifications')
        .where('toUserId', isEqualTo: me)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Stream del conteo de notificaciones no leídas (para el badge del header).
  static Stream<int> unreadNotificationsCount() {
    final me = _requireMe();
    return _db
        .collection('notifications')
        .where('toUserId', isEqualTo: me)
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
    final me   = _requireMe();
    final snap = await _db
        .collection('notifications')
        .where('toUserId', isEqualTo: me)
        .where('read', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GRUPOS — nuevo, Community Hub
  //
  // Índices requeridos en Firestore:
  //   groups        → city (ASC) + createdAt (DESC)
  //   groups        → category (ASC) + city (ASC)
  //   group_members → groupId (ASC) + joinedAt (ASC)
  //   group_members → userId (ASC) + joinedAt (ASC)
  //   events        → groupId (ASC) + eventDate (ASC)
  // ══════════════════════════════════════════════════════════════════════════

  // ── Crear grupo ────────────────────────────────────────────────────────────

  /// Crea un grupo y automáticamente agrega al creador como admin.
  ///
  /// Ejemplo:
  ///   final result = await SocialService.createGroup(
  ///     name: 'Fútbol los domingos',
  ///     description: 'Partidos amistosos en el Retiro cada domingo',
  ///     category: GroupCategory.sport,
  ///     country: 'España',
  ///     city: 'madrid',
  ///     coverEmoji: '⚽',
  ///   );
  static Future<({String? groupId, String? error})> createGroup({
    required String        name,
    required String        description,
    required GroupCategory category,
    required String        country,
    required String        city,
    String  coverEmoji = '🤝',
    bool    isPrivate  = false,
    int?    maxMembers,
  }) async {
    try {
      final me = _requireMe();

      // 1. Crear el documento del grupo.
      final groupRef = _db.collection('groups').doc();
      final group    = GroupModel(
        docId:      groupRef.id,
        name:       name.trim(),
        description: description.trim(),
        category:   category,
        country:    country,
        city:       city.trim().toLowerCase(),
        coverEmoji: coverEmoji,
        isPrivate:  isPrivate,
        maxMembers: maxMembers,
        createdBy:  me,
        memberCount: 1, // el creador ya es miembro
      );

      final batch = _db.batch();

      batch.set(groupRef, group.toMap());

      // 2. Agregar al creador como miembro admin.
      final memberRef = _db
          .collection('group_members')
          .doc('${groupRef.id}_$me');

      batch.set(memberRef, {
        'groupId':  groupRef.id,
        'userId':   me,
        'isAdmin':  true,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return (groupId: groupRef.id, error: null);
    } catch (e) {
      return (groupId: null, error: 'No se pudo crear el grupo. Intentá de nuevo.');
    }
  }

  // ── Leer grupos ────────────────────────────────────────────────────────────

  /// Stream de grupos filtrados por ciudad y opcionalmente por categoría.
  ///
  /// Índice requerido: city (ASC) + createdAt (DESC)
  static Stream<List<GroupModel>> streamGroups({
    required String city,
    GroupCategory?  category,
    int             limit = 20,
  }) {
    var query = _db
        .collection('groups')
        .where('city', isEqualTo: city.trim().toLowerCase())
        .orderBy('createdAt', descending: true)
        .limit(limit);

    // Firestore no soporta múltiples where en campos distintos sin índice
    // compuesto. Si se filtra por categoría, se necesita el índice:
    //   category (ASC) + city (ASC)
    if (category != null) {
      query = _db
          .collection('groups')
          .where('city',     isEqualTo: city.trim().toLowerCase())
          .where('category', isEqualTo: category.toFirestoreString())
          .orderBy('createdAt', descending: true)
          .limit(limit);
    }

    return query.snapshots().map(
      (snap) => snap.docs.map(GroupModel.fromDoc).toList(),
    );
  }

  /// Stream en tiempo real del detalle de un grupo.
  static Stream<GroupModel?> streamGroupDetail(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map((snap) => snap.exists ? GroupModel.fromDoc(snap) : null);
  }

  /// Consulta puntual de un grupo.
  static Future<GroupModel?> getGroup(String groupId) async {
    final snap = await _db.collection('groups').doc(groupId).get();
    if (!snap.exists) return null;
    return GroupModel.fromDoc(snap);
  }

  /// Stream de los grupos a los que pertenece el usuario actual.
  static Stream<List<GroupModel>> streamMyGroups() {
    final me = _requireMe();

    // Primero obtenemos los IDs de los grupos del usuario,
    // luego los resolvemos. Como Firestore no soporta joins,
    // usamos dos queries encadenadas.
    return _db
        .collection('group_members')
        .where('userId', isEqualTo: me)
        .snapshots()
        .asyncMap((membersSnap) async {
          final groupIds = membersSnap.docs
              .map((doc) => doc.data()['groupId'] as String? ?? '')
              .where((id) => id.isNotEmpty)
              .toList();

          if (groupIds.isEmpty) return <GroupModel>[];

          // Firestore limita whereIn a 30.
          final ids  = groupIds.take(30).toList();
          final snap = await _db
              .collection('groups')
              .where(FieldPath.documentId, whereIn: ids)
              .get();

          return snap.docs.map(GroupModel.fromDoc).toList();
        });
  }

  // ── Unirse / abandonar ─────────────────────────────────────────────────────

  /// Únete a un grupo.
  ///
  /// Usa transacción para verificar el cupo antes de agregar al miembro
  /// y para incrementar memberCount de forma atómica.
  static Future<String?> joinGroup(String groupId) async {
    try {
      final me        = _requireMe();
      final groupRef  = _db.collection('groups').doc(groupId);
      final memberRef = _db
          .collection('group_members')
          .doc('${groupId}_$me');

      await _db.runTransaction((txn) async {
        final groupSnap  = await txn.get(groupRef);
        final memberSnap = await txn.get(memberRef);

        if (!groupSnap.exists) {
          throw Exception('El grupo no existe.');
        }
        if (memberSnap.exists) {
          // Ya es miembro — no hacer nada, no es un error.
          return;
        }

        final group = GroupModel.fromDoc(groupSnap);

        // Verificar cupo si el grupo tiene límite.
        if (!group.hasCapacity) {
          throw Exception('El grupo está lleno.');
        }

        txn.set(memberRef, {
          'groupId':  groupId,
          'userId':   me,
          'isAdmin':  false,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        txn.update(groupRef, {
          'memberCount': FieldValue.increment(1),
          'updatedAt':   FieldValue.serverTimestamp(),
        });
      });

      // Notificar al creador del grupo (fuera de la transacción).
      final group = await getGroup(groupId);
      if (group != null && group.createdBy != me) {
        await _db.collection('notifications').add({
          'toUserId':   group.createdBy,
          'fromUserId': me,
          'type':       'group_join',
          'refId':      groupId,
          'read':       false,
          'createdAt':  FieldValue.serverTimestamp(),
        });
      }

      return null; // éxito
    } on Exception catch (e) {
      // Mensajes de error tipados (cupo lleno, no existe).
      return e.toString().replaceAll('Exception: ', '');
    } catch (e) {
      return 'No se pudo unir al grupo. Intentá de nuevo.';
    }
  }

  /// Abandonar un grupo.
  static Future<String?> leaveGroup(String groupId) async {
    try {
      final me        = _requireMe();
      final groupRef  = _db.collection('groups').doc(groupId);
      final memberRef = _db
          .collection('group_members')
          .doc('${groupId}_$me');

      final batch = _db.batch();

      batch.delete(memberRef);
      batch.update(groupRef, {
        'memberCount': FieldValue.increment(-1),
        'updatedAt':   FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return null;
    } catch (e) {
      return 'No se pudo abandonar el grupo. Intentá de nuevo.';
    }
  }

  /// Stream: ¿el usuario actual es miembro de este grupo?
  static Stream<bool> isMemberStream(String groupId) {
    final me = _requireMe();
    return _db
        .collection('group_members')
        .doc('${groupId}_$me')
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Stream de los miembros de un grupo.
  ///
  /// Índice requerido: groupId (ASC) + joinedAt (ASC)
  static Stream<List<GroupMemberModel>> streamGroupMembers(
    String groupId, {
    int limit = 50,
  }) {
    return _db
        .collection('group_members')
        .where('groupId', isEqualTo: groupId)
        .orderBy('joinedAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(GroupMemberModel.fromDoc).toList());
  }

  // ── Chat grupal ────────────────────────────────────────────────────────────

  /// Stream de mensajes del chat grupal, ordenados por fecha ascendente.
  ///
  /// Los mensajes se guardan como subcolección de groups/{groupId}/messages
  /// para mantenerlos agrupados y facilitar las reglas de seguridad de Firestore
  /// (solo miembros del grupo pueden leer/escribir).
  static Stream<List<GroupMessageModel>> streamGroupChat(
    String groupId, {
    int limit = 50,
  }) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(limit) // últimos N mensajes — más natural para un chat
        .snapshots()
        .map((snap) => snap.docs.map(GroupMessageModel.fromDoc).toList());
  }

  /// Envía un mensaje al chat grupal.
  ///
  /// Solo actualiza lastMessageAt en el grupo para poder ordenar
  /// la lista de grupos por actividad reciente.
  static Future<String?> sendGroupMessage({
    required String groupId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return null;

    try {
      final me    = _requireMe();
      final batch = _db.batch();

      // Mensaje en la subcolección.
      final msgRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc();

      batch.set(msgRef, {
        'groupId':   groupId,
        'authorId':  me,
        'text':      text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Actualizar timestamp de último mensaje en el grupo
      // para poder ordenar la lista de grupos por actividad.
      batch.update(_db.collection('groups').doc(groupId), {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt':     FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return null;
    } catch (e) {
      return 'No se pudo enviar el mensaje. Intentá de nuevo.';
    }
  }

  // ── Eventos de grupo ───────────────────────────────────────────────────────

  /// Crea un evento asociado a un grupo.
  ///
  /// Los eventos se guardan en la colección raíz 'events' con una referencia
  /// al groupId para que FeedService pueda listarlos por ciudad sin depender
  /// de la pertenencia al grupo.
  static Future<String?> createEvent({
    required String   groupId,
    required String   title,
    required String   city,
    String?           description,
    String?           place,
    DateTime?         eventDate,
  }) async {
    try {
      final me = _requireMe();

      final eventRef = _db.collection('events').doc();
      await eventRef.set({
        'groupId':       groupId,
        'createdBy':     me,
        'title':         title.trim(),
        'description':   description?.trim(),
        'city':          city.trim().toLowerCase(),
        'place':         place?.trim(),
        'eventDate':     eventDate != null
            ? Timestamp.fromDate(eventDate)
            : null,
        'attendeesCount': 0,
        'createdAt':     FieldValue.serverTimestamp(),
      });

      // Actualizar nextEventAt en el grupo si es el evento más próximo.
      if (eventDate != null) {
        await _db.collection('groups').doc(groupId).update({
          'nextEventAt': Timestamp.fromDate(eventDate),
          'updatedAt':   FieldValue.serverTimestamp(),
        });
      }

      return null;
    } catch (e) {
      return 'No se pudo crear el evento. Intentá de nuevo.';
    }
  }

  /// Stream de eventos de un grupo, ordenados por fecha ascendente.
  ///
  /// Índice requerido: groupId (ASC) + eventDate (ASC)
  static Stream<List<GroupEventModel>> streamGroupEvents(
    String groupId, {
    int limit = 10,
  }) {
    return _db
        .collection('events')
        .where('groupId', isEqualTo: groupId)
        .orderBy('eventDate', descending: false)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(GroupEventModel.fromDoc).toList());
  }

  /// Confirmar asistencia a un evento.
  static Future<String?> attendEvent(String eventId) async {
    try {
      final me          = _requireMe();
      final eventRef    = _db.collection('events').doc(eventId);
      final attendeeRef = _db
          .collection('event_attendees')
          .doc('${eventId}_$me');

      await _db.runTransaction((txn) async {
        final attendeeSnap = await txn.get(attendeeRef);
        if (attendeeSnap.exists) return; // ya confirmó

        txn.set(attendeeRef, {
          'eventId':   eventId,
          'userId':    me,
          'createdAt': FieldValue.serverTimestamp(),
        });
        txn.update(eventRef, {
          'attendeesCount': FieldValue.increment(1),
        });
      });

      return null;
    } catch (e) {
      return 'No se pudo confirmar la asistencia.';
    }
  }

  /// Cancelar asistencia a un evento.
  static Future<String?> cancelAttendance(String eventId) async {
    try {
      final me          = _requireMe();
      final eventRef    = _db.collection('events').doc(eventId);
      final attendeeRef = _db
          .collection('event_attendees')
          .doc('${eventId}_$me');

      await _db.runTransaction((txn) async {
        final attendeeSnap = await txn.get(attendeeRef);
        if (!attendeeSnap.exists) return;

        txn.delete(attendeeRef);
        txn.update(eventRef, {
          'attendeesCount': FieldValue.increment(-1),
        });
      });

      return null;
    } catch (e) {
      return 'No se pudo cancelar la asistencia.';
    }
  }

  /// Stream: ¿el usuario actual confirmó asistencia a este evento?
  static Stream<bool> isAttendingStream(String eventId) {
    final me = _requireMe();
    return _db
        .collection('event_attendees')
        .doc('${eventId}_$me')
        .snapshots()
        .map((snap) => snap.exists);
  }
}

// ── Helper privado global: Timestamp → DateTime ───────────────────────────────

DateTime? _ts(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
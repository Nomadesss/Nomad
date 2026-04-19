import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SocialService — operaciones de Firestore para el grafo social de Nomad
// ─────────────────────────────────────────────────────────────────────────────

// ══════════════════════════════════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════════════════════════════════

enum GroupCategory {
  sport,
  art,
  food,
  language,
  talks,
  other;

  static GroupCategory fromString(String? value) {
    switch (value) {
      case 'sport':
        return GroupCategory.sport;
      case 'art':
        return GroupCategory.art;
      case 'food':
        return GroupCategory.food;
      case 'language':
        return GroupCategory.language;
      case 'talks':
        return GroupCategory.talks;
      default:
        return GroupCategory.other;
    }
  }

  String toFirestoreString() => name;

  String get label {
    switch (this) {
      case GroupCategory.sport:
        return 'Deporte';
      case GroupCategory.art:
        return 'Arte y cultura';
      case GroupCategory.food:
        return 'Gastronomía';
      case GroupCategory.language:
        return 'Idiomas';
      case GroupCategory.talks:
        return 'Charlas';
      case GroupCategory.other:
        return 'Otro';
    }
  }

  String get emoji {
    switch (this) {
      case GroupCategory.sport:
        return '⚽';
      case GroupCategory.art:
        return '🎨';
      case GroupCategory.food:
        return '🍳';
      case GroupCategory.language:
        return '🗣️';
      case GroupCategory.talks:
        return '💬';
      case GroupCategory.other:
        return '🤝';
    }
  }
}

class GroupModel {
  final String docId;
  final String name;
  final String description;
  final GroupCategory category;
  final String country;
  final String city;
  final String coverEmoji;
  final bool isPrivate;
  final int? maxMembers;
  final String createdBy;
  final int memberCount;
  final DateTime? nextEventAt;
  final DateTime? createdAt;

  const GroupModel({
    required this.docId,
    required this.name,
    required this.description,
    required this.category,
    required this.country,
    required this.city,
    required this.createdBy,
    this.coverEmoji = '🤝',
    this.isPrivate = false,
    this.maxMembers,
    this.memberCount = 0,
    this.nextEventAt,
    this.createdAt,
  });

  factory GroupModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return GroupModel(
      docId: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      category: GroupCategory.fromString(d['category'] as String?),
      country: d['country'] as String? ?? '',
      city: d['city'] as String? ?? '',
      coverEmoji: d['coverEmoji'] as String? ?? '🤝',
      isPrivate: d['isPrivate'] as bool? ?? false,
      maxMembers: (d['maxMembers'] as num?)?.toInt(),
      createdBy: d['createdBy'] as String? ?? '',
      memberCount: (d['memberCount'] as num?)?.toInt() ?? 0,
      nextEventAt: _ts(d['nextEventAt']),
      createdAt: _ts(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'category': category.toFirestoreString(),
    'country': country,
    'city': city.trim().toLowerCase(),
    'coverEmoji': coverEmoji,
    'isPrivate': isPrivate,
    'maxMembers': maxMembers,
    'createdBy': createdBy,
    'memberCount': memberCount,
    'nextEventAt': nextEventAt != null
        ? Timestamp.fromDate(nextEventAt!)
        : null,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  bool get hasCapacity => maxMembers == null || memberCount < maxMembers!;
}

// 'member' | 'moderator' | 'admin'
enum GroupRole {
  member,
  moderator,
  admin;

  static GroupRole fromString(String? v) {
    switch (v) {
      case 'admin':     return GroupRole.admin;
      case 'moderator': return GroupRole.moderator;
      default:          return GroupRole.member;
    }
  }

  String get label {
    switch (this) {
      case GroupRole.admin:     return 'Admin';
      case GroupRole.moderator: return 'Moderador';
      case GroupRole.member:    return 'Miembro';
    }
  }

  bool get canManage => this == GroupRole.admin || this == GroupRole.moderator;
}

class GroupMemberModel {
  final String docId;
  final String groupId;
  final String userId;
  final GroupRole role;
  final DateTime? joinedAt;

  bool get isAdmin => role == GroupRole.admin;

  const GroupMemberModel({
    required this.docId,
    required this.groupId,
    required this.userId,
    this.role = GroupRole.member,
    this.joinedAt,
  });

  factory GroupMemberModel.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    // backward compat: if no 'role' field, derive from isAdmin
    final roleStr = d['role'] as String?;
    final legacyAdmin = d['isAdmin'] as bool? ?? false;
    final role = roleStr != null
        ? GroupRole.fromString(roleStr)
        : (legacyAdmin ? GroupRole.admin : GroupRole.member);
    return GroupMemberModel(
      docId:   doc.id,
      groupId: d['groupId'] as String? ?? '',
      userId:  d['userId']  as String? ?? '',
      role:    role,
      joinedAt: _ts(d['joinedAt']),
    );
  }
}

class GroupMessageModel {
  final String docId;
  final String groupId;
  final String authorId;
  final String text;
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
      docId: doc.id,
      groupId: d['groupId'] as String? ?? '',
      authorId: d['authorId'] as String? ?? '',
      text: d['text'] as String? ?? '',
      createdAt: _ts(d['createdAt']),
    );
  }

  bool isMine(String myUid) => authorId == myUid;
}

class GroupEventModel {
  final String docId;
  final String groupId;
  final String title;
  final String? description;
  final String city;
  final String? place;
  final DateTime? eventDate;
  final int attendeesCount;
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
      docId: doc.id,
      groupId: d['groupId'] as String? ?? '',
      title: d['title'] as String? ?? '',
      description: d['description'] as String?,
      city: d['city'] as String? ?? '',
      place: d['place'] as String?,
      eventDate: _ts(d['eventDate']),
      attendeesCount: (d['attendeesCount'] as num?)?.toInt() ?? 0,
      createdAt: _ts(d['createdAt']),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SocialService
// ══════════════════════════════════════════════════════════════════════════════

class SocialService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

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

  static String get _me => _requireMe();

  // ══════════════════════════════════════════════════════════════════════════
  // FOLLOWS
  // ══════════════════════════════════════════════════════════════════════════

  static Future followUser(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final docId = '${currentUserId}_$targetUserId';

    await FirebaseFirestore.instance.collection('follows').doc(docId).set({
      "followerId": currentUserId,

      "followingId": targetUserId,

      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  static Future unfollowUser(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final docId = '${currentUserId}_$targetUserId';

    await FirebaseFirestore.instance.collection('follows').doc(docId).delete();
  }

  //Gestionar dependiendo de si el usuario es publico o privado.
  static Future followOrRequestUser(String targetUserId) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .get();

    final isPrivate = userDoc.data()?["isPrivate"] ?? false;

    if (isPrivate) {
      await FirebaseFirestore.instance.collection('friend_requests').add({
        "from": myUid,

        "to": targetUserId,

        "status": "pending",

        "createdAt": FieldValue.serverTimestamp(),
      });
    } else {
      final docId = '${myUid}_$targetUserId';

      await FirebaseFirestore.instance.collection('follows').doc(docId).set({
        "followerId": myUid,

        "followingId": targetUserId,

        "createdAt": FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> unfollow(String targetUserId) async {
    final me = _requireMe();
    final followId = '${me}_$targetUserId';
    final batch = _db.batch();

    batch.delete(_db.collection('follows').doc(followId));
    batch.update(_db.collection('users').doc(me), {
      'followingCount': FieldValue.increment(-1),
    });
    batch.update(_db.collection('users').doc(targetUserId), {
      'followersCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  static Stream<bool> followingStream(String targetUserId) {
    final me = _requireMe();
    final followId = '${me}_$targetUserId';
    return _db
        .collection('follows')
        .doc(followId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  static Future<bool> isFollowing(String targetUserId) async {
    final me = _requireMe();
    final snap = await _db
        .collection('follows')
        .doc('${me}_$targetUserId')
        .get();
    return snap.exists;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIKES
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> likePost(String postId, String postAuthorId) async {
    final me = _requireMe();
    final likeId = '${postId}_$me';
    final likeRef = _db.collection('post_likes').doc(likeId);
    final postRef = _db.collection('posts').doc(postId);

    await _db.runTransaction((txn) async {
      final likeSnap = await txn.get(likeRef);
      if (likeSnap.exists) return;

      txn.set(likeRef, {
        'postId': postId,
        'userId': me,
        'createdAt': FieldValue.serverTimestamp(),
      });
      txn.update(postRef, {'likesCount': FieldValue.increment(1)});
    });

    if (postAuthorId != me) {
      await _db.collection('notifications').add({
        'toUserId': postAuthorId,
        'fromUserId': me,
        'type': 'like',
        'refId': postId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> unlikePost(String postId) async {
    final me = _requireMe();
    final likeId = '${postId}_$me';
    final likeRef = _db.collection('post_likes').doc(likeId);
    final postRef = _db.collection('posts').doc(postId);

    await _db.runTransaction((txn) async {
      final likeSnap = await txn.get(likeRef);
      if (!likeSnap.exists) return;

      txn.delete(likeRef);
      txn.update(postRef, {'likesCount': FieldValue.increment(-1)});
    });
  }

  static Stream<bool> likedStream(String postId) {
    final me = _requireMe();
    final likeId = '${postId}_$me';
    return _db
        .collection('post_likes')
        .doc(likeId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  static Stream<int> likesCountStream(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map((snap) => (snap.data()?['likesCount'] as int?) ?? 0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GUARDADOS  (users/{uid}/saved_posts/{postId})
  // ══════════════════════════════════════════════════════════════════════════

  /// Alterna el estado guardado de un post para el usuario actual.
  static Future<void> toggleSave(String postId) async {
    final me = _requireMe();
    final ref = _db
        .collection('users')
        .doc(me)
        .collection('saved_posts')
        .doc(postId);

    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'postId': postId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Stream reactivo: emite `true` si el post está guardado por el usuario actual.
  static Stream<bool> savedStream(String postId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);

    return _db
        .collection('users')
        .doc(uid)
        .collection('saved_posts')
        .doc(postId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Stream con la lista de IDs de posts guardados, ordenados del más reciente.
  /// Útil para construir una pantalla "Guardados".
  static Stream<List<String>> savedPostIdsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('saved_posts')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMENTARIOS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> addComment({
    required String postId,
    required String postAuthorId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    final me = _requireMe();
    final batch = _db.batch();
    final commentRef = _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc();

    batch.set(commentRef, {
      'postId': postId,
      'authorId': me,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('posts').doc(postId), {
      'commentsCount': FieldValue.increment(1),
    });

    await batch.commit();

    if (postAuthorId != me) {
      await _db.collection('notifications').add({
        'toUserId': postAuthorId,
        'fromUserId': me,
        'type': 'comment',
        'refId': postId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
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
        .map(
          (snap) =>
              snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  /// Stream del contador de comentarios en tiempo real.
  static Stream<int> commentsCountStream(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map((snap) => (snap.data()?['commentsCount'] as int?) ?? 0);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICACIONES
  // ══════════════════════════════════════════════════════════════════════════

  static Stream<List<Map<String, dynamic>>> notificationsStream() {
    final me = _requireMe();
    return _db
        .collection('notifications')
        .where('toUserId', isEqualTo: me)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        );
  }

  static Stream<int> unreadNotificationsCount() {
    final me = _requireMe();
    return _db
        .collection('notifications')
        .where('toUserId', isEqualTo: me)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Future<void> markNotificationRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({
      'read': true,
    });
  }

  static Future<void> markAllNotificationsRead() async {
    final me = _requireMe();
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
  // GRUPOS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<({String? groupId, String? error})> createGroup({
    required String name,
    required String description,
    required GroupCategory category,
    required String country,
    required String city,
    String coverEmoji = '🤝',
    bool isPrivate = false,
    int? maxMembers,
  }) async {
    try {
      final me = _requireMe();

      final groupRef = _db.collection('groups').doc();
      final group = GroupModel(
        docId: groupRef.id,
        name: name.trim(),
        description: description.trim(),
        category: category,
        country: country,
        city: city.trim().toLowerCase(),
        coverEmoji: coverEmoji,
        isPrivate: isPrivate,
        maxMembers: maxMembers,
        createdBy: me,
        memberCount: 1,
      );

      final batch = _db.batch();
      batch.set(groupRef, group.toMap());

      final memberRef = _db
          .collection('group_members')
          .doc('${groupRef.id}_$me');
      batch.set(memberRef, {
        'groupId': groupRef.id,
        'userId': me,
        'isAdmin': true,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return (groupId: groupRef.id, error: null);
    } catch (e) {
      return (
        groupId: null,
        error: 'No se pudo crear el grupo. Intentá de nuevo.',
      );
    }
  }

  static Stream<List<GroupModel>> streamGroups({
    String? city,
    GroupCategory? category,
    int limit = 20,
  }) {
    var query = city != null && city.isNotEmpty
        ? _db
            .collection('groups')
            .where('city', isEqualTo: city.trim().toLowerCase())
            .orderBy('createdAt', descending: true)
            .limit(limit)
        : _db
            .collection('groups')
            .orderBy('createdAt', descending: true)
            .limit(limit);

    if (category != null) {
      var q = _db
          .collection('groups')
          .where('category', isEqualTo: category.toFirestoreString())
          .orderBy('createdAt', descending: true)
          .limit(limit);
      if (city != null && city.isNotEmpty) {
        q = _db
            .collection('groups')
            .where('city', isEqualTo: city.trim().toLowerCase())
            .where('category', isEqualTo: category.toFirestoreString())
            .orderBy('createdAt', descending: true)
            .limit(limit);
      }
      query = q;
    }

    return query.snapshots().map(
      (snap) => snap.docs.map(GroupModel.fromDoc).toList(),
    );
  }

  static Stream<GroupModel?> streamGroupDetail(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map((snap) => snap.exists ? GroupModel.fromDoc(snap) : null);
  }

  static Future<GroupModel?> getGroup(String groupId) async {
    final snap = await _db.collection('groups').doc(groupId).get();
    if (!snap.exists) return null;
    return GroupModel.fromDoc(snap);
  }

  static Stream<List<GroupModel>> streamMyGroups() {
    final me = _requireMe();
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

          final ids = groupIds.take(30).toList();
          final snap = await _db
              .collection('groups')
              .where(FieldPath.documentId, whereIn: ids)
              .get();

          return snap.docs.map(GroupModel.fromDoc).toList();
        });
  }

  static Future<String?> joinGroup(String groupId) async {
    try {
      final me = _requireMe();
      final groupRef = _db.collection('groups').doc(groupId);
      final memberRef = _db.collection('group_members').doc('${groupId}_$me');

      await _db.runTransaction((txn) async {
        final groupSnap = await txn.get(groupRef);
        final memberSnap = await txn.get(memberRef);

        if (!groupSnap.exists) throw Exception('El grupo no existe.');
        if (memberSnap.exists) return;

        final group = GroupModel.fromDoc(groupSnap);
        if (!group.hasCapacity) throw Exception('El grupo está lleno.');

        txn.set(memberRef, {
          'groupId': groupId,
          'userId': me,
          'isAdmin': false,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        txn.update(groupRef, {
          'memberCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final group = await getGroup(groupId);
      if (group != null && group.createdBy != me) {
        await _db.collection('notifications').add({
          'toUserId': group.createdBy,
          'fromUserId': me,
          'type': 'group_join',
          'refId': groupId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return null;
    } on Exception catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    } catch (e) {
      return 'No se pudo unir al grupo. Intentá de nuevo.';
    }
  }

  static Future<String?> leaveGroup(String groupId) async {
    try {
      final me = _requireMe();
      final groupRef = _db.collection('groups').doc(groupId);
      final memberRef = _db.collection('group_members').doc('${groupId}_$me');

      final batch = _db.batch();
      batch.delete(memberRef);
      batch.update(groupRef, {
        'memberCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return null;
    } catch (e) {
      return 'No se pudo abandonar el grupo. Intentá de nuevo.';
    }
  }

  static Stream<bool> isMemberStream(String groupId) {
    final me = _requireMe();
    return _db
        .collection('group_members')
        .doc('${groupId}_$me')
        .snapshots()
        .map((snap) => snap.exists);
  }

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

  static Stream<List<GroupMessageModel>> streamGroupChat(
    String groupId, {
    int limit = 50,
  }) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snap) => snap.docs.map(GroupMessageModel.fromDoc).toList());
  }

  static Future<String?> sendGroupMessage({
    required String groupId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return null;

    try {
      final me = _requireMe();
      final batch = _db.batch();

      final msgRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc();

      batch.set(msgRef, {
        'groupId': groupId,
        'authorId': me,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(_db.collection('groups').doc(groupId), {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return null;
    } catch (e) {
      return 'No se pudo enviar el mensaje. Intentá de nuevo.';
    }
  }

  static Future<String?> createEvent({
    required String groupId,
    required String title,
    required String city,
    String? description,
    String? place,
    DateTime? eventDate,
  }) async {
    try {
      final me = _requireMe();

      final eventRef = _db.collection('events').doc();
      await eventRef.set({
        'groupId': groupId,
        'createdBy': me,
        'title': title.trim(),
        'description': description?.trim(),
        'city': city.trim().toLowerCase(),
        'place': place?.trim(),
        'eventDate': eventDate != null ? Timestamp.fromDate(eventDate) : null,
        'attendeesCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (eventDate != null) {
        await _db.collection('groups').doc(groupId).update({
          'nextEventAt': Timestamp.fromDate(eventDate),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return null;
    } catch (e) {
      return 'No se pudo crear el evento. Intentá de nuevo.';
    }
  }

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

  static Future<String?> attendEvent(String eventId) async {
    try {
      final me = _requireMe();
      final eventRef = _db.collection('events').doc(eventId);
      final attendeeRef = _db
          .collection('event_attendees')
          .doc('${eventId}_$me');

      await _db.runTransaction((txn) async {
        final attendeeSnap = await txn.get(attendeeRef);
        if (attendeeSnap.exists) return;

        txn.set(attendeeRef, {
          'eventId': eventId,
          'userId': me,
          'createdAt': FieldValue.serverTimestamp(),
        });
        txn.update(eventRef, {'attendeesCount': FieldValue.increment(1)});
      });

      return null;
    } catch (e) {
      return 'No se pudo confirmar la asistencia.';
    }
  }

  static Future<String?> cancelAttendance(String eventId) async {
    try {
      final me = _requireMe();
      final eventRef = _db.collection('events').doc(eventId);
      final attendeeRef = _db
          .collection('event_attendees')
          .doc('${eventId}_$me');

      await _db.runTransaction((txn) async {
        final attendeeSnap = await txn.get(attendeeRef);
        if (!attendeeSnap.exists) return;

        txn.delete(attendeeRef);
        txn.update(eventRef, {'attendeesCount': FieldValue.increment(-1)});
      });

      return null;
    } catch (e) {
      return 'No se pudo cancelar la asistencia.';
    }
  }

  static Stream<bool> isAttendingStream(String eventId) {
    final me = _requireMe();
    return _db
        .collection('event_attendees')
        .doc('${eventId}_$me')
        .snapshots()
        .map((snap) => snap.exists);
  }

  // ── Roles ──────────────────────────────────────────────────────────────────

  static Stream<GroupRole> myRoleStream(String groupId) {
    final me = _requireMe();
    return _db
        .collection('group_members')
        .doc('${groupId}_$me')
        .snapshots()
        .map((snap) {
          if (!snap.exists) return GroupRole.member;
          final d = snap.data()!;
          return GroupRole.fromString(d['role'] as String?);
        });
  }

  static Future<String?> setMemberRole(
      String groupId, String targetUserId, GroupRole role) async {
    try {
      final me = _requireMe();
      final myDoc = await _db
          .collection('group_members')
          .doc('${groupId}_$me')
          .get();
      if (!myDoc.exists) return 'No sos miembro de este grupo';
      final myRole = GroupRole.fromString(myDoc.data()?['role'] as String?);
      if (myRole != GroupRole.admin) return 'Solo los admins pueden cambiar roles';

      await _db.collection('group_members').doc('${groupId}_$targetUserId').update({
        'role':    role.name,
        'isAdmin': role == GroupRole.admin,
      });
      return null;
    } catch (e) {
      return 'No se pudo cambiar el rol.';
    }
  }

  static Future<String?> removeMember(String groupId, String targetUserId) async {
    try {
      final me = _requireMe();
      final myDoc = await _db
          .collection('group_members')
          .doc('${groupId}_$me')
          .get();
      final myRole = GroupRole.fromString(myDoc.data()?['role'] as String?);
      if (!myRole.canManage && me != targetUserId) {
        return 'Sin permisos para expulsar miembros';
      }
      final batch = _db.batch();
      batch.delete(
          _db.collection('group_members').doc('${groupId}_$targetUserId'));
      batch.update(_db.collection('groups').doc(groupId), {
        'memberCount': FieldValue.increment(-1),
      });
      await batch.commit();
      return null;
    } catch (e) {
      return 'No se pudo expulsar al miembro.';
    }
  }

  // ── Posts del grupo ────────────────────────────────────────────────────────

  static Stream<List<GroupPostModel>> streamGroupPosts(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('posts')
        .where('removed', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(GroupPostModel.fromDoc).toList());
  }

  static Future<String?> createGroupPost({
    required String groupId,
    required String body,
    String? imageUrl,
  }) async {
    try {
      final me = _requireMe();
      final userDoc = await _db.collection('users').doc(me).get();
      final ud = userDoc.data() ?? {};
      final username = (ud['username'] as String?) ??
          (ud['displayName'] as String?) ?? 'Usuario';
      final avatar = ud['photoURL'] as String?;

      await _db
          .collection('groups')
          .doc(groupId)
          .collection('posts')
          .add({
        'authorId':        me,
        'authorUsername':  username,
        'authorAvatarUrl': avatar,
        'body':            body,
        'imageUrl':        imageUrl,
        'likesCount':      0,
        'likedBy':         [],
        'commentsCount':   0,
        'removed':         false,
        'createdAt':       FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'No se pudo publicar.';
    }
  }

  static Future<void> toggleLikeGroupPost(
      String groupId, String postId) async {
    final me = _requireMe();
    final ref = _db
        .collection('groups')
        .doc(groupId)
        .collection('posts')
        .doc(postId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;
      final likedBy =
          List<String>.from(snap.data()!['likedBy'] as List? ?? []);
      if (likedBy.contains(me)) {
        txn.update(ref, {
          'likedBy':    FieldValue.arrayRemove([me]),
          'likesCount': FieldValue.increment(-1),
        });
      } else {
        txn.update(ref, {
          'likedBy':    FieldValue.arrayUnion([me]),
          'likesCount': FieldValue.increment(1),
        });
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GroupPostModel
// ─────────────────────────────────────────────────────────────────────────────

class GroupPostModel {
  final String  docId;
  final String  authorId;
  final String  authorUsername;
  final String? authorAvatarUrl;
  final String  body;
  final String? imageUrl;
  final int     likesCount;
  final List<String> likedBy;
  final int     commentsCount;
  final bool    removed;
  final DateTime? createdAt;

  const GroupPostModel({
    required this.docId,
    required this.authorId,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.body,
    this.imageUrl,
    required this.likesCount,
    required this.likedBy,
    required this.commentsCount,
    required this.removed,
    this.createdAt,
  });

  factory GroupPostModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return GroupPostModel(
      docId:           doc.id,
      authorId:        d['authorId']        as String? ?? '',
      authorUsername:  d['authorUsername']  as String? ?? 'Usuario',
      authorAvatarUrl: d['authorAvatarUrl'] as String?,
      body:            d['body']            as String? ?? '',
      imageUrl:        d['imageUrl']        as String?,
      likesCount:      (d['likesCount']     as num?)?.toInt() ?? 0,
      likedBy:         List<String>.from(d['likedBy'] as List? ?? []),
      commentsCount:   (d['commentsCount']  as num?)?.toInt() ?? 0,
      removed:         d['removed']         as bool? ?? false,
      createdAt:       _ts(d['createdAt']),
    );
  }
}

// ── Helper privado global: Timestamp → DateTime ───────────────────────────────

DateTime? _ts(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

// ═════════════════════════════════════════════════════════════════════════════
// FORO — Modelos
// ═════════════════════════════════════════════════════════════════════════════

class ForumPost {
  final String  docId;
  final String  authorId;
  final String  authorUsername;
  final String? authorAvatarUrl;
  final String  category;
  final String  title;
  final String  body;
  final int     upvotes;
  final List<String> upvotedBy;
  final int     repliesCount;
  final bool    flagged;
  final bool    removed;
  final bool    pinned;
  final DateTime? createdAt;

  const ForumPost({
    required this.docId,
    required this.authorId,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.category,
    required this.title,
    required this.body,
    required this.upvotes,
    required this.upvotedBy,
    required this.repliesCount,
    required this.flagged,
    required this.removed,
    required this.pinned,
    this.createdAt,
  });

  factory ForumPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ForumPost(
      docId:           doc.id,
      authorId:        d['authorId'] as String? ?? '',
      authorUsername:  d['authorUsername'] as String? ?? 'Usuario',
      authorAvatarUrl: d['authorAvatarUrl'] as String?,
      category:        d['category'] as String? ?? 'general',
      title:           d['title'] as String? ?? '',
      body:            d['body'] as String? ?? '',
      upvotes:         (d['upvotes'] as num?)?.toInt() ?? 0,
      upvotedBy:       List<String>.from(d['upvotedBy'] as List? ?? []),
      repliesCount:    (d['repliesCount'] as num?)?.toInt() ?? 0,
      flagged:         d['flagged'] as bool? ?? false,
      removed:         d['removed'] as bool? ?? false,
      pinned:          d['pinned'] as bool? ?? false,
      createdAt:       _ts(d['createdAt']),
    );
  }
}

class ForumReply {
  final String  docId;
  final String  authorId;
  final String  authorUsername;
  final String? authorAvatarUrl;
  final String  body;
  final int     upvotes;
  final List<String> upvotedBy;
  final bool    flagged;
  final DateTime? createdAt;

  const ForumReply({
    required this.docId,
    required this.authorId,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.body,
    required this.upvotes,
    required this.upvotedBy,
    required this.flagged,
    this.createdAt,
  });

  factory ForumReply.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ForumReply(
      docId:           doc.id,
      authorId:        d['authorId'] as String? ?? '',
      authorUsername:  d['authorUsername'] as String? ?? 'Usuario',
      authorAvatarUrl: d['authorAvatarUrl'] as String?,
      body:            d['body'] as String? ?? '',
      upvotes:         (d['upvotes'] as num?)?.toInt() ?? 0,
      upvotedBy:       List<String>.from(d['upvotedBy'] as List? ?? []),
      flagged:         d['flagged'] as bool? ?? false,
      createdAt:       _ts(d['createdAt']),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FORO — Servicio
// ═════════════════════════════════════════════════════════════════════════════

class ForumService {
  static final _db  = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String _requireMe() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');
    return uid;
  }

  // ── Moderation ─────────────────────────────────────────────────────────────

  static const List<String> illegalKeywords = [
    'vendo droga', 'venta de droga', 'cocaina', 'cocaína', 'heroína', 'heroina',
    'metanfetamina', 'fentanilo', 'vendo cannabis', 'marihuana en venta',
    'vendo arma', 'venta de armas', 'pistola en venta', 'compro armas',
    'escort sexual', 'prostitución', 'prostituta en venta',
    'pasaporte falso', 'dni falso', 'documento falso', 'visa falsa',
    'blanqueo de capitales', 'lavado de dinero', 'lavado de plata',
    'hackeo a sueldo', 'sicario', 'matar a alguien',
  ];

  static bool containsIllegalContent(String text) {
    final lower = text.toLowerCase();
    return illegalKeywords.any((kw) => lower.contains(kw));
  }

  // ── Stream principal del foro ──────────────────────────────────────────────

  static Stream<List<ForumPost>> streamPosts({String? category, int limit = 40}) {
    var query = _db
        .collection('forum_posts')
        .where('removed', isEqualTo: false)
        .orderBy('pinned', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (category != null && category != 'general') {
      query = _db
          .collection('forum_posts')
          .where('removed', isEqualTo: false)
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .limit(limit);
    }

    return query.snapshots().map((snap) =>
        snap.docs.map(ForumPost.fromDoc).toList());
  }

  // ── Crear post ─────────────────────────────────────────────────────────────

  static Future<String?> createPost({
    required String category,
    required String title,
    required String body,
  }) async {
    try {
      final me = _requireMe();
      final userDoc = await _db.collection('users').doc(me).get();
      final ud = userDoc.data() ?? {};
      final username = (ud['username'] as String?) ?? (ud['displayName'] as String?) ?? 'Usuario';
      final avatar = ud['photoURL'] as String?;

      final flagged = containsIllegalContent('$title $body');

      await _db.collection('forum_posts').add({
        'authorId':        me,
        'authorUsername':  username,
        'authorAvatarUrl': avatar,
        'category':        category,
        'title':           title,
        'body':            body,
        'upvotes':         0,
        'upvotedBy':       [],
        'repliesCount':    0,
        'flagged':         flagged,
        'removed':         false,
        'pinned':          false,
        'createdAt':       FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      return 'No se pudo publicar. Intentá de nuevo.';
    }
  }

  // ── Upvote post ────────────────────────────────────────────────────────────

  static Future<void> toggleUpvotePost(String postId) async {
    final me = _requireMe();
    final ref = _db.collection('forum_posts').doc(postId);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;
      final upvotedBy = List<String>.from(snap.data()!['upvotedBy'] as List? ?? []);
      if (upvotedBy.contains(me)) {
        txn.update(ref, {
          'upvotedBy': FieldValue.arrayRemove([me]),
          'upvotes':   FieldValue.increment(-1),
        });
      } else {
        txn.update(ref, {
          'upvotedBy': FieldValue.arrayUnion([me]),
          'upvotes':   FieldValue.increment(1),
        });
      }
    });
  }

  // ── Respuestas ─────────────────────────────────────────────────────────────

  static Stream<List<ForumReply>> streamReplies(String postId) {
    return _db
        .collection('forum_posts')
        .doc(postId)
        .collection('replies')
        .where('flagged', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(ForumReply.fromDoc).toList());
  }

  static Future<String?> addReply({
    required String postId,
    required String body,
  }) async {
    try {
      final me = _requireMe();
      final userDoc = await _db.collection('users').doc(me).get();
      final ud = userDoc.data() ?? {};
      final username = (ud['username'] as String?) ?? (ud['displayName'] as String?) ?? 'Usuario';
      final avatar = ud['photoURL'] as String?;

      final flagged = containsIllegalContent(body);

      final batch = _db.batch();
      final replyRef = _db.collection('forum_posts').doc(postId).collection('replies').doc();
      batch.set(replyRef, {
        'authorId':        me,
        'authorUsername':  username,
        'authorAvatarUrl': avatar,
        'body':            body,
        'upvotes':         0,
        'upvotedBy':       [],
        'flagged':         flagged,
        'createdAt':       FieldValue.serverTimestamp(),
      });
      if (!flagged) {
        batch.update(_db.collection('forum_posts').doc(postId), {
          'repliesCount': FieldValue.increment(1),
        });
      }
      await batch.commit();
      return null;
    } catch (e) {
      return 'No se pudo publicar la respuesta.';
    }
  }

  static Future<void> toggleUpvoteReply(String postId, String replyId) async {
    final me = _requireMe();
    final ref = _db.collection('forum_posts').doc(postId).collection('replies').doc(replyId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;
      final upvotedBy = List<String>.from(snap.data()!['upvotedBy'] as List? ?? []);
      if (upvotedBy.contains(me)) {
        txn.update(ref, {'upvotedBy': FieldValue.arrayRemove([me]), 'upvotes': FieldValue.increment(-1)});
      } else {
        txn.update(ref, {'upvotedBy': FieldValue.arrayUnion([me]), 'upvotes': FieldValue.increment(1)});
      }
    });
  }

  // ── Reportar contenido ─────────────────────────────────────────────────────

  static Future<String?> updatePost({
    required String postId,
    required String title,
    required String body,
    required String category,
  }) async {
    try {
      final me = _requireMe();
      final ref = _db.collection('forum_posts').doc(postId);
      final snap = await ref.get();
      if (!snap.exists || snap.data()?['authorId'] != me) {
        return 'No tenés permiso para editar esta publicación.';
      }
      final flagged = containsIllegalContent('$title $body');
      await ref.update({
        'title':     title,
        'body':      body,
        'category':  category,
        'flagged':   flagged,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'No se pudo guardar los cambios.';
    }
  }

  static Future<void> reportContent({
    required String targetId,
    required String targetType,
    required String reason,
  }) async {
    final me = _requireMe();
    await _db.collection('forum_reports').add({
      'targetId':   targetId,
      'targetType': targetType,
      'reporterId': me,
      'reason':     reason,
      'createdAt':  FieldValue.serverTimestamp(),
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_service.dart';
import 'location_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PostModel — representa un documento de la colección 'posts' en Firestore
//
// NUEVO respecto al original.
// Antes los posts viajaban como Map<String, dynamic> por toda la app.
// Un typo en 'authorId' vs 'authorid' fallaba en runtime sin warning.
// Ahora el compilador lo detecta.
// ─────────────────────────────────────────────────────────────────────────────

class PostModel {
  final String  docId;
  final String  authorId;
  final String  username;
  final List<String> images;
  final String  caption;
  final String? city;
  final String? countryFlag;
  final String? bio;
  final int     likesCount;
  final int     commentsCount;
  final DateTime? createdAt;
  // 'type' diferencia posts de eventos en el feed combinado.
  final String  type; // 'post' | 'event'

  const PostModel({
    required this.docId,
    required this.authorId,
    required this.username,
    required this.images,
    required this.caption,
    this.city,
    this.countryFlag,
    this.bio,
    this.likesCount    = 0,
    this.commentsCount = 0,
    this.createdAt,
    this.type = 'post',
  });

  factory PostModel.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      docId:         doc.id,
      authorId:      data['authorId']  as String? ?? '',
      username:      data['username']  as String? ?? 'usuario',
      images:        List<String>.from(data['images'] ?? []),
      caption:       data['caption']   as String? ?? '',
      city:          data['city']      as String?,
      countryFlag:   data['countryFlag'] as String?,
      bio:           data['bio']       as String?,
      likesCount:    (data['likesCount']    as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      createdAt:     _tsToDateTime(data['createdAt']),
      type:          data['type'] as String? ?? 'post',
    );
  }

  /// Para compatibilidad con código existente que espera Map.
  /// Migrar los widgets a PostModel directamente en cuanto sea posible.
  Map<String, dynamic> toMap() => {
    'type':         type,
    'docId':        docId,
    'authorId':     authorId,
    'username':     username,
    'images':       images,
    'caption':      caption,
    'city':         city,
    'countryFlag':  countryFlag,
    'bio':          bio,
    'likesCount':   likesCount,
    'commentsCount': commentsCount,
  };

  static DateTime? _tsToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EventModel — representa un documento de la colección 'events'
// ─────────────────────────────────────────────────────────────────────────────

class EventModel {
  final String  docId;
  final String  title;
  final String? city;
  final String? date;
  final String? location;
  final String? emoji;
  final int     attendeesCount;

  const EventModel({
    required this.docId,
    required this.title,
    this.city,
    this.date,
    this.location,
    this.emoji,
    this.attendeesCount = 0,
  });

  factory EventModel.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      docId:          doc.id,
      title:          data['title']    as String? ?? '',
      city:           data['city']     as String?,
      date:           data['date']     as String?,
      location:       data['location'] as String?,
      emoji:          data['emoji']    as String?,
      attendeesCount: (data['attendeesCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'type':           'event',
    'docId':          docId,
    'title':          title,
    'city':           city,
    'date':           date,
    'location':       location,
    'emoji':          emoji,
    'attendeesCount': attendeesCount,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// FeedResult — resultado paginado del feed
//
// NUEVO: incluye el último documento para paginación.
// Pasá lastDoc al siguiente llamado a getFeed() para cargar más.
// ─────────────────────────────────────────────────────────────────────────────

class FeedResult {
  final List<PostModel>  posts;
  final List<EventModel> events;
  // Lista combinada y ordenada para el ListView del feed.
  // Cada elemento es PostModel o EventModel — el widget decide cómo renderizar
  // según el tipo (post.type == 'post' vs 'event').
  final List<dynamic>    combined;
  // Último documento de Firestore — pasarlo como startAfterDoc
  // en el siguiente llamado para cargar más posts (paginación).
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  const FeedResult({
    required this.posts,
    required this.events,
    required this.combined,
    this.lastDoc,
    this.hasMore = false,
  });

  static const empty = FeedResult(
    posts:    [],
    events:   [],
    combined: [],
    hasMore:  false,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FeedService — construye el feed principal de Nomad
//
// Secciones del feed (en orden de prioridad):
//   1. Posts de usuarios seguidos  → contenido más relevante primero
//   2. Posts cercanos (misma ciudad) → descubrimiento local
//   3. Eventos cercanos             → intercalados en posiciones fijas
//
// CORRECCIONES respecto al original:
//   - shuffle() eliminado → orden cronológico por createdAt DESC
//   - UserService.getFollowing() → UserService.getFollowingIds() (solo IDs)
//   - city ahora usa cityEffective de LocationData cuando se pasa el objeto
//   - Paginación con startAfterDoc
//   - Posts y eventos tipados con PostModel / EventModel
// ─────────────────────────────────────────────────────────────────────────────

class FeedService {
  static final _db = FirebaseFirestore.instance;

  // Cuántos posts cargar por sección en cada llamada.
  static const _pageSize = 10;

  // ── getFeed ────────────────────────────────────────────────────────────────
  //
  // Acepta la ciudad como String directo o como LocationData.
  // Si pasás LocationData, usa cityEffective (GPS con fallback a IP).
  //
  // Ejemplo con String:
  //   final result = await FeedService.getFeed(
  //     city: 'madrid',
  //     userId: uid,
  //   );
  //
  // Ejemplo con LocationData (recomendado — usa el mejor dato disponible):
  //   final location = await LocationService.collect();
  //   final result = await FeedService.getFeed(
  //     locationData: location,
  //     userId: uid,
  //   );
  //
  // Paginación — cargar más posts:
  //   final more = await FeedService.getFeed(
  //     city: 'madrid',
  //     userId: uid,
  //     startAfterDoc: result.lastDoc,
  //   );

  static Future<FeedResult> getFeed({
    String? city,
    LocationData? locationData,
    required String userId,
    DocumentSnapshot? startAfterDoc,
  }) async {
    // Resolver la ciudad: parámetro explícito > LocationData > vacío.
    final rawCity = city ?? locationData?.cityEffective ?? '';
    final normalizedCity = rawCity.trim().toLowerCase();

    final List<PostModel>  followingPosts = [];
    final List<PostModel>  nearbyPosts    = [];
    final List<EventModel> events         = [];
    final Set<String>      addedDocIds    = {};
    DocumentSnapshot?      lastDoc;

    // ── 1. Posts de usuarios seguidos ──────────────────────────────────────
    //
    // CORRECCIÓN: usa getFollowingIds() (estático, devuelve List<String>)
    // en lugar del antiguo getFollowing() que devolvía lo mismo pero
    // no era el método correcto en el nuevo UserService.
    //
    // Índice requerido en Firestore:
    //   Colección: posts
    //   Campos: authorId (ASC) + createdAt (DESC)
    //   Crear en: Firebase Console → Firestore → Índices

    final followingIds = await UserService.getFollowingIds(userId);

    if (followingIds.isNotEmpty) {
      // Firestore limita whereIn a 30 elementos.
      // Si el usuario sigue a más de 30, tomamos los primeros 30.
      // En v2.0 con Elasticsearch esto desaparece.
      final ids = followingIds.take(30).toList();

      var query = _db
          .collection('posts')
          .where('authorId', whereIn: ids)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snap = await query.get();

      for (final doc in snap.docs) {
        if (addedDocIds.contains(doc.id)) continue;
        addedDocIds.add(doc.id);
        followingPosts.add(PostModel.fromDoc(doc));
        lastDoc = doc;
      }
    }

    // ── 2. Posts cercanos (misma ciudad) ───────────────────────────────────
    //
    // Solo si tenemos ciudad. Si el usuario no dio permiso de ubicación
    // y la IP tampoco resolvió, esta sección se salta silenciosamente.
    //
    // Índice requerido en Firestore:
    //   Colección: posts
    //   Campos: city (ASC) + createdAt (DESC)

    if (normalizedCity.isNotEmpty) {
      var nearbyQuery = _db
          .collection('posts')
          .where('city', isEqualTo: normalizedCity)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      // Para nearby no usamos startAfterDoc del caller
      // porque es una query independiente de la de following.
      // La paginación de nearby se maneja por separado si se necesita.

      final nearbySnap = await nearbyQuery.get();

      for (final doc in nearbySnap.docs) {
        if (addedDocIds.contains(doc.id)) continue; // ya está de following
        addedDocIds.add(doc.id);
        nearbyPosts.add(PostModel.fromDoc(doc));
        if (lastDoc == null) lastDoc = doc;
      }
    }

    // ── 3. Eventos cercanos ────────────────────────────────────────────────
    //
    // Los eventos siempre se cargan frescos (sin paginación por ahora).
    // Son pocos y cambian poco — no justifica el overhead de paginación.
    //
    // Índice requerido en Firestore:
    //   Colección: events
    //   Campos: city (ASC) + date (ASC)

    if (normalizedCity.isNotEmpty) {
      final eventsSnap = await _db
          .collection('events')
          .where('city', isEqualTo: normalizedCity)
          .orderBy('date', descending: false) // próximos primero
          .limit(5)
          .get();

      for (final doc in eventsSnap.docs) {
        events.add(EventModel.fromDoc(doc));
      }
    }

    // ── Combinar y ordenar ─────────────────────────────────────────────────
    //
    // CORRECCIÓN: eliminado el shuffle() del original.
    //
    // Estrategia de combinación:
    //   - Posts de seguidos primero (más relevantes).
    //   - Posts cercanos después (descubrimiento).
    //   - Eventos intercalados cada 5 items para visibilidad.
    //
    // El orden dentro de cada sección es cronológico (ya viene así de Firestore).

    final combined = _buildCombinedFeed(
      followingPosts: followingPosts,
      nearbyPosts:    nearbyPosts,
      events:         events,
    );

    final totalPosts = followingPosts.length + nearbyPosts.length;

    return FeedResult(
      posts:    [...followingPosts, ...nearbyPosts],
      events:   events,
      combined: combined,
      lastDoc:  lastDoc,
      // hasMore: si alguna sección devolvió el máximo de items,
      // probablemente hay más. El caller decide si cargar más.
      hasMore: totalPosts >= _pageSize,
    );
  }

  // ── Stream del feed en tiempo real ────────────────────────────────────────
  //
  // Para cuando querés que el feed se actualice automáticamente
  // cuando alguien a quien seguís publica algo nuevo.
  //
  // NOTA: los streams de Firestore tienen costo por lectura en cada
  // actualización. Usar con criterio — por defecto el feed usa getFeed()
  // puntual y un botón "Actualizar". El stream es opt-in.

  static Stream<List<PostModel>> streamFollowingPosts({
    required String userId,
    int limit = _pageSize,
  }) async* {
    final followingIds = await UserService.getFollowingIds(userId);
    if (followingIds.isEmpty) {
      yield [];
      return;
    }

    final ids = followingIds.take(30).toList();

    yield* _db
        .collection('posts')
        .where('authorId', whereIn: ids)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(PostModel.fromDoc).toList());
  }

  // ── Crear un post ──────────────────────────────────────────────────────────
  //
  // Centralizado acá para que el schema del documento sea siempre consistente.
  // El caller no construye el Map — siempre pasa por este método.

  static Future<String?> crearPost({
    required String  authorId,
    required String  username,
    required String  caption,
    required List<String> imageUrls,
    String?  city,
    LocationData? locationData,
    String?  countryFlag,
    String?  bio,
  }) async {
    try {
      final effectiveCity = city
          ?? locationData?.cityEffective?.trim().toLowerCase()
          ?? '';

      await _db.collection('posts').add({
        'authorId':     authorId,
        'username':     username,
        'caption':      caption.trim(),
        'images':       imageUrls,
        'city':         effectiveCity.isEmpty ? null : effectiveCity,
        'countryFlag':  countryFlag,
        'bio':          bio,
        'likesCount':   0,
        'commentsCount': 0,
        'type':         'post',
        'createdAt':    FieldValue.serverTimestamp(),
        'updatedAt':    FieldValue.serverTimestamp(),
      });
      return null; // éxito
    } catch (e) {
      return 'No se pudo publicar. Intentá de nuevo.';
    }
  }

  // ── Eliminar un post ───────────────────────────────────────────────────────

  static Future<String?> eliminarPost(String postId) async {
    try {
      await _db.collection('posts').doc(postId).delete();
      // Los likes y comentarios del post se limpian con una Cloud Function
      // (eliminar subcolecciones desde el cliente es costoso e ineficiente).
      return null;
    } catch (e) {
      return 'No se pudo eliminar el post. Intentá de nuevo.';
    }
  }

  // ── Helper: construir el feed combinado ───────────────────────────────────
  //
  // Intercala eventos cada 5 posts para que tengan visibilidad
  // sin dominar el feed.
  //
  // Resultado ejemplo con 8 posts y 2 eventos:
  //   post, post, post, post, post, EVENT, post, post, post, EVENT

  static List<dynamic> _buildCombinedFeed({
    required List<PostModel>  followingPosts,
    required List<PostModel>  nearbyPosts,
    required List<EventModel> events,
  }) {
    // Prioridad: following primero, nearby después.
    final allPosts = [...followingPosts, ...nearbyPosts];
    final result   = <dynamic>[];
    var   eventIdx = 0;

    for (var i = 0; i < allPosts.length; i++) {
      result.add(allPosts[i]);

      // Insertar un evento cada 5 posts si quedan eventos disponibles.
      if ((i + 1) % 5 == 0 && eventIdx < events.length) {
        result.add(events[eventIdx]);
        eventIdx++;
      }
    }

    // Agregar eventos restantes al final si no se intercalaron todos.
    while (eventIdx < events.length) {
      result.add(events[eventIdx]);
      eventIdx++;
    }

    return result;
  }
}
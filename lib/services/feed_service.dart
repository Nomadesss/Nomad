import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'location_service.dart';

//
// ─────────────────────────────────────────────
// MODELOS
// ─────────────────────────────────────────────
//

class PostModel {
  final String docId;
  final String authorId;
  final String username;
  final List<String> images;
  final String caption;
  final String? city;
  final String? countryFlag;
  final String? bio;
  final int likesCount;
  final int commentsCount;
  final DateTime? createdAt;
  final String type;

  // Coordenadas del post (guardadas cuando el autor las tiene disponibles).
  // Usadas para calcular la distancia al usuario actual en el cliente.
  final double? lat;
  final double? lng;

  // Visibilidad: 'public' | 'friends'
  final String visibility;

  // Distancia calculada en el cliente (km). null si no hay coords.
  final double? distanceKm;

  const PostModel({
    required this.docId,
    required this.authorId,
    required this.username,
    required this.images,
    required this.caption,
    this.city,
    this.countryFlag,
    this.bio,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.createdAt,
    this.type = 'post',
    this.lat,
    this.lng,
    this.visibility = 'public',
    this.distanceKm,
  });

  factory PostModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return PostModel(
      docId: doc.id,
      authorId: d['authorId'] as String? ?? '',
      username: d['username'] as String? ?? '',
      images: List<String>.from(d['images'] as List? ?? []),
      caption: d['caption'] as String? ?? '',
      city: d['city'] as String?,
      countryFlag: d['countryFlag'] as String?,
      bio: d['bio'] as String?,
      likesCount: (d['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (d['commentsCount'] as num?)?.toInt() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      visibility: d['visibility'] as String? ?? 'public',
    );
  }

  PostModel copyWith({double? distanceKm}) => PostModel(
    docId: docId,
    authorId: authorId,
    username: username,
    images: images,
    caption: caption,
    city: city,
    countryFlag: countryFlag,
    bio: bio,
    likesCount: likesCount,
    commentsCount: commentsCount,
    createdAt: createdAt,
    type: type,
    lat: lat,
    lng: lng,
    visibility: visibility,
    distanceKm: distanceKm ?? this.distanceKm,
  );
}

class EventModel {
  final String docId;
  final String title;
  final String? city;
  final String? date;
  final String? location;
  final double? lat;
  final double? lng;
  final double? distanceKm;

  const EventModel({
    required this.docId,
    required this.title,
    this.city,
    this.date,
    this.location,
    this.lat,
    this.lng,
    this.distanceKm,
  });

  factory EventModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final dateTs = d['date'] as Timestamp?;
    return EventModel(
      docId: doc.id,
      title: d['title'] as String? ?? '',
      city: d['city'] as String?,
      date: dateTs != null ? dateTs.toDate().toIso8601String() : null,
      location: d['location'] as String?,
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
    );
  }

  EventModel copyWith({double? distanceKm}) => EventModel(
    docId: docId,
    title: title,
    city: city,
    date: date,
    location: location,
    lat: lat,
    lng: lng,
    distanceKm: distanceKm ?? this.distanceKm,
  );
}

class FeedResult {
  final List<PostModel> posts;
  final List<EventModel> events;
  final List<dynamic> combined;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  const FeedResult({
    required this.posts,
    required this.events,
    required this.combined,
    this.lastDoc,
    this.hasMore = false,
  });

  static const empty = FeedResult(posts: [], events: [], combined: []);
}

//
// ─────────────────────────────────────────────
// FEED SERVICE
// ─────────────────────────────────────────────
//
// Lógica de ordenamiento:
//
//   • Posts PÚBLICOS  → ordenados por distancia al usuario (Haversine en cliente).
//                       Si no hay coordenadas GPS disponibles, se ordenan por
//                       ciudad coincidente primero, luego el resto por fecha.
//
//   • Posts de AMIGOS → ordenados por fecha de publicación (más reciente primero).
//
//   • Eventos         → ordenados por distancia (igual que posts públicos).
//
// Firestore no soporta ORDER BY por distancia geográfica de forma nativa,
// por lo que la estrategia es:
//   1. Traer un lote amplio desde Firestore (sin filtro de ciudad estricto).
//   2. Calcular distancias en el cliente con Haversine.
//   3. Ordenar y paginar en memoria.
//
// Índices requeridos en Firestore:
//   posts → visibility (ASC) + createdAt (DESC)
//   posts → visibility (ASC) + authorId  (ASC) + createdAt (DESC)  ← para amigos

class FeedService {
  static final _db = FirebaseFirestore.instance;

  // Cuántos docs traemos de Firestore por lote antes de ordenar en cliente.
  // Más grande = mejor ordenamiento local, más lento el fetch.
  static const int _fetchBatchSize = 40;

  // Cuántos items devolvemos por "página" al caller.
  static const int _pageSize = 10;

  // ── API pública ───────────────────────────────────────────────────────────

  static Future<FeedResult> getFeed({
    LocationData? locationData,
    required String userId,
    List<String> friendIds = const [],
    DocumentSnapshot? startAfterDoc,
  }) async {
    try {
      final results = await Future.wait([
        _fetchPublicPosts(
          locationData: locationData,
          startAfterDoc: startAfterDoc,
        ),
        if (friendIds.isNotEmpty)
          _fetchFriendsPosts(friendIds: friendIds, startAfterDoc: startAfterDoc)
        else
          Future.value(<PostModel>[]),
        _fetchEvents(locationData: locationData),
      ]);

      final publicPosts = results[0] as List<PostModel>;
      final friendsPosts = results[1] as List<PostModel>;
      final events = results[2] as List<EventModel>;

      // Combinar evitando duplicados (un amigo puede tener post público)
      final seenIds = <String>{};
      final allPosts = <PostModel>[];

      // Amigos primero (ya ordenados por fecha)
      for (final p in friendsPosts) {
        if (seenIds.add(p.docId)) allPosts.add(p);
      }
      // Luego públicos (ya ordenados por distancia)
      for (final p in publicPosts) {
        if (seenIds.add(p.docId)) allPosts.add(p);
      }

      final validPosts = allPosts
          .where((p) => p.docId.isNotEmpty && p.images.isNotEmpty)
          .toList();

      final combined = _buildCombinedFeed(posts: validPosts, events: events);

      // Para paginación simple usamos el último doc de posts públicos.
      // Si en el futuro querés paginación separada por tipo, extendé FeedResult.
      final lastDoc = publicPosts.isNotEmpty
          ? null
          : null; // ver nota abajo (*)

      return FeedResult(
        posts: validPosts,
        events: events,
        combined: combined,
        lastDoc: lastDoc,
        hasMore:
            publicPosts.length >= _fetchBatchSize ||
            friendsPosts.length >= _fetchBatchSize,
      );
    } catch (e) {
      debugPrint('[FeedService] Error cargando feed: $e');
      return FeedResult.empty;
    }
  }

  // ── Posts públicos — ordenados por distancia ──────────────────────────────
  //
  // (*) Nota sobre paginación:
  // Firestore no permite combinar startAfterDocument con ORDER BY en cliente.
  // Para el MVP paginamos por offset en memoria: en cada llamada traemos
  // _fetchBatchSize docs y en el cliente mostramos solo _pageSize.
  // En producción, podés implementar geo-hashing (GeoFlutterFire) para
  // paginación real por proximidad.

  static Future<List<PostModel>> _fetchPublicPosts({
    LocationData? locationData,
    DocumentSnapshot? startAfterDoc,
  }) async {
    // Firestore no tiene operador OR ni isNull nativo, así que hacemos dos
    // queries en paralelo y los combinamos en el cliente:
    //   1. Posts con visibility == 'public'  (nuevos)
    //   2. Todos los posts sin filtro        (legacy — sin campo visibility)
    // Del resultado 2 filtramos en cliente los que tengan visibility == 'friends'.

    Query qPublic = _db
        .collection('posts')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(_fetchBatchSize);

    Query qAll = _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(_fetchBatchSize);

    if (startAfterDoc != null) {
      qPublic = qPublic.startAfterDocument(startAfterDoc);
      qAll = qAll.startAfterDocument(startAfterDoc);
    }

    final snaps = await Future.wait([qPublic.get(), qAll.get()]);

    // Unir ambos resultados: excluir 'friends', deduplicar por docId
    final seenIds = <String>{};
    final allDocs = <DocumentSnapshot>[];

    for (final snap in snaps) {
      for (final doc in snap.docs) {
        final vis =
            (doc.data() as Map<String, dynamic>?)?['visibility'] as String?;
        if (vis == 'friends') continue; // excluir privados
        if (seenIds.add(doc.id)) allDocs.add(doc); // deduplicar
      }
    }

    if (allDocs.isEmpty) return [];

    // Reordenar por fecha desc (los dos queries pueden llegar mezclados)
    allDocs.sort((a, b) {
      final aTs = ((a.data() as Map)['createdAt'] as Timestamp?);
      final bTs = ((b.data() as Map)['createdAt'] as Timestamp?);
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.compareTo(aTs);
    });

    var posts = allDocs.map(PostModel.fromDoc).toList();

    // Calcular distancias si tenemos GPS
    final userLat = locationData?.lat;
    final userLng = locationData?.lng;

    if (userLat != null && userLng != null) {
      posts = posts.map((p) {
        final dist = (p.lat != null && p.lng != null)
            ? _haversineKm(userLat, userLng, p.lat!, p.lng!)
            : null;
        return p.copyWith(distanceKm: dist);
      }).toList();

      // Ordenar: posts con coords primero (por distancia asc),
      // luego posts sin coords (por fecha desc).
      posts.sort((a, b) {
        final dA = a.distanceKm;
        final dB = b.distanceKm;

        if (dA != null && dB != null) return dA.compareTo(dB);
        if (dA != null) return -1; // a tiene distancia, b no → a va antes
        if (dB != null) return 1;

        // Ambos sin distancia → fallback por ciudad luego fecha
        final cityEffective = locationData?.cityEffective?.toLowerCase() ?? '';
        final aCity = (a.city ?? '').toLowerCase();
        final bCity = (b.city ?? '').toLowerCase();

        if (aCity == cityEffective && bCity != cityEffective) return -1;
        if (bCity == cityEffective && aCity != cityEffective) return 1;

        return _compareDates(b.createdAt, a.createdAt); // más reciente primero
      });
    } else {
      // Sin GPS: ordenar por ciudad coincidente (IP/fallback) luego fecha
      final cityEffective = locationData?.cityEffective?.toLowerCase() ?? '';

      if (cityEffective.isNotEmpty) {
        posts.sort((a, b) {
          final aCity = (a.city ?? '').toLowerCase();
          final bCity = (b.city ?? '').toLowerCase();

          if (aCity == cityEffective && bCity != cityEffective) return -1;
          if (bCity == cityEffective && aCity != cityEffective) return 1;

          return _compareDates(b.createdAt, a.createdAt);
        });
      }
      // Si tampoco hay IP, quedan ordenados por fecha (lo que devolvió Firestore)
    }

    return posts;
  }

  // ── Posts de amigos — ordenados por fecha ─────────────────────────────────

  static Future<List<PostModel>> _fetchFriendsPosts({
    required List<String> friendIds,
    DocumentSnapshot? startAfterDoc,
  }) async {
    // Firestore limita whereIn a 30 elementos.
    final chunks = _chunkList(friendIds, 30);
    final futures = chunks.map((chunk) {
      Query q = _db
          .collection('posts')
          .where('authorId', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .limit(_fetchBatchSize);

      if (startAfterDoc != null) {
        q = q.startAfterDocument(startAfterDoc);
      }

      return q.get();
    });

    final snaps = await Future.wait(futures);
    final docs = snaps.expand((s) => s.docs).toList();

    // Ordenar globalmente por fecha (los chunks pueden llegar mezclados)
    docs.sort((a, b) {
      final aTs = (a.data() as Map)['createdAt'] as Timestamp?;
      final bTs = (b.data() as Map)['createdAt'] as Timestamp?;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.compareTo(aTs); // más reciente primero
    });

    return docs.map(PostModel.fromDoc).toList();
  }

  // ── Eventos — ordenados por distancia ─────────────────────────────────────

  static Future<List<EventModel>> _fetchEvents({
    LocationData? locationData,
  }) async {
    try {
      final now = Timestamp.now();
      final snap = await _db
          .collection('events')
          .where('date', isGreaterThanOrEqualTo: now)
          .orderBy('date', descending: false)
          .limit(20)
          .get();

      if (snap.docs.isEmpty) return [];

      var events = snap.docs.map(EventModel.fromDoc).toList();

      final userLat = locationData?.lat;
      final userLng = locationData?.lng;

      if (userLat != null && userLng != null) {
        events = events.map((e) {
          final dist = (e.lat != null && e.lng != null)
              ? _haversineKm(userLat, userLng, e.lat!, e.lng!)
              : null;
          return e.copyWith(distanceKm: dist);
        }).toList();

        events.sort((a, b) {
          final dA = a.distanceKm;
          final dB = b.distanceKm;
          if (dA != null && dB != null) return dA.compareTo(dB);
          if (dA != null) return -1;
          if (dB != null) return 1;
          return 0;
        });
      } else {
        // Sin GPS: ciudad de IP primero, luego el resto
        final cityEffective = locationData?.cityEffective?.toLowerCase() ?? '';
        if (cityEffective.isNotEmpty) {
          events.sort((a, b) {
            final aC = (a.city ?? '').toLowerCase() == cityEffective;
            final bC = (b.city ?? '').toLowerCase() == cityEffective;
            if (aC && !bC) return -1;
            if (!aC && bC) return 1;
            return 0;
          });
        }
      }

      return events;
    } catch (e) {
      debugPrint('[FeedService] Error cargando eventos: $e');
      return [];
    }
  }

  // ── Combinador posts + eventos ─────────────────────────────────────────────
  // Intercala un evento cada 5 posts.

  static List<dynamic> _buildCombinedFeed({
    required List<PostModel> posts,
    required List<EventModel> events,
  }) {
    final result = <dynamic>[];
    var eventIdx = 0;

    for (var i = 0; i < posts.length; i++) {
      result.add(posts[i]);

      if ((i + 1) % 5 == 0 && eventIdx < events.length) {
        result.add(events[eventIdx]);
        eventIdx++;
      }
    }

    while (eventIdx < events.length) {
      result.add(events[eventIdx++]);
    }

    return result;
  }

  // ── Utilidades ─────────────────────────────────────────────────────────────

  /// Distancia en kilómetros entre dos puntos geográficos (fórmula Haversine).
  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0; // radio medio de la Tierra en km
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  /// Compara dos DateTime nullable. Null va al final.
  static int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  /// Divide una lista en sub-listas de tamaño [size].
  static List<List<T>> _chunkList<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, math.min(i + size, list.length)));
    }
    return chunks;
  }
}

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
    );
  }
}

class EventModel {
  final String docId;
  final String title;
  final String? city;
  final String? date;
  final String? location;

  const EventModel({
    required this.docId,
    required this.title,
    this.city,
    this.date,
    this.location,
  });
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
// FEED SERVICE — conectado a Firestore real
// ─────────────────────────────────────────────
//

class FeedService {
  static final _db = FirebaseFirestore.instance;

  static const int _pageSize = 10;

  static Future<FeedResult> getFeed({
    String? city,
    LocationData? locationData,
    required String userId,
    DocumentSnapshot? startAfterDoc,
  }) async {
    try {
      // Determinar ciudad efectiva: parámetro > GPS > IP > fallback
      final effectiveCity = (city?.trim().isNotEmpty == true)
          ? city!.trim().toLowerCase()
          : (locationData?.cityEffective?.trim().toLowerCase() ?? '');

      // ── Query base: posts ordenados por fecha ──────────────────────────────
      //
      // Filtramos por ciudad si tenemos una.
      // Si no hay ciudad, traemos los posts más recientes globales.
      //
      // Índice requerido en Firestore:
      //   posts → city (ASC) + createdAt (DESC)

      Query query = _db
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      if (effectiveCity.isNotEmpty) {
        query = _db
            .collection('posts')
            .where('city', isEqualTo: effectiveCity)
            .orderBy('createdAt', descending: true)
            .limit(_pageSize);
      }

      // Paginación: arrancar después del último doc de la página anterior
      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snap = await query.get();
      final docs = snap.docs;

      if (docs.isEmpty) {
        return FeedResult.empty;
      }

      final posts = docs
          .map(PostModel.fromDoc)
          .where((p) => p.docId.isNotEmpty && p.images.isNotEmpty)
          .toList();

      // Eventos hardcodeados por ahora (podés conectarlos a Firestore después)
      final events = <EventModel>[];

      final combined = _buildCombinedFeed(posts: posts, events: events);

      return FeedResult(
        posts: posts,
        events: events,
        combined: combined,
        lastDoc: docs.last,
        hasMore: docs.length == _pageSize,
      );
    } catch (e) {
      debugPrint('[FeedService] Error cargando feed: $e');
      return FeedResult.empty;
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
}

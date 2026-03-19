import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'user_service.dart';
import 'location_service.dart';

/// 🔥 Toggle de mocks
const USE_MOCK_FEED = true;

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

  static const empty = FeedResult(
    posts: [],
    events: [],
    combined: [],
  );
}

//
// ─────────────────────────────────────────────
// FEED SERVICE
// ─────────────────────────────────────────────
//

class FeedService {
  static final _db = FirebaseFirestore.instance;

  static Future<FeedResult> getFeed({
    String? city,
    LocationData? locationData,
    required String userId,
    DocumentSnapshot? startAfterDoc,
  }) async {

    /// 🔥 MOCK ACTIVADO
    if (USE_MOCK_FEED) {
      await Future.delayed(const Duration(milliseconds: 800)); // simula loading
      return _mockFeedPersonalized(userId);
    }

    // --- AQUÍ IRÍA TU LÓGICA REAL ---
    return FeedResult.empty;
  }

  //
  // ─────────────────────────────────────────────
  // MOCK REALISTA TIPO INSTAGRAM
  // ─────────────────────────────────────────────
  //

  static FeedResult _mockFeedPersonalized(String userId) {
    final now = DateTime.now();

    // ─────────────────────────────────────────────
    // 👤 Usuario actual (simulado)
    // ─────────────────────────────────────────────

    final userCity = "madrid";
    final userCountry = "uruguay";

    final followingIds = ["user_1", "user_3"];

    // ─────────────────────────────────────────────
    // 🌍 Usuarios mock
    // country = origen (clave para coterráneos)
    // ─────────────────────────────────────────────

    final users = [
      ("user_0", "MateoUy", "uruguay", "madrid"),
      ("user_1", "SofiUy", "uruguay", "barcelona"),
      ("user_2", "CarlosAr", "argentina", "madrid"),
      ("user_3", "LuUy", "uruguay", "madrid"),
      ("user_4", "ValeCl", "chile", "madrid"),
      ("user_5", "JuanUy", "uruguay", "lisboa"),
      ("user_6", "AnaPe", "peru", "madrid"),
      ("user_7", "TomUy", "uruguay", "madrid"),
    ];

    final captions = [
      "Recién llegado, buscando laburo 👀",
      "Algún uruguayo por acá? 🇺🇾",
      "Recomendaciones de barrios?",
      "After office hoy 🍻",
      "Trámites de residencia",
      "Buscando room 🙏",
    ];

    // ─────────────────────────────────────────────
    // 🧱 Generar posts
    // ─────────────────────────────────────────────

    final posts = List.generate(20, (i) {
      final user = users[i % users.length];

      return PostModel(
        docId: 'mock_$i',
        authorId: user.$1,
        username: user.$2,
        countryFlag: _flag(user.$3),
        bio: "De ${user.$3} en ${user.$4}",
        city: user.$4,
        images: [
          "https://picsum.photos/500/400?random=${i + 100}"
        ],
        caption: captions[i % captions.length],
        likesCount: 10 + i * 2,
        commentsCount: i,
        createdAt: now.subtract(Duration(minutes: i * 12)),
      );
    });

    // ─────────────────────────────────────────────
    // 🧠 SCORING SEGÚN TU LÓGICA
    // ─────────────────────────────────────────────

    double score(PostModel post) {
      double s = 0;

      final isSameCountry =
          post.bio?.toLowerCase().contains(userCountry) ?? false;

      final isSameCity = post.city == userCity;

      // 🥇 Coterráneo + misma ciudad
      if (isSameCountry && isSameCity) s += 100;

      // 🥈 Coterráneo + otra ciudad
      else if (isSameCountry) s += 80;

      // 🥉 Migrante + misma ciudad
      else if (isSameCity) s += 60;

      // 🪶 Migrante + otra ciudad
      else s += 40;

      // Amigos
      if (followingIds.contains(post.authorId)) s += 30;

      // Engagement
      s += post.likesCount * 0.3;

      // Recencia
      final minutesAgo =
          now.difference(post.createdAt ?? now).inMinutes;
      s += (100 - minutesAgo).clamp(0, 100);

      return s;
    }

    posts.sort((a, b) => score(b).compareTo(score(a)));

    // ─────────────────────────────────────────────
    // 🎉 Eventos (se mantienen)
    // ─────────────────────────────────────────────

    final events = [
      EventModel(
        docId: "event_1",
        title: "Uruguayos en Madrid 🇺🇾",
        location: "Madrid",
        date: "Hoy 20:00",
      ),
      EventModel(
        docId: "event_2",
        title: "Networking migrantes 🌍",
        location: "Madrid",
        date: "Mañana",
      ),
    ];

    final combined = _buildCombinedFeed(
      followingPosts: posts.take(10).toList(),
      nearbyPosts: posts.skip(10).toList(),
      events: events,
    );

    return FeedResult(
      posts: posts,
      events: events,
      combined: combined,
      hasMore: false,
    );
  }

  //
  // ─────────────────────────────────────────────
  // COMBINADOR (igual que el tuyo)
  // ─────────────────────────────────────────────
  //

  static List<dynamic> _buildCombinedFeed({
    required List<PostModel> followingPosts,
    required List<PostModel> nearbyPosts,
    required List<EventModel> events,
  }) {
    final allPosts = [...followingPosts, ...nearbyPosts];
    final result = <dynamic>[];
    var eventIdx = 0;

    for (var i = 0; i < allPosts.length; i++) {
      result.add(allPosts[i]);

      if ((i + 1) % 5 == 0 && eventIdx < events.length) {
        result.add(events[eventIdx]);
        eventIdx++;
      }
    }

    while (eventIdx < events.length) {
      result.add(events[eventIdx]);
      eventIdx++;
    }

    return result;
  }

  static String _flag(String country) {
  switch (country) {
    case "uruguay":
      return "🇺🇾";
    case "argentina":
      return "🇦🇷";
    case "chile":
      return "🇨🇱";
    case "peru":
      return "🇵🇪";
    default:
      return "🌍";
  }
}
}
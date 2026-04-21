import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SeedStories
//
// Crea historias ficticias en Firestore para los usuarios del feed.
// Solo se ejecuta en modo debug y solo si las historias aún no existen.
//
// Colección: stories/{storyId}
// {
//   authorId:    String,
//   username:    String,
//   avatarUrl:   String?,
//   mediaUrl:    String,       ← imagen de Unsplash (placeholder)
//   mediaType:   'image',
//   caption:     String?,
//   location:    String?,
//   createdAt:   Timestamp,
//   expiresAt:   Timestamp,    ← createdAt + 24h
//   viewedBy:    List<String>, ← IDs de usuarios que la vieron
// }
// ─────────────────────────────────────────────────────────────────────────────

class SeedStories {
  static final _db = FirebaseFirestore.instance;
  static bool _ran = false;

  static Future<void> run() async {
    if (!kDebugMode || _ran) return;
    _ran = true;

    try {
      // Verificar si ya existen historias
      final existing = await _db.collection('stories').limit(1).get();
      if (existing.docs.isNotEmpty) {
        debugPrint('[SeedStories] Ya existen historias, skip.');
        return;
      }

      debugPrint('[SeedStories] Creando historias ficticias...');

      final now = DateTime.now();
      final batch = _db.batch();

      for (final user in _fakeUsers) {
        for (int i = 0; i < user.stories.length; i++) {
          final story = user.stories[i];
          final createdAt = now.subtract(Duration(hours: story.hoursAgo));
          final expiresAt = createdAt.add(const Duration(hours: 24));

          final ref = _db.collection('stories').doc();
          batch.set(ref, {
            'authorId': user.userId,
            'username': user.username,
            'avatarUrl': user.avatarUrl,
            'mediaUrl': story.imageUrl,
            'mediaType': 'image',
            'caption': story.caption,
            'location': story.location,
            'createdAt': Timestamp.fromDate(createdAt),
            'expiresAt': Timestamp.fromDate(expiresAt),
            'viewedBy': <String>[],
            'order': i,
          });
        }
      }

      await batch.commit();
      debugPrint('[SeedStories] ✓ Historias creadas correctamente.');
    } catch (e) {
      debugPrint('[SeedStories] Error: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Datos ficticios
// ─────────────────────────────────────────────────────────────────────────────

class _FakeUser {
  final String userId;
  final String username;
  final String? avatarUrl;
  final List<_FakeStory> stories;

  const _FakeUser({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.stories,
  });
}

class _FakeStory {
  final String imageUrl;
  final String? caption;
  final String? location;
  final int hoursAgo;

  const _FakeStory({
    required this.imageUrl,
    this.caption,
    this.location,
    this.hoursAgo = 0,
  });
}

const _fakeUsers = [
  _FakeUser(
    userId: 'fake_user_ana',
    username: 'Ana',
    avatarUrl: 'https://i.pravatar.cc/150?img=47',
    stories: [
      _FakeStory(
        imageUrl:
            'https://images.unsplash.com/photo-1543051932-6ef9fecfbc80?w=800&q=80',
        caption: '¡Barcelona desde las alturas! 🏙️',
        location: 'Barcelona, España',
        hoursAgo: 2,
      ),
      _FakeStory(
        imageUrl:
            'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
        caption: 'Primer día en la oficina nueva 💼',
        location: 'Barcelona',
        hoursAgo: 1,
      ),
    ],
  ),
  _FakeUser(
    userId: 'fake_user_luis',
    username: 'Luis',
    avatarUrl: 'https://i.pravatar.cc/150?img=12',
    stories: [
      _FakeStory(
        imageUrl:
            'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=800&q=80',
        caption: 'Dubai nunca decepciona 🌆',
        location: 'Dubai, EAU',
        hoursAgo: 5,
      ),
      _FakeStory(
        imageUrl:
            'https://images.unsplash.com/photo-1580674684081-7617fbf3d745?w=800&q=80',
        caption: 'Atardecer increíble 🌅',
        location: 'Dubai Marina',
        hoursAgo: 3,
      ),
      _FakeStory(
        imageUrl:
            'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=800&q=80',
        caption: 'El desierto te cambia la perspectiva 🏜️',
        location: 'Desierto de Dubái',
        hoursAgo: 1,
      ),
    ],
  ),
  _FakeUser(
    userId: 'fake_user_pedro',
    username: 'Pedro',
    avatarUrl: 'https://i.pravatar.cc/150?img=33',
    stories: [
      _FakeStory(
        imageUrl:
            'https://images.unsplash.com/photo-1499678329028-101435549a4e?w=800&q=80',
        caption: 'Berlín en primavera 🌸',
        location: 'Berlín, Alemania',
        hoursAgo: 8,
      ),
      _FakeStory(
        imageUrl:
            'https://images.unsplash.com/photo-1528360983277-13d401cdc186?w=800&q=80',
        caption: 'El muro ya no divide, une ❤️',
        location: 'East Side Gallery, Berlín',
        hoursAgo: 6,
      ),
    ],
  ),
  _FakeUser(
    userId: 'fake_user_mateo',
    username: 'Mateo',
    avatarUrl: 'https://i.pravatar.cc/150?img=68',
    stories: [
      _FakeStory(
        imageUrl:
            'https://images.unsplash.com/photo-1534430480872-3498386e7856?w=800&q=80',
        caption: 'Montreal en invierno ❄️',
        location: 'Montreal, Canadá',
        hoursAgo: 10,
      ),
      _FakeStory(
        imageUrl:
            'https://images.unsplash.com/photo-1519121785383-3229633bb75b?w=800&q=80',
        caption: 'Poutine por primera vez 🍟',
        location: 'Vieux-Montréal',
        hoursAgo: 7,
      ),
      _FakeStory(
        imageUrl:
            'https://images.unsplash.com/photo-1467269204594-9661b134dd2b?w=800&q=80',
        caption: 'La nieve ya es parte de mi vida ⛄',
        location: 'Montreal',
        hoursAgo: 4,
      ),
    ],
  ),
  _FakeUser(
    userId: 'fake_user_sofia',
    username: 'Sofia',
    avatarUrl: 'https://i.pravatar.cc/150?img=5',
    stories: [
      _FakeStory(
        imageUrl:
            'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=800&q=80',
        caption: 'Roma en un día 🏛️',
        location: 'Roma, Italia',
        hoursAgo: 15,
      ),
    ],
  ),
];

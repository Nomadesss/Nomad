import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/discover_service.dart';
import '../chat/chat_screen.dart';
import 'discover_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// matches_screen.dart  –  Nomad App
// Ubicación: lib/features/discover/matches_screen.dart
//
// Muestra todos los matches del usuario.
// Tap en un match → abre el ChatScreen directamente.
// ─────────────────────────────────────────────────────────────────────────────

const _teal = Color(0xFF0D9488);
const _tealLight = Color(0xFF5EEAD4);
const _tealDark = Color(0xFF134E4A);
const _tealBg = Color(0xFFF0FAF9);

final Map<String, Map<String, dynamic>> _userCache = {};

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  Future<Map<String, dynamic>> _fetchUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid]!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};
      _userCache[uid] = data;
      return data;
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: _tealDark,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mis matches',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _tealDark,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            DiscoverService.matchesStream()
                as Stream<QuerySnapshot<Map<String, dynamic>>>,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _teal));
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState(context);
          }

          return CustomScrollView(
            slivers: [
              // Banner superior
              SliverToBoxAdapter(child: _buildBanner(docs.length)),

              // Grid de matches
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final data = docs[i].data();
                    final uids = List<String>.from(data['uids'] as List? ?? []);
                    final chatId = data['chatId'] as String? ?? '';
                    final otherUid = uids.firstWhere(
                      (u) => u != myUid,
                      orElse: () => '',
                    );

                    if (otherUid.isEmpty) return const SizedBox.shrink();

                    return FutureBuilder<Map<String, dynamic>>(
                      future: _fetchUser(otherUid),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) {
                          return _MatchCardSkeleton();
                        }

                        final userData = userSnap.data!;
                        final rawName = (userData['displayName'] as String?)
                            ?.trim();
                        final rawNombre = (userData['nombre'] as String?)
                            ?.trim();
                        final name =
                            (rawName?.isNotEmpty == true
                                ? rawName
                                : rawNombre) ??
                            'Nomad';
                        final username =
                            (userData['username'] as String?) ?? '';
                        final photo = userData['photoURL'] as String?;
                        final pais = userData['paisOrigen'] as String?;
                        final flag = userData['countryFlag'] as String?;
                        final ciudad = userData['ciudadActual'] as String?;

                        return _MatchCard(
                          name: name,
                          username: username,
                          photoURL: photo,
                          pais: pais,
                          flag: flag,
                          ciudad: ciudad,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chatId,
                                otherUserId: otherUid,
                                otherUsername: username,
                                otherAvatarUrl: photo,
                                otherName: name,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }, childCount: docs.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBanner(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_teal, Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('❤️', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count match${count != 1 ? 'es' : ''}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const Text(
                  'Tocá un perfil para chatear',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _tealBg,
                shape: BoxShape.circle,
                border: Border.all(color: _tealLight, width: 2),
              ),
              child: const Text(
                '💫',
                style: TextStyle(fontSize: 42),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Todavía no tenés matches',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _tealDark,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Seguí deslizando para encontrar\nnomads que conecten con vos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.explore_rounded, size: 16),
              label: const Text('Seguir descubriendo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MatchCard — tarjeta individual de match en el grid
// ─────────────────────────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final String name;
  final String username;
  final String? photoURL;
  final String? pais;
  final String? flag;
  final String? ciudad;
  final VoidCallback onTap;

  const _MatchCard({
    required this.name,
    required this.username,
    required this.photoURL,
    required this.pais,
    required this.flag,
    required this.ciudad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Foto o gradiente
            photoURL != null
                ? Image.network(
                    photoURL!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildGradient(),
                  )
                : _buildGradient(),

            // Gradiente inferior
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                ),
              ),
            ),

            // Botón de mensaje
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _teal,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: _teal.withOpacity(0.4), blurRadius: 8),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

            // Info inferior
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (flag != null)
                        Text(flag!, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  if (ciudad != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_rounded,
                          size: 10,
                          color: _tealLight,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            ciudad!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradient() {
    final colors = [
      [const Color(0xFF0D9488), const Color(0xFF134E4A)],
      [const Color(0xFF7C3AED), const Color(0xFF4C1D95)],
      [const Color(0xFFD97706), const Color(0xFF92400E)],
      [const Color(0xFFDB2777), const Color(0xFF831843)],
    ];
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors[idx],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MatchCardSkeleton
// ─────────────────────────────────────────────────────────────────────────────

class _MatchCardSkeleton extends StatefulWidget {
  @override
  State<_MatchCardSkeleton> createState() => _MatchCardSkeletonState();
}

class _MatchCardSkeletonState extends State<_MatchCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(color: const Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}

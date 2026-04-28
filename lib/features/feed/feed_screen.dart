import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';

import 'widgets/seed_stories.dart';
import '../../services/location_service.dart';
import '../../services/feed_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'widgets/feed_header.dart';
import 'widgets/stories_bar.dart';
import 'widgets/post_card.dart';
import 'widgets/event_card.dart';
import 'widgets/bottom_nav.dart';
import '../../l10n/app_localizations.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  FeedResult _feedResult = FeedResult.empty;
  bool _isLoading = true;
  bool _isLoadingMore = false;

  /// Posts ocultos en esta sesión (no me interesa / reportar)
  final Set<String> _hiddenPostIds = {};

  // IDs de usuarios que el usuario actual sigue (amigos).
  // Se carga una vez al iniciar y se reutiliza en _loadMore.
  List<String> _friendIds = [];

  final ScrollController _scrollController = ScrollController();
  bool _showBottomBar = true;
  bool _showHeader = true;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      SeedStories.run();
    }
    _loadFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _hidePost(String postId) {
    setState(() => _hiddenPostIds.add(postId));
  }

  void _onScroll() {
    final direction = _scrollController.position.userScrollDirection;

    if (direction == ScrollDirection.reverse) {
      if (_showBottomBar || _showHeader) {
        setState(() {
          _showBottomBar = false;
          _showHeader = false;
        });
      }
    }

    if (direction == ScrollDirection.forward) {
      if (!_showBottomBar || !_showHeader) {
        setState(() {
          _showBottomBar = true;
          _showHeader = true;
        });
      }
    }

    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  /// Carga la lista de IDs de usuarios seguidos por el usuario actual.
  /// Retorna una lista vacía si falla — el feed funciona igual sin amigos.
  Future<List<String>> _loadFriendIds(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('follows')
          .where('followerId', isEqualTo: userId)
          .get();
      return snap.docs
          .map((doc) => doc.data()['followingId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[FeedScreen] No se pudo obtener amigos: $e');
      return [];
    }
  }

  Future<void> _loadFeed() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Cargamos ubicación y amigos en paralelo para no agregar latencia
      final results = await Future.wait([
        LocationService.collect(),
        _loadFriendIds(userId),
      ]);

      final locationData = results[0] as LocationData;
      final friendIds = results[1] as List<String>;

      _friendIds = friendIds; // guardar para _loadMore

      final result = await FeedService.getFeed(
        locationData: locationData,
        userId: userId,
        friendIds: friendIds,
      );

      if (mounted) {
        setState(() {
          _feedResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[FeedScreen] Error cargando feed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_feedResult.hasMore || _feedResult.lastDoc == null) {
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final locationData = await LocationService.collect();
      final more = await FeedService.getFeed(
        locationData: locationData,
        userId: userId,
        friendIds: _friendIds,
        startAfterDoc: _feedResult.lastDoc,
      );

      if (mounted) {
        setState(() {
          _feedResult = FeedResult(
            posts: [..._feedResult.posts, ...more.posts],
            events: [..._feedResult.events, ...more.events],
            combined: [..._feedResult.combined, ...more.combined],
            lastDoc: more.lastDoc ?? _feedResult.lastDoc,
            hasMore: more.hasMore,
          );
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('[FeedScreen] Error cargando más: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _feedResult = FeedResult.empty;
      _hiddenPostIds.clear();
      _isLoading = true;
    });
    await _loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final visibleCombined = _feedResult.combined.where((item) {
      if (item is PostModel) {
        return !_hiddenPostIds.contains(item.docId);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF0D9488),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              backgroundColor: Colors.white,
              automaticallyImplyLeading: false,
              toolbarHeight: _showHeader ? 64 : 0,
              title: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showHeader ? 1.0 : 0.0,
                child: const FeedHeader(),
              ),
            ),

            // ── StoriesBar en tiempo real ─────────────────────────────────
            const SliverToBoxAdapter(child: StoriesBar()),

            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                  ),
                ),
              ),

            if (!_isLoading && visibleCombined.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('✈️', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text(
                          l10n.feedEmptyTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF134E4A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.feedEmptyMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (!_isLoading && visibleCombined.isNotEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = visibleCombined[index];

                  if (item is PostModel) {
                    if (item.docId.isEmpty) return const SizedBox.shrink();
                    return PostCard(
                      key: ValueKey(item.docId),
                      postId: item.docId,
                      postAuthorId: item.authorId,
                      username: item.username,
                      images: item.images,
                      caption: item.caption,
                      userCountryFlag: item.countryFlag,
                      userCity: item.city,
                      userBio: item.bio,
                      onDismiss: () => _hidePost(item.docId),
                    );
                  }

                  if (item is EventModel) {
                    return EventCard(
                      key: ValueKey('event_${item.docId}'),
                      title: item.title,
                      location: item.location ?? '',
                      date: item.date ?? '',
                    );
                  }

                  return const SizedBox.shrink();
                }, childCount: visibleCombined.length),
              ),

            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),

      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: _showBottomBar ? Offset.zero : const Offset(0, 1),
        child: const BottomNav(currentIndex: 0),
      ),
    );
  }
}

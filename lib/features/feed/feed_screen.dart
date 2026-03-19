import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';

import '../../services/seed_posts.dart';
import '../../services/location_service.dart';
import '../../services/feed_service.dart';

import 'widgets/feed_header.dart';
import 'widgets/stories_bar.dart';
import 'widgets/post_card.dart';
import 'widgets/event_card.dart';
import 'widgets/bottom_nav.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {

  // ── Estado del feed ────────────────────────────────────────────────────────
  //
  // FIX 1: era List<Map<String, dynamic>>.
  // Ahora usamos FeedResult que envuelve posts, eventos y paginación.
  // Para el ListView usamos result.combined — ya viene ordenado y con
  // eventos intercalados cada 5 posts.

  FeedResult _feedResult = FeedResult.empty;
  bool       _isLoading  = true;
  bool       _isLoadingMore = false;

  // ── Scroll ─────────────────────────────────────────────────────────────────

  final ScrollController _scrollController = ScrollController();
  bool _showBottomBar = true;
  bool _showHeader    = true;

  @override
  void initState() {
    super.initState();

    // FIX: SeedPosts solo en debug. En el original corría en producción
    // y creaba posts falsos para cada usuario que abría el feed.
    if (kDebugMode) {
      SeedPosts.run();
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

  // ── Listener de scroll ─────────────────────────────────────────────────────

  void _onScroll() {
    final direction = _scrollController.position.userScrollDirection;

    // Ocultar header y bottom bar al bajar.
    if (direction == ScrollDirection.reverse) {
      if (_showBottomBar || _showHeader) {
        setState(() {
          _showBottomBar = false;
          _showHeader    = false;
        });
      }
    }

    // Mostrar al subir.
    if (direction == ScrollDirection.forward) {
      if (!_showBottomBar || !_showHeader) {
        setState(() {
          _showBottomBar = true;
          _showHeader    = true;
        });
      }
    }

    // Cargar más posts al llegar al 80% del scroll.
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.8) {
      _loadMore();
    }
  }

  // ── Carga inicial del feed ─────────────────────────────────────────────────

  Future<void> _loadFeed() async {
    // FIX: el original usaba currentUser!.uid sin protección.
    // Si por algún edge case no hay sesión, el ! lanzaba una excepción.
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      // No hay sesión — el router debería haber redirigido al login.
      // Si llegamos acá, simplemente mostramos el feed vacío.
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // FIX 1: getFeed ahora recibe parámetros nombrados.
      // FIX 2: pasamos locationData directamente — FeedService usa
      //        cityEffective internamente (GPS con fallback a IP).
      //        Ya no hace falta extraer el string de ciudad acá.
      final locationData = await LocationService.collect();

      // FIX 2: getFeed devuelve FeedResult, no List<Map<String,dynamic>>.
      final result = await FeedService.getFeed(
        locationData: locationData,
        userId:       userId,
      );

      if (mounted) {
        setState(() {
          _feedResult = result;
          _isLoading  = false;
        });
      }
    } catch (e) {
      debugPrint('[FeedScreen] Error cargando feed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Paginación: cargar más ─────────────────────────────────────────────────
  //
  // Se llama automáticamente al llegar al 80% del scroll.
  // Usa lastDoc de FeedResult para continuar desde donde quedó.

  Future<void> _loadMore() async {
    // No cargar si ya está cargando, si no hay más páginas,
    // o si no hay lastDoc para paginar.
    if (_isLoadingMore || !_feedResult.hasMore || _feedResult.lastDoc == null) {
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final locationData = await LocationService.collect();

      final more = await FeedService.getFeed(
        locationData:   locationData,
        userId:         userId,
        startAfterDoc:  _feedResult.lastDoc,
      );

      if (mounted) {
        setState(() {
          // Combinar los items anteriores con los nuevos.
          _feedResult = FeedResult(
            posts:    [..._feedResult.posts,    ...more.posts],
            events:   [..._feedResult.events,   ...more.events],
            combined: [..._feedResult.combined, ...more.combined],
            lastDoc:  more.lastDoc ?? _feedResult.lastDoc,
            hasMore:  more.hasMore,
          );
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('[FeedScreen] Error cargando más: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ── Pull-to-refresh ────────────────────────────────────────────────────────

  Future<void> _onRefresh() async {
    setState(() {
      _feedResult = FeedResult.empty;
      _isLoading  = true;
    });
    await _loadFeed();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF0D9488), // teal de Nomad
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [

            // ── Header animado ───────────────────────────────────────────────
            SliverAppBar(
              floating:        true,
              snap:            true,
              elevation:       0,
              backgroundColor: Colors.white,
              toolbarHeight:   _showHeader ? 64 : 0,
              title: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showHeader ? 1.0 : 0.0,
                child: const FeedHeader(),
              ),
            ),

            // ── Stories ──────────────────────────────────────────────────────
            const SliverToBoxAdapter(child: StoriesBar()),

            // ── Loading inicial ──────────────────────────────────────────────
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ),
              ),

            // ── Feed vacío ───────────────────────────────────────────────────
            if (!_isLoading && _feedResult.combined.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Text('✈️', style: TextStyle(fontSize: 40)),
                        SizedBox(height: 12),
                        Text(
                          'Tu feed está vacío por ahora',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF134E4A),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Seguí a otros nomads o activá\ntu ubicación para ver posts cercanos',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Lista del feed ───────────────────────────────────────────────
            //
            // FIX: _feedResult.combined reemplaza a la lista feed anterior.
            // Cada item es PostModel o EventModel — chequeamos el tipo
            // con is en lugar de item["type"] == "post".

            if (!_isLoading && _feedResult.combined.isNotEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _feedResult.combined[index];

                    if (item is PostModel) {
                      if (item.docId.isEmpty) return const SizedBox.shrink();
                      return PostCard(
                        postId:          item.docId,
                        postAuthorId:    item.authorId,
                        username:        item.username,
                        images:          item.images,
                        caption:         item.caption,
                        userCountryFlag: item.countryFlag,
                        userCity:        item.city,
                        userBio:         item.bio,
                      );
                    }

                    if (item is EventModel) {
                      return EventCard(
                        title:    item.title,
                        location: item.location ?? '',
                        date:     item.date ?? '',
                      );
                    }

                    return const SizedBox.shrink();
                  },
                  childCount: _feedResult.combined.length,
                ),
              ),

            // ── Indicador de carga de más posts ─────────────────────────────
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

      // ── Bottom bar animado ─────────────────────────────────────────────────
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve:    Curves.easeInOut,
        offset:   _showBottomBar ? Offset.zero : const Offset(0, 1),
        child:    const BottomNav(),
      ),
    );
  }
}
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../l10n/app_localizations.dart';
import '../../services/explore_service.dart';
import '../../services/feed_service.dart';
import '../feed/widgets/bottom_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
// search_screen.dart — Explorar & Buscar (estilo Instagram Explore)
//
// Estados:
//   Explorar: grid de contenido personalizado con tabs de categoría
//   Buscando: resultados de usuarios y posts
//
// Recomendaciones: ExploreService calcula un score híbrido por recencia,
// engagement y afinidad de país aprendida de las interacciones del usuario.
// ─────────────────────────────────────────────────────────────────────────────

const _bg = Color(0xFF0F0F14);
const _surface = Color(0xFF1A1A24);
const _teal = Color(0xFF0D9488);
const _tealDim = Color(0xFF0F766E);
const _white70 = Color(0xB3FFFFFF);
const _white40 = Color(0x66FFFFFF);
const _gap = 2.0;

enum _ExploreTab { forYou, recent, people }

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  late final TabController _tabCtrl;

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isSearching = false;
  String _query = '';

  // Explore content
  List<PostModel> _forYouPosts = [];
  List<PostModel> _recentPosts = [];
  List<Map<String, dynamic>> _suggestedUsers = [];

  bool _loadingForYou = true;
  bool _loadingRecent = true;
  bool _loadingPeople = true;

  // Search results
  List<Map<String, dynamic>> _userResults = [];
  List<PostModel> _postResults = [];
  bool _loadingSearch = false;

  // Viewer
  PostModel? _viewerPost;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _focusNode.addListener(_onFocusChange);
    _searchCtrl.addListener(_onQueryChange);
    _tabCtrl.addListener(() => setState(() {}));
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    _loadForYou();
    _loadRecent();
    _loadPeople();
  }

  Future<void> _loadForYou() async {
    setState(() => _loadingForYou = true);
    final posts = await ExploreService.getPersonalizedFeed(limit: 36);
    if (mounted) setState(() { _forYouPosts = posts; _loadingForYou = false; });
  }

  Future<void> _loadRecent() async {
    setState(() => _loadingRecent = true);
    final posts = await ExploreService.getRecentFeed(limit: 36);
    if (mounted) setState(() { _recentPosts = posts; _loadingRecent = false; });
  }

  Future<void> _loadPeople() async {
    setState(() => _loadingPeople = true);
    final users = await ExploreService.getSuggestedUsers(limit: 24);
    if (mounted) setState(() { _suggestedUsers = users; _loadingPeople = false; });
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() { _userResults = []; _postResults = []; });
      return;
    }
    setState(() => _loadingSearch = true);
    final users = await ExploreService.searchUsers(q);
    final posts = await ExploreService.searchPosts(q);
    if (mounted) {
      setState(() {
        _userResults = users;
        _postResults = posts;
        _loadingSearch = false;
      });
    }
  }

  // ── Listeners ──────────────────────────────────────────────────────────────

  void _onFocusChange() {
    setState(() => _isSearching = _focusNode.hasFocus);
  }

  void _onQueryChange() {
    final q = _searchCtrl.text.trim();
    setState(() => _query = q);
    _search(q);
  }

  void _cancelSearch() {
    _focusNode.unfocus();
    _searchCtrl.clear();
    setState(() { _isSearching = false; _query = ''; _userResults = []; _postResults = []; });
  }

  // ── Interaction tracking ───────────────────────────────────────────────────

  void _onTileVisible(PostModel post) {
    ExploreService.recordInteraction(
      contentId: post.docId,
      type: 'view',
      countryFlag: post.countryFlag,
    );
  }

  void _onTileTap(PostModel post) {
    HapticFeedback.selectionClick();
    _onTileVisible(post);
    setState(() => _viewerPost = post);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      body: Stack(
        children: [
          _viewerPost != null
              ? _FullscreenViewer(
                  post: _viewerPost!,
                  onClose: () => setState(() => _viewerPost = null),
                  onLike: () => ExploreService.recordInteraction(
                    contentId: _viewerPost!.docId,
                    type: 'like',
                    countryFlag: _viewerPost!.countryFlag,
                  ),
                )
              : _buildExplore(),
        ],
      ),
      bottomNavigationBar: _viewerPost == null
          ? const BottomNav(currentIndex: 2)
          : null,
    );
  }

  Widget _buildExplore() {
    return NestedScrollView(
      controller: _scrollCtrl,
      headerSliverBuilder: (context, _) => [
        _buildSearchBar(),
        if (!_isSearching) _buildTabBar(),
      ],
      body: _isSearching ? _buildSearchResults() : _buildTabContent(),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

  SliverAppBar _buildSearchBar() {
    final l10n = AppLocalizations.of(context);
    return SliverAppBar(
      backgroundColor: _bg,
      floating: true,
      snap: true,
      elevation: 0,
      toolbarHeight: 60,
      title: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 42,
              decoration: BoxDecoration(
                color: _isSearching
                    ? _surface
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isSearching
                      ? _teal.withValues(alpha: 0.6)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText:
                      '${l10n.searchPeople}, ${l10n.searchEvents}, lugares...',
                  hintStyle: const TextStyle(color: _white40, fontSize: 13.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _isSearching ? _teal : _white40,
                    size: 20,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: _cancelSearch,
                          child: const Icon(
                            Icons.close_rounded,
                            color: _white40,
                            size: 18,
                          ),
                        )
                      : null,
                ),
                onSubmitted: _search,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _isSearching
                ? Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: GestureDetector(
                      onTap: _cancelSearch,
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: _teal,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  SliverPersistentHeader _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabCtrl,
          indicatorColor: _teal,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: _white40,
          labelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Para ti'),
            Tab(text: 'Recientes'),
            Tab(text: 'Personas'),
          ],
        ),
        backgroundColor: _bg,
      ),
    );
  }

  // ── Tab content ────────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildPostGrid(_forYouPosts, _loadingForYou, onRefresh: _loadForYou),
        _buildPostGrid(_recentPosts, _loadingRecent, onRefresh: _loadRecent),
        _buildPeopleGrid(),
      ],
    );
  }

  // ── Post grid (staggered) ──────────────────────────────────────────────────

  Widget _buildPostGrid(
    List<PostModel> posts,
    bool loading, {
    required Future<void> Function() onRefresh,
  }) {
    if (loading) return _buildGridSkeleton();

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined, size: 48, color: _white40),
            const SizedBox(height: 12),
            const Text(
              'Sin contenido todavía',
              style: TextStyle(color: _white70, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _teal,
      backgroundColor: _surface,
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.zero,
            sliver: _StaggeredPostSliver(
              posts: posts,
              onTap: _onTileTap,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── People grid ────────────────────────────────────────────────────────────

  Widget _buildPeopleGrid() {
    if (_loadingPeople) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => _SkeletonBox(radius: 16),
      );
    }

    if (_suggestedUsers.isEmpty) {
      return const Center(
        child: Text(
          'No hay personas sugeridas',
          style: TextStyle(color: _white70),
        ),
      );
    }

    return RefreshIndicator(
      color: _teal,
      backgroundColor: _surface,
      onRefresh: _loadPeople,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _suggestedUsers.length,
        itemBuilder: (context, i) =>
            _UserCard(user: _suggestedUsers[i]),
      ),
    );
  }

  // ── Grid skeleton ──────────────────────────────────────────────────────────

  Widget _buildGridSkeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sw = constraints.maxWidth;
        final tileH = sw / 3;

        Widget skeletonPad() => Padding(
              padding: const EdgeInsets.all(_gap / 2),
              child: _SkeletonBox(radius: 0),
            );

        // Alterna: fila featured (1 grande + 2 chicos apilados) y fila normal (3 iguales)
        final rows = <Widget>[];
        for (int i = 0; i < 3; i++) {
          final featuredLeft = i.isEven;
          final featured = SizedBox(
            width: sw * 2 / 3,
            height: tileH * 2,
            child: skeletonPad(),
          );
          final smallCol = SizedBox(
            width: sw / 3,
            child: Column(children: [
              SizedBox(height: tileH, child: skeletonPad()),
              SizedBox(height: tileH, child: skeletonPad()),
            ]),
          );
          rows.add(Row(
            children: featuredLeft
                ? [featured, smallCol]
                : [smallCol, featured],
          ));
          rows.add(Row(
            children: List.generate(
              3,
              (_) => SizedBox(
                width: sw / 3,
                height: tileH,
                child: skeletonPad(),
              ),
            ),
          ));
        }

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        );
      },
    );
  }

  // ── Search results ─────────────────────────────────────────────────────────

  Widget _buildSearchResults() {
    if (_query.isEmpty) return _buildSearchSuggestions();

    if (_loadingSearch) {
      return const Center(
        child: CircularProgressIndicator(color: _teal, strokeWidth: 2),
      );
    }

    if (_userResults.isEmpty && _postResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: _white40),
            const SizedBox(height: 12),
            Text(
              'Sin resultados para "$_query"',
              style: const TextStyle(color: _white70, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      children: [
        if (_userResults.isNotEmpty) ...[
          _SearchSectionHeader('Personas'),
          ..._userResults.map((u) => _SearchUserTile(user: u)),
        ],
        if (_postResults.isNotEmpty) ...[
          _SearchSectionHeader('Publicaciones'),
          ..._postResults.map(
            (p) => _SearchPostTile(post: p, onTap: () => _onTileTap(p)),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchSuggestions() {
    const suggestions = [
      'Migrantes en México DF',
      'Visa de trabajo España',
      'Comunidad argentina en Europa',
      'Networking nómadas digitales',
      'Seguro médico extranjero',
      'NIE trámites',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.trending_up_rounded, size: 14, color: _teal),
              const SizedBox(width: 6),
              const Text(
                'TENDENCIAS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _teal,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        ...suggestions.map(
          (s) => _SuggestionTile(
            text: s,
            onTap: () {
              _searchCtrl.text = s;
              _search(s);
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staggered post grid sliver
// ─────────────────────────────────────────────────────────────────────────────
// Patrón por bloques de 6:
//   Bloque par  → [featured izq 2/3] | [small top] / [small bottom]
//                 [small] | [small] | [small]
//   Bloque impar → [small top] / [small bottom] | [featured der 2/3]
//                  [small] | [small] | [small]

class _StaggeredPostSliver extends StatelessWidget {
  final List<PostModel> posts;
  final void Function(PostModel) onTap;

  const _StaggeredPostSliver({required this.posts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final blockCount = (posts.length / 6).ceil();
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, blockIdx) {
          final start = blockIdx * 6;
          if (start >= posts.length) return null;
          final chunk =
              posts.sublist(start, math.min(start + 6, posts.length));
          return _buildBlock(context, chunk, blockIdx.isEven);
        },
        childCount: blockCount,
      ),
    );
  }

  Widget _buildBlock(
    BuildContext context,
    List<PostModel> chunk,
    bool featuredLeft,
  ) {
    final sw = MediaQuery.of(context).size.width;
    final smallH = sw / 3;
    final bigH = smallH * 2;
    final bigW = sw * 2 / 3;

    Widget featuredTile = chunk.isNotEmpty
        ? _PostTile(
            post: chunk[0],
            width: bigW,
            height: bigH,
            featured: true,
            onTap: onTap,
          )
        : SizedBox(width: bigW, height: bigH);

    Widget smallStack = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (chunk.length > 1)
          _PostTile(post: chunk[1], width: sw / 3, height: smallH, onTap: onTap),
        if (chunk.length > 2)
          _PostTile(post: chunk[2], width: sw / 3, height: smallH, onTap: onTap),
        if (chunk.length < 3) SizedBox(height: smallH * (3 - chunk.length)),
      ],
    );

    Widget topRow = featuredLeft
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [featuredTile, Expanded(child: smallStack)],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: smallStack), featuredTile],
          );

    Widget bottomRow = Row(
      children: [
        for (int i = 3; i < 6; i++)
          if (i < chunk.length)
            _PostTile(post: chunk[i], width: sw / 3, height: smallH, onTap: onTap)
          else
            SizedBox(width: sw / 3, height: smallH),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        topRow,
        if (chunk.length > 3) bottomRow,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post tile
// ─────────────────────────────────────────────────────────────────────────────

class _PostTile extends StatelessWidget {
  final PostModel post;
  final double width;
  final double height;
  final bool featured;
  final void Function(PostModel) onTap;

  const _PostTile({
    required this.post,
    required this.width,
    required this.height,
    required this.onTap,
    this.featured = false,
  });

  bool get _isVideo => post.type == 'video';

  @override
  Widget build(BuildContext context) {
    final hasImage = post.images.isNotEmpty;

    return GestureDetector(
      onTap: () => onTap(post),
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(_gap / 2),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagen o fondo degradado
              hasImage
                  ? Image.network(
                      post.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _GradientFallback(post: post),
                    )
                  : _GradientFallback(post: post),

              // Overlay oscuro en la parte inferior
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: featured ? 80 : 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Ícono de video
              if (_isVideo)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),

              // Carrusel (múltiples imágenes)
              if (post.images.length > 1)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.copy_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),

              // Info inferior
              Positioned(
                left: 8,
                right: 8,
                bottom: 6,
                child: Row(
                  children: [
                    if (post.countryFlag != null) ...[
                      Text(
                        post.countryFlag!,
                        style: TextStyle(fontSize: featured ? 16 : 11),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (featured && post.city != null)
                      Expanded(
                        child: Text(
                          post.city!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const Spacer(),
                    if (post.likesCount > 0) ...[
                      const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _formatCount(post.likesCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient fallback (cuando no hay imagen)
// ─────────────────────────────────────────────────────────────────────────────

class _GradientFallback extends StatelessWidget {
  final PostModel post;
  const _GradientFallback({required this.post});

  static const _gradients = [
    [Color(0xFF134E4A), Color(0xFF0D9488)],
    [Color(0xFF1E1B4B), Color(0xFF4338CA)],
    [Color(0xFF1C1917), Color(0xFF78350F)],
    [Color(0xFF0F172A), Color(0xFF0891B2)],
    [Color(0xFF14532D), Color(0xFF16A34A)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors =
        _gradients[post.authorId.hashCode.abs() % _gradients.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        post.caption,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fullscreen viewer
// ─────────────────────────────────────────────────────────────────────────────

class _FullscreenViewer extends StatefulWidget {
  final PostModel post;
  final VoidCallback onClose;
  final VoidCallback onLike;

  const _FullscreenViewer({
    required this.post,
    required this.onClose,
    required this.onLike,
  });

  @override
  State<_FullscreenViewer> createState() => _FullscreenViewerState();
}

class _FullscreenViewerState extends State<_FullscreenViewer> {
  bool _liked = false;
  int _imageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Imagen principal
          if (post.images.isNotEmpty)
            Positioned.fill(
              child: PageView.builder(
                itemCount: post.images.length,
                onPageChanged: (i) => setState(() => _imageIndex = i),
                itemBuilder: (_, i) => Image.network(
                  post.images[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      _GradientFallback(post: post),
                ),
              ),
            )
          else
            Positioned.fill(child: _GradientFallback(post: post)),

          // Gradient inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.92),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Info del post
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Autor
                Row(
                  children: [
                    _UserAvatar(
                      flag: post.countryFlag,
                      username: post.username,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '@${post.username}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (post.city != null) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: _white70,
                      ),
                      Text(
                        post.city!,
                        style: const TextStyle(
                          color: _white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                if (post.caption.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    post.caption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Indicador de páginas
                if (post.images.length > 1) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(post.images.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _imageIndex == i ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _imageIndex == i
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),

          // Acciones laterales (like, comentar)
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                _ActionButton(
                  icon: _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _liked ? Colors.red : Colors.white,
                  label: _formatCount(
                    post.likesCount + (_liked ? 1 : 0),
                  ),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _liked = !_liked);
                    if (_liked) widget.onLike();
                  },
                ),
                const SizedBox(height: 20),
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  label: _formatCount(post.commentsCount),
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                _ActionButton(
                  icon: Icons.share_outlined,
                  color: Colors.white,
                  label: '',
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Botón cerrar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User card (tab Personas)
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatefulWidget {
  final Map<String, dynamic> user;
  const _UserCard({required this.user});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _following = false;
  final _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final flag = u['countryFlag'] as String? ?? '';
    final username = u['username'] as String? ?? '';
    final city = u['city'] as String? ??
        u['ciudadActual'] as String? ?? '';
    final isMe = u['uid'] == _myUid;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _UserAvatar(flag: flag, username: username, size: 56),
          const SizedBox(height: 10),
          Text(
            '@$username',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (city.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              city,
              style: const TextStyle(color: _white40, fontSize: 11.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          if (!isMe)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _following = !_following);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _following ? _surface : _teal,
                  borderRadius: BorderRadius.circular(20),
                  border: _following
                      ? Border.all(
                          color: _teal.withValues(alpha: 0.5),
                        )
                      : null,
                ),
                child: Text(
                  _following ? 'Siguiendo' : 'Seguir',
                  style: TextStyle(
                    color: _following ? _teal : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search result tiles
// ─────────────────────────────────────────────────────────────────────────────

class _SearchSectionHeader extends StatelessWidget {
  final String title;
  const _SearchSectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _teal,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SearchUserTile extends StatefulWidget {
  final Map<String, dynamic> user;
  const _SearchUserTile({required this.user});

  @override
  State<_SearchUserTile> createState() => _SearchUserTileState();
}

class _SearchUserTileState extends State<_SearchUserTile> {
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final flag = u['countryFlag'] as String? ?? '';
    final username = u['username'] as String? ?? '';
    final city = u['city'] as String? ?? u['ciudadActual'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _UserAvatar(flag: flag, username: username, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$username',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (city.isNotEmpty)
                  Text(
                    city,
                    style: const TextStyle(color: _white40, fontSize: 12),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _following = !_following);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _following ? _surface : _teal,
                borderRadius: BorderRadius.circular(20),
                border: _following
                    ? Border.all(color: _teal.withValues(alpha: 0.5))
                    : null,
              ),
              child: Text(
                _following ? 'Siguiendo' : 'Seguir',
                style: TextStyle(
                  color: _following ? _teal : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPostTile extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;

  const _SearchPostTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 62,
                height: 62,
                child: post.images.isNotEmpty
                    ? Image.network(
                        post.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _GradientFallback(post: post),
                      )
                    : _GradientFallback(post: post),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${post.username}',
                    style: const TextStyle(
                      color: _teal,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    post.caption,
                    style: const TextStyle(color: _white70, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionTile({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.north_east_rounded, size: 16, color: _white40),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: _white70, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User avatar
// ─────────────────────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  final String? flag;
  final String username;
  final double size;

  const _UserAvatar({required this.flag, required this.username, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_tealDim, _teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: flag != null && flag!.isNotEmpty
            ? Text(flag!, style: TextStyle(fontSize: size * 0.45))
            : Text(
                username.isNotEmpty
                    ? username[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.4,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonBox extends StatefulWidget {
  final double radius;
  const _SkeletonBox({required this.radius});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.06, end: 0.14).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TabBar persistent header delegate
// ─────────────────────────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  const _TabBarDelegate(this.tabBar, {required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          tabBar,
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => tabBar != old.tabBar;
}

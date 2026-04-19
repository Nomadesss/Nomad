import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'chat_screen.dart';

const _teal = Color(0xFF0D9488);
const _tealDark = Color(0xFF134E4A);
const _tealBg = Color(0xFFF0FAF9);
const _bg = Color(0xFFF5F6FA);

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _myId = FirebaseAuth.instance.currentUser?.uid;
  String _query = '';

  List<_UserResult> _recentUsers = [];
  List<String> _followingIds = [];
  bool _loadingRecents = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadRecentContacts(), _loadFollowingIds()]);
  }

  Future<void> _loadFollowingIds() async {
    if (_myId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('follows')
          .where('followerId', isEqualTo: _myId)
          .get();
      if (mounted) {
        setState(() {
          _followingIds = snap.docs
              .map((d) => d.data()['followingId'] as String? ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRecentContacts() async {
    if (_myId == null) {
      setState(() => _loadingRecents = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('chats')
          .where('participantIds', arrayContains: _myId)
          .orderBy('lastMessageAt', descending: true)
          .limit(10)
          .get();

      final futures = snap.docs.map((doc) async {
        final ids = List<String>.from(
          doc.data()['participantIds'] as List? ?? [],
        );
        final otherId = ids.firstWhere((id) => id != _myId, orElse: () => '');
        if (otherId.isEmpty) return null;
        return _fetchUser(otherId);
      });

      final results = await Future.wait(futures);
      if (mounted)
        setState(() {
          _recentUsers = results.whereType<_UserResult>().toList();
          _loadingRecents = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingRecents = false);
    }
  }

  Future<_UserResult?> _fetchUser(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return _UserResult.fromDoc(uid, doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Stream<List<_UserResult>> _searchStream(String query) {
    if (query.isEmpty) return const Stream.empty();
    final q = query.toLowerCase();
    return FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: q)
        .where('username', isLessThan: '${q}z')
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs
              .where((d) => d.id != _myId)
              .map((d) => _UserResult.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  void _openChat(_UserResult user) {
    if (_myId == null) return;
    final ids = [_myId!, user.uid]..sort();
    final chatId = '${ids[0]}_${ids[1]}';
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserId: user.uid,
          otherUsername: user.username.isNotEmpty ? user.username : user.name,
          otherAvatarUrl: user.avatar,
          otherName: user.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // Gradient: solo el título
          _Header(onBack: () => Navigator.pop(context)),
          // Buscador: franja blanca con pill de borde teal
          _SearchBarSection(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            query: _query,
            onChanged: (v) => setState(() => _query = v.trim()),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _query = '');
            },
          ),
          Expanded(
            child: _query.isEmpty
                ? _RecentAndSuggestions(
                    recentUsers: _recentUsers,
                    followingIds: _followingIds,
                    loadingRecents: _loadingRecents,
                    myId: _myId ?? '',
                    onTap: _openChat,
                  )
                : _SearchResults(
                    stream: _searchStream(_query),
                    query: _query,
                    onTap: _openChat,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — solo el gradiente con el título
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(4, top + 6, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Colors.white,
            ),
            onPressed: onBack,
          ),
          const SizedBox(width: 2),
          const Text(
            'Nueva conversación',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SearchBar — franja blanca con pill de borde teal y autofocus
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBarSection extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final void Function(String) onChanged;
  final VoidCallback onClear;

  const _SearchBarSection({
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_SearchBarSection> createState() => _SearchBarSectionState();
}

class _SearchBarSectionState extends State<_SearchBarSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.focusNode.requestFocus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _teal, width: 1.5),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search_rounded, size: 20, color: Colors.grey.shade400),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                onChanged: widget.onChanged,
                style: const TextStyle(fontSize: 15, color: _tealDark),
                cursorColor: _teal,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o @usuario…',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (widget.query.isNotEmpty)
              GestureDetector(
                onTap: widget.onClear,
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recientes + Seguidos + Sugerencias
// ─────────────────────────────────────────────────────────────────────────────

class _RecentAndSuggestions extends StatelessWidget {
  final List<_UserResult> recentUsers;
  final List<String> followingIds;
  final bool loadingRecents;
  final String myId;
  final void Function(_UserResult) onTap;

  const _RecentAndSuggestions({
    required this.recentUsers,
    required this.followingIds,
    required this.loadingRecents,
    required this.myId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingRecents) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => const _UserTileSkeleton(),
      );
    }

    // IDs ya mostrados en "Recientes" — no repetirlos en Seguidos ni Sugerencias
    final recentIds = recentUsers.map((u) => u.uid).toSet();
    // Seguidos que NO están ya en Recientes
    final filteredFollowingIds = followingIds
        .where((id) => !recentIds.contains(id))
        .toList();
    // Todo lo que ya se muestra (para excluir de Sugerencias)
    final shownIds = <String>{...recentIds, ...filteredFollowingIds};

    return CustomScrollView(
      slivers: [
        // 1. Recientes
        if (recentUsers.isNotEmpty) ...[
          SliverToBoxAdapter(child: _SectionLabel(label: 'Recientes')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _UserCard(
                    user: recentUsers[i],
                    onTap: () => onTap(recentUsers[i]),
                  ),
                ),
                childCount: recentUsers.length,
              ),
            ),
          ),
        ],

        // 2. Personas que seguís (sin repetir los que ya están en Recientes)
        if (filteredFollowingIds.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionLabel(label: 'Personas que seguís'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _FollowingUsers(
                followingIds: filteredFollowingIds,
                myId: myId,
                onTap: onTap,
              ),
            ),
          ),
        ],

        // 3. Sugerencias (excluyendo los ya mostrados)
        SliverToBoxAdapter(child: _SectionLabel(label: 'Sugerencias')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverToBoxAdapter(
            child: _SuggestedUsers(
              myId: myId,
              excludeIds: shownIds,
              onTap: onTap,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Personas que seguís
// ─────────────────────────────────────────────────────────────────────────────

class _FollowingUsers extends StatelessWidget {
  final List<String> followingIds;
  final String myId;
  final void Function(_UserResult) onTap;

  const _FollowingUsers({
    required this.followingIds,
    required this.myId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_UserResult>>(
      future: _loadFollowing(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Column(
            children: List.generate(
              followingIds.length.clamp(0, 3),
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: _UserTileSkeleton(),
              ),
            ),
          );
        }
        final users = snap.data ?? [];
        if (users.isEmpty) return const SizedBox.shrink();
        return Column(
          children: users
              .map(
                (u) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _UserCard(user: u, onTap: () => onTap(u)),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<List<_UserResult>> _loadFollowing() async {
    final results = <_UserResult>[];
    // Cargar en lotes de 10 (límite de Firestore whereIn)
    final chunks = <List<String>>[];
    for (int i = 0; i < followingIds.length; i += 10) {
      chunks.add(
        followingIds.sublist(i, (i + 10).clamp(0, followingIds.length)),
      );
    }
    for (final chunk in chunks) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          results.add(_UserResult.fromDoc(doc.id, doc.data()));
        }
      } catch (_) {}
    }
    return results;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sugerencias (excluye recientes y seguidos)
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestedUsers extends StatelessWidget {
  final String myId;
  final Set<String> excludeIds;
  final void Function(_UserResult) onTap;

  const _SuggestedUsers({
    required this.myId,
    required this.excludeIds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(40)
          .snapshots(),
      builder: (_, snap) {
        final docs =
            snap.data?.docs
                .where((d) => d.id != myId && !excludeIds.contains(d.id))
                .toList() ??
            [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(
          children: docs.map((doc) {
            final user = _UserResult.fromDoc(
              doc.id,
              doc.data() as Map<String, dynamic>,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _UserCard(user: user, onTap: () => onTap(user)),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resultados de búsqueda
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  final Stream<List<_UserResult>> stream;
  final String query;
  final void Function(_UserResult) onTap;

  const _SearchResults({
    required this.stream,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<_UserResult>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, __) => const _UserTileSkeleton(),
          );
        }
        final results = snap.data ?? [];
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: _tealBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search_off_rounded,
                      size: 34,
                      color: _teal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sin resultados para "$query"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _tealDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Probá con el nombre completo\no el usuario exacto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _UserCard(
            user: results[i],
            onTap: () => onTap(results[i]),
            highlightQuery: query,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de usuario
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final _UserResult user;
  final VoidCallback onTap;
  final String highlightQuery;

  const _UserCard({
    required this.user,
    required this.onTap,
    this.highlightQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    final initials = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: _tealBg,
        highlightColor: _tealBg.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFCCFBF1),
                backgroundImage: user.avatar != null
                    ? NetworkImage(user.avatar!)
                    : null,
                child: user.avatar == null
                    ? Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _teal,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HighlightText(
                      text: user.name,
                      query: highlightQuery,
                      baseStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _tealDark,
                      ),
                    ),
                    if (user.username.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      _HighlightText(
                        text: '@${user.username}',
                        query: highlightQuery,
                        baseStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                    if (user.country != null && user.country!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '📍 ${user.country}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: _tealBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: _teal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Label de sección
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: _teal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _teal,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Highlight texto buscado
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle baseStyle;

  const _HighlightText({
    required this.text,
    required this.query,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: baseStyle);
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query.toLowerCase());
    if (idx < 0) return Text(text, style: baseStyle);
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: baseStyle.copyWith(
              color: _teal,
              fontWeight: FontWeight.w800,
              backgroundColor: _tealBg,
            ),
          ),
          if (idx + query.length < text.length)
            TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton
// ─────────────────────────────────────────────────────────────────────────────

class _UserTileSkeleton extends StatefulWidget {
  const _UserTileSkeleton();

  @override
  State<_UserTileSkeleton> createState() => _UserTileSkeletonState();
}

class _UserTileSkeletonState extends State<_UserTileSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.35,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _box(w: 52, h: 52, circle: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(w: 140, h: 13),
                    const SizedBox(height: 7),
                    _box(w: 90, h: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box({required double w, required double h, bool circle = false}) =>
      Container(
        width: w,
        height: h,
        decoration: circle
            ? const BoxDecoration(
                color: Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              )
            : BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo
// ─────────────────────────────────────────────────────────────────────────────

class _UserResult {
  final String uid;
  final String name;
  final String username;
  final String? avatar;
  final String? country;

  const _UserResult({
    required this.uid,
    required this.name,
    required this.username,
    this.avatar,
    this.country,
  });

  factory _UserResult.fromDoc(String uid, Map<String, dynamic> d) {
    final rawName = (d['displayName'] as String?)?.trim();
    final rawNombre = (d['name'] as String?)?.trim();
    return _UserResult(
      uid: uid,
      name: (rawName?.isNotEmpty == true ? rawName : rawNombre) ?? 'Usuario',
      username: (d['username'] as String?) ?? '',
      avatar: d['photoURL'] as String?,
      country: d['country'] as String?,
    );
  }
}

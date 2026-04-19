import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../app_theme.dart';
import '../../../services/social_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Categorías del foro
// ─────────────────────────────────────────────────────────────────────────────

class _ForumCategory {
  final String id;
  final String label;
  final String emoji;
  final Color color;

  const _ForumCategory({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
  });
}

const _categories = [
  _ForumCategory(id: 'all',        label: 'Todo',         emoji: '🌍', color: Color(0xFF0D9488)),
  _ForumCategory(id: 'general',    label: 'General',      emoji: '💬', color: Color(0xFF6B7280)),
  _ForumCategory(id: 'visas',      label: 'Visas',        emoji: '📋', color: Color(0xFF8B5CF6)),
  _ForumCategory(id: 'alojamiento',label: 'Alojamiento',  emoji: '🏠', color: Color(0xFF3B82F6)),
  _ForumCategory(id: 'trabajo',    label: 'Trabajo',      emoji: '💼', color: Color(0xFFF59E0B)),
  _ForumCategory(id: 'salud',      label: 'Salud',        emoji: '🏥', color: Color(0xFFEF4444)),
  _ForumCategory(id: 'idiomas',    label: 'Idiomas',      emoji: '📚', color: Color(0xFF10B981)),
  _ForumCategory(id: 'social',     label: 'Social',       emoji: '🎉', color: Color(0xFFEC4899)),
  _ForumCategory(id: 'consejos',   label: 'Consejos',     emoji: '💡', color: Color(0xFFEAB308)),
];

_ForumCategory _catById(String id) =>
    _categories.firstWhere((c) => c.id == id, orElse: () => _categories[1]);

// ─────────────────────────────────────────────────────────────────────────────
// SocialScreen — Tabs: Foro + Grupos
// ─────────────────────────────────────────────────────────────────────────────

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _activeCat = 'all';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [_buildAppBar()],
        body: TabBarView(
          controller: _tabs,
          children: [
            _ForumTab(activeCat: _activeCat, onCatChanged: (c) => setState(() => _activeCat = c)),
            const _GruposTab(),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: NomadColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Nueva publicación',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              onPressed: () => _showCreatePost(context),
            )
          : FloatingActionButton.extended(
              backgroundColor: NomadColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.group_add_rounded, size: 18),
              label: const Text('Crear grupo',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              onPressed: () => _showCreateGroup(context),
            ),
    );
  }

  void _showCreateGroup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateGroupSheet(),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: NomadColors.feedIconColor),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Comunidad',
        style: TextStyle(
          color: NomadColors.feedIconColor,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: false,
      bottom: TabBar(
        controller: _tabs,
        labelColor: NomadColors.primary,
        unselectedLabelColor: Colors.grey.shade400,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
        indicatorColor: NomadColors.primary,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(text: 'Foro'),
          Tab(text: 'Grupos'),
        ],
      ),
    );
  }

  void _showCreatePost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreatePostSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ForumTab — feed principal del foro
// ─────────────────────────────────────────────────────────────────────────────

class _ForumTab extends StatelessWidget {
  final String activeCat;
  final ValueChanged<String> onCatChanged;

  const _ForumTab({required this.activeCat, required this.onCatChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CategoryBar(activeCat: activeCat, onChanged: onCatChanged),
        Expanded(
          child: StreamBuilder<List<ForumPost>>(
            stream: ForumService.streamPosts(
              category: activeCat == 'all' ? null : activeCat,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeletons();
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error al cargar',
                      style: TextStyle(color: Colors.grey.shade400)),
                );
              }

              final posts = (snapshot.data ?? [])
                  .where((p) => !p.flagged || p.authorId == FirebaseAuth.instance.currentUser?.uid)
                  .toList();

              if (posts.isEmpty) return _buildEmpty();

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                itemCount: posts.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (context, i) => _PostCard(
                  post: posts[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForumPostDetailScreen(post: posts[i]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletons() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (_, __) => const _PostSkeleton(),
    );
  }

  Widget _buildEmpty() {
    final cat = _catById(activeCat);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat.emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              activeCat == 'all'
                  ? 'Sé el primero en publicar'
                  : 'Sin publicaciones en ${cat.label}',
              style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: NomadColors.feedIconColor, letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Compartí tu experiencia, hacé una\npregunta o ayudá a otros nomads.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CategoryBar
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  final String activeCat;
  final ValueChanged<String> onChanged;

  const _CategoryBar({required this.activeCat, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final active = cat.id == activeCat;
          return GestureDetector(
            onTap: () => onChanged(cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? cat.color : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PostCard — tarjeta de post en el feed
// ─────────────────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final ForumPost post;
  final VoidCallback onTap;

  const _PostCard({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    final cat = _catById(post.category);
    final initials = post.authorUsername.isNotEmpty
        ? post.authorUsername[0].toUpperCase()
        : '?';
    final timeAgo = _formatAgo(post.createdAt);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFFF0FDFB),
        highlightColor: const Color(0xFFF0FDFB).withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: avatar + autor + categoría + tiempo ────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFCCFBF1),
                    backgroundImage: post.authorAvatarUrl != null
                        ? NetworkImage(post.authorAvatarUrl!)
                        : null,
                    child: post.authorAvatarUrl == null
                        ? Text(initials,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: NomadColors.primary))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '@${post.authorUsername}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: NomadColors.feedIconColor),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(
                                color: cat.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${cat.emoji} ${cat.label}',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: cat.color),
                              ),
                            ),
                          ],
                        ),
                        Text(timeAgo,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                  _PostMenu(post: post),
                ],
              ),
              const SizedBox(height: 10),

              // ── Título ────────────────────────────────────────────────────
              if (post.pinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.push_pin_rounded, size: 12, color: NomadColors.primary),
                      const SizedBox(width: 4),
                      Text('Destacado',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: NomadColors.primary)),
                    ],
                  ),
                ),
              Text(
                post.title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: NomadColors.feedIconColor,
                    letterSpacing: -0.2,
                    height: 1.35),
              ),
              if (post.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  post.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5),
                ),
              ],

              // ── Flagged warning ────────────────────────────────────────────
              if (post.flagged)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Esta publicación está en revisión.',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // ── Footer: upvotes + replies ──────────────────────────────────
              Row(
                children: [
                  _UpvoteButton(
                    postId: post.docId,
                    upvotes: post.upvotes,
                    upvotedByMe: myId != null && post.upvotedBy.contains(myId),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 5),
                  Text('${post.repliesCount}',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UpvoteButton — con estado local optimista
// ─────────────────────────────────────────────────────────────────────────────

class _UpvoteButton extends StatefulWidget {
  final String postId;
  final int upvotes;
  final bool upvotedByMe;

  const _UpvoteButton({
    required this.postId,
    required this.upvotes,
    required this.upvotedByMe,
  });

  @override
  State<_UpvoteButton> createState() => _UpvoteButtonState();
}

class _UpvoteButtonState extends State<_UpvoteButton>
    with SingleTickerProviderStateMixin {
  late bool _voted;
  late int _count;
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _voted = widget.upvotedByMe;
    _count = widget.upvotes;
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1, end: 1.3)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _voted = !_voted;
      _count += _voted ? 1 : -1;
    });
    _ctrl.forward().then((_) => _ctrl.reverse());
    await ForumService.toggleUpvotePost(widget.postId);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Row(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(
              _voted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
              size: 17,
              color: _voted ? NomadColors.primary : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _count > 0 ? '$_count' : 'Me gusta',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _voted ? NomadColors.primary : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PostMenu — 3 puntos con opciones de reporte y eliminación
// ─────────────────────────────────────────────────────────────────────────────

class _PostMenu extends StatelessWidget {
  final ForumPost post;

  const _PostMenu({required this.post});

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    final isOwn = myId == post.authorId;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, color: Colors.grey.shade400, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) => _onSelect(context, v),
      itemBuilder: (_) => [
        if (!isOwn)
          const PopupMenuItem(
            value: 'report',
            child: Row(children: [
              Icon(Icons.flag_outlined, size: 18, color: Colors.orange),
              SizedBox(width: 10),
              Text('Reportar', style: TextStyle(fontSize: 14)),
            ]),
          ),
        if (isOwn)
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 18, color: NomadColors.primary),
              SizedBox(width: 10),
              Text('Editar', style: TextStyle(fontSize: 14)),
            ]),
          ),
        if (isOwn)
          const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              SizedBox(width: 10),
              Text('Eliminar', style: TextStyle(fontSize: 14, color: Colors.red)),
            ]),
          ),
        const PopupMenuItem(
          value: 'copy',
          child: Row(children: [
            Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
            SizedBox(width: 10),
            Text('Copiar texto', style: TextStyle(fontSize: 14)),
          ]),
        ),
      ],
    );
  }

  Future<void> _onSelect(BuildContext context, String value) async {
    switch (value) {
      case 'report':
        _showReportDialog(context);
        break;
      case 'edit':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _EditPostSheet(post: post),
        );
        break;
      case 'delete':
        await FirebaseFirestore.instance
            .collection('forum_posts')
            .doc(post.docId)
            .update({'removed': true});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Publicación eliminada')),
          );
        }
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: '${post.title}\n\n${post.body}'));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Texto copiado')),
          );
        }
        break;
    }
  }

  void _showReportDialog(BuildContext context) {
    final reasons = [
      'Contenido ilegal o dañino',
      'Spam o publicidad',
      'Información falsa',
      'Acoso o lenguaje ofensivo',
      'Otro motivo',
    ];
    String? selected;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Reportar publicación',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map((r) => RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: NomadColors.primary,
                      title: Text(r, style: const TextStyle(fontSize: 13)),
                      value: r,
                      groupValue: selected,
                      onChanged: (v) => setS(() => selected = v),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: NomadColors.primary),
              onPressed: selected == null
                  ? null
                  : () async {
                      await ForumService.reportContent(
                        targetId: post.docId,
                        targetType: 'post',
                        reason: selected!,
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reporte enviado. Gracias por ayudar.'),
                          ),
                        );
                      }
                    },
              child: const Text('Enviar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ForumPostDetailScreen — hilo completo con respuestas
// ─────────────────────────────────────────────────────────────────────────────

class ForumPostDetailScreen extends StatefulWidget {
  final ForumPost post;

  const ForumPostDetailScreen({super.key, required this.post});

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;

    // Moderación
    if (ForumService.containsIllegalContent(text)) {
      _showModerationWarning(text);
      return;
    }

    setState(() => _sending = true);
    _replyCtrl.clear();
    final err = await ForumService.addReply(postId: widget.post.docId, body: text);
    setState(() => _sending = false);

    if (err != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _showModerationWarning(String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.shield_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Text('Contenido detectado',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'Tu mensaje puede contener contenido inapropiado o ilegal. '
          'Por favor revisá el texto antes de publicar.\n\n'
          'Si creés que es un error, contactanos.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Revisar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = _catById(widget.post.category);
    final myId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20,
              color: NomadColors.feedIconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${cat.emoji} ${cat.label}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: cat.color),
              ),
            ),
          ],
        ),
        actions: [
          _PostMenu(post: widget.post),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ForumReply>>(
              stream: ForumService.streamReplies(widget.post.docId),
              builder: (context, snap) {
                final replies = snap.data ?? [];
                final hasReplies = replies.isNotEmpty;
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: 1 + (hasReplies ? 1 : 0) + replies.length,
                  itemBuilder: (context, i) {
                    if (i == 0) return _buildPostBody(myId, liveReplyCount: replies.length);
                    if (hasReplies && i == 1) return _buildRepliesHeader(replies.length);
                    final rIdx = hasReplies ? i - 2 : i - 1;
                    return _ReplyTile(
                      reply: replies[rIdx],
                      postId: widget.post.docId,
                    );
                  },
                );
              },
            ),
          ),
          _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildRepliesHeader(int count) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, size: 16, color: NomadColors.primary),
          const SizedBox(width: 8),
          Text(
            count == 1 ? '1 respuesta' : '$count respuestas',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: NomadColors.primary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostBody(String? myId, {int liveReplyCount = 0}) {
    final p = widget.post;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Autor
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFCCFBF1),
                backgroundImage: p.authorAvatarUrl != null
                    ? NetworkImage(p.authorAvatarUrl!)
                    : null,
                child: p.authorAvatarUrl == null
                    ? Text(
                        p.authorUsername[0].toUpperCase(),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: NomadColors.primary))
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${p.authorUsername}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: NomadColors.feedIconColor)),
                  Text(_formatAgo(p.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            p.title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: NomadColors.feedIconColor,
                letterSpacing: -0.4,
                height: 1.3),
          ),
          if (p.body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              p.body,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade700, height: 1.65),
            ),
          ],
          if (p.flagged)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Esta publicación está en revisión por nuestro equipo.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              _UpvoteButton(
                postId: p.docId,
                upvotes: p.upvotes,
                upvotedByMe: myId != null && p.upvotedBy.contains(myId),
              ),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 5),
              Text(
                liveReplyCount == 1 ? '1 respuesta' : '$liveReplyCount respuestas',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Escribí tu respuesta…',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sending ? null : _sendReply,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _sending ? Colors.grey.shade300 : NomadColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReplyTile
// ─────────────────────────────────────────────────────────────────────────────

class _ReplyTile extends StatelessWidget {
  final ForumReply reply;
  final String postId;

  const _ReplyTile({required this.reply, required this.postId});

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    final initials = reply.authorUsername.isNotEmpty
        ? reply.authorUsername[0].toUpperCase()
        : '?';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Línea vertical izquierda
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFE0F2FE),
                backgroundImage: reply.authorAvatarUrl != null
                    ? NetworkImage(reply.authorAvatarUrl!)
                    : null,
                child: reply.authorAvatarUrl == null
                    ? Text(initials,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0369A1)))
                    : null,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '@${reply.authorUsername}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: NomadColors.feedIconColor),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatAgo(reply.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, size: 18, color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) async {
                        if (v == 'report') {
                          await ForumService.reportContent(
                            targetId: reply.docId,
                            targetType: 'reply',
                            reason: 'Reportado por usuario',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reporte enviado. Gracias por ayudarnos.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } else if (v == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text('Eliminar respuesta',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              content: const Text(
                                  '¿Eliminar esta respuesta? No se puede deshacer.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text('Eliminar',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await FirebaseFirestore.instance
                                .collection('forum_posts')
                                .doc(postId)
                                .collection('replies')
                                .doc(reply.docId)
                                .delete();
                            await FirebaseFirestore.instance
                                .collection('forum_posts')
                                .doc(postId)
                                .update({
                              'repliesCount': FieldValue.increment(-1),
                            });
                          }
                        } else if (v == 'edit') {
                          final ctrl = TextEditingController(text: reply.body);
                          final newText = await showDialog<String>(
                            context: context,
                            builder: (d) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text('Editar respuesta',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              content: TextField(
                                controller: ctrl,
                                maxLines: 5,
                                minLines: 2,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(d, ctrl.text.trim()),
                                  child: const Text('Guardar',
                                      style: TextStyle(
                                          color: NomadColors.primary,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          );
                          if (newText != null && newText.isNotEmpty) {
                            await FirebaseFirestore.instance
                                .collection('forum_posts')
                                .doc(postId)
                                .collection('replies')
                                .doc(reply.docId)
                                .update({'body': newText});
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        if (myId == reply.authorId) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_outlined, size: 16, color: NomadColors.primary),
                              SizedBox(width: 8),
                              Text('Editar', style: TextStyle(fontSize: 13)),
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Eliminar',
                                  style: TextStyle(fontSize: 13, color: Colors.red)),
                            ]),
                          ),
                        ],
                        if (myId != null && myId != reply.authorId)
                          const PopupMenuItem(
                            value: 'report',
                            child: Row(children: [
                              Icon(Icons.flag_outlined, size: 16, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Reportar', style: TextStyle(fontSize: 13)),
                            ]),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.body,
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade700, height: 1.55),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => ForumService.toggleUpvoteReply(postId, reply.docId),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        myId != null && reply.upvotedBy.contains(myId)
                            ? Icons.thumb_up_rounded
                            : Icons.thumb_up_outlined,
                        size: 14,
                        color: myId != null && reply.upvotedBy.contains(myId)
                            ? NomadColors.primary
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        reply.upvotes > 0 ? '${reply.upvotes}' : 'Me gusta',
                        style: TextStyle(
                          fontSize: 12,
                          color: myId != null && reply.upvotedBy.contains(myId)
                              ? NomadColors.primary
                              : Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CreatePostSheet — bottom sheet para nueva publicación
// ─────────────────────────────────────────────────────────────────────────────

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet();

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _selectedCat = 'general';
  bool _publishing = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  bool get _canPost =>
      _titleCtrl.text.trim().length >= 5 && !_publishing;

  Future<void> _publish() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    // Moderación automática
    if (ForumService.containsIllegalContent('$title $body')) {
      _showModerationBlock();
      return;
    }

    setState(() => _publishing = true);
    final err = await ForumService.createPost(
      category: _selectedCat,
      title: title,
      body: body,
    );
    setState(() => _publishing = false);

    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Publicación creada!'),
          backgroundColor: NomadColors.primary,
        ),
      );
    }
  }

  void _showModerationBlock() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.shield_rounded, color: Colors.red),
          SizedBox(width: 10),
          Text('Contenido no permitido',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'Tu publicación contiene términos asociados a actividades ilegales '
          'y no puede ser enviada.\n\n'
          'Nomad es un espacio de ayuda para migrantes. '
          'Cualquier contenido ilegal será reportado.',
          style: TextStyle(fontSize: 13, height: 1.55),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NomadColors.primary),
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nueva publicación',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: NomadColors.feedIconColor,
                        letterSpacing: -0.3)),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: _canPost ? NomadColors.primary : Colors.grey.shade200,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: _canPost ? _publish : null,
                  icon: _publishing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                  label: Text(
                    'Publicar',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _canPost ? Colors.white : Colors.grey.shade400),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Categoría
            const Text('Categoría',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: NomadColors.feedIconColor,
                    letterSpacing: 0.2)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.skip(1).map((cat) {
                final sel = cat.id == _selectedCat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCat = cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? cat.color : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${cat.emoji} ${cat.label}',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? Colors.white : Colors.grey.shade600),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Título
            const Text('Título',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: NomadColors.feedIconColor,
                    letterSpacing: 0.2)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              onChanged: (_) => setState(() {}),
              maxLength: 120,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: NomadColors.feedIconColor),
              decoration: InputDecoration(
                hintText: '¿Cuál es tu pregunta o tema?',
                hintStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Cuerpo
            const Text('Descripción (opcional)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: NomadColors.feedIconColor,
                    letterSpacing: 0.2)),
            const SizedBox(height: 6),
            TextField(
              controller: _bodyCtrl,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Contá más detalle, contexto, o lo que necesitás…',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Aviso moderación
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: NomadColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user_rounded, size: 16, color: NomadColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nomad modera el contenido automáticamente. '
                      'Las publicaciones con contenido ilegal son bloqueadas y reportadas.',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: NomadColors.primary.withOpacity(0.8),
                          height: 1.5),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// _GruposTab — tab de grupos (usa SocialService existente)
// ─────────────────────────────────────────────────────────────────────────────
// _CreateGroupSheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet();

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _countryCtrl = TextEditingController();
  GroupCategory _cat = GroupCategory.other;
  String _emoji      = '🤝';
  bool _isPrivate    = false;
  bool _saving       = false;

  static const _emojis = ['🤝', '⚽', '🎨', '🍽️', '📚', '🗣️', '🎭', '🎸', '🏃', '🌍', '🏋️', '🎮'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameCtrl.text.trim().length >= 3 &&
      _cityCtrl.text.trim().isNotEmpty &&
      _countryCtrl.text.trim().isNotEmpty &&
      !_saving;

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await SocialService.createGroup(
      name:        _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category:    _cat,
      country:     _countryCtrl.text.trim(),
      city:        _cityCtrl.text.trim(),
      coverEmoji:  _emoji,
      isPrivate:   _isPrivate,
    );
    setState(() => _saving = false);
    if (!mounted) return;
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!)),
      );
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Grupo creado!'),
          backgroundColor: NomadColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Crear grupo',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: NomadColors.feedIconColor, letterSpacing: -0.3)),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: _canSave ? NomadColors.primary : Colors.grey.shade200,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: _canSave ? _save : null,
                  icon: _saving
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: Text('Crear',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: _canSave ? Colors.white : Colors.grey.shade400)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Emoji picker
            const _Label('Ícono del grupo'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _emojis.map((e) {
                final sel = e == _emoji;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: sel ? NomadColors.primary.withOpacity(0.12) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: sel ? Border.all(color: NomadColors.primary, width: 2) : null,
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Nombre
            const _Label('Nombre del grupo *'),
            const SizedBox(height: 6),
            _Field(controller: _nameCtrl, hint: 'Ej: Fútbol los domingos en Madrid',
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),

            // Descripción
            const _Label('Descripción'),
            const SizedBox(height: 6),
            _Field(controller: _descCtrl,
                hint: '¿De qué se trata el grupo?', maxLines: 3),
            const SizedBox(height: 12),

            // Categoría
            const _Label('Categoría *'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: GroupCategory.values.map((cat) {
                final sel = cat == _cat;
                return GestureDetector(
                  onTap: () => setState(() => _cat = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? NomadColors.primary : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${cat.emoji} ${cat.label}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? Colors.white : Colors.grey.shade600)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Ciudad y país en fila
            Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _Label('Ciudad *'),
                    const SizedBox(height: 6),
                    _Field(controller: _cityCtrl, hint: 'Madrid',
                        onChanged: (_) => setState(() {})),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _Label('País *'),
                    const SizedBox(height: 6),
                    _Field(controller: _countryCtrl, hint: 'España',
                        onChanged: (_) => setState(() {})),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Privado toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 18, color: NomadColors.feedIconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Grupo privado',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                              color: NomadColors.feedIconColor)),
                      Text('Solo por invitación',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                  ),
                  Switch(
                    value: _isPrivate,
                    activeColor: NomadColors.primary,
                    onChanged: (v) => setState(() => _isPrivate = v),
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

// helpers del sheet
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: NomadColors.feedIconColor, letterSpacing: 0.2));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: NomadColors.feedIconColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _GruposTab extends StatefulWidget {
  const _GruposTab();

  @override
  State<_GruposTab> createState() => _GruposTabState();
}

class _GruposTabState extends State<_GruposTab> {
  GroupCategory? _filterCat;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCategoryFilter(),
        Expanded(
          child: StreamBuilder<List<GroupModel>>(
            stream: SocialService.streamGroups(city: null, category: _filterCat),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: NomadColors.primary));
              }
              final groups = snap.data ?? [];
              if (groups.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👥', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        const Text('Sin grupos por ahora',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: NomadColors.feedIconColor)),
                        const SizedBox(height: 8),
                        Text('Pronto podrás crear grupos\nde actividades con otros nomads.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade500, height: 1.6)),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                itemCount: groups.length,
                itemBuilder: (context, i) => _GroupCard(group: groups[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final cats = [null, ...GroupCategory.values];
    return Container(
      height: 46,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: cats.length,
        itemBuilder: (context, i) {
          final cat = cats[i];
          final active = cat == _filterCat;
          final label = cat == null ? 'Todos' : cat.label;
          final emoji = cat == null ? '🌍' : cat.emoji;
          return GestureDetector(
            onTap: () => setState(() => _filterCat = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: active ? NomadColors.primary : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? Colors.white : Colors.grey.shade600)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupModel group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: NomadColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(group.coverEmoji ?? '👥',
                    style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: NomadColors.feedIconColor)),
                  const SizedBox(height: 2),
                  Text(
                    '${group.category.emoji} ${group.category.label} · ${group.memberCount} miembros',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  if (group.city != null)
                    Text('📍 ${group.city}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            ),
            StreamBuilder<bool>(
              stream: SocialService.isMemberStream(group.docId),
              builder: (context, snap) {
                final isMember = snap.data ?? false;
                return GestureDetector(
                  onTap: () async {
                    if (isMember) {
                      await SocialService.leaveGroup(group.docId);
                    } else {
                      await SocialService.joinGroup(group.docId);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isMember ? NomadColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: NomadColors.primary),
                    ),
                    child: Text(
                      isMember ? 'Unido ✓' : 'Unirse',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isMember ? Colors.white : NomadColors.primary),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    )); // GestureDetector
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// _EditPostSheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditPostSheet extends StatefulWidget {
  final ForumPost post;
  const _EditPostSheet({required this.post});

  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  late String _selectedCat;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl   = TextEditingController(text: widget.post.title);
    _bodyCtrl    = TextEditingController(text: widget.post.body);
    _selectedCat = widget.post.category;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _titleCtrl.text.trim().length >= 5 && !_saving;

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim();
    if (ForumService.containsIllegalContent('$title $body')) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Contenido no permitido',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: const Text('El texto contiene términos no permitidos.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: NomadColors.primary),
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final err = await ForumService.updatePost(
      postId:   widget.post.docId,
      title:    title,
      body:     body,
      category: _selectedCat,
    );
    setState(() => _saving = false);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación actualizada'),
            backgroundColor: NomadColors.primary),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Editar publicación',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                        color: NomadColors.feedIconColor, letterSpacing: -0.3)),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: _canSave ? NomadColors.primary : Colors.grey.shade200,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: _canSave ? _save : null,
                  icon: _saving
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: Text('Guardar',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: _canSave ? Colors.white : Colors.grey.shade400)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Categoría'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _categories.skip(1).map((cat) {
                final sel = cat.id == _selectedCat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCat = cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? cat.color : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${cat.emoji} ${cat.label}',
                        style: TextStyle(fontSize: 12.5,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? Colors.white : Colors.grey.shade600)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            const _Label('Título'),
            const SizedBox(height: 6),
            _Field(controller: _titleCtrl, hint: 'Título',
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            const _Label('Descripción'),
            const SizedBox(height: 6),
            _Field(controller: _bodyCtrl, hint: 'Descripción', maxLines: 5),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GroupDetailScreen — pantalla tipo Facebook con tabs
// ─────────────────────────────────────────────────────────────────────────────

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final myId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<GroupRole>(
      stream: SocialService.myRoleStream(g.docId),
      builder: (context, roleSnap) {
        final myRole = roleSnap.data ?? GroupRole.member;
        final isMember = roleSnap.connectionState != ConnectionState.waiting;

        return Scaffold(
          backgroundColor: NomadColors.feedBg,
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              _buildHeader(g, myRole, myId),
            ],
            body: Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _GroupFeedTab(group: g, myRole: myRole),
                      _GroupChatTab(group: g, isMember: isMember),
                      _GroupMembersTab(group: g, myRole: myRole, myId: myId ?? ''),
                      _GroupEventsTab(group: g, myRole: myRole),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  SliverAppBar _buildHeader(GroupModel g, GroupRole myRole, String? myId) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20,
            color: NomadColors.feedIconColor),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [NomadColors.primary.withOpacity(0.8), NomadColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              Text(g.coverEmoji, style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(g.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -0.3)),
              Text('${g.category.emoji} ${g.category.label} · ${g.memberCount} miembros',
                  style: TextStyle(fontSize: 12,
                      color: Colors.white.withOpacity(0.8))),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: StreamBuilder<bool>(
                  stream: SocialService.isMemberStream(g.docId),
                  builder: (context, snap) {
                    final isMember = snap.data ?? false;
                    return GestureDetector(
                      onTap: () async {
                        if (isMember) {
                          await SocialService.leaveGroup(g.docId);
                        } else {
                          await SocialService.joinGroup(g.docId);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: isMember ? NomadColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: NomadColors.primary),
                        ),
                        child: Center(
                          child: Text(
                            isMember ? '✓ Miembro' : 'Unirse al grupo',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                color: isMember ? Colors.white : NomadColors.primary),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: NomadColors.feedBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(g.isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                    size: 18, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabs,
        labelColor: NomadColors.primary,
        unselectedLabelColor: Colors.grey.shade400,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
        indicatorColor: NomadColors.primary,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Publicaciones'),
          Tab(text: 'Chat'),
          Tab(text: 'Miembros'),
          Tab(text: 'Eventos'),
        ],
      ),
    );
  }
}

// ─── Tab Publicaciones ────────────────────────────────────────────────────────

class _GroupFeedTab extends StatefulWidget {
  final GroupModel group;
  final GroupRole myRole;
  const _GroupFeedTab({required this.group, required this.myRole});

  @override
  State<_GroupFeedTab> createState() => _GroupFeedTabState();
}

class _GroupFeedTabState extends State<_GroupFeedTab> {
  final _postCtrl = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _postCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final body = _postCtrl.text.trim();
    if (body.isEmpty) return;
    if (ForumService.containsIllegalContent(body)) return;
    setState(() => _posting = true);
    _postCtrl.clear();
    await SocialService.createGroupPost(groupId: widget.group.docId, body: body);
    setState(() => _posting = false);
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      children: [
        // Composer
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const CircleAvatar(radius: 18, backgroundColor: Color(0xFFCCFBF1),
                  child: Icon(Icons.person_rounded, size: 18, color: NomadColors.primary)),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showComposeDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: NomadColors.feedBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('¿Qué querés compartir con el grupo?',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        Expanded(
          child: StreamBuilder<List<GroupPostModel>>(
            stream: SocialService.streamGroupPosts(widget.group.docId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: NomadColors.primary));
              }
              final posts = snap.data ?? [];
              if (posts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(widget.group.coverEmoji,
                          style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      const Text('Sin publicaciones todavía',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              color: NomadColors.feedIconColor)),
                      const SizedBox(height: 6),
                      Text('Sé el primero en publicar algo.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                    ]),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 40),
                itemCount: posts.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (context, i) =>
                    _GroupPostCard(post: posts[i], group: widget.group,
                        myRole: widget.myRole, myId: myId ?? ''),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showComposeDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Nueva publicación',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                      color: NomadColors.feedIconColor)),
              TextButton(
                style: TextButton.styleFrom(
                    backgroundColor: NomadColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  final text = ctrl.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(context);
                  await SocialService.createGroupPost(
                      groupId: widget.group.docId, body: text);
                },
                child: const Text('Publicar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: '¿Qué querés compartir?',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: NomadColors.feedBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupPostCard extends StatelessWidget {
  final GroupPostModel post;
  final GroupModel group;
  final GroupRole myRole;
  final String myId;

  const _GroupPostCard({
    required this.post,
    required this.group,
    required this.myRole,
    required this.myId,
  });

  @override
  Widget build(BuildContext context) {
    final isOwn     = post.authorId == myId;
    final likedByMe = post.likedBy.contains(myId);
    final initials  = post.authorUsername.isNotEmpty
        ? post.authorUsername[0].toUpperCase()
        : '?';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFCCFBF1),
                backgroundImage: post.authorAvatarUrl != null
                    ? NetworkImage(post.authorAvatarUrl!)
                    : null,
                child: post.authorAvatarUrl == null
                    ? Text(initials,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                            color: NomadColors.primary))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('@${post.authorUsername}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: NomadColors.feedIconColor)),
                  Text(_formatAgo(post.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ]),
              ),
              if (isOwn || myRole.canManage)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, size: 20, color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) async {
                    if (v == 'delete') {
                      await FirebaseFirestore.instance
                          .collection('groups')
                          .doc(group.docId)
                          .collection('posts')
                          .doc(post.docId)
                          .update({'removed': true});
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(fontSize: 13, color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(post.body,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.55)),
          const SizedBox(height: 12),
          Row(children: [
            GestureDetector(
              onTap: () => SocialService.toggleLikeGroupPost(group.docId, post.docId),
              child: Row(children: [
                Icon(likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                    color: likedByMe ? Colors.red.shade400 : Colors.grey.shade400),
                const SizedBox(width: 5),
                Text('${post.likesCount}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: likedByMe ? Colors.red.shade400 : Colors.grey.shade500)),
              ]),
            ),
            const SizedBox(width: 16),
            Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 5),
            Text('${post.commentsCount}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ]),
        ],
      ),
    );
  }
}

// ─── Tab Chat ─────────────────────────────────────────────────────────────────

class _GroupChatTab extends StatefulWidget {
  final GroupModel group;
  final bool isMember;
  const _GroupChatTab({required this.group, required this.isMember});

  @override
  State<_GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends State<_GroupChatTab> {
  final _ctrl     = TextEditingController();
  final _scroll   = ScrollController();
  bool  _sending  = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _ctrl.clear();
    await SocialService.sendGroupMessage(groupId: widget.group.docId, text: text);
    setState(() => _sending = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<GroupMessageModel>>(
            stream: SocialService.streamGroupChat(widget.group.docId),
            builder: (context, snap) {
              final msgs = snap.data ?? [];
              if (msgs.isEmpty) {
                return Center(
                  child: Text('Sin mensajes todavía. ¡Rompé el hielo! 👋',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                );
              }
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: msgs.length,
                itemBuilder: (context, i) {
                  final m    = msgs[i];
                  final isMe = m.authorId == myId;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.72),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe ? NomadColors.primary : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft:     const Radius.circular(14),
                          topRight:    const Radius.circular(14),
                          bottomLeft:  Radius.circular(isMe ? 14 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 14),
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04),
                              blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text(m.text,
                          style: TextStyle(fontSize: 14, height: 1.4,
                              color: isMe ? Colors.white : NomadColors.feedIconColor)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (!widget.isMember)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Text('Unite al grupo para participar en el chat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          )
        else
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                  blurRadius: 6, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Mensaje al grupo…',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: NomadColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Tab Miembros ─────────────────────────────────────────────────────────────

class _GroupMembersTab extends StatelessWidget {
  final GroupModel group;
  final GroupRole  myRole;
  final String     myId;

  const _GroupMembersTab({
    required this.group,
    required this.myRole,
    required this.myId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupMemberModel>>(
      stream: SocialService.streamGroupMembers(group.docId),
      builder: (context, snap) {
        final members = snap.data ?? [];
        if (members.isEmpty) {
          return Center(
            child: Text('Sin miembros',
                style: TextStyle(color: Colors.grey.shade400)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          itemCount: members.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.grey.shade100),
          itemBuilder: (context, i) {
            final m        = members[i];
            final isMe     = m.userId == myId;
            final canEdit  = myRole == GroupRole.admin && !isMe &&
                             m.userId != group.createdBy;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(m.userId)
                  .get(),
              builder: (context, userSnap) {
                final ud = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                final name   = (ud['displayName'] as String?) ??
                               (ud['name'] as String?) ?? m.userId;
                final avatar = ud['photoURL'] as String?;
                final init   = name.isNotEmpty ? name[0].toUpperCase() : '?';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFCCFBF1),
                    backgroundImage:
                        avatar != null ? NetworkImage(avatar) : null,
                    child: avatar == null
                        ? Text(init,
                            style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: NomadColors.primary))
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(name,
                          style: const TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: NomadColors.feedIconColor)),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Text('(vos)',
                            style: TextStyle(fontSize: 11,
                                color: Colors.grey.shade400)),
                      ],
                    ],
                  ),
                  subtitle: _RoleBadge(role: m.role),
                  trailing: canEdit
                      ? _RoleMenu(
                          groupId:      group.docId,
                          targetUserId: m.userId,
                          currentRole:  m.role,
                        )
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final GroupRole role;
  const _RoleBadge({required this.role});

  Color get _color {
    switch (role) {
      case GroupRole.admin:     return const Color(0xFF7C3AED);
      case GroupRole.moderator: return const Color(0xFF0369A1);
      case GroupRole.member:    return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (role == GroupRole.member) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(role.label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: _color)),
      ),
    );
  }
}

class _RoleMenu extends StatelessWidget {
  final String     groupId;
  final String     targetUserId;
  final GroupRole  currentRole;

  const _RoleMenu({
    required this.groupId,
    required this.targetUserId,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<GroupRole>(
      icon: const Icon(Icons.more_vert_rounded, color: NomadColors.primary, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tooltip: 'Cambiar rol',
      onSelected: (newRole) async {
        final err = await SocialService.setMemberRole(
            groupId, targetUserId, newRole);
        if (err != null && context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(err)));
        }
      },
      itemBuilder: (_) => GroupRole.values
          .where((r) => r != currentRole)
          .map((r) => PopupMenuItem<GroupRole>(
                value: r,
                child: Row(children: [
                  Icon(
                    r == GroupRole.admin
                        ? Icons.shield_rounded
                        : r == GroupRole.moderator
                            ? Icons.manage_accounts_rounded
                            : Icons.person_rounded,
                    size: 18,
                    color: r == GroupRole.admin
                        ? const Color(0xFF7C3AED)
                        : r == GroupRole.moderator
                            ? const Color(0xFF0369A1)
                            : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text('Hacer ${r.label}',
                      style: const TextStyle(fontSize: 13)),
                ]),
              ))
          .toList(),
    );
  }
}

// ─── Tab Eventos ──────────────────────────────────────────────────────────────

class _GroupEventsTab extends StatelessWidget {
  final GroupModel group;
  final GroupRole  myRole;

  const _GroupEventsTab({required this.group, required this.myRole});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupEventModel>>(
      stream: SocialService.streamGroupEvents(group.docId),
      builder: (context, snap) {
        final events = snap.data ?? [];
        if (events.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('📅', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('Sin eventos próximos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: NomadColors.feedIconColor)),
                const SizedBox(height: 6),
                if (myRole.canManage)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: NomadColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: () => _showCreateEvent(context),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: const Text('Crear evento',
                        style: TextStyle(color: Colors.white)),
                  ),
              ]),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          itemCount: events.length + (myRole.canManage ? 1 : 0),
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.grey.shade100),
          itemBuilder: (context, i) {
            if (i == events.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: NomadColors.primary,
                      side: const BorderSide(color: NomadColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _showCreateEvent(context),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Crear evento'),
                ),
              );
            }
            final e = events[i];
            return StreamBuilder<bool>(
              stream: SocialService.isAttendingStream(e.docId),
              builder: (context, attendSnap) {
                final attending = attendSnap.data ?? false;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: NomadColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              e.eventDate != null
                                  ? '${e.eventDate!.day}'
                                  : '—',
                              style: const TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: NomadColors.primaryDark, height: 1)),
                            Text(
                              e.eventDate != null
                                  ? DateFormat('MMM', 'es').format(e.eventDate!).toUpperCase()
                                  : '',
                              style: const TextStyle(fontSize: 9,
                                  color: NomadColors.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.title,
                                style: const TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: NomadColors.feedIconColor)),
                            if (e.place != null)
                              Text('📍 ${e.place}',
                                  style: TextStyle(fontSize: 12,
                                      color: Colors.grey.shade500)),
                            Text('${e.attendeesCount} personas van',
                                style: const TextStyle(fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: NomadColors.primary)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          if (attending) {
                            await SocialService.cancelAttendance(e.docId);
                          } else {
                            await SocialService.attendEvent(e.docId);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: attending
                                ? NomadColors.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: NomadColors.primary),
                          ),
                          child: Text(
                            attending ? 'Voy ✓' : 'Asistir',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: attending
                                    ? Colors.white
                                    : NomadColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCreateEvent(BuildContext context) {
    final titleCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    DateTime? selectedDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Crear evento',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: NomadColors.feedIconColor)),
                TextButton(
                  style: TextButton.styleFrom(
                      backgroundColor: NomadColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: titleCtrl.text.trim().isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await SocialService.createEvent(
                            groupId:     group.docId,
                            title:       titleCtrl.text.trim(),
                            description: '',
                            city:        group.city,
                            place:       placeCtrl.text.trim(),
                            eventDate:   selectedDate ?? DateTime.now()
                                .add(const Duration(days: 7)),
                          );
                        },
                  child: const Text('Crear',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 14),
              _Field(controller: titleCtrl, hint: 'Nombre del evento',
                  onChanged: (_) => setS(() {})),
              const SizedBox(height: 10),
              _Field(controller: placeCtrl, hint: 'Lugar'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setS(() => selectedDate = d);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_month_rounded, size: 18,
                        color: NomadColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      selectedDate != null
                          ? DateFormat('d MMM yyyy', 'es').format(selectedDate!)
                          : 'Seleccionar fecha',
                      style: TextStyle(fontSize: 14,
                          color: selectedDate != null
                              ? NomadColors.feedIconColor
                              : Colors.grey.shade400),
                    ),
                  ]),
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

class _PostSkeleton extends StatefulWidget {
  const _PostSkeleton();

  @override
  State<_PostSkeleton> createState() => _PostSkeletonState();
}

class _PostSkeletonState extends State<_PostSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _box(w: 36, h: 36, circle: true),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _box(w: 100, h: 12),
                  const SizedBox(height: 4),
                  _box(w: 60, h: 10),
                ]),
              ]),
              const SizedBox(height: 12),
              _box(w: double.infinity, h: 14),
              const SizedBox(height: 6),
              _box(w: 240, h: 12),
              const SizedBox(height: 6),
              _box(w: 180, h: 12),
              const SizedBox(height: 14),
              Row(children: [_box(w: 50, h: 12), const SizedBox(width: 16), _box(w: 40, h: 12)]),
              const Divider(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box({required double w, required double h, bool circle = false}) {
    return Container(
      width: w,
      height: h,
      decoration: circle
          ? const BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle)
          : BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(6),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

String _formatAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
  if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
  if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
  return DateFormat('d MMM', 'es').format(dt);
}

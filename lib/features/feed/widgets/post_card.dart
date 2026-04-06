import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'post_options_sheet.dart';
import 'share_sheet.dart';
import 'comments_screen.dart';
import '../../profile/perfil_screen.dart';
import '../../profile/visitor_profile_screen.dart';
import 'follow_button.dart';

/// Tarjeta de post del feed.
///
/// El parámetro [onDismiss] es opcional: si se provee, el card se elimina
/// visualmente del feed cuando el usuario elige "No me interesa" o "Reportar".
/// En FeedScreen se maneja a través de un Set de IDs ocultos en el estado.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.username,
    required this.images,
    required this.caption,
    this.userCountryFlag,
    this.userCity,
    this.userBio,
    this.onDismiss,
  });

  final String postId;
  final String postAuthorId;
  final String username;
  final List<String> images;
  final String caption;
  final String? userCountryFlag;
  final String? userCity;
  final String? userBio;

  /// Llamado cuando el usuario oculta el post (no me interesa / reportar).
  final VoidCallback? onDismiss;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final String? _myId = FirebaseAuth.instance.currentUser?.uid;

  bool _isLiked = false;
  int _likesCount = 0;
  bool _isSaved = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    if (_myId == null) return;
    try {
      // Cargar likes
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();
      final data = postDoc.data() ?? {};
      final likes = List<String>.from(data['likedBy'] ?? []);
      final count = (data['likesCount'] as num?)?.toInt() ?? likes.length;

      // Cargar guardados
      final savedDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_myId)
          .collection('saved_posts')
          .doc(widget.postId)
          .get();

      if (mounted) {
        setState(() {
          _isLiked = likes.contains(_myId);
          _likesCount = count;
          _isSaved = savedDoc.exists;
        });
      }
    } catch (e) {
      debugPrint('[PostCard] Error cargando estado: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_myId == null) return;
    final newLiked = !_isLiked;
    setState(() {
      _isLiked = newLiked;
      _likesCount += newLiked ? 1 : -1;
    });
    try {
      final ref = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId);
      if (newLiked) {
        await ref.update({
          'likedBy': FieldValue.arrayUnion([_myId]),
          'likesCount': FieldValue.increment(1),
        });
      } else {
        await ref.update({
          'likedBy': FieldValue.arrayRemove([_myId]),
          'likesCount': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      // Revertir si falla
      if (mounted) {
        setState(() {
          _isLiked = !newLiked;
          _likesCount += newLiked ? -1 : 1;
        });
      }
    }
  }

  void _openComments() {
    CommentsScreen.show(
      context,
      postId: widget.postId,
      postAuthorId: widget.postAuthorId,
    );
  }

  void _openShare() {
    ShareSheet.show(context, postId: widget.postId, username: widget.username);
  }

  void _openOptions() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final esPropio = myUid == widget.postAuthorId;

    if (esPropio) {
      PerfilPostOptionsSheet.show(
        context,
        postId: widget.postId,
        autorId: widget.postAuthorId,
      );
    } else {
      showPostOptions(
        context: context,
        postId: widget.postId,
        postAuthorId: widget.postAuthorId,
        username: widget.username,
        onDismissPost: () {
          widget.onDismiss?.call();
        },
      );
    }
  }

  /// Mini-perfil al tocar avatar o nombre (solo para posts de otros usuarios)
  void _openAuthorPreview() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == widget.postAuthorId)
      return; // no abrir preview del propio perfil

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AuthorPreviewSheet(
        authorId: widget.postAuthorId,
        username: widget.username,
        userCountryFlag: widget.userCountryFlag,
        userCity: widget.userCity,
        userBio: widget.userBio,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header del post ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Avatar — tappable para posts ajenos
                GestureDetector(
                  onTap: _openAuthorPreview,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFD1FAE5),
                    child: Text(
                      widget.username.isNotEmpty
                          ? widget.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF0D9488),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Nombre + ubicación — también tappable
                Expanded(
                  child: GestureDetector(
                    onTap: _openAuthorPreview,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            if (widget.userCountryFlag != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                widget.userCountryFlag!,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                        if (widget.userCity != null)
                          Text(
                            widget.userCity!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Tres puntos → abre opciones
                IconButton(
                  icon: Icon(
                    PhosphorIcons.dotsThree(),
                    color: const Color(0xFF6B7280),
                    size: 22,
                  ),
                  onPressed: _openOptions,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // ── Imágenes ──────────────────────────────────────────────────────
          if (widget.images.isNotEmpty)
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: PageView.builder(
                    itemCount: widget.images.length,
                    onPageChanged: (i) =>
                        setState(() => _currentImageIndex = i),
                    itemBuilder: (_, i) => Image.network(
                      widget.images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF3F4F6),
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFFD1D5DB),
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.images.length > 1)
                  Positioned(
                    bottom: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        widget.images.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentImageIndex == i ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentImageIndex == i
                                ? const Color(0xFF0D9488)
                                : Colors.white70,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

          // ── Acciones (like, comentario, compartir, guardar) ───────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Like
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _isLiked
                            ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                            : PhosphorIcons.heart(),
                        color: _isLiked
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF6B7280),
                        size: 24,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_likesCount',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Comentarios — ahora funcional
                GestureDetector(
                  onTap: _openComments,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.postId)
                        .collection('comments')
                        .snapshots(),
                    builder: (context, snap) {
                      final count = snap.data?.docs.length ?? 0;
                      return Row(
                        children: [
                          Icon(
                            PhosphorIcons.chatCircle(),
                            color: const Color(0xFF6B7280),
                            size: 24,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Compartir — ahora funcional
                GestureDetector(
                  onTap: _openShare,
                  child: Icon(
                    PhosphorIcons.paperPlaneTilt(),
                    color: const Color(0xFF6B7280),
                    size: 24,
                  ),
                ),
                const Spacer(),
                // Guardar
                GestureDetector(
                  onTap: () async {
                    setState(() => _isSaved = !_isSaved);
                    if (_myId == null) return;
                    final ref = FirebaseFirestore.instance
                        .collection('users')
                        .doc(_myId)
                        .collection('saved_posts')
                        .doc(widget.postId);
                    if (_isSaved) {
                      await ref.set({'savedAt': FieldValue.serverTimestamp()});
                    } else {
                      await ref.delete();
                    }
                  },
                  child: Icon(
                    _isSaved
                        ? PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill)
                        : PhosphorIcons.bookmarkSimple(),
                    color: _isSaved
                        ? const Color(0xFF0D9488)
                        : const Color(0xFF6B7280),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // ── Caption ───────────────────────────────────────────────────────
          if (widget.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1F2937),
                  ),
                  children: [
                    TextSpan(
                      text: '${widget.username} ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: widget.caption),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini-perfil del autor (bottom sheet al tocar avatar / nombre)
// ─────────────────────────────────────────────────────────────────────────────

class _AuthorPreviewSheet extends StatelessWidget {
  const _AuthorPreviewSheet({
    required this.authorId,
    required this.username,
    this.userCountryFlag,
    this.userCity,
    this.userBio,
  });

  final String authorId;
  final String username;
  final String? userCountryFlag;
  final String? userCity;
  final String? userBio;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Avatar
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFFD1FAE5),
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF0D9488),
                fontWeight: FontWeight.bold,
                fontSize: 26,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Nombre + flag
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                username,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: Color(0xFF1F2937),
                ),
              ),
              if (userCountryFlag != null) ...[
                const SizedBox(width: 6),
                Text(userCountryFlag!, style: const TextStyle(fontSize: 17)),
              ],
            ],
          ),

          // Ciudad
          if (userCity != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 3),
                Text(
                  userCity!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],

          // Bio
          if (userBio != null && userBio!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              userBio!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4B5563),
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Botón Seguir (reactivo, usa FollowButton)
          FollowButton(targetUserId: authorId),

          const SizedBox(height: 12),

          // Ir al perfil completo
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitorProfileScreen(targetUserId: authorId),
                ),
              );
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: const Text(
              'Ver perfil completo',
              style: TextStyle(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

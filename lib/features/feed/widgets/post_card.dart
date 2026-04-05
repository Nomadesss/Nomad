import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'post_options_sheet.dart';

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

  void _openOptions() {
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
                // Avatar
                CircleAvatar(
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
                const SizedBox(width: 10),
                // Nombre + ubicación
                Expanded(
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
                // Comentarios
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.chatCircle(),
                      color: const Color(0xFF6B7280),
                      size: 24,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '0',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Compartir
                Icon(
                  PhosphorIcons.paperPlaneTilt(),
                  color: const Color(0xFF6B7280),
                  size: 24,
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

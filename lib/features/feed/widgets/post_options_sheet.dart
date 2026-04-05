import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Muestra el bottom sheet de opciones de un post.
///
/// [postId]       — ID del documento en la colección `posts`.
/// [postAuthorId] — UID del autor del post.
/// [username]     — Nombre de usuario del autor (para los labels).
/// [onDismissPost]— Callback que el padre (PostCard / FeedScreen) debe usar
///                  para eliminar visualmente el post del feed.
Future<void> showPostOptions({
  required BuildContext context,
  required String postId,
  required String postAuthorId,
  required String username,
  required VoidCallback onDismissPost,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PostOptionsSheet(
      postId: postId,
      postAuthorId: postAuthorId,
      username: username,
      onDismissPost: onDismissPost,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _PostOptionsSheet extends StatefulWidget {
  const _PostOptionsSheet({
    required this.postId,
    required this.postAuthorId,
    required this.username,
    required this.onDismissPost,
  });

  final String postId;
  final String postAuthorId;
  final String username;
  final VoidCallback onDismissPost;

  @override
  State<_PostOptionsSheet> createState() => _PostOptionsSheetState();
}

class _PostOptionsSheetState extends State<_PostOptionsSheet> {
  final String? _myId = FirebaseAuth.instance.currentUser?.uid;

  // null = aún cargando, true = ya sigo, false = no sigo
  bool? _isFollowing;
  bool _loadingFollow = true;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  // ── Verifica si ya sigo al autor ─────────────────────────────────────────
  Future<void> _checkFollowStatus() async {
    if (_myId == null || _myId == widget.postAuthorId) {
      setState(() => _loadingFollow = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('follows')
          .where('followerId', isEqualTo: _myId)
          .where('followingId', isEqualTo: widget.postAuthorId)
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          _isFollowing = snap.docs.isNotEmpty;
          _loadingFollow = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFollow = false);
    }
  }

  // ── Seguir ────────────────────────────────────────────────────────────────
  Future<void> _follow() async {
    if (_myId == null) return;
    setState(() => _isFollowing = true);
    try {
      // Usamos un ID determinístico para evitar duplicados
      final docId = '${_myId}_${widget.postAuthorId}';
      await FirebaseFirestore.instance.collection('follows').doc(docId).set({
        'followerId': _myId,
        'followingId': widget.postAuthorId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) setState(() => _isFollowing = false);
      debugPrint('[PostOptions] Error al seguir: $e');
    }
  }

  // ── Dejar de seguir ───────────────────────────────────────────────────────
  Future<void> _unfollow() async {
    if (_myId == null) return;
    setState(() => _isFollowing = false);
    try {
      final docId = '${_myId}_${widget.postAuthorId}';
      await FirebaseFirestore.instance
          .collection('follows')
          .doc(docId)
          .delete();
    } catch (e) {
      if (mounted) setState(() => _isFollowing = true);
      debugPrint('[PostOptions] Error al dejar de seguir: $e');
    }
  }

  // ── Ocultar post (no me interesa / reportar) ──────────────────────────────
  Future<void> _dismissPost({required bool isReport}) async {
    Navigator.pop(context); // cerrar sheet primero
    widget.onDismissPost(); // remover del feed

    if (_myId == null) return;

    try {
      if (isReport) {
        // Guardar reporte en Firestore
        await FirebaseFirestore.instance.collection('reports').add({
          'postId': widget.postId,
          'reportedBy': _myId,
          'authorId': widget.postAuthorId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      // En ambos casos registrar que el usuario no quiere ver este post
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_myId)
          .collection('hidden_posts')
          .doc(widget.postId)
          .set({'hiddenAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('[PostOptions] Error al ocultar/reportar: $e');
    }
  }

  // ── Guardar publicación ───────────────────────────────────────────────────
  Future<void> _savePost() async {
    Navigator.pop(context);
    if (_myId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_myId)
          .collection('saved_posts')
          .doc(widget.postId)
          .set({'savedAt': FieldValue.serverTimestamp()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Publicación guardada'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[PostOptions] Error al guardar: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // No mostrar "Seguir/Dejar de seguir" si es mi propio post
    final isOwnPost = _myId == widget.postAuthorId;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A2E2B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Me interesa ─────────────────────────────────────────────────
          _OptionTile(
            icon: PhosphorIcons.thumbsUp(),
            label: 'Me interesa',
            subtitle: 'Verás más publicaciones como esta en el feed.',
            onTap: () => Navigator.pop(context),
          ),

          // ── No me interesa ───────────────────────────────────────────────
          _OptionTile(
            icon: PhosphorIcons.thumbsDown(),
            label: 'No me interesa',
            subtitle: 'Verás menos publicaciones como esta en el feed.',
            onTap: () => _dismissPost(isReport: false),
          ),

          // ── ¿Por qué veo esto? ───────────────────────────────────────────
          _OptionTile(
            icon: PhosphorIcons.question(),
            label: '¿Por qué veo esta publicación?',
            subtitle: 'Esta publicación se sugirió en función de tu actividad.',
            onTap: () => Navigator.pop(context),
          ),

          // ── Guardar ──────────────────────────────────────────────────────
          _OptionTile(
            icon: PhosphorIcons.bookmarkSimple(),
            label: 'Guardar publicación',
            onTap: _savePost,
          ),

          // ── Notificaciones ───────────────────────────────────────────────
          _OptionTile(
            icon: PhosphorIcons.bell(),
            label: 'Recibir notificaciones',
            subtitle: 'Activa alertas sobre esta publicación.',
            onTap: () => Navigator.pop(context),
          ),

          // ── Seguir / Dejar de seguir (solo si no es mi post) ─────────────
          if (!isOwnPost)
            _loadingFollow
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  )
                : _OptionTile(
                    icon: _isFollowing == true
                        ? PhosphorIcons.userMinus()
                        : PhosphorIcons.userPlus(),
                    label: _isFollowing == true
                        ? 'Dejar de seguir a ${widget.username}'
                        : 'Seguir a ${widget.username}',
                    subtitle: _isFollowing == true
                        ? 'Dejarás de ver publicaciones de ${widget.username}.'
                        : 'Ver publicaciones de ${widget.username}.',
                    onTap: () async {
                      if (_isFollowing == true) {
                        await _unfollow();
                      } else {
                        await _follow();
                      }
                      if (mounted) Navigator.pop(context);
                    },
                  ),

          // ── Reportar ────────────────────────────────────────────────────
          _OptionTile(
            icon: PhosphorIcons.flag(),
            label: 'Reportar publicación',
            subtitle:
                'No le diremos a ${widget.username} quién envió el reporte.',
            labelColor: const Color(0xFFEF4444),
            onTap: () => _showReportOptions(),
          ),
        ],
      ),
    );
  }

  // ── Sub-sheet de opciones de reporte ─────────────────────────────────────
  void _showReportOptions() {
    Navigator.pop(context); // cerrar el sheet principal

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A2E2B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Text(
                '¿Por qué querés reportar esta publicación?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            for (final reason in _reportReasons)
              _OptionTile(
                icon: PhosphorIcons.flag(),
                label: reason,
                labelColor: const Color(0xFFEF4444),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDismissPost();
                  _saveReport(reason);
                },
              ),
          ],
        ),
      ),
    );
  }

  static const _reportReasons = [
    'Spam o publicidad no deseada',
    'Contenido violento o perturbador',
    'Acoso o bullying',
    'Desinformación',
    'Contenido inapropiado',
    'Otro motivo',
  ];

  Future<void> _saveReport(String reason) async {
    if (_myId == null) return;
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'postId': widget.postId,
        'reportedBy': _myId,
        'authorId': widget.postAuthorId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_myId)
          .collection('hidden_posts')
          .doc(widget.postId)
          .set({'hiddenAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('[PostOptions] Error al guardar reporte: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile reutilizable
// ─────────────────────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.labelColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = labelColor ?? Colors.white;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF243B38),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: subtitle != null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                      ),
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
}

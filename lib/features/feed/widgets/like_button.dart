import 'package:flutter/material.dart';
import '../../../services/social_service.dart';

class LikeButton extends StatefulWidget {
  final String postId;
  final String postAuthorId;

  const LikeButton({
    super.key,
    required this.postId,
    required this.postAuthorId,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  bool? _optimisticLiked; // null = todavía no llegó el stream
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));
  }

  // ✅ FIX PRINCIPAL: cuando Flutter reutiliza este State con un postId distinto
  // (por ejemplo al hacer scroll en el feed), reseteamos el estado local
  // para que el nuevo stream arranque desde cero.
  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      setState(() {
        _optimisticLiked = null;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading || _optimisticLiked == null) return;

    final wasLiked = _optimisticLiked!;

    setState(() {
      _optimisticLiked = !wasLiked;
      _loading = true;
    });

    if (!wasLiked) _bounceCtrl.forward(from: 0);

    try {
      if (wasLiked) {
        await SocialService.unlikePost(widget.postId);
      } else {
        await SocialService.likePost(widget.postId, widget.postAuthorId);
      }
    } catch (_) {
      if (mounted) setState(() => _optimisticLiked = wasLiked);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      // ✅ key por postId — fuerza a Flutter a recrear el StreamBuilder si cambia el post
      key: ValueKey(widget.postId),
      stream: SocialService.likedStream(widget.postId),
      builder: (context, likedSnap) {
        // Sincronizar con Firestore siempre que no haya toggle en curso
        if (likedSnap.hasData && !_loading) {
          _optimisticLiked = likedSnap.data!;
        }

        final liked = _optimisticLiked ?? false;

        return StreamBuilder<int>(
          key: ValueKey('count_${widget.postId}'),
          stream: SocialService.likesCountStream(widget.postId),
          builder: (context, countSnap) {
            final count = countSnap.data ?? 0;

            return GestureDetector(
              onTap: _toggle,
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _bounceAnim,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        key: ValueKey(liked),
                        color: liked
                            ? const Color(0xFFE24B4A)
                            : const Color(0xFF134E4A),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      '$count',
                      key: ValueKey(count),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF134E4A),
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
  }
}

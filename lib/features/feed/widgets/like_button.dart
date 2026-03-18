import 'package:flutter/material.dart';
import '../../../services/social_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LikeButton — reemplaza el like_button.dart anterior.
//
// Ahora está conectado a Firestore:
//  - El estado liked viene de un Stream (post_likes/{postId}_{uid})
//  - El contador viene de un Stream (posts/{postId}.likesCount)
//  - Usa UI optimista: anima de inmediato, revierte si Firestore falla
//
// Uso en PostCard:
//   LikeButton(postId: item["id"], postAuthorId: item["authorId"])
// ─────────────────────────────────────────────────────────────────────────────

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

  bool _optimisticLiked = false;
  bool _initialized = false;
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

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;

    final wasLiked = _optimisticLiked;
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
      stream: SocialService.likedStream(widget.postId),
      builder: (context, likedSnap) {
        if (!_initialized && likedSnap.hasData) {
          _optimisticLiked = likedSnap.data!;
          _initialized = true;
        }

        return StreamBuilder<int>(
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
                        _optimisticLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        key: ValueKey(_optimisticLiked),
                        color: _optimisticLiked
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
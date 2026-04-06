import 'package:flutter/material.dart';
import '../../../services/social_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FollowButton — botón reactivo que refleja el estado real de Firestore.
//
// Uso:
//   FollowButton(targetUserId: "uid_del_otro")
//
// El widget usa un StreamBuilder sobre followingStream() para mantenerse
// sincronizado en tiempo real. Si el usuario abre la app en dos dispositivos,
// ambos se actualizan solos.
// ─────────────────────────────────────────────────────────────────────────────

class FollowButton extends StatefulWidget {
  final String targetUserId;

  /// Tamaño compacto para usar dentro de tarjetas de perfil.
  final bool compact;

  const FollowButton({
    super.key,
    required this.targetUserId,
    this.compact = false,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  // Loading optimista: mientras espera a Firestore muestra el estado nuevo
  bool _loading = false;

  Future<void> _toggle(bool currentlyFollowing) async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      if (currentlyFollowing) {
        await SocialService.unfollow(widget.targetUserId);
      } else {
        await SocialService.followUser(widget.targetUserId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ocurrió un error. Intentá de nuevo."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: SocialService.followingStream(widget.targetUserId),
      builder: (context, snap) {
        final following = snap.data ?? false;

        if (widget.compact) {
          return _CompactButton(
            following: following,
            loading: _loading,
            onTap: () => _toggle(following),
          );
        }

        return _FullButton(
          following: following,
          loading: _loading,
          onTap: () => _toggle(following),
        );
      },
    );
  }
}

// ── Variante completa (para pantalla de perfil) ───────────────────────────────

class _FullButton extends StatelessWidget {
  final bool following;
  final bool loading;
  final VoidCallback onTap;

  const _FullButton({
    required this.following,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 42,
      decoration: BoxDecoration(
        color: following ? const Color(0xFFE6FAF8) : const Color(0xFF0D9488),
        borderRadius: BorderRadius.circular(10),
        border: following ? Border.all(color: const Color(0xFF5EEAD4)) : null,
      ),
      child: TextButton(
        onPressed: loading ? null : onTap,
        style: TextButton.styleFrom(
          foregroundColor: following ? const Color(0xFF0D9488) : Colors.white,
          minimumSize: const Size(double.infinity, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: following ? const Color(0xFF0D9488) : Colors.white,
                ),
              )
            : Text(
                following ? "Siguiendo" : "Seguir",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}

// ── Variante compacta (para listas, tarjetas de post) ────────────────────────

class _CompactButton extends StatelessWidget {
  final bool following;
  final bool loading;
  final VoidCallback onTap;

  const _CompactButton({
    required this.following,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: following ? Colors.transparent : const Color(0xFF0D9488),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: following
                ? const Color(0xFF5EEAD4)
                : const Color(0xFF0D9488),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF0D9488),
                ),
              )
            : Text(
                following ? "Siguiendo" : "Seguir",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: following ? const Color(0xFF0D9488) : Colors.white,
                ),
              ),
      ),
    );
  }
}

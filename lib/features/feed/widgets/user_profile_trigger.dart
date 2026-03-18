import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'user_profile_card.dart';

// ── Trigger de perfil (detecta plataforma automáticamente) ────────────────────
//
// Uso:
//   UserProfileTrigger(
//     user: UserProfileData(username: "carlos", ...),
//     child: Row(children: [avatar, nombre]),
//   )
//
// - En móvil:  tap  → BottomSheet con la tarjeta
// - En web:    hover → Popover flotante sobre el widget

class UserProfileTrigger extends StatefulWidget {
  final UserProfileData user;
  final Widget child;

  const UserProfileTrigger({
    super.key,
    required this.user,
    required this.child,
  });

  @override
  State<UserProfileTrigger> createState() => _UserProfileTriggerState();
}

class _UserProfileTriggerState extends State<UserProfileTrigger> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _hoverActive = false;

  // ── Web: mostrar popover ──────────────────────────────────────────────────

  void _showPopover() {
    if (_overlayEntry != null) return;
    _hoverActive = true;

    _overlayEntry = OverlayEntry(
      builder: (_) => _PopoverOverlay(
        layerLink: _layerLink,
        user: widget.user,
        onDismiss: _hidePopover,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hidePopover() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _hoverActive = false;
  }

  // ── Móvil: mostrar BottomSheet ────────────────────────────────────────────

  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProfileBottomSheet(user: widget.user),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _hidePopover();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web: MouseRegion para hover + CompositedTransformTarget para posicionar el popover
      return CompositedTransformTarget(
        link: _layerLink,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _showPopover(),
          onExit: (_) {
            // Pequeño delay para que el usuario pueda mover el cursor al popover
            Future.delayed(const Duration(milliseconds: 120), () {
              if (!_hoverActive) return;
              _hidePopover();
            });
          },
          child: widget.child,
        ),
      );
    }

    // Móvil: GestureDetector con tap
    return GestureDetector(
      onTap: _showBottomSheet,
      child: widget.child,
    );
  }
}

// ── Popover web ───────────────────────────────────────────────────────────────

class _PopoverOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final UserProfileData user;
  final VoidCallback onDismiss;

  const _PopoverOverlay({
    required this.layerLink,
    required this.user,
    required this.onDismiss,
  });

  @override
  State<_PopoverOverlay> createState() => _PopoverOverlayState();
}

class _PopoverOverlayState extends State<_PopoverOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _mouseInside = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Capa transparente para cerrar al hacer clic fuera
        Positioned.fill(
          child: GestureDetector(
            onTap: _dismiss,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),

        // El popover posicionado debajo del trigger
        CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48), // debajo del header del post
          child: Align(
            alignment: Alignment.topLeft,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: MouseRegion(
                  onEnter: (_) => _mouseInside = true,
                  onExit: (_) {
                    _mouseInside = false;
                    Future.delayed(const Duration(milliseconds: 120), () {
                      if (!_mouseInside) _dismiss();
                    });
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 300,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF5EEAD4),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.10),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: UserProfileCard(user: widget.user),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── BottomSheet móvil ─────────────────────────────────────────────────────────

class _ProfileBottomSheet extends StatelessWidget {
  final UserProfileData user;

  const _ProfileBottomSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          UserProfileCard(user: user),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
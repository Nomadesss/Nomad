import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// bottom_nav.dart  –  Nomad App
// Ubicación: lib/features/feed/widgets/bottom_nav.dart
//
// Widget compartido por todas las screens. Cada screen lo instancia
// pasando su propio currentIndex. Al tocar un ítem navega con
// pushReplacement para no acumular el historial.
// ─────────────────────────────────────────────────────────────────────────────

// Rutas nombradas — registralas en tu MaterialApp
// '/feed'    → FeedScreen
// '/map'     → MapScreen
// '/search'  → SearchScreen
// '/profile' → PerfilPropio

const _kRoutes = ['/feed', '/map', '/search', '/profile'];

class BottomNav extends StatelessWidget {
  /// Índice del tab activo en esta pantalla (0-3).
  final int currentIndex;

  const BottomNav({super.key, this.currentIndex = 0});

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return; // ya estamos acá
    HapticFeedback.selectionClick();
    Navigator.of(context).pushReplacementNamed(_kRoutes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                outlinedIcon: Icons.home_outlined,
                index: 0,
                currentIndex: currentIndex,
                onTap: (i) => _onTap(context, i),
              ),
              _NavItem(
                icon: Icons.map_rounded,
                outlinedIcon: Icons.map_outlined,
                index: 1,
                currentIndex: currentIndex,
                onTap: (i) => _onTap(context, i),
              ),
              _NavItem(
                icon: Icons.search_rounded,
                outlinedIcon: Icons.search_outlined,
                index: 2,
                currentIndex: currentIndex,
                onTap: (i) => _onTap(context, i),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                outlinedIcon: Icons.person_outline_rounded,
                index: 3,
                currentIndex: currentIndex,
                onTap: (i) => _onTap(context, i),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ítem individual
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData outlinedIcon;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.outlinedIcon,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF0D9488).withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              selected ? icon : outlinedIcon,
              color: selected
                  ? const Color(0xFF0D9488)
                  : const Color(0xFF94A3B8),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

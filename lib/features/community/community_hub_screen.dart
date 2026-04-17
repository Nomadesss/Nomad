import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_theme.dart';

import 'empleo/empleo_screen.dart';
import 'empleo/empleo_empleador_screen.dart';
import 'empleo/empleo_role_selector.dart';
import 'legal/legal_screen.dart';
import 'social/social_screen.dart';
import 'journey/destination_dashboard_screen.dart';

// Clave de persistencia del rol elegido
const _kEmpleoRole = 'empleo_role'; // 'busca' | 'ofrece'

class CommunityHubScreen extends StatelessWidget {
  const CommunityHubScreen({super.key});

  // ── Navegar a Empleo según rol guardado (o preguntar si no hay ninguno) ────
  Future<void> _navigateToEmpleo(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString(_kEmpleoRole);

    if (!context.mounted) return;

    if (savedRole == 'busca') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EmpleoScreen()),
      );
      return;
    }

    if (savedRole == 'ofrece') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EmpleoEmpleadorScreen()),
      );
      return;
    }

    // Sin rol guardado → mostrar selector
    final role = await showEmpleoRoleSelector(context);
    if (role == null || !context.mounted) return;

    await prefs.setString(_kEmpleoRole, role);

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => role == 'busca'
            ? const EmpleoScreen()
            : const EmpleoEmpleadorScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: CustomScrollView(
        slivers: [
          // ── APP BAR ─────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: NomadColors.feedHeaderBg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: NomadColors.feedIconColor,
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "Nomad",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D9488),
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: true,
          ),

          // ── CONTENIDO ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tu actividad",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF134E4A),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 1. JOURNEY ───────────────────────────
                  _FeedCard(
                    icon: "🧭",
                    title: "Tu plan migratorio",
                    subtitle: "Organizá tu camino paso a paso",
                    color: const Color(0xFF0D9488),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DestinationDashboardScreen(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── 2. EMPLEO — abre selector de rol ─────
                  _FeedCard(
                    icon: "💼",
                    title: "Oportunidades laborales",
                    subtitle: "Trabajos adaptados a migrantes",
                    color: const Color(0xFF0D9488),
                    onTap: () => _navigateToEmpleo(context),
                  ),

                  const SizedBox(height: 14),

                  // ── 3. LEGAL ─────────────────────────────
                  _FeedCard(
                    icon: "⚖️",
                    title: "Guías legales",
                    subtitle: "Visas, residencia y trámites",
                    color: const Color(0xFF3B82F6),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LegalScreen()),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── 4. SOCIAL ────────────────────────────
                  _FeedCard(
                    icon: "🤝",
                    title: "Comunidad",
                    subtitle: "Conectá con coterráneos",
                    color: const Color(0xFF9333EA),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SocialScreen()),
                    ),
                  ),
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
// Feed Card (sin cambios)
// ─────────────────────────────────────────────────────────────────────────────

class _FeedCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeedCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF134E4A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

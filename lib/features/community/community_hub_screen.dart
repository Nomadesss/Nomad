import 'package:flutter/material.dart';
import '../../app_theme.dart';

import 'empleo/empleo_screen.dart';
import 'legal/legal_screen.dart';
import 'social/social_screen.dart';
import 'journey/destination_dashboard_screen.dart';

class CommunityHubScreen extends StatelessWidget {
  const CommunityHubScreen({super.key});

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
              "Comunidad",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),

          // ── CONTENIDO ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── PROGRESO (core del producto) ─────────
                  const _ProgressCard(),

                  const SizedBox(height: 28),

                  // ── HEADER ───────────────────────────────
                  const Text(
                    "Tu actividad",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── 1. JOURNEY (NUEVO — PRIORIDAD ALTA) ─
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

                  const SizedBox(height: 12),

                  // ── 2. EMPLEO ───────────────────────────
                  _FeedCard(
                    icon: "💼",
                    title: "Oportunidades laborales",
                    subtitle: "Trabajos adaptados a migrantes",
                    color: const Color(0xFF0D9488),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmpleoScreen()),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── 3. LEGAL ────────────────────────────
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

                  const SizedBox(height: 12),

                  // ── 4. SOCIAL ───────────────────────────
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

//
// ─────────────────────────────────────────────
// PROGRESS CARD (base para gamificación futura)
// ─────────────────────────────────────────────
//

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0D9488),
            Color(0xFF14B8A6),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Tu progreso en el exterior 🌍",
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            "Nivel 2",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 0.45,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _MiniStep(label: "Trabajo"),
              _MiniStep(label: "Legal"),
              _MiniStep(label: "Social"),
              _MiniStep(label: "Instalación"),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStep extends StatelessWidget {
  final String label;

  const _MiniStep({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        )
      ],
    );
  }
}

//
// ─────────────────────────────────────────────
// FEED CARD (UI reutilizable)
// ─────────────────────────────────────────────
//

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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [

            // Icono
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
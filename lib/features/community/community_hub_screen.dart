import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'empleo/empleo_screen.dart';
import 'legal/legal_screen.dart';
import 'social/social_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CommunityHubScreen — punto de entrada al Community Hub
//
// Accesible desde FeedHeader → botón handHeart.
// Muestra las 3 cards de acceso: Empleo, Legal y Social.
//
// Ubicación: lib/features/community/community_hub_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

class CommunityHubScreen extends StatelessWidget {
  const CommunityHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: CustomScrollView(
        slivers: [

          // ── App bar ───────────────────────────────────────────────────────
          SliverAppBar(
            floating:        true,
            snap:            true,
            elevation:       0,
            backgroundColor: NomadColors.feedHeaderBg,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
              ),
              color:   NomadColors.feedIconColor,
              onPressed: () => Navigator.of(context).pop(),
            ),
            centerTitle: true,
            title: const Text(
              'Nomad',
              style: TextStyle(
                fontFamily:  'Georgia',
                fontSize:    22,
                fontWeight:  FontWeight.w700,
                color:       NomadColors.primary,
                letterSpacing: -0.3,
              ),
            ),
          ),

          // ── Header ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comunidad',
                    style: TextStyle(
                      fontSize:      11,
                      fontWeight:    FontWeight.w600,
                      color:         NomadColors.primary,
                      letterSpacing: .12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tu red de apoyo\nen el exterior',
                    style: TextStyle(
                      fontFamily:  'Georgia',
                      fontSize:    28,
                      fontWeight:  FontWeight.w700,
                      color:       NomadColors.feedIconColor,
                      height:      1.15,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Empleo, asesoría legal y grupos sociales',
                    style: TextStyle(
                      fontSize: 14,
                      color:    NomadColors.feedIconColor.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Cards ─────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _HubCard(
                  emoji:       '💼',
                  title:       'Empleo',
                  subtitle:    'Ofertas y búsqueda activa',
                  badgeText:   '18 ofertas nuevas',
                  tagText:     'Remoto · Presencial',
                  gradientFrom: const Color(0xFFCCFBF1),
                  gradientTo:   const Color(0xFF99F6E4),
                  titleColor:   NomadColors.feedIconColor,
                  subtitleColor: NomadColors.primaryDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmpleoScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _HubCard(
                  emoji:       '⚖️',
                  title:       'Asesoría Legal',
                  subtitle:    'Visas, residencia y trámites',
                  badgeText:   '7 temas',
                  tagText:     'Chat IA · Guías',
                  gradientFrom: const Color(0xFFE0F2FE),
                  gradientTo:   const Color(0xFFBAE6FD),
                  titleColor:   const Color(0xFF1E3A5F),
                  subtitleColor: const Color(0xFF2563EB),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LegalScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _HubCard(
                  emoji:       '🤝',
                  title:       'Social',
                  subtitle:    'Grupos e intereses comunes',
                  badgeText:   'Grupos activos',
                  tagText:     'Deporte · Arte · Charlas',
                  gradientFrom: const Color(0xFFFDF4FF),
                  gradientTo:   const Color(0xFFF0ABFC),
                  titleColor:   const Color(0xFF4A1D5F),
                  subtitleColor: const Color(0xFF9333EA),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SocialScreen()),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HubCard — card de acceso a cada sección del hub
// ─────────────────────────────────────────────────────────────────────────────

class _HubCard extends StatelessWidget {
  final String   emoji;
  final String   title;
  final String   subtitle;
  final String   badgeText;
  final String   tagText;
  final Color    gradientFrom;
  final Color    gradientTo;
  final Color    titleColor;
  final Color    subtitleColor;
  final VoidCallback onTap;

  const _HubCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.tagText,
    required this.gradientFrom,
    required this.gradientTo,
    required this.titleColor,
    required this.subtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.07),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color:       Colors.black.withValues(alpha: 0.04),
              blurRadius:  8,
              offset:      const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Banner de color con emoji ──────────────────────────────
              Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradientFrom, gradientTo],
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 34)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily:  'Georgia',
                              fontSize:    19,
                              fontWeight:  FontWeight.w700,
                              color:       titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize:   12,
                              color:      subtitleColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: subtitleColor.withValues(alpha: 0.5),
                      size:  22,
                    ),
                  ],
                ),
              ),

              // ── Badges ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical:   12,
                ),
                child: Wrap(
                  spacing:    6,
                  runSpacing: 6,
                  children: [
                    _Badge(text: badgeText, teal: true),
                    _Badge(text: tagText,   teal: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool   teal;

  const _Badge({required this.text, required this.teal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: teal
            ? NomadColors.primary.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.w600,
          color: teal ? NomadColors.primaryDark : Colors.grey.shade600,
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../community/community_hub_screen.dart';

class FeedHeader extends StatelessWidget {
  const FeedHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFD),
        border: Border(bottom: BorderSide(color: Color(0xFFEAEAEA), width: 1)),
      ),
      child: Row(
        children: [
          // IZQUIERDA
          Expanded(
            child: Row(
              children: [
                _HeaderIcon(icon: PhosphorIcons.heart(), onTap: () {}),
                const SizedBox(width: 6),
                _HeaderIcon(icon: PhosphorIcons.handHeart(), onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CommunityHubScreen()),
                )),
              ],
            ),
          ),

          // LOGO ANIMADO
          const Expanded(child: Center(child: _NomadAnimatedLogo())),

          // DERECHA
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _HeaderIcon(icon: PhosphorIcons.bell(), onTap: () {}),
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: const Center(
                          child: Text(
                            "3",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                _HeaderIcon(icon: PhosphorIcons.chatCircle(), onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logo animado ──────────────────────────────────────────────

class _NomadAnimatedLogo extends StatefulWidget {
  const _NomadAnimatedLogo();

  @override
  State<_NomadAnimatedLogo> createState() => _NomadAnimatedLogoState();
}

class _NomadAnimatedLogoState extends State<_NomadAnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // Duración de un ciclo completo: aparece + pausa + desaparece + pausa
  static const _cycleDuration = Duration(seconds: 8);

  // Cada letra tiene su propio offset de delay
  static const _letters = ['N', 'o', 'm', 'a', 'd'];
  static const _letterDelay = 0.08; // fracción del ciclo entre letras

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _cycleDuration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: List.generate(_letters.length, (i) {
            return _AnimatedLetter(
              letter: _letters[i],
              progress: _ctrl.value,
              delay: i * _letterDelay,
            );
          }),
        );
      },
    );
  }
}

class _AnimatedLetter extends StatelessWidget {
  final String letter;
  final double progress; // 0.0 → 1.0 del ciclo completo
  final double delay; // fracción de delay dentro del ciclo

  const _AnimatedLetter({
    required this.letter,
    required this.progress,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    // Ventanas del ciclo (fracciones de 0–1):
    // 0.00–0.05 : pausa inicial
    // 0.05–0.30 : aparece (entrada desde abajo)
    // 0.30–0.65 : visible quieto
    // 0.65–0.85 : desaparece (sale hacia arriba)
    // 0.85–1.00 : pausa antes del siguiente ciclo

    // Ajusta el progreso con el delay de la letra
    final p = ((progress - delay) % 1.0 + 1.0) % 1.0;

    double opacity;
    double translateY;

    if (p < 0.05) {
      // Pausa inicial
      opacity = 0.0;
      translateY = 10.0;
    } else if (p < 0.25) {
      // Entrada
      final t = _easeOut((p - 0.05) / 0.20);
      opacity = t;
      translateY = 10.0 * (1 - t);
    } else if (p < 0.65) {
      // Visible
      opacity = 1.0;
      translateY = 0.0;
    } else if (p < 0.82) {
      // Salida hacia arriba
      final t = _easeIn((p - 0.65) / 0.17);
      opacity = 1.0 - t;
      translateY = -10.0 * t;
    } else {
      // Pausa final
      opacity = 0.0;
      translateY = -10.0;
    }

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Text(
          letter,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0D9488),
            height: 1.0,
          ),
        ),
      ),
    );
  }

  double _easeOut(double t) => 1 - (1 - t) * (1 - t);
  double _easeIn(double t) => t * t;
}

// ── Ícono del header ──────────────────────────────────────────

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 22, color: const Color(0xFF134E4A)),
      ),
    );
  }
}

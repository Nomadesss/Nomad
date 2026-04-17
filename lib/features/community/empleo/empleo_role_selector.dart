import 'package:flutter/material.dart';

/// Muestra el bottom sheet de selección de rol laboral.
/// Retorna `'busca'`, `'ofrece'` o `null` si el usuario cierra sin elegir.
/// Solo se llama UNA vez: el resultado se persiste en SharedPreferences.
Future<String?> showEmpleoRoleSelector(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _EmpleoRoleSelectorSheet(),
  );
}

class _EmpleoRoleSelectorSheet extends StatelessWidget {
  const _EmpleoRoleSelectorSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FFFE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCCE8E6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 28),

          // Ícono principal
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('💼', style: TextStyle(fontSize: 30)),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Oportunidades laborales',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF134E4A),
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '¿Cómo querés usar esta sección?\nPodés cambiarlo cuando quieras desde tu perfil.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // ── Opción: Se busca ──────────────────────────────────────────────
          _RoleOption(
            emoji: '🔍',
            title: 'Estoy buscando trabajo',
            subtitle:
                'Explorá ofertas, postulate y encontrá oportunidades cerca de vos.',
            accentColor: const Color(0xFF0D9488),
            onTap: () => Navigator.pop(context, 'busca'),
          ),

          const SizedBox(height: 14),

          // ── Opción: Se ofrece ─────────────────────────────────────────────
          _RoleOption(
            emoji: '🏢',
            title: 'Soy empleador / ofrezco trabajo',
            subtitle:
                'Publicá puestos, revisá postulantes y gestioná tus ofertas.',
            accentColor: const Color(0xFF7C3AED),
            onTap: () => Navigator.pop(context, 'ofrece'),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accentColor.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: accentColor.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:math' show pi;

import '../nueva_historia_screen.dart';
import '../nueva_publicacion_screen.dart';
import '../crear_evento_screen.dart';
import '../mensaje_comunidad_screen.dart';

// NOTA sobre los imports: ajustá las rutas según tu estructura de carpetas.
// Si las pantallas están en features/feed/, los imports de arriba son correctos.
// Si las pusiste en otra carpeta, actualizá las rutas.

class StoriesBar extends StatelessWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> stories = [
      {"name": "Mi historia", "isCreate": true},
      {"name": "Carlos", "viewed": false},
      {"name": "Sofía", "viewed": true},
      {"name": "Lucas", "viewed": false},
      {"name": "Valentina", "viewed": true},
      {"name": "Andrés", "viewed": false},
    ];

    stories.sort((a, b) {
      final aCreate = (a["isCreate"] as bool?) ?? false;
      final bCreate = (b["isCreate"] as bool?) ?? false;
      if (aCreate) return -1;
      if (bCreate) return 1;
      final aViewed = (a["viewed"] as bool?) ?? false;
      final bViewed = (b["viewed"] as bool?) ?? false;
      if (aViewed == bViewed) return 0;
      return aViewed ? 1 : -1;
    });

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: stories.length,
        itemBuilder: (context, index) {
          final story = stories[index];
          return _StoryBubble(
            name: story["name"] as String,
            isCreate: (story["isCreate"] as bool?) ?? false,
            viewed: (story["viewed"] as bool?) ?? false,
          );
        },
      ),
    );
  }
}

// ── Blob shape painter ────────────────────────────────────────

class _BlobBorderPainter extends CustomPainter {
  final double progress;
  final bool viewed;

  const _BlobBorderPainter({required this.progress, required this.viewed});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shapes = [
      [0.30, 0.70, 0.70, 0.30, 0.70, 0.30, 0.30, 0.70],
      [0.70, 0.30, 0.30, 0.70, 0.30, 0.70, 0.70, 0.30],
      [0.50, 0.50, 0.30, 0.70, 0.60, 0.40, 0.60, 0.40],
      [0.40, 0.60, 0.70, 0.30, 0.40, 0.70, 0.30, 0.60],
    ];

    final totalShapes = shapes.length;
    final scaledProgress = progress * totalShapes;
    final shapeIndex = scaledProgress.floor() % totalShapes;
    final nextIndex = (shapeIndex + 1) % totalShapes;
    final t = scaledProgress - scaledProgress.floor();
    final ease = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

    final current = shapes[shapeIndex];
    final next = shapes[nextIndex];
    final r = List.generate(
      8,
      (i) => current[i] + (next[i] - current[i]) * ease,
    );

    final path = _buildBlobPath(w, h, r);

    if (!viewed) {
      final gradient = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0D9488), Color(0xFF34D399)],
      );
      final paint = Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, paint);
    } else {
      final paint = Paint()
        ..color = const Color(0xFFD1D5DB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(path, paint);
    }
  }

  Path _buildBlobPath(double w, double h, List<double> r) {
    final tlH = r[0] * w, tlV = r[1] * h;
    final trH = r[2] * w, trV = r[3] * h;
    final brH = r[4] * w, brV = r[5] * h;
    final blH = r[6] * w, blV = r[7] * h;

    return Path()
      ..moveTo(tlH, 0)
      ..lineTo(w - trH, 0)
      ..quadraticBezierTo(w, 0, w, trV)
      ..lineTo(w, h - brV)
      ..quadraticBezierTo(w, h, w - brH, h)
      ..lineTo(blH, h)
      ..quadraticBezierTo(0, h, 0, h - blV)
      ..lineTo(0, tlV)
      ..quadraticBezierTo(0, 0, tlH, 0)
      ..close();
  }

  @override
  bool shouldRepaint(_BlobBorderPainter old) =>
      old.progress != progress || old.viewed != viewed;
}

// ── Story bubble ──────────────────────────────────────────────

class _StoryBubble extends StatefulWidget {
  final String name;
  final bool isCreate;
  final bool viewed;

  const _StoryBubble({
    required this.name,
    this.isCreate = false,
    this.viewed = false,
  });

  @override
  State<_StoryBubble> createState() => _StoryBubbleState();
}

class _StoryBubbleState extends State<_StoryBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _handleTap(context);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 72,
          margin: const EdgeInsets.only(right: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => SizedBox(
                  width: 66,
                  height: 66,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(66, 66),
                        painter: _BlobBorderPainter(
                          progress: _anim.value,
                          viewed: widget.viewed,
                        ),
                      ),
                      ClipPath(
                        clipper: _BlobClippy(progress: _anim.value),
                        child: SizedBox(
                          width: 58,
                          height: 58,
                          child: widget.isCreate
                              ? Container(
                                  color: const Color(0xFFE6FAF8),
                                  child: const Icon(
                                    Icons.add,
                                    size: 28,
                                    color: Color(0xFF0D9488),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFFE6FAF8),
                                  child: Icon(
                                    Icons.person,
                                    size: 28,
                                    color: widget.viewed
                                        ? Colors.grey
                                        : const Color(0xFF0D9488),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: widget.viewed ? Colors.grey : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (widget.isCreate) {
      _openCreateMenu(context);
    }
    // TODO: si no es isCreate, abrir el viewer de la historia
  }

  // ── Bottom sheet de creación ───────────────────────────────────────────────

  void _openCreateMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              _OpcionMenu(
                emoji: '🕐',
                titulo: 'Nueva historia',
                subtitulo: 'Desaparece en 24 horas',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NuevaHistoriaScreen(),
                    ),
                  );
                },
              ),

              _OpcionMenu(
                emoji: '🖼️',
                titulo: 'Nueva publicación',
                subtitulo: 'Aparece en el feed y tu perfil',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NuevaPublicacionScreen(),
                    ),
                  );
                },
              ),

              _OpcionMenu(
                emoji: '📅',
                titulo: 'Crear evento',
                subtitulo: 'Con fecha, lugar y descripción',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CrearEventoScreen(),
                    ),
                  );
                },
              ),

              _OpcionMenu(
                emoji: '📣',
                titulo: 'Mensaje a la comunidad',
                subtitulo: 'Un aviso para todos los nomads',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MensajeComunidadScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Opción del menú ───────────────────────────────────────────────────────────

class _OpcionMenu extends StatelessWidget {
  final String emoji;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _OpcionMenu({
    required this.emoji,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE6FAF8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF134E4A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF5EEAD4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Clipper separado ──────────────────────────────────────────────────────────

class _BlobClippy extends CustomClipper<Path> {
  final double progress;
  const _BlobClippy({required this.progress});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    final shapes = [
      [0.30, 0.70, 0.70, 0.30, 0.70, 0.30, 0.30, 0.70],
      [0.70, 0.30, 0.30, 0.70, 0.30, 0.70, 0.70, 0.30],
      [0.50, 0.50, 0.30, 0.70, 0.60, 0.40, 0.60, 0.40],
      [0.40, 0.60, 0.70, 0.30, 0.40, 0.70, 0.30, 0.60],
    ];

    final n = shapes.length;
    final sp = progress * n;
    final si = sp.floor() % n;
    final ni = (si + 1) % n;
    final t = sp - sp.floor();
    final ease = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
    final cur = shapes[si];
    final nxt = shapes[ni];
    final r = List.generate(8, (i) => cur[i] + (nxt[i] - cur[i]) * ease);

    final tlH = r[0] * w, tlV = r[1] * h;
    final trH = r[2] * w, trV = r[3] * h;
    final brH = r[4] * w, brV = r[5] * h;
    final blH = r[6] * w, blV = r[7] * h;

    return Path()
      ..moveTo(tlH, 0)
      ..lineTo(w - trH, 0)
      ..quadraticBezierTo(w, 0, w, trV)
      ..lineTo(w, h - brV)
      ..quadraticBezierTo(w, h, w - brH, h)
      ..lineTo(blH, h)
      ..quadraticBezierTo(0, h, 0, h - blV)
      ..lineTo(0, tlV)
      ..quadraticBezierTo(0, 0, tlH, 0)
      ..close();
  }

  @override
  bool shouldReclip(_BlobClippy old) => old.progress != progress;
}
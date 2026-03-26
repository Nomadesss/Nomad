import 'package:flutter/material.dart';
import 'dart:math' show pi;
import 'dart:ui' show ImageFilter;

import '../nueva_historia_screen.dart';
import '../nueva_publicacion_screen.dart';
import '../crear_evento_screen.dart';
import '../mensaje_comunidad_screen.dart';

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

  // ── Bottom sheet — Glass teal oscuro ──────────────────────────────────────
  //
  // Diseño: panel traslúcido sobre fondo oscuro teal (#0F2E29).
  // Cada opción tiene su propio tinte de color + tag identificador.
  // isScrollControlled: true para que el sheet se ajuste al contenido
  // sin forzar altura fija.

  void _openCreateMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Fondo oscuro detrás del sheet — refuerza la atmósfera teal.
      barrierColor: const Color(0xFF0A2420).withOpacity(0.72),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CreateMenuSheet(),
    );
  }
}

// ── Sheet completo ────────────────────────────────────────────────────────────

class _CreateMenuSheet extends StatefulWidget {
  const _CreateMenuSheet();

  @override
  State<_CreateMenuSheet> createState() => _CreateMenuSheetState();
}

class _CreateMenuSheetState extends State<_CreateMenuSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);

    _slide = Tween(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  static const options = [
    _CreateOption(
      icon: Icons.auto_awesome_rounded,
      title: "Nueva historia",
      subtitle: "Desaparece en 24 horas",
      color: Color(0xFF14B8A6),
      tag: "24h",
    ),

    _CreateOption(
      icon: Icons.grid_view_rounded,
      title: "Nueva publicación",
      subtitle: "Aparece en el feed",
      color: Color(0xFFF59E0B),
      tag: "Feed",
    ),

    _CreateOption(
      icon: Icons.event_rounded,
      title: "Crear evento",
      subtitle: "Con fecha y ubicación",
      color: Color(0xFF3B82F6),
      tag: "Evento",
    ),

    _CreateOption(
      icon: Icons.campaign_rounded,
      title: "Mensaje a la comunidad",
      subtitle: "Aviso global",
      color: Color(0xFFA855F7),
      tag: "Global",
    ),
  ];

  void navigate(BuildContext context, int index) {
    Navigator.pop(context);

    final screens = [
      const NuevaHistoriaScreen(),
      const NuevaPublicacionScreen(),
      const CrearEventoScreen(),
      const MensajeComunidadScreen(),
    ];

    Navigator.push(context, MaterialPageRoute(builder: (_) => screens[index]));
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,

      child: FadeTransition(
        opacity: _fade,

        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),

          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),

            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),

              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,

                  colors: [
                    const Color(0xFF0B1F1B).withOpacity(.96),
                    const Color(0xFF071513).withOpacity(.98),
                  ],
                ),

                border: Border.all(color: Colors.white.withOpacity(.07)),
              ),

              child: SafeArea(
                top: false,

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.18),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),

                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(bottom: 14),

                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,

                            Colors.white.withOpacity(.08),

                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    Text(
                      "Crear",

                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,

                        color: Colors.white.withOpacity(.92),
                      ),
                    ),

                    const SizedBox(height: 22),

                    ...List.generate(
                      options.length,

                      (i) => _CreateTile(
                        data: options[i],
                        onTap: () => navigate(context, i),
                      ),
                    ),

                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateOption {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String tag;

  const _CreateOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.tag,
  });
}

class _CreateTile extends StatefulWidget {
  final _CreateOption data;
  final VoidCallback onTap;

  const _CreateTile({required this.data, required this.onTap});

  @override
  State<_CreateTile> createState() => _CreateTileState();
}

class _CreateTileState extends State<_CreateTile> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    return GestureDetector(
      onTapDown: (_) => setState(() => pressed = true),

      onTapUp: (_) {
        setState(() => pressed = false);
        widget.onTap();
      },

      onTapCancel: () => setState(() => pressed = false),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),

        margin: const EdgeInsets.only(bottom: 14),

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),

          color: pressed ? d.color.withOpacity(.20) : d.color.withOpacity(.11),

          border: Border.all(color: Colors.white.withOpacity(.08)),

          boxShadow: [
            BoxShadow(
              color: d.color.withOpacity(.08),

              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),

        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,

              decoration: BoxDecoration(
                color: d.color.withOpacity(.18),

                borderRadius: BorderRadius.circular(16),
              ),

              child: Icon(d.icon, color: d.color, size: 24),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    d.title,

                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.2,

                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    d.subtitle,

                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withOpacity(.55),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

              decoration: BoxDecoration(
                color: d.color.withOpacity(.18),

                borderRadius: BorderRadius.circular(10),
              ),

              child: Text(
                d.tag,

                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,

                  color: d.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Datos de cada opción ──────────────────────────────────────────────────────

class _OpcionData {
  final String emoji;
  final String titulo;
  final String subtitulo;
  final Color tintColor;
  final Color tagColor;
  final Color tagBg;
  final String tagTexto;

  const _OpcionData({
    required this.emoji,
    required this.titulo,
    required this.subtitulo,
    required this.tintColor,
    required this.tagColor,
    required this.tagBg,
    required this.tagTexto,
  });
}

// ── Fila individual con glass y tinte ────────────────────────────────────────

class _GlassOpcion extends StatefulWidget {
  final _OpcionData data;
  final VoidCallback onTap;

  const _GlassOpcion({required this.data, required this.onTap});

  @override
  State<_GlassOpcion> createState() => _GlassOpcionState();
}

class _GlassOpcionState extends State<_GlassOpcion> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            // Tinte individual de color sobre fondo glass.
            color: _pressed
                ? widget.data.tintColor.withOpacity(0.18)
                : widget.data.tintColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? Colors.white.withOpacity(0.20)
                  : Colors.white.withOpacity(0.08),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              // Ícono con fondo tintado
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.data.tintColor.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    widget.data.emoji,
                    style: const TextStyle(fontSize: 18),
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
                      widget.data.titulo,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.90),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.data.subtitulo,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Tag de categoría
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.data.tagBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.data.tagTexto,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: widget.data.tagColor,
                  ),
                ),
              ),
            ],
          ),
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

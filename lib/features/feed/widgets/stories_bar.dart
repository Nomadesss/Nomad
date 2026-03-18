import 'package:flutter/material.dart';
import 'dart:math' show pi;

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

    // Interpola entre 4 formas de border-radius usando puntos de control
    // Cada forma está definida por 8 valores de radio (TL-H, TL-V, TR-H, TR-V, BR-H, BR-V, BL-H, BL-V)
    final shapes = [
      [0.30, 0.70, 0.70, 0.30, 0.70, 0.30, 0.30, 0.70],
      [0.70, 0.30, 0.30, 0.70, 0.30, 0.70, 0.70, 0.30],
      [0.50, 0.50, 0.30, 0.70, 0.60, 0.40, 0.60, 0.40],
      [0.40, 0.60, 0.70, 0.30, 0.40, 0.70, 0.30, 0.60],
    ];

    // Interpola entre la forma actual y la siguiente
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

    // Dibuja el path del blob con los radios interpolados
    final path = _buildBlobPath(w, h, r);

    if (!viewed) {
      // Borde con gradiente
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
      // Borde gris para vistas
      final paint = Paint()
        ..color = const Color(0xFFD1D5DB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(path, paint);
    }
  }

  Path _buildBlobPath(double w, double h, List<double> r) {
    // r = [TL-H, TL-V, TR-H, TR-V, BR-H, BR-V, BL-H, BL-V] como fracción de w/h
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

class _BlobClipper extends CustomClipper<Path> {
  final double progress;

  const _BlobClipper({required this.progress});

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
  bool shouldReclip(_BlobClipper old) => old.progress != progress;
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
                      // Borde blob animado
                      CustomPaint(
                        size: const Size(66, 66),
                        painter: _BlobBorderPainter(
                          progress: _anim.value,
                          viewed: widget.viewed,
                        ),
                      ),
                      // Avatar con clip blob
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
    if (widget.isCreate) _openCreateMenu(context);
  }

  void _openCreateMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Nueva historia"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text("Nueva publicación"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text("Crear evento"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text("Mensaje a la comunidad"),
              onTap: () {},
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ── Clipper separado (necesita ser clase top-level o named) ───

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

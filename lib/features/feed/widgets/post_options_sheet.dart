import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PostOptionsSheet — menú de 3 puntitos estilo Facebook, colores Nomad
// ─────────────────────────────────────────────────────────────────────────────

class PostOptionsSheet {
  static void show(
    BuildContext context, {
    required String postId,
    required String username,
    bool isOwnPost = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF0A2420).withOpacity(0.55),
      builder: (_) => _PostOptionsContent(
        postId: postId,
        username: username,
        isOwnPost: isOwnPost,
      ),
    );
  }
}

class _PostOptionsContent extends StatelessWidget {
  final String postId;
  final String username;
  final bool isOwnPost;

  const _PostOptionsContent({
    required this.postId,
    required this.username,
    required this.isOwnPost,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F2422),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2D5550),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // ── Grupo 1: Interés ──────────────────────────────────────────────
          _OptionsGroup(
            children: [
              _OptionTile(
                icon: PhosphorIcons.thumbsUp(),
                label: 'Me interesa',
                subtitle: 'Verás más publicaciones como esta en el feed.',
                onTap: () {
                  Navigator.pop(context);
                  _showSnack(context, 'Marcado como interesante');
                },
              ),
              _Divider(),
              _OptionTile(
                icon: PhosphorIcons.thumbsDown(),
                label: 'No me interesa',
                subtitle: 'Verás menos publicaciones como esta en el feed.',
                onTap: () {
                  Navigator.pop(context);
                  _showSnack(context, 'Preferencia guardada');
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Grupo 2: ¿Por qué veo esto? ──────────────────────────────────
          _OptionsGroup(
            children: [
              _OptionTile(
                icon: PhosphorIcons.question(),
                label: '¿Por qué veo esta publicación?',
                subtitle:
                    'Esta publicación se sugirió en función de tu actividad.',
                labelColor: const Color(0xFF4DC9C2),
                onTap: () {
                  Navigator.pop(context);
                  _showWhyDialog(context);
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Grupo 3: Acciones ─────────────────────────────────────────────
          _OptionsGroup(
            children: [
              _OptionTile(
                icon: PhosphorIcons.bookmarkSimple(),
                label: 'Guardar publicación',
                onTap: () {
                  Navigator.pop(context);
                  _showSnack(context, 'Publicación guardada');
                },
              ),
              _Divider(),
              _OptionTile(
                icon: PhosphorIcons.bellSimple(),
                label: 'Recibir notificaciones',
                subtitle: 'Activa alertas sobre esta publicación.',
                onTap: () {
                  Navigator.pop(context);
                  _showSnack(context, 'Notificaciones activadas');
                },
              ),
              _Divider(),
              _OptionTile(
                icon: PhosphorIcons.userPlus(),
                label: 'Seguir a $username',
                subtitle: 'Ver publicaciones de $username.',
                onTap: () {
                  Navigator.pop(context);
                  _showSnack(context, 'Siguiendo a $username');
                },
              ),
              if (isOwnPost) ...[
                _Divider(),
                _OptionTile(
                  icon: PhosphorIcons.trash(),
                  label: 'Eliminar publicación',
                  labelColor: const Color(0xFFF87171),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirm(context, postId);
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // ── Grupo 4: Reportar ─────────────────────────────────────────────
          _OptionsGroup(
            children: [
              _OptionTile(
                icon: PhosphorIcons.flag(),
                label: 'Reportar publicación',
                subtitle: 'No le diremos a $username quién envió el reporte.',
                labelColor: const Color(0xFFF87171),
                onTap: () {
                  Navigator.pop(context);
                  _showSnack(context, 'Reporte enviado. Gracias.');
                },
              ),
            ],
          ),

          SizedBox(height: bottomPadding + 16),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0D9488),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showWhyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F2422),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Por qué veo esta publicación?',
          style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 16),
        ),
        content: const Text(
          'Esta publicación se sugirió en función de tu ubicación, actividad reciente y las personas que seguís.',
          style: TextStyle(color: Color(0xFF99B8B5), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Entendido',
              style: TextStyle(color: Color(0xFF4DC9C2)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F2422),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar publicación',
          style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 16),
        ),
        content: const Text(
          '¿Estás seguro? Esta acción no se puede deshacer.',
          style: TextStyle(color: Color(0xFF99B8B5), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF4DC9C2)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: llamar al servicio para eliminar el post
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grupo de opciones con fondo glass ────────────────────────────────────────
class _OptionsGroup extends StatelessWidget {
  final List<Widget> children;
  const _OptionsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D5550), width: 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// ── Divider interno ───────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 56),
      color: const Color(0xFF2D5550),
    );
  }
}

// ── Fila de opción individual ─────────────────────────────────────────────────
class _OptionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.labelColor,
    required this.onTap,
  });

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed
              ? const Color(0xFF0D9488).withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 18,
                color: widget.labelColor ?? const Color(0xFF4DC9C2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.labelColor ?? const Color(0xFFCCFBF1),
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B9E99),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

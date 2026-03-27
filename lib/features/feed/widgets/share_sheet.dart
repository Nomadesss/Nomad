import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShareSheet — bottom sheet estilo Instagram, colores Nomad
// ─────────────────────────────────────────────────────────────────────────────

class ShareSheet {
  static void show(
    BuildContext context, {
    required String postId,
    required String username,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheetContent(postId: postId, username: username),
    );
  }
}

class _ShareSheetContent extends StatefulWidget {
  final String postId;
  final String username;

  const _ShareSheetContent({required this.postId, required this.username});

  @override
  State<_ShareSheetContent> createState() => _ShareSheetContentState();
}

class _ShareSheetContentState extends State<_ShareSheetContent> {
  final TextEditingController _searchController = TextEditingController();
  final List<_MockContact> _allContacts = _MockContact.samples();
  List<_MockContact> _filtered = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _filtered = _allContacts;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allContacts
          : _allContacts
                .where((c) => c.name.toLowerCase().contains(q))
                .toList();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    });
  }

  String get _postLink => 'https://nomad.app/post/${widget.postId}';

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _postLink));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Enlace copiado'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _sendToSelected() {
    if (_selected.isEmpty) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Enviado a ${_selected.length} persona${_selected.length > 1 ? 's' : ''}',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
          const SizedBox(height: 16),

          // ── Fila de contactos ─────────────────────────────────────────────
          SizedBox(
            height: 108,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(width: 20),
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final isSel = _selected.contains(c.id);
                return GestureDetector(
                  onTap: () => _toggleSelect(c.id),
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSel
                                    ? const Color(0xFF0D9488)
                                    : const Color(0xFF1A3A36),
                                border: Border.all(
                                  color: isSel
                                      ? const Color(0xFF0D9488)
                                      : const Color(0xFF2D5550),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: isSel
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 26,
                                      )
                                    : Text(
                                        c.initials,
                                        style: const TextStyle(
                                          color: Color(0xFF99E6E0),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          c.firstName,
                          style: const TextStyle(
                            color: Color(0xFFCCFBF1),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // ── Buscador ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A36),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2D5550)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    PhosphorIcons.magnifyingGlass(),
                    size: 17,
                    color: const Color(0xFF4D9E98),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        color: Color(0xFFCCFBF1),
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Buscar',
                        hintStyle: TextStyle(color: Color(0xFF4D9E98)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Botón enviar (aparece si hay seleccionados) ───────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _selected.isNotEmpty
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _sendToSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _selected.length == 1
                        ? 'Enviar'
                        : 'Enviar a ${_selected.length}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            secondChild: const SizedBox(height: 0),
          ),

          // ── Divider ───────────────────────────────────────────────────────
          Container(height: 1, color: const Color(0xFF1A3A36)),

          // ── Fila de acciones rápidas (estilo Instagram) ───────────────────
          SizedBox(
            height: 116,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              scrollDirection: Axis.horizontal,
              children: [
                _QuickAction(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Agregar a\nhistoria',
                  color: const Color(0xFF0D9488),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 20),
                _QuickAction(
                  customIcon: _WhatsAppIcon(),
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 20),
                _QuickAction(
                  icon: PhosphorIcons.link(),
                  label: 'Copiar\nenlace',
                  color: const Color(0xFF2D5550),
                  onTap: _copyLink,
                ),
                const SizedBox(width: 20),
                _QuickAction(
                  customIcon: _FacebookIcon(),
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 20),
                _QuickAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Compartir\nen...',
                  color: const Color(0xFF2D5550),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          SizedBox(height: bottomPadding + 8),
        ],
      ),
    );
  }
}

// ── Acción rápida circular ────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    this.icon,
    this.customIcon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: Center(
                child: customIcon ?? Icon(icon, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFCCFBF1),
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ícono WhatsApp (SVG path inline) ─────────────────────────────────────────
class _WhatsAppIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.chat, color: Colors.white, size: 26);
  }
}

// ── Ícono Facebook ────────────────────────────────────────────────────────────
class _FacebookIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'f',
      style: TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }
}

// ── Modelo mock de contactos ──────────────────────────────────────────────────
class _MockContact {
  final String id;
  final String name;

  const _MockContact({required this.id, required this.name});

  String get firstName => name.split(' ').first;

  String get initials {
    final parts = name.trim().split(' ');
    return parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : parts[0][0].toUpperCase();
  }

  static List<_MockContact> samples() => [
    _MockContact(id: '1', name: 'Ana García'),
    _MockContact(id: '2', name: 'Luis Martínez'),
    _MockContact(id: '3', name: 'Carla Ruiz'),
    _MockContact(id: '4', name: 'Pedro López'),
    _MockContact(id: '5', name: 'Sofía Torres'),
    _MockContact(id: '6', name: 'Mateo Silva'),
    _MockContact(id: '7', name: 'Valentina Paz'),
    _MockContact(id: '8', name: 'Diego Vera'),
  ];
}

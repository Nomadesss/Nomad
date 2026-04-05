import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

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
  final List<_MockContact> _allContacts = _MockContact.sortedByAffinity();
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
        backgroundColor: const Color(0xFF0D9488),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareWhatsApp() async {
    final text = Uri.encodeComponent(
      'Mirá esta publicación de @${widget.username} en Nomad: $_postLink',
    );
    final uri = Uri.parse('whatsapp://send?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await _shareNative();
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareFacebook() async {
    final uri = Uri.parse(
      'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_postLink)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {
        // Fallback: compartir nativo
        await _shareNative();
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareNative() async {
    await Share.share(
      'Mirá esta publicación de @${widget.username} en Nomad: $_postLink',
      subject: 'Publicación en Nomad',
    );
    if (mounted) Navigator.pop(context);
  }

  void _addToStory() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Próximamente: agregar a historia'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0D9488),
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
        backgroundColor: const Color(0xFF0D9488),
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
          // ── Handle ──────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2D5550),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // ── Fila de contactos ordenados por afinidad ─────────────
          SizedBox(
            height: 96,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final isSel = _selected.contains(c.id);
                return GestureDetector(
                  onTap: () => _toggleSelect(c.id),
                  child: SizedBox(
                    width: 54,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel
                                      ? const Color(0xFF0D9488)
                                      : const Color(0xFF2D5550),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: isSel
                                    ? ColorFiltered(
                                        colorFilter: ColorFilter.mode(
                                          const Color(
                                            0xFF0D9488,
                                          ).withOpacity(0.6),
                                          BlendMode.srcOver,
                                        ),
                                        child: _buildAvatar(c),
                                      )
                                    : _buildAvatar(c),
                              ),
                            ),
                            if (isSel)
                              const Positioned.fill(
                                child: Center(
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          c.firstName,
                          style: const TextStyle(
                            color: Color(0xFFCCFBF1),
                            fontSize: 11,
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

          const SizedBox(height: 12),

          // ── Buscador ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.magnifyingGlass(),
                  size: 16,
                  color: const Color(0xFF4D9E98),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                      color: Color(0xFFCCFBF1),
                      fontSize: 22,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Buscar',
                      hintStyle: TextStyle(
                        color: Color(0xFF4D9E98),
                        fontSize: 18,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Botón enviar ─────────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _selected.isNotEmpty
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SizedBox(
                width: double.infinity,
                height: 44,
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

          // ── Divider ──────────────────────────────────────────────
          Container(height: 1, color: const Color(0xFF1A3A36)),

          // ── Acciones rápidas ─────────────────────────────────────
          SizedBox(
            height: 100,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              scrollDirection: Axis.horizontal,
              children: [
                _QuickAction(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Historia',
                  color: const Color(0xFF0D9488),
                  onTap: _addToStory,
                ),
                const SizedBox(width: 20),
                _QuickAction(
                  customIcon: _WhatsAppIcon(),
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: _shareWhatsApp,
                ),
                const SizedBox(width: 20),
                _QuickAction(
                  icon: PhosphorIcons.link(),
                  label: 'Copiar link',
                  color: const Color(0xFF2D5550),
                  onTap: _copyLink,
                ),
                const SizedBox(width: 20),
                _QuickAction(
                  customIcon: _FacebookIcon(),
                  label: 'Facebook',
                  color: const Color(0xFF1877F2),
                  onTap: _shareFacebook,
                ),
                const SizedBox(width: 20),
                _QuickAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Compartir',
                  color: const Color(0xFF2D5550),
                  onTap: _shareNative,
                ),
              ],
            ),
          ),

          SizedBox(height: bottomPadding + 8),
        ],
      ),
    );
  }

  Widget _buildAvatar(_MockContact c) {
    return Image.network(
      c.avatarUrl,
      width: 52,
      height: 52,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF1A3A36),
        child: Center(
          child: Text(
            c.initials,
            style: const TextStyle(
              color: Color(0xFF99E6E0),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Acción rápida circular ────────────────────────────────────

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
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: Center(
                child: customIcon ?? Icon(icon, color: Colors.white, size: 22),
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
                fontSize: 10,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Íconos desde assets ───────────────────────────────────────

class _WhatsAppIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/icons/whatsapp.png', width: 28, height: 28);
}

class _FacebookIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/icons/facebook.png', width: 28, height: 28);
}

// ── Modelo con score de afinidad ─────────────────────────────

class _MockContact {
  final String id;
  final String name;
  final String avatarUrl;
  final int affinityScore;

  const _MockContact({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.affinityScore,
  });

  String get firstName => name.split(' ').first;

  String get initials {
    final parts = name.trim().split(' ');
    return parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : parts[0][0].toUpperCase();
  }

  static List<_MockContact> sortedByAffinity() {
    final list = [
      const _MockContact(
        id: '1',
        name: 'Ana García',
        avatarUrl: 'https://randomuser.me/api/portraits/women/44.jpg',
        affinityScore: 95,
      ),
      const _MockContact(
        id: '2',
        name: 'Luis Martínez',
        avatarUrl: 'https://randomuser.me/api/portraits/men/32.jpg',
        affinityScore: 88,
      ),
      const _MockContact(
        id: '3',
        name: 'Carla Ruiz',
        avatarUrl: 'https://randomuser.me/api/portraits/women/68.jpg',
        affinityScore: 82,
      ),
      const _MockContact(
        id: '4',
        name: 'Pedro López',
        avatarUrl: 'https://randomuser.me/api/portraits/men/75.jpg',
        affinityScore: 74,
      ),
      const _MockContact(
        id: '5',
        name: 'Sofía Torres',
        avatarUrl: 'https://randomuser.me/api/portraits/women/90.jpg',
        affinityScore: 68,
      ),
      const _MockContact(
        id: '6',
        name: 'Mateo Silva',
        avatarUrl: 'https://randomuser.me/api/portraits/men/12.jpg',
        affinityScore: 61,
      ),
      const _MockContact(
        id: '7',
        name: 'Valentina Paz',
        avatarUrl: 'https://randomuser.me/api/portraits/women/21.jpg',
        affinityScore: 55,
      ),
      const _MockContact(
        id: '8',
        name: 'Diego Vera',
        avatarUrl: 'https://randomuser.me/api/portraits/men/55.jpg',
        affinityScore: 48,
      ),
    ];
    list.sort((a, b) => b.affinityScore.compareTo(a.affinityScore));
    return list;
  }
}

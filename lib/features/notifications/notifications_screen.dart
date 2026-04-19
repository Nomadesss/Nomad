import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const _teal = Color(0xFF0D9488);
const _tealDark = Color(0xFF134E4A);
const _tealBg = Color(0xFFF0FAF9);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    if (_userId == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: _userId)
        .where('read', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    if (_userId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  IconData _icon(String type) {
    switch (type) {
      case 'like':    return Icons.favorite_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      case 'follow':  return Icons.person_add_rounded;
      case 'mention': return Icons.alternate_email_rounded;
      case 'event':   return Icons.event_rounded;
      case 'match':   return Icons.favorite_border_rounded;
      default:        return Icons.notifications_rounded;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'like':    return const Color(0xFFEF4444);
      case 'comment': return const Color(0xFF3B82F6);
      case 'follow':  return const Color(0xFF8B5CF6);
      case 'mention': return const Color(0xFFF59E0B);
      case 'event':   return _teal;
      case 'match':   return const Color(0xFFEC4899);
      default:        return const Color(0xFF6B7280);
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('d MMM', 'es').format(dt);
  }

  String _groupLabel(Timestamp? ts) {
    if (ts == null) return 'Antes';
    final dt = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final docDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(docDay).inDays;
    if (diff == 0) return 'Hoy';
    if (diff <= 7) return 'Esta semana';
    return 'Antes';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final docs = snapshot.data?.docs ?? [];

          // Filtrar por tipo
          final filtered = _filter == 'all'
              ? docs
              : docs.where((d) => (d.data()['type'] as String?) == _filter).toList();

          // Agrupar por fecha
          final groups = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
          for (final doc in filtered) {
            final ts = doc.data()['createdAt'] as Timestamp?;
            final label = _groupLabel(ts);
            groups.putIfAbsent(label, () => []).add(doc);
          }

          // Construir items lineales: [header, item, item, header, item...]
          final items = <_ListItem>[];
          for (final label in ['Hoy', 'Esta semana', 'Antes']) {
            final group = groups[label];
            if (group == null || group.isEmpty) continue;
            items.add(_ListItem.header(label));
            for (final doc in group) {
              items.add(_ListItem.notification(doc));
            }
          }

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(unreadCount: docs.where((d) => !(d.data()['read'] as bool? ?? true)).length),
              SliverToBoxAdapter(child: _buildFilterChips()),
              if (isLoading)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => const _NotifSkeleton(),
                    childCount: 8,
                  ),
                )
              else if (items.isEmpty)
                SliverFillRemaining(child: _buildEmpty())
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final item = items[i];
                      if (item.isHeader) return _SectionHeader(label: item.label!);
                      final data = item.doc!.data();
                      return _NotifTile(
                        type: data['type'] as String? ?? 'generic',
                        fromUsername: data['fromUsername'] as String? ?? 'Alguien',
                        fromAvatar: data['fromAvatarUrl'] as String?,
                        body: data['body'] as String? ?? '',
                        createdAt: data['createdAt'] as Timestamp?,
                        isRead: data['read'] as bool? ?? true,
                        icon: _icon(data['type'] as String? ?? ''),
                        iconColor: _color(data['type'] as String? ?? ''),
                        timeAgo: _timeAgo(data['createdAt'] as Timestamp?),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildSliverAppBar({required int unreadCount}) {
    return SliverAppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      floating: true,
      snap: true,
      pinned: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _tealDark, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          const Text(
            'Actividad',
            style: TextStyle(
              color: _tealDark,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _teal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF1F5F9)),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      ('all', 'Todo', Icons.apps_rounded),
      ('like', 'Likes', Icons.favorite_rounded),
      ('comment', 'Comentarios', Icons.chat_bubble_rounded),
      ('follow', 'Seguimientos', Icons.person_add_rounded),
      ('mention', 'Menciones', Icons.alternate_email_rounded),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: filters.length,
        itemBuilder: (context, i) {
          final (value, label, icon) = filters[i];
          final selected = _filter == value;
          return GestureDetector(
            onTap: () => setState(() => _filter = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              decoration: BoxDecoration(
                color: selected ? _teal : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 13, color: selected ? Colors.white : Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFCCFBF1), Color(0xFFE0F2FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 38, color: _teal),
            ),
            const SizedBox(height: 20),
            Text(
              _filter == 'all' ? 'Sin actividad por ahora' : 'Sin notificaciones de este tipo',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _tealDark,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _filter == 'all'
                  ? 'Cuando alguien interactúe con vos\naparecerá acá.'
                  : 'Probá cambiando el filtro.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ListItem — wrapper para unificar headers y notificaciones en un solo ListView
// ─────────────────────────────────────────────────────────────────────────────

class _ListItem {
  final bool isHeader;
  final String? label;
  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  const _ListItem._({required this.isHeader, this.label, this.doc});

  factory _ListItem.header(String label) => _ListItem._(isHeader: true, label: label);
  factory _ListItem.notification(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      _ListItem._(isHeader: false, doc: doc);
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionHeader
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotifTile
// ─────────────────────────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final String type;
  final String fromUsername;
  final String? fromAvatar;
  final String body;
  final Timestamp? createdAt;
  final bool isRead;
  final IconData icon;
  final Color iconColor;
  final String timeAgo;

  const _NotifTile({
    required this.type,
    required this.fromUsername,
    required this.fromAvatar,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.icon,
    required this.iconColor,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final initials = fromUsername.isNotEmpty ? fromUsername[0].toUpperCase() : '?';

    return Material(
      color: isRead ? Colors.white : const Color(0xFFF0FDFB),
      child: InkWell(
        onTap: () {},
        splashColor: _tealBg,
        highlightColor: _tealBg.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar + tipo ───────────────────────────────────────────
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFCCFBF1),
                    backgroundImage: fromAvatar != null ? NetworkImage(fromAvatar!) : null,
                    child: fromAvatar == null
                        ? Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _teal,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(icon, color: Colors.white, size: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // ── Texto + tiempo ──────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: isRead ? const Color(0xFF374151) : const Color(0xFF111827),
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: fromUsername,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(text: body),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: isRead ? Colors.grey.shade400 : _teal,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Punto no leído ──────────────────────────────────────────
              if (!isRead)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotifSkeleton
// ─────────────────────────────────────────────────────────────────────────────

class _NotifSkeleton extends StatefulWidget {
  const _NotifSkeleton();

  @override
  State<_NotifSkeleton> createState() => _NotifSkeletonState();
}

class _NotifSkeletonState extends State<_NotifSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(width: 220, height: 13),
                    const SizedBox(height: 6),
                    _box(width: 160, height: 11),
                    const SizedBox(height: 6),
                    _box(width: 60, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box({required double width, required double height}) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(6),
        ),
      );
}

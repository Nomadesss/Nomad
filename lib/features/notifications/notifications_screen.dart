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

  // Respuestas locales a solicitudes de follow: docId → true=aceptado, false=rechazado
  final Map<String, bool> _followResponses = {};

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

  // ── Aceptar solicitud de follow ───────────────────────────────────────────

  Future<void> _acceptFollow(String docId, String fromUserId) async {
    setState(() => _followResponses[docId] = true);
    try {
      await FirebaseFirestore.instance.collection('follows').add({
        'followerId': fromUserId,
        'followingId': _userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .update({'accepted': true});
    } catch (e) {
      debugPrint('[Notifications] Error al aceptar follow: $e');
    }
  }

  Future<void> _rejectFollow(String docId) async {
    setState(() => _followResponses[docId] = false);
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .update({'accepted': false});
    } catch (e) {
      debugPrint('[Notifications] Error al rechazar follow: $e');
    }
  }

  Future<void> _followBack(String fromUserId) async {
    try {
      await FirebaseFirestore.instance.collection('follows').add({
        'followerId': _userId,
        'followingId': fromUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Notifications] Error al seguir de vuelta: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  IconData _icon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      case 'mention':
        return Icons.alternate_email_rounded;
      case 'event':
        return Icons.event_rounded;
      case 'match':
        return Icons.favorite_border_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'like':
        return const Color(0xFFEF4444);
      case 'comment':
        return const Color(0xFF3B82F6);
      case 'follow':
        return const Color(0xFF8B5CF6);
      case 'mention':
        return const Color(0xFFF59E0B);
      case 'event':
        return _teal;
      case 'match':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF6B7280);
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

          final filtered = _filter == 'all'
              ? docs
              : docs
                    .where((d) => (d.data()['type'] as String?) == _filter)
                    .toList();

          final groups =
              <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
          for (final doc in filtered) {
            final ts = doc.data()['createdAt'] as Timestamp?;
            final label = _groupLabel(ts);
            groups.putIfAbsent(label, () => []).add(doc);
          }

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
              _buildSliverAppBar(
                unreadCount: docs
                    .where((d) => !(d.data()['read'] as bool? ?? true))
                    .length,
              ),
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
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final item = items[i];
                    if (item.isHeader)
                      return _SectionHeader(label: item.label!);

                    final data = item.doc!.data();
                    final docId = item.doc!.id;
                    final type = data['type'] as String? ?? 'generic';
                    final fromUsername =
                        data['fromUsername'] as String? ?? 'Usuario';
                    final fromUserId = data['fromUserId'] as String? ?? '';
                    final fromAvatar = data['fromAvatarUrl'] as String?;
                    final body = data['body'] as String? ?? '';
                    final ts = data['createdAt'] as Timestamp?;
                    final isRead = data['read'] as bool? ?? true;
                    final alreadyAccepted = data['accepted'] as bool?;
                    final localResponse = _followResponses[docId];

                    return _NotifTile(
                      docId: docId,
                      type: type,
                      fromUsername: fromUsername,
                      fromUserId: fromUserId,
                      fromAvatar: fromAvatar,
                      body: body,
                      isRead: isRead,
                      icon: _icon(type),
                      iconColor: _color(type),
                      timeAgo: _timeAgo(ts),
                      followResponse: localResponse,
                      alreadyAccepted: alreadyAccepted,
                      onAccept: type == 'follow'
                          ? () => _acceptFollow(docId, fromUserId)
                          : null,
                      onReject: type == 'follow'
                          ? () => _rejectFollow(docId)
                          : null,
                      onFollowBack:
                          (localResponse == true || alreadyAccepted == true)
                          ? () => _followBack(fromUserId)
                          : null,
                    );
                  }, childCount: items.length),
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
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _tealDark,
          size: 20,
        ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected ? _teal : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: selected ? Colors.white : Colors.grey.shade500,
                  ),
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
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 38,
                color: _teal,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _filter == 'all'
                  ? 'Sin actividad por ahora'
                  : 'Sin notificaciones de este tipo',
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ListItem
// ─────────────────────────────────────────────────────────────────────────────

class _ListItem {
  final bool isHeader;
  final String? label;
  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  const _ListItem._({required this.isHeader, this.label, this.doc});

  factory _ListItem.header(String label) =>
      _ListItem._(isHeader: true, label: label);
  factory _ListItem.notification(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => _ListItem._(isHeader: false, doc: doc);
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
// _NotifTile — con botones de follow estilo Instagram
// ─────────────────────────────────────────────────────────────────────────────

class _NotifTile extends StatefulWidget {
  final String docId;
  final String type;
  final String fromUsername;
  final String fromUserId;
  final String? fromAvatar;
  final String body;
  final bool isRead;
  final IconData icon;
  final Color iconColor;
  final String timeAgo;
  final bool? followResponse;
  final bool? alreadyAccepted;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onFollowBack;

  const _NotifTile({
    required this.docId,
    required this.type,
    required this.fromUsername,
    required this.fromUserId,
    required this.fromAvatar,
    required this.body,
    required this.isRead,
    required this.icon,
    required this.iconColor,
    required this.timeAgo,
    this.followResponse,
    this.alreadyAccepted,
    this.onAccept,
    this.onReject,
    this.onFollowBack,
  });

  @override
  State<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends State<_NotifTile> {
  bool _followedBack = false;

  @override
  Widget build(BuildContext context) {
    final initials = widget.fromUsername.isNotEmpty
        ? widget.fromUsername[0].toUpperCase()
        : '?';

    final responded =
        widget.followResponse != null || widget.alreadyAccepted != null;
    final accepted =
        widget.followResponse == true || widget.alreadyAccepted == true;

    return Material(
      color: widget.isRead ? Colors.white : const Color(0xFFF0FDFB),
      child: InkWell(
        onTap: () {},
        splashColor: _tealBg,
        highlightColor: _tealBg.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar + ícono ────────────────────────────────────────────
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFCCFBF1),
                    backgroundImage: widget.fromAvatar != null
                        ? NetworkImage(widget.fromAvatar!)
                        : null,
                    child: widget.fromAvatar == null
                        ? Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 18,
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
                        color: widget.iconColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 11),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 14),

              // ── Texto + botones ───────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isRead
                              ? const Color(0xFF374151)
                              : const Color(0xFF111827),
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: widget.fromUsername,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(text: widget.body),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      widget.timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isRead ? Colors.grey.shade400 : _teal,
                        fontWeight: widget.isRead
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),

                    // ── Botones de follow ─────────────────────────────────
                    if (widget.type == 'follow') ...[
                      const SizedBox(height: 10),

                      if (!responded) ...[
                        // Pendiente → Confirmar / Eliminar
                        Row(
                          children: [
                            Expanded(
                              child: _FollowButton(
                                label: 'Confirmar',
                                isPrimary: true,
                                onTap: widget.onAccept,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _FollowButton(
                                label: 'Eliminar',
                                isPrimary: false,
                                onTap: widget.onReject,
                              ),
                            ),
                          ],
                        ),
                      ] else if (accepted) ...[
                        // Aceptado → Seguir también / Siguiendo
                        _FollowButton(
                          label: _followedBack
                              ? 'Siguiendo ✓'
                              : 'Seguir también',
                          isPrimary: !_followedBack,
                          onTap: _followedBack
                              ? null
                              : () {
                                  setState(() => _followedBack = true);
                                  widget.onFollowBack?.call();
                                },
                        ),
                      ] else ...[
                        // Rechazado
                        Text(
                          'Solicitud eliminada',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              // ── Punto no leído ────────────────────────────────────────────
              if (!widget.isRead)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _teal,
                      shape: BoxShape.circle,
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

// ─────────────────────────────────────────────────────────────────────────────
// _FollowButton
// ─────────────────────────────────────────────────────────────────────────────

class _FollowButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _FollowButton({
    required this.label,
    required this.isPrimary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 34,
        decoration: BoxDecoration(
          color: isPrimary ? _teal : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: isPrimary ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isPrimary ? Colors.white : const Color(0xFF374151),
            ),
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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.35,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
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

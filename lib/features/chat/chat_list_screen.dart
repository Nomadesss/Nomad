import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';
import 'new_chat_screen.dart';
import '../profile/visitor_profile_screen.dart';

const _teal      = Color(0xFF0D9488);
const _tealLight = Color(0xFF5EEAD4);
const _tealDark  = Color(0xFF134E4A);
const _tealBg    = Color(0xFFF0FAF9);

final Map<String, Map<String, dynamic>> _userCache = {};

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>> _fetchUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid]!;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      _userCache[uid] = data;
      return data;
    } catch (_) { return {}; }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final dt   = ts.toDate();
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return 'Ahora';
    if (diff.inHours   < 24) return DateFormat('HH:mm').format(dt);
    if (diff.inDays    < 7)  return DateFormat('EEE', 'es').format(dt);
    return DateFormat('d/MM').format(dt);
  }

  Future<void> _deleteChat(String chatId) async {
    try {
      final ref = FirebaseFirestore.instance.collection('chats').doc(chatId);
      // Borrar subcolección de mensajes
      final msgs = await ref.collection('messages').limit(500).get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in msgs.docs) batch.delete(doc.reference);
      batch.delete(ref);
      await batch.commit();
    } catch (e) {
      debugPrint('[ChatList] Error borrando chat: $e');
    }
  }

  Future<void> _toggleMute(String chatId, String userId, bool currentlyMuted) async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'mutedBy': currentlyMuted
            ? FieldValue.arrayRemove([userId])
            : FieldValue.arrayUnion([userId]),
      });
    } catch (_) {}
  }

  Future<void> _markUnread(String chatId, String userId) async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'unreadCount.$userId': 1,
      });
    } catch (_) {}
  }

  void _showChatOptions(BuildContext ctx, _ResolvedChat chat, String userId) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatOptionsSheet(
        chat:     chat,
        userId:   userId,
        onViewProfile: () => Navigator.push(
          ctx,
          MaterialPageRoute(
            builder: (_) => VisitorProfileScreen(targetUserId: chat.otherId),
          ),
        ),
        onDelete: () async {
          final confirm = await showDialog<bool>(
            context: ctx,
            builder: (d) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Eliminar conversación',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              content: const Text('Se eliminará para vos. La otra persona seguirá viéndola.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (confirm == true) await _deleteChat(chat.chatId);
        },
        onMuteToggle: () => _toggleMute(chat.chatId, userId, chat.isMuted),
        onMarkUnread: () => _markUnread(chat.chatId, userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: userId == null
          ? const Center(child: Text('Iniciá sesión para ver tus mensajes'))
          : NestedScrollView(
              headerSliverBuilder: (context, _) => [_buildSliverAppBar()],
              body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _chatsStream(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonList();
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error al cargar chats',
                          style: TextStyle(color: Colors.grey.shade400)),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  // Excluir chats que el usuario eliminó (soft delete)
                  final visible = docs.where((d) {
                    final deletedBy = List<String>.from(
                        d.data()['deletedBy'] as List? ?? []);
                    return !deletedBy.contains(userId);
                  }).toList();

                  if (visible.isEmpty) return _buildEmptyState(hasQuery: false);

                  return FutureBuilder<List<_ResolvedChat>>(
                    future: _resolveChats(visible, userId),
                    builder: (context, resolved) {
                      final chats = resolved.data ?? [];

                      final filtered = _query.isEmpty
                          ? chats
                          : chats.where((c) {
                              final q = _query.toLowerCase();
                              return c.otherName.toLowerCase().contains(q) ||
                                  c.otherUsername.toLowerCase().contains(q);
                            }).toList();

                      if (filtered.isEmpty) {
                        return _buildEmptyState(hasQuery: _query.isNotEmpty);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 32),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final c = filtered[i];
                          return _ChatTile(
                            chat:       c,
                            formatDate: _formatDate,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  chatId:         c.chatId,
                                  otherUserId:    c.otherId,
                                  otherUsername:  c.otherUsername,
                                  otherAvatarUrl: c.otherAvatar,
                                  otherName:      c.otherName,
                                ),
                              ),
                            ),
                            onLongPress: () => _showChatOptions(context, c, userId),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  Future<List<_ResolvedChat>> _resolveChats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String userId,
  ) async {
    final results = <_ResolvedChat>[];
    for (final doc in docs) {
      final data          = doc.data();
      final participantIds = List<String>.from(data['participantIds'] as List? ?? []);
      final otherId        = participantIds.firstWhere((id) => id != userId, orElse: () => '');
      if (otherId.isEmpty) continue;

      final userData  = await _fetchUser(otherId);
      final rawName   = (userData['displayName'] as String?)?.trim();
      final rawNombre = (userData['name'] as String?)?.trim();
      final otherName = (rawName?.isNotEmpty == true ? rawName : rawNombre) ?? 'Usuario';

      final unreadMap = data['unreadCount'] as Map<String, dynamic>? ?? {};
      final mutedBy   = List<String>.from(data['mutedBy'] as List? ?? []);

      results.add(_ResolvedChat(
        chatId:        doc.id,
        otherId:       otherId,
        otherName:     otherName,
        otherUsername: (userData['username'] as String?) ?? '',
        otherAvatar:   userData['photoURL'] as String?,
        lastMessage:   data['lastMessage'] as String? ?? '',
        lastMessageAt: data['lastMessageAt'] as Timestamp?,
        myUnread:      (unreadMap[userId] as num?)?.toInt() ?? 0,
        isMuted:       mutedBy.contains(userId),
      ));
    }
    return results;
  }

  SliverAppBar _buildSliverAppBar() {
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
      title: const Text(
        'Mensajes',
        style: TextStyle(
          color: _tealDark,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            icon: Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(color: _tealBg, shape: BoxShape.circle),
              child: const Icon(Icons.edit_outlined, color: _teal, size: 18),
            ),
            tooltip: 'Nuevo mensaje',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewChatScreen()),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(fontSize: 14, color: _tealDark),
              decoration: InputDecoration(
                hintText: 'Buscar conversación…',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        child: Icon(Icons.cancel_rounded, color: Colors.grey.shade400, size: 18),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 6,
      itemBuilder: (_, __) => const _ChatTileSkeleton(),
    );
  }

  Widget _buildEmptyState({required bool hasQuery}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFCCFBF1), Color(0xFFE0F2FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasQuery ? Icons.search_off_rounded : Icons.chat_bubble_outline_rounded,
                size: 36, color: _teal,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery ? 'Sin resultados' : 'Sin conversaciones',
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: _tealDark, letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'No encontramos chats con "$_query"'
                  : 'Visitá el perfil de otro nomad\ny mandále un mensaje.',
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

class _ResolvedChat {
  final String    chatId;
  final String    otherId;
  final String    otherName;
  final String    otherUsername;
  final String?   otherAvatar;
  final String    lastMessage;
  final Timestamp? lastMessageAt;
  final int       myUnread;
  final bool      isMuted;

  const _ResolvedChat({
    required this.chatId,
    required this.otherId,
    required this.otherName,
    required this.otherUsername,
    required this.otherAvatar,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.myUnread,
    required this.isMuted,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChatTile
// ─────────────────────────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  final _ResolvedChat   chat;
  final String Function(Timestamp?) formatDate;
  final VoidCallback    onTap;
  final VoidCallback    onLongPress;

  const _ChatTile({
    required this.chat,
    required this.formatDate,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = chat.myUnread > 0;
    final initials  = chat.otherName.isNotEmpty ? chat.otherName[0].toUpperCase() : '?';
    final preview   = chat.lastMessage.isEmpty ? 'Conversación iniciada' : chat.lastMessage;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap:      onTap,
        onLongPress: onLongPress,
        splashColor:    _tealBg,
        highlightColor: _tealBg.withOpacity(0.4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    padding: EdgeInsets.all(hasUnread ? 2.5 : 0),
                    decoration: hasUnread
                        ? const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [_teal, _tealLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          )
                        : null,
                    child: Container(
                      padding: EdgeInsets.all(hasUnread ? 2 : 0),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFCCFBF1),
                        backgroundImage:
                            chat.otherAvatar != null ? NetworkImage(chat.otherAvatar!) : null,
                        child: chat.otherAvatar == null
                            ? Text(initials,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700, color: _teal))
                            : null,
                      ),
                    ),
                  ),
                  if (chat.isMuted)
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.volume_off_rounded, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 14),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            chat.otherName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                              color: hasUnread ? _tealDark : const Color(0xFF1E293B),
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatDate(chat.lastMessageAt),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                            color: hasUnread ? _teal : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: hasUnread ? const Color(0xFF334155) : Colors.grey.shade500,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_teal, Color(0xFF14B8A6)]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                chat.myUnread > 99 ? '99+' : '${chat.myUnread}',
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
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
// Bottom sheet de opciones del chat
// ─────────────────────────────────────────────────────────────────────────────

class _ChatOptionsSheet extends StatelessWidget {
  final _ResolvedChat  chat;
  final String         userId;
  final VoidCallback   onViewProfile;
  final VoidCallback   onDelete;
  final VoidCallback   onMuteToggle;
  final VoidCallback   onMarkUnread;

  const _ChatOptionsSheet({
    required this.chat,
    required this.userId,
    required this.onViewProfile,
    required this.onDelete,
    required this.onMuteToggle,
    required this.onMarkUnread,
  });

  @override
  Widget build(BuildContext context) {
    final initials = chat.otherName.isNotEmpty ? chat.otherName[0].toUpperCase() : '?';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Avatar + nombre
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFCCFBF1),
                  backgroundImage:
                      chat.otherAvatar != null ? NetworkImage(chat.otherAvatar!) : null,
                  child: chat.otherAvatar == null
                      ? Text(initials,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700, color: _teal))
                      : null,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chat.otherName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: _tealDark)),
                    if (chat.otherUsername.isNotEmpty)
                      Text('@${chat.otherUsername}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          _OptionItem(
            icon: Icons.person_outline_rounded,
            color: _teal,
            label: 'Ver perfil',
            onTap: () { Navigator.pop(context); onViewProfile(); },
          ),
          _OptionItem(
            icon: chat.isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: Colors.blueGrey,
            label: chat.isMuted ? 'Activar notificaciones' : 'Silenciar',
            onTap: () { Navigator.pop(context); onMuteToggle(); },
          ),
          _OptionItem(
            icon: Icons.mark_chat_unread_outlined,
            color: Colors.indigo,
            label: 'Marcar como no leído',
            onTap: () { Navigator.pop(context); onMarkUnread(); },
          ),
          _OptionItem(
            icon: Icons.delete_outline_rounded,
            color: Colors.red,
            label: 'Eliminar conversación',
            onTap: () { Navigator.pop(context); onDelete(); },
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  final IconData  icon;
  final Color     color;
  final String    label;
  final VoidCallback onTap;

  const _OptionItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: label.contains('Eliminar') ? Colors.red : const Color(0xFF1E293B),
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton
// ─────────────────────────────────────────────────────────────────────────────

class _ChatTileSkeleton extends StatefulWidget {
  const _ChatTileSkeleton();

  @override
  State<_ChatTileSkeleton> createState() => _ChatTileSkeletonState();
}

class _ChatTileSkeletonState extends State<_ChatTileSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _box(width: 130, height: 13),
                        _box(width: 32, height: 11),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _box(width: 200, height: 11),
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
        width: width, height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(6),
        ),
      );
}

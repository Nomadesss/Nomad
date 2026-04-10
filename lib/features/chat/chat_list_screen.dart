import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// chat_list_screen.dart  –  Nomad App
// Ubicación: lib/features/chat/chat_list_screen.dart
//
// PROBLEMA ORIGINAL: la pantalla leía `participantNames` y `participantAvatars`
// del documento /chats/{id}, pero esos campos no existen en Firestore.
// Por eso aparecía "Usuario desconocido".
//
// SOLUCIÓN: para cada chat, se obtiene el UID del otro participante y se busca
// su doc en /users/{uid} para obtener displayName, username y photoURL reales.
// Se usa un FutureBuilder por fila + cache en memoria para evitar re-reads.
// ─────────────────────────────────────────────────────────────────────────────

const _teal = Color(0xFF0D9488);
const _tealLight = Color(0xFF5EEAD4);
const _tealDark = Color(0xFF134E4A);
const _tealBg = Color(0xFFF0FAF9);

// Cache global de sesión para no re-leer el mismo usuario múltiples veces
final Map<String, Map<String, dynamic>> _userCache = {};

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  // ── Stream de chats ────────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  // ── Resolver datos del otro usuario ────────────────────────────────────────
  // Busca en /users/{uid} y guarda en cache para no repetir la consulta.

  Future<Map<String, dynamic>> _fetchUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid]!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};
      _userCache[uid] = data;
      return data;
    } catch (_) {
      return {};
    }
  }

  // ── Formatear fecha del último mensaje ─────────────────────────────────────

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE', 'es').format(dt);
    return DateFormat('d/MM').format(dt);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFE),
      appBar: _buildAppBar(),
      body: userId == null
          ? const Center(child: Text('Iniciá sesión para ver tus mensajes'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _chatsStream(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _teal),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar chats',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final chatDoc = docs[index];
                    final data = chatDoc.data();
                    final chatId = chatDoc.id;

                    final participantIds = List<String>.from(
                      data['participantIds'] as List? ?? [],
                    );
                    final otherId = participantIds.firstWhere(
                      (id) => id != userId,
                      orElse: () => '',
                    );

                    if (otherId.isEmpty) return const SizedBox.shrink();

                    // Resolver nombre real del otro usuario
                    return FutureBuilder<Map<String, dynamic>>(
                      future: _fetchUser(otherId),
                      builder: (context, userSnap) {
                        // Mientras carga, mostrar skeleton
                        if (!userSnap.hasData) {
                          return _ChatTileSkeleton();
                        }

                        final userData = userSnap.data!;
                        final rawName = (userData['displayName'] as String?)
                            ?.trim();
                        final rawNombre = (userData['name'] as String?)?.trim();
                        final otherName =
                            (rawName?.isNotEmpty == true
                                ? rawName
                                : rawNombre) ??
                            'Usuario';
                        final otherUsername =
                            (userData['username'] as String?) ?? '';
                        final otherAvatar = userData['photoURL'] as String?;

                        final lastMessage =
                            data['lastMessage'] as String? ?? '';
                        final lastMessageAt =
                            data['lastMessageAt'] as Timestamp?;
                        final unreadMap =
                            data['unreadCount'] as Map<String, dynamic>? ?? {};
                        final myUnread =
                            (unreadMap[userId] as num?)?.toInt() ?? 0;

                        return _ChatTile(
                          chatId: chatId,
                          otherId: otherId,
                          otherName: otherName,
                          otherUsername: otherUsername,
                          otherAvatar: otherAvatar,
                          lastMessage: lastMessage,
                          lastMessageAt: lastMessageAt,
                          myUnread: myUnread,
                          formatDate: _formatDate,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chatId,
                                otherUserId: otherId,
                                otherUsername: otherUsername,
                                otherAvatarUrl: otherAvatar,
                                otherName: otherName,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _tealDark,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: const Text(
        'Mensajes',
        style: TextStyle(
          color: _tealDark,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, color: _teal, size: 22),
            tooltip: 'Nuevo mensaje',
            onPressed: () {
              // TODO: pantalla de búsqueda de usuario para iniciar chat
            },
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE2E8F0)),
      ),
    );
  }

  // ── Estado vacío ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _tealBg,
                shape: BoxShape.circle,
                border: Border.all(color: _tealLight, width: 2),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: _teal,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Sin conversaciones todavía',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _tealDark,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Visitá el perfil de otro nomad\ny mandále un mensaje.',
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
// _ChatTile — fila de una conversación
// ─────────────────────────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  final String chatId;
  final String otherId;
  final String otherName;
  final String otherUsername;
  final String? otherAvatar;
  final String lastMessage;
  final Timestamp? lastMessageAt;
  final int myUnread;
  final String Function(Timestamp?) formatDate;
  final VoidCallback onTap;

  const _ChatTile({
    required this.chatId,
    required this.otherId,
    required this.otherName,
    required this.otherUsername,
    required this.otherAvatar,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.myUnread,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = myUnread > 0;
    final initials = otherName.isNotEmpty ? otherName[0].toUpperCase() : '?';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          // Fondo sutil en teal si hay mensajes sin leer
          color: hasUnread ? _tealBg.withOpacity(0.5) : Colors.white,
          border: const Border(
            bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
        ),
        child: Row(
          children: [
            // ── Avatar + badge ────────────────────────────────────────────
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFCCFBF1),
                  backgroundImage: otherAvatar != null
                      ? NetworkImage(otherAvatar!)
                      : null,
                  child: otherAvatar == null
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
                if (hasUnread)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _teal,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          myUnread > 9 ? '9+' : '$myUnread',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            // ── Nombre + último mensaje + hora ────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + hora
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasUnread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: _tealDark,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatDate(lastMessageAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: hasUnread ? _teal : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Username + último mensaje
                  Row(
                    children: [
                      if (otherUsername.isNotEmpty) ...[
                        Text(
                          '@$otherUsername',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _teal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          lastMessage.isEmpty
                              ? 'Conversación iniciada'
                              : lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread ? _tealDark : Colors.grey.shade500,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChatTileSkeleton — placeholder animado mientras carga el usuario
// ─────────────────────────────────────────────────────────────────────────────

class _ChatTileSkeleton extends StatefulWidget {
  @override
  State<_ChatTileSkeleton> createState() => _ChatTileSkeletonState();
}

class _ChatTileSkeletonState extends State<_ChatTileSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 0.9,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar placeholder
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
                    Container(
                      height: 13,
                      width: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 11,
                      width: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
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

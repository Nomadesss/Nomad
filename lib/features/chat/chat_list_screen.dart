import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  final String? _userId =
      // ignore: prefer_const_constructors
      null; // se resuelve en build vía FirebaseAuth

  Stream<QuerySnapshot<Map<String, dynamic>>> _chatsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

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

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF134E4A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mensajes',
          style: TextStyle(
            color: Color(0xFF134E4A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF0D9488),
              size: 22,
            ),
            tooltip: 'Nuevo mensaje',
            onPressed: () {
              // TODO: pantalla de nuevo chat / buscar usuario
            },
          ),
        ],
      ),
      body: userId == null
          ? const Center(child: Text('Iniciá sesión para ver tus mensajes'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _chatsStream(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0D9488)),
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

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('💬', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text(
                          'Sin conversaciones todavía',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF134E4A),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Escribile a otro nomad\npara empezar a chatear.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72, endIndent: 16),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final chatId = docs[index].id;

                    // IDs y nombres de participantes
                    final participantIds = List<String>.from(
                      data['participantIds'] ?? [],
                    );
                    final names = Map<String, String>.from(
                      (data['participantNames'] as Map?)?.map(
                            (k, v) => MapEntry(k.toString(), v.toString()),
                          ) ??
                          {},
                    );
                    final avatars = Map<String, String>.from(
                      (data['participantAvatars'] as Map?)?.map(
                            (k, v) => MapEntry(k.toString(), v.toString()),
                          ) ??
                          {},
                    );

                    // El "otro" participante
                    final otherId = participantIds.firstWhere(
                      (id) => id != userId,
                      orElse: () => '',
                    );
                    final otherName = names[otherId] ?? 'Usuario desconocido';
                    final otherAvatar = avatars[otherId];

                    final lastMessage = data['lastMessage'] as String? ?? '';
                    final lastMessageAt = data['lastMessageAt'] as Timestamp?;
                    final unreadMap =
                        data['unreadCount'] as Map<String, dynamic>? ?? {};
                    final myUnread = (unreadMap[userId] as num?)?.toInt() ?? 0;

                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chatId,
                              otherUserId: otherId,
                              otherUsername: otherName,
                              otherAvatarUrl: otherAvatar,
                            ),
                          ),
                        );
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFD1FAE5),
                        backgroundImage: otherAvatar != null
                            ? NetworkImage(otherAvatar)
                            : null,
                        child: otherAvatar == null
                            ? Text(
                                otherName.isNotEmpty
                                    ? otherName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D9488),
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        otherName,
                        style: TextStyle(
                          fontWeight: myUnread > 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: const Color(0xFF1F2937),
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: myUnread > 0
                              ? const Color(0xFF134E4A)
                              : const Color(0xFF9CA3AF),
                          fontWeight: myUnread > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatDate(lastMessageAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: myUnread > 0
                                  ? const Color(0xFF0D9488)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                          if (myUnread > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0D9488),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  myUnread > 99 ? '99+' : '$myUnread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

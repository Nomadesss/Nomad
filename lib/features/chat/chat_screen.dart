import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// chat_screen.dart  –  Nomad App
// Ubicación: lib/features/chat/chat_screen.dart
//
// Mejoras sobre la versión original:
//   · Separadores de fecha (Hoy / Ayer / fecha)
//   · Burbujas agrupadas visualmente (esquinas según consecutividad)
//   · Tilde simple/doble (enviado/leído) en mensajes propios
//   · Botón enviar desactivado cuando no hay texto
//   · Estado vacío con ilustración
//   · Scroll suave al llegar mensajes nuevos
//   · Se mantiene la estructura de datos original (sentAt, unreadCount, readBy)
// ─────────────────────────────────────────────────────────────────────────────

const _teal = Color(0xFF0D9488);
const _tealDark = Color(0xFF134E4A);
const _tealBg = Color(0xFFF0FAF9);
const _tealLight = Color(0xFF5EEAD4);

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUsername,
    this.otherAvatarUrl,
    this.otherName,
  });

  final String chatId;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;
  final String? otherName; // nombre completo (opcional)

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final String? _myId = FirebaseAuth.instance.currentUser?.uid;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Marcar como leído cuando la app vuelve al frente
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _markMessagesAsRead();
  }

  // ── Marcar mensajes como leídos ───────────────────────────────────────────

  Future<void> _markMessagesAsRead() async {
    if (_myId == null) return;
    try {
      // Resetear contador de no leídos
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'unreadCount.$_myId': 0});

      // Marcar mensajes individuales del otro como leídos
      final snap = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('senderId', isEqualTo: widget.otherUserId)
          .get();

      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] as List? ?? []);
        if (!readBy.contains(_myId)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([_myId]),
          });
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[ChatScreen] Error marcando como leído: $e');
    }
  }

  // ── Stream de mensajes ────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots();
  }

  // ── Enviar mensaje ────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _myId == null || _isSending) return;

    setState(() => _isSending = true);
    _inputController.clear();
    HapticFeedback.lightImpact();

    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId);

      final batch = FirebaseFirestore.instance.batch();

      final msgRef = chatRef.collection('messages').doc();
      batch.set(msgRef, {
        'senderId': _myId,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
        'readBy': [_myId],
      });

      batch.update(chatRef, {
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
      });

      await batch.commit();
      _scrollToBottom();
    } catch (e) {
      debugPrint('[ChatScreen] Error enviando mensaje: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo enviar el mensaje'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    final displayName = (widget.otherName?.isNotEmpty == true)
        ? widget.otherName!
        : '@${widget.otherUsername}';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _tealDark,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFD1FAE5),
            backgroundImage: widget.otherAvatarUrl != null
                ? NetworkImage(widget.otherAvatarUrl!)
                : null,
            child: widget.otherAvatarUrl == null
                ? Text(
                    widget.otherUsername.isNotEmpty
                        ? widget.otherUsername[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _teal,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: _tealDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.otherName?.isNotEmpty == true)
                  Text(
                    '@${widget.otherUsername}',
                    style: const TextStyle(fontSize: 11, color: _teal),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE2E8F0)),
      ),
    );
  }

  // ── Lista de mensajes ─────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _teal));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        // Marcar como leído cuando llegan mensajes nuevos del otro
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markMessagesAsRead();
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final senderId = data['senderId'] as String? ?? '';
            final text = data['text'] as String? ?? '';
            final sentAt = data['sentAt'] as Timestamp?;
            final readBy = List<String>.from(data['readBy'] as List? ?? []);
            final isMe = senderId == _myId;
            final isRead = readBy.contains(widget.otherUserId);

            // Agrupar burbujas consecutivas del mismo remitente
            final prevSender = index > 0
                ? (docs[index - 1].data()['senderId'] as String? ?? '')
                : null;
            final nextSender = index < docs.length - 1
                ? (docs[index + 1].data()['sentAt'] != null
                      ? docs[index + 1].data()['senderId'] as String? ?? ''
                      : null)
                : null;

            final isFirstInGroup = prevSender != senderId;
            final isLastInGroup = nextSender != senderId;

            // Separador de fecha cuando cambia el día
            final prevSentAt = index > 0
                ? (docs[index - 1].data()['sentAt'] as Timestamp?)?.toDate()
                : null;
            final showDateSep =
                sentAt != null &&
                (prevSentAt == null || !_sameDay(prevSentAt, sentAt.toDate()));

            return Column(
              children: [
                if (showDateSep && sentAt != null)
                  _DateSeparator(date: sentAt.toDate()),
                _MessageBubble(
                  text: text,
                  isMe: isMe,
                  sentAt: sentAt,
                  isRead: isRead,
                  isFirstInGroup: isFirstInGroup,
                  isLastInGroup: isLastInGroup,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: _tealBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 34,
                color: _teal,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Empezá la conversación!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _tealDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mandále un mensaje a @${widget.otherUsername} 👋',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Barra de input ─────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
              decoration: InputDecoration(
                hintText: 'Escribí un mensaje...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              onChanged: (_) =>
                  setState(() {}), // para activar/desactivar botón
            ),
          ),
          const SizedBox(width: 8),
          // Botón enviar — activo solo cuando hay texto
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _inputController.text.trim().isNotEmpty
                  ? _teal
                  : const Color(0xFFE5E7EB),
              shape: BoxShape.circle,
            ),
            child: GestureDetector(
              onTap: _sendMessage,
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: _inputController.text.trim().isNotEmpty
                          ? Colors.white
                          : const Color(0xFFD1D5DB),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────────────────────────
// _MessageBubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.isRead,
    this.sentAt,
  });

  final String text;
  final bool isMe;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isRead;
  final Timestamp? sentAt;

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('HH:mm').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    // Esquinas redondeadas según posición en el grupo (estilo iMessage)
    final topLeft = isMe ? 18.0 : (isFirstInGroup ? 18.0 : 4.0);
    final topRight = isMe ? (isFirstInGroup ? 18.0 : 4.0) : 18.0;
    final bottomLeft = isMe ? 18.0 : (isLastInGroup ? 18.0 : 4.0);
    final bottomRight = isMe ? (isLastInGroup ? 4.0 : 4.0) : 18.0;

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 6 : 2,
        bottom: isLastInGroup ? 2 : 0,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? _teal : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(topLeft),
              topRight: Radius.circular(topRight),
              bottomLeft: Radius.circular(bottomLeft),
              bottomRight: Radius.circular(bottomRight),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFF1F2937),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              // Hora + tilde de lectura (solo en el último del grupo)
              if (isLastInGroup) ...[
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(sentAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe
                            ? Colors.white.withOpacity(0.7)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      Icon(
                        isRead
                            ? Icons
                                  .done_all_rounded // leído ✓✓
                            : Icons.done_rounded, // enviado ✓
                        size: 12,
                        color: isRead
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DateSeparator — separador de fecha entre mensajes de días distintos
// ─────────────────────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Hoy';
    if (day == today.subtract(const Duration(days: 1))) return 'Ayer';
    const meses = [
      '',
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final year = date.year != now.year ? ' ${date.year}' : '';
    return '${date.day} ${meses[date.month]}$year';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _label(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:io';

const _teal      = Color(0xFF0D9488);
const _tealDark  = Color(0xFF134E4A);
const _tealBg    = Color(0xFFF0FAF9);
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

  final String  chatId;
  final String  otherUserId;
  final String  otherUsername;
  final String? otherAvatarUrl;
  final String? otherName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _inputCtrl    = TextEditingController();
  final _scrollCtrl   = ScrollController();
  final _searchCtrl   = TextEditingController();
  final String? _myId = FirebaseAuth.instance.currentUser?.uid;

  bool   _isSending       = false;
  bool   _isUploadingImg  = false;
  bool   _searchMode      = false;
  String _searchQuery     = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _markMessagesAsRead();
  }

  // ── Crear chat solo si no existe (llamado al enviar primer mensaje) ─────────

  Future<void> _ensureChatExists() async {
    if (_myId == null) return;
    final ref = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    await ref.set({
      'participantIds': [_myId, widget.otherUserId],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount': {_myId: 0, widget.otherUserId: 0},
    }, SetOptions(merge: true));
  }

  // ── Marcar como leído ───────────────────────────────────────────────────────

  Future<void> _markMessagesAsRead() async {
    if (_myId == null) return;
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats').doc(widget.chatId).get();
      if (!chatDoc.exists) return;

      await FirebaseFirestore.instance
          .collection('chats').doc(widget.chatId)
          .update({'unreadCount.$_myId': 0});

      final snap = await FirebaseFirestore.instance
          .collection('chats').doc(widget.chatId)
          .collection('messages')
          .where('senderId', isEqualTo: widget.otherUserId)
          .get();

      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] as List? ?? []);
        if (!readBy.contains(_myId)) {
          batch.update(doc.reference, {'readBy': FieldValue.arrayUnion([_myId])});
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[ChatScreen] Error marcando leído: $e');
    }
  }

  // ── Stream de mensajes ──────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    return FirebaseFirestore.instance
        .collection('chats').doc(widget.chatId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots();
  }

  // ── Enviar texto ────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _myId == null || _isSending) return;

    setState(() => _isSending = true);
    _inputCtrl.clear();
    HapticFeedback.lightImpact();

    try {
      await _ensureChatExists();
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      final batch   = FirebaseFirestore.instance.batch();

      final msgRef = chatRef.collection('messages').doc();
      batch.set(msgRef, {
        'senderId': _myId,
        'text':     text,
        'sentAt':   FieldValue.serverTimestamp(),
        'readBy':   [_myId],
      });
      batch.update(chatRef, {
        'lastMessage':               text,
        'lastMessageAt':             FieldValue.serverTimestamp(),
        'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
      });

      await batch.commit();
      _scrollToBottom();
    } catch (e) {
      debugPrint('[ChatScreen] Error enviando: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el mensaje'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Enviar imagen ───────────────────────────────────────────────────────────

  Future<void> _sendImage() async {
    if (_myId == null) return;
    try {
      final picker = ImagePicker();
      final xFile  = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (xFile == null) return;

      setState(() => _isUploadingImg = true);
      await _ensureChatExists();

      final file     = File(xFile.path);
      final fileName = 'chat_${widget.chatId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref      = FirebaseStorage.instance.ref('chat_images/$fileName');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      final batch   = FirebaseFirestore.instance.batch();
      final msgRef  = chatRef.collection('messages').doc();
      batch.set(msgRef, {
        'senderId':  _myId,
        'text':      '',
        'imageUrl':  url,
        'sentAt':    FieldValue.serverTimestamp(),
        'readBy':    [_myId],
      });
      batch.update(chatRef, {
        'lastMessage':               '📷 Foto',
        'lastMessageAt':             FieldValue.serverTimestamp(),
        'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
      });
      await batch.commit();
      _scrollToBottom();
    } catch (e) {
      debugPrint('[ChatScreen] Error enviando imagen: $e');
    } finally {
      if (mounted) setState(() => _isUploadingImg = false);
    }
  }

  // ── Eliminar mensaje ────────────────────────────────────────────────────────

  Future<void> _deleteMessage(String msgId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats').doc(widget.chatId)
          .collection('messages').doc(msgId)
          .delete();
    } catch (_) {}
  }

  // ── Eliminar conversación ───────────────────────────────────────────────────

  Future<void> _deleteChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar conversación',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('¿Eliminar todos los mensajes? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // Soft delete: agregar el UID al array deletedBy.
      // Las reglas prohíben delete directo; update sí está permitido a participantes.
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'deletedBy': FieldValue.arrayUnion([_myId]),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[ChatScreen] Error eliminando: $e');
    }
  }

  // ── Llamada / videollamada via Jitsi ───────────────────────────────────────

  Future<void> _launchCall({required bool video}) async {
    HapticFeedback.lightImpact();
    final room = 'nomad-${widget.chatId.replaceAll('_', '-')}';
    final extra = video ? '' : '#config.startWithVideoMuted=true&config.startWithAudioMuted=false';
    final url = Uri.parse('https://meet.jit.si/$room$extra');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la llamada. Instalá la app de Jitsi Meet.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Buscador dentro del chat ────────────────────────────────────────────────

  void _toggleSearch() {
    setState(() {
      _searchMode = !_searchMode;
      if (!_searchMode) {
        _searchCtrl.clear();
        _searchQuery = '';
      }
    });
  }

  // ── Menú de medios ──────────────────────────────────────────────────────────

  void _showMediaSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MediaSheet(chatId: widget.chatId),
    );
  }

  // ── Long press en mensaje ───────────────────────────────────────────────────

  void _onMessageLongPress(BuildContext ctx, String msgId, String text, bool isMe) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)),
            ),
            if (text.isNotEmpty)
              _OptionItem(
                icon: Icons.copy_rounded,
                color: _teal,
                label: 'Copiar texto',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copiado'), behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1)),
                  );
                },
              ),
            if (isMe)
              _OptionItem(
                icon: Icons.delete_outline_rounded,
                color: Colors.red,
                label: 'Eliminar mensaje',
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(msgId);
                },
              ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 12),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
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
          if (_searchMode) _buildSearchBar(),
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  AppBar _buildAppBar() {
    final displayName = (widget.otherName?.isNotEmpty == true)
        ? widget.otherName!
        : '@${widget.otherUsername}';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _tealDark, size: 20),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _teal),
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
                  style: const TextStyle(color: _tealDark, fontWeight: FontWeight.w700, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.otherName?.isNotEmpty == true)
                  Text('@${widget.otherUsername}',
                      style: const TextStyle(fontSize: 11, color: _teal)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Llamada de voz
        IconButton(
          icon: const Icon(Icons.call_rounded, color: _teal, size: 22),
          tooltip: 'Llamada de voz',
          onPressed: () => _launchCall(video: false),
        ),
        // Videollamada
        IconButton(
          icon: const Icon(Icons.videocam_rounded, color: _teal, size: 24),
          tooltip: 'Videollamada',
          onPressed: () => _launchCall(video: true),
        ),
        // Más opciones
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: _tealDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (v) {
            switch (v) {
              case 'search':   _toggleSearch(); break;
              case 'media':    _showMediaSheet(); break;
              case 'delete':   _deleteChat(); break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'search',
                child: _PopupRow(icon: Icons.search_rounded, label: 'Buscar en el chat')),
            PopupMenuItem(value: 'media',
                child: _PopupRow(icon: Icons.perm_media_outlined, label: 'Fotos y medios')),
            PopupMenuItem(value: 'delete',
                child: _PopupRow(icon: Icons.delete_outline_rounded, label: 'Eliminar conversación', danger: true)),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE2E8F0)),
      ),
    );
  }

  // ── Barra de búsqueda en chat ──────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                style: const TextStyle(fontSize: 14, color: _tealDark),
                decoration: InputDecoration(
                  hintText: 'Buscar en la conversación…',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleSearch,
            child: Text('Cancelar',
                style: const TextStyle(fontSize: 13, color: _teal, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Lista de mensajes ──────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _teal));
        }

        var docs = snapshot.data?.docs ?? [];

        // Filtrar por búsqueda si está activa
        if (_searchMode && _searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final text = (d.data()['text'] as String? ?? '').toLowerCase();
            return text.contains(_searchQuery.toLowerCase());
          }).toList();
        }

        if (docs.isEmpty) {
          return _searchMode && _searchQuery.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Sin resultados para "$_searchQuery"',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    ],
                  ),
                )
              : _buildEmptyState();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markMessagesAsRead();
          if (!_searchMode) _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc      = docs[index];
            final data     = doc.data();
            final senderId = data['senderId'] as String? ?? '';
            final text     = data['text']     as String? ?? '';
            final imageUrl = data['imageUrl'] as String?;
            final sentAt   = data['sentAt']   as Timestamp?;
            final readBy   = List<String>.from(data['readBy'] as List? ?? []);
            final isMe     = senderId == _myId;
            final isRead   = readBy.contains(widget.otherUserId);

            final prevSender = index > 0
                ? (docs[index - 1].data()['senderId'] as String? ?? '')
                : null;
            final nextSender = index < docs.length - 1
                ? (docs[index + 1].data()['senderId'] as String? ?? '')
                : null;

            final isFirstInGroup = prevSender != senderId;
            final isLastInGroup  = nextSender != senderId;

            final prevSentAt = index > 0
                ? (docs[index - 1].data()['sentAt'] as Timestamp?)?.toDate()
                : null;
            final showDateSep = sentAt != null &&
                (prevSentAt == null || !_sameDay(prevSentAt, sentAt.toDate()));

            return Column(
              children: [
                if (showDateSep && sentAt != null) _DateSeparator(date: sentAt.toDate()),
                GestureDetector(
                  onLongPress: () =>
                      _onMessageLongPress(context, doc.id, text, isMe),
                  child: _MessageBubble(
                    text:          text,
                    imageUrl:      imageUrl,
                    isMe:          isMe,
                    sentAt:        sentAt,
                    isRead:        isRead,
                    isFirstInGroup: isFirstInGroup,
                    isLastInGroup:  isLastInGroup,
                    searchQuery:   _searchMode ? _searchQuery : '',
                  ),
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
              width: 72, height: 72,
              decoration: const BoxDecoration(color: _tealBg, shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 34, color: _teal),
            ),
            const SizedBox(height: 16),
            const Text('¡Empezá la conversación!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _tealDark)),
            const SizedBox(height: 6),
            Text(
              'Mandále un mensaje a @${widget.otherUsername} 👋',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5),
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
        12, 8, 12,
        MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Botón de adjuntar imagen
          GestureDetector(
            onTap: _isUploadingImg ? null : _sendImage,
            child: Container(
              width: 40, height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(color: _tealBg, shape: BoxShape.circle),
              child: _isUploadingImg
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined, color: _teal, size: 20),
            ),
          ),

          // Campo de texto
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
              decoration: InputDecoration(
                hintText: 'Escribí un mensaje...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              onChanged: (_) => setState(() {}),
            ),
          ),

          const SizedBox(width: 8),

          // Botón enviar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _inputCtrl.text.trim().isNotEmpty ? _teal : const Color(0xFFE5E7EB),
              shape: BoxShape.circle,
            ),
            child: GestureDetector(
              onTap: _sendMessage,
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: _inputCtrl.text.trim().isNotEmpty
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
    required this.imageUrl,
    required this.isMe,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.isRead,
    required this.searchQuery,
    this.sentAt,
  });

  final String  text;
  final String? imageUrl;
  final bool    isMe;
  final bool    isFirstInGroup;
  final bool    isLastInGroup;
  final bool    isRead;
  final String  searchQuery;
  final Timestamp? sentAt;

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('HH:mm').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final topLeft     = isMe ? 18.0 : (isFirstInGroup ? 18.0 : 4.0);
    final topRight    = isMe ? (isFirstInGroup ? 18.0 : 4.0) : 18.0;
    final bottomLeft  = isMe ? 18.0 : (isLastInGroup ? 18.0 : 4.0);
    final bottomRight = isMe ? (isLastInGroup ? 4.0 : 4.0) : 18.0;

    return Padding(
      padding: EdgeInsets.only(top: isFirstInGroup ? 6 : 2, bottom: isLastInGroup ? 2 : 0),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            color: isMe ? _teal : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft:     Radius.circular(topLeft),
              topRight:    Radius.circular(topRight),
              bottomLeft:  Radius.circular(bottomLeft),
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
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Imagen
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft:     Radius.circular(topLeft),
                    topRight:    Radius.circular(topRight),
                    bottomLeft:  text.isEmpty ? Radius.circular(bottomLeft) : Radius.zero,
                    bottomRight: text.isEmpty ? Radius.circular(bottomRight) : Radius.zero,
                  ),
                  child: Image.network(
                    imageUrl!,
                    width: MediaQuery.of(context).size.width * 0.65,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            width: MediaQuery.of(context).size.width * 0.65,
                            height: 160,
                            color: isMe ? _teal.withOpacity(0.3) : Colors.grey.shade100,
                            child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2, color: _teal)),
                          ),
                  ),
                ),

              // Texto
              if (text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    imageUrl != null ? 6 : 10,
                    14,
                    isLastInGroup ? 4 : 10,
                  ),
                  child: _buildText(),
                ),

              // Hora + tilde
              if (isLastInGroup)
                Padding(
                  padding: EdgeInsets.fromLTRB(14, text.isEmpty && imageUrl != null ? 4 : 0, 14, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(sentAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white.withOpacity(0.7) : const Color(0xFF9CA3AF),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(
                          isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 12,
                          color: isRead ? Colors.white : Colors.white.withOpacity(0.6),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildText() {
    if (searchQuery.isEmpty || !text.toLowerCase().contains(searchQuery.toLowerCase())) {
      return Text(
        text,
        style: TextStyle(
          color: isMe ? Colors.white : const Color(0xFF1F2937),
          fontSize: 14,
          height: 1.4,
        ),
      );
    }
    // Resaltar coincidencias de búsqueda
    final lower  = text.toLowerCase();
    final idx    = lower.indexOf(searchQuery.toLowerCase());
    final before = text.substring(0, idx);
    final match  = text.substring(idx, idx + searchQuery.length);
    final after  = text.substring(idx + searchQuery.length);
    final base   = TextStyle(color: isMe ? Colors.white : const Color(0xFF1F2937), fontSize: 14, height: 1.4);
    return RichText(
      text: TextSpan(style: base, children: [
        TextSpan(text: before),
        TextSpan(text: match, style: base.copyWith(
          backgroundColor: Colors.yellow.withOpacity(0.6),
          fontWeight: FontWeight.w700,
        )),
        TextSpan(text: after),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DateSeparator
// ─────────────────────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String _label() {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day   = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Hoy';
    if (day == today.subtract(const Duration(days: 1))) return 'Ayer';
    const meses = ['','ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final year  = date.year != now.year ? ' ${date.year}' : '';
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
            child: Text(_label(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MediaSheet — fotos y enlaces en la conversación
// ─────────────────────────────────────────────────────────────────────────────

class _MediaSheet extends StatefulWidget {
  final String chatId;
  const _MediaSheet({required this.chatId});

  @override
  State<_MediaSheet> createState() => _MediaSheetState();
}

class _MediaSheetState extends State<_MediaSheet> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Stream<QuerySnapshot<Map<String, dynamic>>> _msgsStream() {
    return FirebaseFirestore.instance
        .collection('chats').doc(widget.chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .snapshots();
  }

  static final _urlRegex = RegExp(r'https?://\S+');

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)),
          ),

          // Título
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Fotos y medios',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _tealDark)),
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                color: _teal,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade500,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.all(3),
              tabs: const [Tab(text: 'Fotos'), Tab(text: 'Enlaces')],
            ),
          ),

          const SizedBox(height: 8),

          // Contenido
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _msgsStream(),
              builder: (_, snap) {
                final docs = snap.data?.docs ?? [];
                final images = docs
                    .where((d) => (d.data()['imageUrl'] as String?) != null)
                    .map((d) => d.data()['imageUrl'] as String)
                    .toList();
                final links = docs
                    .where((d) => _urlRegex.hasMatch(d.data()['text'] as String? ?? ''))
                    .expand((d) => _urlRegex
                        .allMatches(d.data()['text'] as String)
                        .map((m) => m.group(0)!))
                    .toSet()
                    .toList();

                return TabBarView(
                  controller: _tabs,
                  children: [
                    // Fotos
                    images.isEmpty
                        ? _EmptyTab(icon: Icons.photo_library_outlined, label: 'Sin fotos todavía')
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
                            itemCount: images.length,
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(images[i], fit: BoxFit.cover),
                            ),
                          ),
                    // Enlaces
                    links.isEmpty
                        ? _EmptyTab(icon: Icons.link_rounded, label: 'Sin enlaces todavía')
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: links.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) => ListTile(
                              leading: Container(
                                width: 38, height: 38,
                                decoration: const BoxDecoration(color: _tealBg, shape: BoxShape.circle),
                                child: const Icon(Icons.link_rounded, color: _teal, size: 20),
                              ),
                              title: Text(links[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13, color: _teal, fontWeight: FontWeight.w500)),
                              onTap: () async {
                                final uri = Uri.tryParse(links[i]);
                                if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                              },
                            ),
                          ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _EmptyTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets helpers reutilizados
// ─────────────────────────────────────────────────────────────────────────────

class _PopupRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     danger;
  const _PopupRow({required this.icon, required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : _tealDark;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 14, color: color)),
      ],
    );
  }
}

class _OptionItem extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       label;
  final VoidCallback onTap;
  const _OptionItem({required this.icon, required this.color, required this.label, required this.onTap});

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
                  color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
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

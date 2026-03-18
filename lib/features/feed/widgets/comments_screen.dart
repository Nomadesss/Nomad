import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/social_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CommentsScreen — pantalla completa de comentarios de un post.
//
// Se abre como BottomSheet desde PostCard:
//   CommentsScreen.show(context, postId: "...", postAuthorId: "...");
//
// Características:
//  - Stream en tiempo real: los comentarios nuevos aparecen solos
//  - Campo de texto fijo en el bottom
//  - Scroll automático al agregar un comentario nuevo
//  - El propio comentario del usuario aparece resaltado
// ─────────────────────────────────────────────────────────────────────────────

class CommentsScreen extends StatefulWidget {
  final String postId;
  final String postAuthorId;

  const CommentsScreen({
    super.key,
    required this.postId,
    required this.postAuthorId,
  });

  /// Abre la pantalla como BottomSheet modal.
  static void show(
    BuildContext context, {
    required String postId,
    required String postAuthorId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsScreen(
        postId: postId,
        postAuthorId: postAuthorId,
      ),
    );
  }

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _controller  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _focusNode   = FocusNode();
  bool _sending      = false;
  final _myUid       = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await SocialService.addComment(
        postId:       widget.postId,
        postAuthorId: widget.postAuthorId,
        text:         text,
      );

      // Scroll al final después de que el Stream actualice la lista
      await Future.delayed(const Duration(milliseconds: 200));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {
      if (mounted) {
        // Restaurar texto si falló
        _controller.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo enviar el comentario."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75 + bottomInset,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [

          // Handle + título
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Comentarios",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF134E4A),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE6FAF8)),
              ],
            ),
          ),

          // Lista de comentarios en tiempo real
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SocialService.commentsStream(widget.postId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF0D9488),
                      strokeWidth: 2,
                    ),
                  );
                }

                final comments = snap.data ?? [];

                if (comments.isEmpty) {
                  return const Center(
                    child: Text(
                      "Sé el primero en comentar",
                      style: TextStyle(
                        color: Color(0xFF5EEAD4),
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: comments.length,
                  itemBuilder: (_, i) =>
                      _CommentTile(
                        comment:  comments[i],
                        isMyComment: comments[i]['authorId'] == _myUid,
                      ),
                );
              },
            ),
          ),

          // Divider
          const Divider(height: 1, color: Color(0xFFE6FAF8)),

          // Campo de texto
          Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
            child: Row(
              children: [

                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFCCFBF1),
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: Color(0xFF0D9488),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FAF9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF5EEAD4)),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF134E4A),
                      ),
                      decoration: const InputDecoration(
                        hintText: "Escribí un comentario...",
                        hintStyle: TextStyle(
                          color: Color(0xFF5EEAD4),
                          fontSize: 14,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488),
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile de un comentario individual ─────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isMyComment;

  const _CommentTile({
    required this.comment,
    required this.isMyComment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          CircleAvatar(
            radius: 16,
            backgroundColor: isMyComment
                ? const Color(0xFF0D9488)
                : const Color(0xFFCCFBF1),
            child: Icon(
              Icons.person,
              size: 16,
              color: isMyComment
                  ? Colors.white
                  : const Color(0xFF0D9488),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  children: [
                    Text(
                      comment['authorId'] ?? 'usuario',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF134E4A),
                      ),
                    ),
                    if (isMyComment) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6FAF8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "Vos",
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF0D9488),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 3),

                Text(
                  comment['text'] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF134E4A),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
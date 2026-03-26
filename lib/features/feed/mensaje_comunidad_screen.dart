import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MensajeComunidadScreen — publicar un aviso para toda la comunidad
// Colección Firestore: 'community_messages'
// ─────────────────────────────────────────────────────────────────────────────

class MensajeComunidadScreen extends StatefulWidget {
  const MensajeComunidadScreen({super.key});

  @override
  State<MensajeComunidadScreen> createState() => _MensajeComunidadScreenState();
}

class _MensajeComunidadScreenState extends State<MensajeComunidadScreen> {
  final _tituloCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();
  String _categoria = 'Info';
  bool _enviando = false;

  static const _categorias = [
    _Cat('Info', '📢', Color(0xFF0D9488)),
    _Cat('Urgente', '🚨', Color(0xFFDC2626)),
    _Cat('Pregunta', '❓', Color(0xFF7C3AED)),
    _Cat('Oferta', '🎁', Color(0xFF059669)),
    _Cat('Alerta', '⚠️', Color(0xFFD97706)),
  ];

  _Cat get _catActual => _categorias.firstWhere((c) => c.nombre == _categoria);

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_mensajeCtrl.text.trim().isEmpty) {
      _snack('Escribí un mensaje para la comunidad');
      return;
    }
    setState(() => _enviando = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance.collection('community_messages').add({
        'authorId': user.uid,
        'username':
            userData['username'] ?? userData['nombreCompleto'] ?? 'usuario',
        'titulo': _tituloCtrl.text.trim(),
        'mensaje': _mensajeCtrl.text.trim(),
        'categoria': _categoria,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Mensaje enviado a la comunidad!'),
            backgroundColor: Color(0xFF0D9488),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) _snack('No se pudo enviar. Intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );

  @override
  Widget build(BuildContext context) {
    final cat = _catActual;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mensaje a la comunidad',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner informativo
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.megaphone(),
                    color: const Color(0xFF34D399),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Compartí información útil con nomads cerca tuyo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Categoría
            _DarkLabel(icono: PhosphorIcons.tag(), texto: 'Categoría'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categorias.map((c) {
                final sel = _categoria == c.nombre;
                return GestureDetector(
                  onTap: () => setState(() => _categoria = c.nombre),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: sel
                          ? LinearGradient(
                              colors: [
                                c.color.withValues(alpha: .35),
                                c.color.withValues(alpha: .18),
                              ],
                            )
                          : null,
                      color: sel ? null : Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? c.color.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          c.nombre,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: sel ? Colors.white : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Título opcional
            _DarkLabel(
              icono: PhosphorIcons.textT(),
              texto: 'Título (opcional)',
            ),
            const SizedBox(height: 10),
            _DarkField(
              controller: _tituloCtrl,
              hint: 'ej: ¡Reunión de nomads este sábado!',
              bold: true,
            ),

            const SizedBox(height: 24),

            // Mensaje
            _DarkLabel(icono: PhosphorIcons.chatText(), texto: 'Mensaje'),
            const SizedBox(height: 10),
            _DarkField(
              controller: _mensajeCtrl,
              hint: 'Escribí tu aviso para la comunidad...',
              maxLines: 6,
              maxLength: 600,
            ),

            // Preview en vivo
            AnimatedBuilder(
              animation: Listenable.merge([_tituloCtrl, _mensajeCtrl]),
              builder: (_, __) {
                final tieneContenido =
                    _tituloCtrl.text.isNotEmpty || _mensajeCtrl.text.isNotEmpty;
                if (!tieneContenido) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'Vista previa',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cat.color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 10,

                                    backgroundColor: cat.color.withValues(
                                      alpha: .35,
                                    ),

                                    child: Icon(
                                      PhosphorIcons.megaphone(),

                                      size: 12,

                                      color: Colors.white,
                                    ),
                                  ),

                                  SizedBox(width: 8),

                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),

                                    decoration: BoxDecoration(
                                      color: cat.color,

                                      borderRadius: BorderRadius.circular(10),
                                    ),

                                    child: Text(
                                      cat.nombre,

                                      style: TextStyle(
                                        color: Colors.white,

                                        fontSize: 11,

                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),

                                  SizedBox(width: 8),

                                  Text(
                                    "Ahora",

                                    style: TextStyle(
                                      fontSize: 11,

                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_tituloCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _tituloCtrl.text,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                          if (_mensajeCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              _mensajeCtrl.text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 36),

            // Botón enviar
            GestureDetector(
              onTap: _enviando ? null : _enviar,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF34D399)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: _enviando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorIcons.megaphone(),
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Enviar a la comunidad',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _DarkLabel extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _DarkLabel({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 14, color: const Color(0xFF0D9488)),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final bool bold;

  const _DarkField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white30,
            fontSize: 14,
            fontWeight: bold ? FontWeight.normal : FontWeight.normal,
          ),
          contentPadding: const EdgeInsets.all(16),
          border: InputBorder.none,
          counterStyle: const TextStyle(color: Colors.white24, fontSize: 11),
        ),
      ),
    );
  }
}

class _Cat {
  final String nombre;
  final String emoji;
  final Color color;
  const _Cat(this.nombre, this.emoji, this.color);
}

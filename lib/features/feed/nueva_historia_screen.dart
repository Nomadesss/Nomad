import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NuevaHistoriaScreen — crear una historia tipo Instagram
//
// Flujo:
//   1. El usuario elige foto de galería o cámara
//   2. Puede añadir texto encima de la imagen
//   3. Toca "Publicar historia" → guarda en Firestore (Stories service, pendiente)
//
// TODO: Conectar con StoriesService.publish() cuando esté disponible.
// ─────────────────────────────────────────────────────────────────────────────

class NuevaHistoriaScreen extends StatefulWidget {
  const NuevaHistoriaScreen({super.key});

  @override
  State<NuevaHistoriaScreen> createState() => _NuevaHistoriaScreenState();
}

class _NuevaHistoriaScreenState extends State<NuevaHistoriaScreen> {
  File? _imagen;
  final TextEditingController _textoCtrl = TextEditingController();
  bool _mostrarTexto = false;
  bool _publicando = false;

  final _picker = ImagePicker();

  Future<void> _elegirFuente(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _imagen = File(picked.path));
    }
  }

  Future<void> _publicar() async {
    if (_imagen == null) return;
    setState(() => _publicando = true);

    // TODO: await StoriesService.publish(imagen: _imagen!, texto: _textoCtrl.text);

    await Future.delayed(const Duration(milliseconds: 800)); // simulado

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Historia publicada!'),
          backgroundColor: Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _textoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'Nueva historia',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_imagen != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: () => setState(() => _mostrarTexto = !_mostrarTexto),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.textT(), color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    const Text(
                      'Texto',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _imagen == null ? _selectorInicial() : _previsualizacion(),
      bottomNavigationBar: _imagen == null ? null : _botonPublicar(),
    );
  }

  // ── Sin imagen: pantalla de selección ─────────────────────────────────────

  Widget _selectorInicial() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          /// icono estilo story
          Container(
            width: 110,
            height: 110,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient: LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF34D399)],
              ),
            ),

            padding: EdgeInsets.all(3),

            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,

                color: Color(0xFF0F0F14),
              ),

              child: Icon(
                PhosphorIcons.sparkle(),

                size: 40,

                color: Color(0xFF34D399),
              ),
            ),
          ),

          const SizedBox(height: 26),

          const Text(
            'Compartí un momento',

            style: TextStyle(
              color: Colors.white,

              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Visible por 24 horas para tu comunidad',

            style: TextStyle(
              color: Colors.white.withOpacity(.45),

              fontSize: 13,
            ),
          ),

          const SizedBox(height: 38),

          /// botón principal
          _botonPrimario(
            icono: PhosphorIcons.images(),

            label: 'Elegir de la galería',

            onTap: () => _elegirFuente(ImageSource.gallery),
          ),

          const SizedBox(height: 14),

          /// botón secundario
          _botonSecundario(
            icono: PhosphorIcons.camera(),

            label: 'Tomar una foto',

            onTap: () => _elegirFuente(ImageSource.camera),
          ),
        ],
      ),
    );
  }

  Widget _botonPrimario({
    required IconData icono,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        width: 270,

        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),

        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF34D399)],
          ),

          borderRadius: BorderRadius.circular(30),

          boxShadow: [
            BoxShadow(
              color: Color(0xFF34D399).withOpacity(.25),

              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(icono, color: Colors.white, size: 20),

            const SizedBox(width: 12),

            Text(
              label,

              style: const TextStyle(
                color: Colors.white,

                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonSecundario({
    required IconData icono,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        width: 270,

        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),

          border: Border.all(color: Color(0xFF34D399).withOpacity(.35)),

          color: Color(0xFF0D9488).withOpacity(.12),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(icono, color: Color(0xFF34D399), size: 20),

            const SizedBox(width: 12),

            Text(
              label,

              style: const TextStyle(
                color: Colors.white,

                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Con imagen: previsualización ───────────────────────────────────────────

  Widget _previsualizacion() {
    return Stack(
      fit: StackFit.expand,

      children: [
        /// imagen
        AnimatedSwitcher(
          duration: Duration(milliseconds: 250),

          child: Image.file(
            _imagen!,

            key: ValueKey(_imagen!.path),

            fit: BoxFit.cover,
          ),
        ),

        /// overlay cinematográfico
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,

                end: Alignment.bottomCenter,

                colors: [
                  Colors.black.withOpacity(.15),

                  Colors.transparent,

                  Colors.transparent,

                  Colors.black.withOpacity(.45),
                ],

                stops: [.0, .25, .55, 1],
              ),
            ),
          ),
        ),

        /// botón cambiar imagen
        Positioned(
          top: 16,

          right: 16,

          child: GestureDetector(
            onTap: () => _elegirFuente(ImageSource.gallery),

            child: Container(
              padding: EdgeInsets.all(10),

              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.35),

                shape: BoxShape.circle,

                border: Border.all(color: Colors.white.withOpacity(.15)),
              ),

              child: Icon(
                PhosphorIcons.arrowsClockwise(),

                color: Colors.white,

                size: 20,
              ),
            ),
          ),
        ),

        /// texto sobre imagen
        AnimatedOpacity(
          duration: Duration(milliseconds: 180),

          opacity: _mostrarTexto ? 1 : 0,

          child: Align(
            alignment: Alignment.center,

            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),

              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),

                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.35),

                  borderRadius: BorderRadius.circular(18),

                  border: Border.all(color: Colors.white.withOpacity(.12)),
                ),

                child: TextField(
                  controller: _textoCtrl,

                  maxLines: 3,

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    color: Colors.white,

                    fontSize: 20,

                    fontWeight: FontWeight.w600,
                  ),

                  decoration: InputDecoration(
                    hintText: "Escribí algo...",

                    hintStyle: TextStyle(color: Colors.white.withOpacity(.45)),

                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Botón publicar ─────────────────────────────────────────────────────────

  Widget _botonPublicar() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 12, 22, 22),

        child: GestureDetector(
          onTap: _publicando ? null : _publicar,

          child: AnimatedContainer(
            duration: Duration(milliseconds: 160),

            height: 56,

            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF34D399)],
              ),

              borderRadius: BorderRadius.circular(40),

              boxShadow: [
                BoxShadow(
                  color: Color(0xFF34D399).withOpacity(.35),

                  blurRadius: 20,

                  offset: Offset(0, 8),
                ),
              ],
            ),

            child: Center(
              child: _publicando
                  ? SizedBox(
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
                          PhosphorIcons.paperPlaneTilt(),

                          color: Colors.white,

                          size: 20,
                        ),

                        SizedBox(width: 10),

                        Text(
                          "Publicar historia",

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
      ),
    );
  }
}

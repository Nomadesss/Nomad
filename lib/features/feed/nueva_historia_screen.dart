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
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
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
                    const Text('Texto',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
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
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Icon(
              PhosphorIcons.image(),
              size: 40,
              color: const Color(0xFF0D9488),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Elegí una foto para tu historia',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Desaparece en 24 horas',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 40),
          _opcionBoton(
            icono: PhosphorIcons.images(),
            label: 'Elegir de la galería',
            onTap: () => _elegirFuente(ImageSource.gallery),
          ),
          const SizedBox(height: 14),
          _opcionBoton(
            icono: PhosphorIcons.camera(),
            label: 'Tomar una foto',
            onTap: () => _elegirFuente(ImageSource.camera),
          ),
        ],
      ),
    );
  }

  Widget _opcionBoton({
    required IconData icono,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0D9488).withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFF34D399).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: const Color(0xFF34D399), size: 20),
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
        // Imagen de fondo
        Image.file(_imagen!, fit: BoxFit.cover),

        // Overlay oscuro sutil
        Container(color: Colors.black.withValues(alpha: 0.15)),

        // Campo de texto encima de la imagen
        if (_mostrarTexto)
          Positioned(
            bottom: 120,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _textoCtrl,
                maxLines: 3,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'Escribí algo...',
                  hintStyle: TextStyle(color: Colors.white54),
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

        // Botón para cambiar imagen
        Positioned(
          top: 16,
          right: 16,
          child: GestureDetector(
            onTap: () => _elegirFuente(ImageSource.gallery),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.arrowsClockwise(),
                color: Colors.white,
                size: 20,
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: GestureDetector(
          onTap: _publicando ? null : _publicar,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF34D399)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: _publicando
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
                        Icon(PhosphorIcons.paperPlaneTilt(),
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        const Text(
                          'Publicar historia',
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
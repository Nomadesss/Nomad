import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:just_audio/just_audio.dart';

import '../../../services/post_service.dart';
import '../../../services/spotify_service.dart';
import '../../../services/places_service.dart';
import '../../../widgets/location_autocomplete_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NuevaPublicacionScreen — crear publicación en 4 pasos
//
// Paso 1: Fotos (hasta 5)
// Paso 2: Caption + Ubicación
// Paso 3: Música (Spotify)
// Paso 4: Preview final → Publicar
// ─────────────────────────────────────────────────────────────────────────────

class NuevaPublicacionScreen extends StatefulWidget {
  const NuevaPublicacionScreen({super.key});

  @override
  State<NuevaPublicacionScreen> createState() => _NuevaPublicacionScreenState();
}

class _NuevaPublicacionScreenState extends State<NuevaPublicacionScreen> {
  final PageController _pageCtrl = PageController();
  int _paso = 0;

  final List<File> _imagenes   = [];
  final _captionCtrl    = TextEditingController();
  final _ubicacionCtrl  = TextEditingController();
  String? _locationDisplay;
  SpotifyTrack? _trackSeleccionado;
  bool _publicando = false;

  static const _maxImagenes = 5;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _pageCtrl.dispose();
    _captionCtrl.dispose();
    _ubicacionCtrl.dispose();
    super.dispose();
  }

  void _siguiente() {
    if (_paso == 0 && _imagenes.isEmpty) {
      _snack('Agregá al menos una foto');
      return;
    }
    if (_paso < 3) {
      setState(() => _paso++);
      _pageCtrl.animateToPage(_paso,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _publicar();
    }
  }

  void _anterior() {
    if (_paso > 0) {
      setState(() => _paso--);
      _pageCtrl.animateToPage(_paso,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _publicar() async {
    setState(() => _publicando = true);
    final result = await PostService.createPost(
      imagenes:          _imagenes,
      caption:           _captionCtrl.text,
      location:          _locationDisplay,
      spotifyTrackId:    _trackSeleccionado?.id,
      spotifyTrackName:  _trackSeleccionado?.name,
      spotifyArtist:     _trackSeleccionado?.artist,
      spotifyPreviewUrl: _trackSeleccionado?.previewUrl,
      spotifyAlbumArt:   _trackSeleccionado?.albumArt,
    );
    if (!mounted) return;
    setState(() => _publicando = false);
    if (result.error != null) { _snack(result.error!); return; }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('¡Publicación creada!'),
      backgroundColor: Color(0xFF0D9488),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  Future<void> _agregarImagenes() async {
    if (_imagenes.length >= _maxImagenes) return;
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (!mounted || picked.isEmpty) return;
    final disponibles = _maxImagenes - _imagenes.length;
    setState(() =>
        _imagenes.addAll(picked.take(disponibles).map((x) => File(x.path))));
  }

  Future<void> _agregarCamara() async {
    if (_imagenes.length >= _maxImagenes) return;
    final picked =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (!mounted || picked == null) return;
    setState(() => _imagenes.add(File(picked.path)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              paso: _paso,
              onBack: _anterior,
              onSkip: _paso == 2 ? _siguiente : null,
            ),
            _IndicadorPasos(paso: _paso),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _PasoFotos(
                    imagenes: _imagenes,
                    onAgregar: _agregarImagenes,
                    onCamara: _agregarCamara,
                    onQuitar: (i) => setState(() => _imagenes.removeAt(i)),
                  ),
                  _PasoCaptionUbicacion(
                    captionCtrl: _captionCtrl,
                    ubicacionCtrl: _ubicacionCtrl,
                    onLocationSelected: (pred, detail) =>
                        _locationDisplay = pred.description,
                  ),
                  _PasoMusica(
                    trackSeleccionado: _trackSeleccionado,
                    onTrackSelected: (t) =>
                        setState(() => _trackSeleccionado = t),
                    onQuitar: () =>
                        setState(() => _trackSeleccionado = null),
                  ),
                  _PasoPreview(
                    imagenes: _imagenes,
                    caption: _captionCtrl.text,
                    location: _locationDisplay,
                    track: _trackSeleccionado,
                  ),
                ],
              ),
            ),
            _BotonSiguiente(
                paso: _paso, publicando: _publicando, onTap: _siguiente),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int paso;
  final VoidCallback onBack;
  final VoidCallback? onSkip;
  const _Header({required this.paso, required this.onBack, this.onSkip});
  static const _titles = ['Elegí tus fotos', 'Contá algo', 'Música', 'Vista previa'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(_titles[paso],
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ),
          if (onSkip != null)
            TextButton(
              onPressed: onSkip,
              child: const Text('Omitir',
                  style: TextStyle(color: Color(0xFF5EEAD4), fontSize: 14)),
            )
          else
            const SizedBox(width: 52),
        ],
      ),
    );
  }
}

// ── Indicador de pasos ────────────────────────────────────────────────────────

class _IndicadorPasos extends StatelessWidget {
  final int paso;
  const _IndicadorPasos({required this.paso});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: List.generate(4, (i) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
              height: 3,
              decoration: BoxDecoration(
                color: i <= paso
                    ? const Color(0xFF0D9488)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Botón siguiente ───────────────────────────────────────────────────────────

class _BotonSiguiente extends StatelessWidget {
  final int paso;
  final bool publicando;
  final VoidCallback onTap;
  const _BotonSiguiente(
      {required this.paso, required this.publicando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final esUltimo = paso == 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: GestureDetector(
        onTap: publicando ? null : onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF34D399)]),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: publicando
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(esUltimo ? 'Publicar' : 'Siguiente',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                      const SizedBox(width: 8),
                      Icon(
                        esUltimo
                            ? PhosphorIcons.paperPlaneTilt()
                            : PhosphorIcons.arrowRight(),
                        color: Colors.white, size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PASO 1 — Fotos
// ─────────────────────────────────────────────────────────────────────────────

class _PasoFotos extends StatelessWidget {
  final List<File> imagenes;
  final VoidCallback onAgregar;
  final VoidCallback onCamara;
  final void Function(int) onQuitar;

  const _PasoFotos({
    required this.imagenes,
    required this.onAgregar,
    required this.onCamara,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hasta 5 fotos  •  ${imagenes.length}/5',
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          if (imagenes.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
              itemCount: imagenes.length,
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(imagenes[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity),
                  ),
                  if (i == 0)
                    Positioned(
                      bottom: 6, left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF0D9488),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('Portada',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => onQuitar(i),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (imagenes.length < 5)
            Row(
              children: [
                Expanded(
                  child: _BtnAgregar(
                      icono: PhosphorIcons.images(),
                      label: 'Galería',
                      onTap: onAgregar),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BtnAgregar(
                      icono: PhosphorIcons.camera(),
                      label: 'Cámara',
                      onTap: onCamara),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(PhosphorIcons.info(),
                    size: 15, color: const Color(0xFF5EEAD4)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Con varias fotos se mostrará como carrusel. El collage drag & drop estará disponible próximamente.',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 12, height: 1.4),
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

class _BtnAgregar extends StatelessWidget {
  final IconData icono;
  final String label;
  final VoidCallback onTap;
  const _BtnAgregar(
      {required this.icono, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF0D9488).withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: const Color(0xFF34D399), size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PASO 2 — Caption + Ubicación
// ─────────────────────────────────────────────────────────────────────────────

class _PasoCaptionUbicacion extends StatelessWidget {
  final TextEditingController captionCtrl;
  final TextEditingController ubicacionCtrl;
  final void Function(PlacePrediction, PlaceDetail?) onLocationSelected;

  const _PasoCaptionUbicacion({
    required this.captionCtrl,
    required this.ubicacionCtrl,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DarkLabel(icono: PhosphorIcons.pencilSimple(), texto: 'Descripción'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: TextField(
              controller: captionCtrl,
              maxLines: 6,
              maxLength: 500,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, height: 1.5),
              decoration: const InputDecoration(
                hintText: 'Contá algo sobre este momento...',
                hintStyle: TextStyle(color: Colors.white30, fontSize: 15),
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
                counterStyle: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _DarkLabel(
              icono: PhosphorIcons.mapPin(), texto: 'Ubicación (opcional)'),
          const SizedBox(height: 10),
          LocationAutocompleteField(
            controller: ubicacionCtrl,
            hint: 'ej: Buenos Aires, Argentina',
            dark: true,
            onSelected: onLocationSelected,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PASO 3 — Música
// ─────────────────────────────────────────────────────────────────────────────

class _PasoMusica extends StatefulWidget {
  final SpotifyTrack? trackSeleccionado;
  final void Function(SpotifyTrack) onTrackSelected;
  final VoidCallback onQuitar;

  const _PasoMusica({
    required this.trackSeleccionado,
    required this.onTrackSelected,
    required this.onQuitar,
  });

  @override
  State<_PasoMusica> createState() => _PasoMusicaState();
}

class _PasoMusicaState extends State<_PasoMusica> {
  final _searchCtrl  = TextEditingController();
  final _audioPlayer = AudioPlayer();
  List<SpotifyTrack> _resultados = [];
  bool _buscando = false;
  Timer? _debounce;
  String? _playingId;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _resultados = []);
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _buscar(query));
  }

  Future<void> _buscar(String query) async {
    setState(() => _buscando = true);
    final results = await SpotifyService.search(query);
    if (mounted)
      setState(() {
        _resultados = results;
        _buscando   = false;
      });
  }

  Future<void> _togglePreview(SpotifyTrack track) async {
    if (_playingId == track.id) {
      await _audioPlayer.stop();
      setState(() => _playingId = null);
    } else {
      if (track.previewUrl == null) return;
      setState(() => _playingId = track.id);
      await _audioPlayer.setUrl(track.previewUrl!);
      await _audioPlayer.play();
      _audioPlayer.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted)
          setState(() => _playingId = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.trackSeleccionado != null)
            _TrackSeleccionado(
                track: widget.trackSeleccionado!, onQuitar: widget.onQuitar),

          if (widget.trackSeleccionado == null) ...[
            _DarkLabel(
                icono: PhosphorIcons.musicNote(), texto: 'Buscar canción en Spotify'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscá una canción...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(),
                      color: const Color(0xFF0D9488), size: 18),
                  suffixIcon: _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF0D9488)),
                          ))
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...(_resultados.map((track) => _TrackTile(
                  track:         track,
                  isPlaying:     _playingId == track.id,
                  onPreview:     () => _togglePreview(track),
                  onSeleccionar: () {
                    _audioPlayer.stop();
                    setState(() => _playingId = null);
                    widget.onTrackSelected(track);
                  },
                ))),
            if (_resultados.isEmpty &&
                !_buscando &&
                _searchCtrl.text.length > 1)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: Text('Sin resultados. Probá con otro nombre.',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 13)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final SpotifyTrack track;
  final bool isPlaying;
  final VoidCallback onPreview;
  final VoidCallback onSeleccionar;

  const _TrackTile({
    required this.track,
    required this.isPlaying,
    required this.onPreview,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaying
              ? const Color(0xFF0D9488).withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: track.albumArt != null
              ? Image.network(track.albumArt!,
                  width: 48, height: 48, fit: BoxFit.cover)
              : Container(
                  width: 48, height: 48,
                  color: const Color(0xFF1A1A24),
                  child: const Icon(Icons.music_note,
                      color: Color(0xFF0D9488), size: 22)),
        ),
        title: Text(track.name,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(track.artist,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (track.previewUrl != null)
              IconButton(
                icon: Icon(
                  isPlaying
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                  color: const Color(0xFF34D399), size: 26,
                ),
                onPressed: onPreview,
              ),
            TextButton(
              onPressed: onSeleccionar,
              style: TextButton.styleFrom(
                backgroundColor:
                    const Color(0xFF0D9488).withValues(alpha: 0.2),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Usar',
                  style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackSeleccionado extends StatelessWidget {
  final SpotifyTrack track;
  final VoidCallback onQuitar;
  const _TrackSeleccionado({required this.track, required this.onQuitar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF1DB954).withValues(alpha: 0.15),
          const Color(0xFF0D9488).withValues(alpha: 0.10),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF1DB954).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFF1DB954),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.music_note, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          if (track.albumArt != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(track.albumArt!,
                  width: 44, height: 44, fit: BoxFit.cover),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(track.artist,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white38, size: 18),
            onPressed: onQuitar,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PASO 4 — Preview
// ─────────────────────────────────────────────────────────────────────────────

class _PasoPreview extends StatelessWidget {
  final List<File> imagenes;
  final String caption;
  final String? location;
  final SpotifyTrack? track;

  const _PasoPreview({
    required this.imagenes,
    required this.caption,
    this.location,
    this.track,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Así se verá tu publicación',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFF1A2E2A),
                        child: Icon(Icons.person,
                            size: 18, color: Color(0xFF0D9488)),
                      ),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vos',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text('Ahora',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (imagenes.isNotEmpty)
                  ClipRRect(
                    child: Image.file(imagenes.first,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (caption.isNotEmpty)
                        Text(caption,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.4),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                      if (location != null) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.location_on,
                              size: 13, color: Color(0xFF5EEAD4)),
                          const SizedBox(width: 4),
                          Text(location!,
                              style: const TextStyle(
                                  color: Color(0xFF5EEAD4), fontSize: 12)),
                        ]),
                      ],
                      if (track != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF1DB954)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_note,
                                  size: 12, color: Color(0xFF1DB954)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${track!.name} — ${track!.artist}',
                                  style: const TextStyle(
                                      color: Color(0xFF1DB954),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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

// ── Label oscuro reutilizable ─────────────────────────────────────────────────

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
        Text(texto,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70)),
      ],
    );
  }
}
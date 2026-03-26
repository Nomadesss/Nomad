// ignore_for_file: prefer_const_constructors

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

const primary = Color(0xFF0D9488);
const accent = Color(0xFF34D399);
const bg = Color(0xFF0F0F14);
const spotify = Color(0xFF1DB954);

class NuevaPublicacionScreen extends StatefulWidget {
  const NuevaPublicacionScreen({super.key});

  @override
  State<NuevaPublicacionScreen> createState() => _NuevaPublicacionScreenState();
}

class _NuevaPublicacionScreenState extends State<NuevaPublicacionScreen> {
  final PageController _pageCtrl = PageController();

  int _paso = 0;

  final List<File> _imagenes = [];

  final _captionCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();

  String? _locationDisplay;

  SpotifyTrack? _trackSeleccionado;

  bool _publicando = false;

  final _picker = ImagePicker();

  static const maxImagenes = 5;

  @override
  void dispose() {
    _pageCtrl.dispose();

    _captionCtrl.dispose();

    _ubicacionCtrl.dispose();

    super.dispose();
  }

  void next() {
    if (_paso == 0 && _imagenes.isEmpty) {
      snack("Agregá al menos una foto");

      return;
    }

    if (_paso < 3) {
      setState(() => _paso++);

      _pageCtrl.animateToPage(
        _paso,

        duration: Duration(milliseconds: 280),

        curve: Curves.easeOut,
      );
    } else {
      publicar();
    }
  }

  void back() {
    if (_paso == 0) {
      Navigator.pop(context);

      return;
    }

    setState(() => _paso--);

    _pageCtrl.animateToPage(
      _paso,

      duration: Duration(milliseconds: 280),

      curve: Curves.easeOut,
    );
  }

  void snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future publicar() async {
    setState(() => _publicando = true);

    final res = await PostService.createPost(
      imagenes: _imagenes,

      caption: _captionCtrl.text,

      location: _locationDisplay,

      spotifyTrackId: _trackSeleccionado?.id,

      spotifyTrackName: _trackSeleccionado?.name,

      spotifyArtist: _trackSeleccionado?.artist,

      spotifyPreviewUrl: _trackSeleccionado?.previewUrl,

      spotifyAlbumArt: _trackSeleccionado?.albumArt,
    );

    setState(() => _publicando = false);

    if (res.error != null) {
      snack(res.error!);

      return;
    }

    Navigator.pop(context);
  }

  Future addGallery() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);

    if (!mounted) return;

    final disponibles = maxImagenes - _imagenes.length;

    setState(() {
      _imagenes.addAll(picked.take(disponibles).map((x) => File(x.path)));
    });
  }

  Future addCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,

      imageQuality: 85,
    );

    if (picked == null) return;

    setState(() => _imagenes.add(File(picked.path)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,

      body: SafeArea(
        child: Column(
          children: [
            Header(paso: _paso, onBack: back, onSkip: _paso == 2 ? next : null),

            StepIndicator(paso: _paso),

            Expanded(
              child: PageView(
                controller: _pageCtrl,

                physics: NeverScrollableScrollPhysics(),

                children: [
                  StepFotos(
                    imagenes: _imagenes,

                    onGaleria: addGallery,

                    onCamara: addCamera,

                    onDelete: (i) => setState(() => _imagenes.removeAt(i)),
                  ),

                  StepCaption(
                    captionCtrl: _captionCtrl,
                    ubicacionCtrl: _ubicacionCtrl,
                    imagenes: _imagenes,

                    onLocation: (p, d) => _locationDisplay = p.description,
                  ),

                  StepMusica(
                    track: _trackSeleccionado,

                    onSelected: (t) => setState(() => _trackSeleccionado = t),

                    onRemove: () => setState(() => _trackSeleccionado = null),
                  ),

                  StepPreview(
                    imagenes: _imagenes,

                    caption: _captionCtrl.text,

                    location: _locationDisplay,

                    track: _trackSeleccionado,
                  ),
                ],
              ),
            ),

            BottomButton(paso: _paso, publicando: _publicando, onTap: next),
          ],
        ),
      ),
    );
  }
}

class Header extends StatelessWidget {
  final int paso;

  final VoidCallback onBack;

  final VoidCallback? onSkip;

  const Header({required this.paso, required this.onBack, this.onSkip});

  static const titles = [
    "Elegí tus fotos",

    "Contá algo",

    "Música",

    "Vista previa",
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 6, 16, 0),

      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),

            onPressed: onBack,
          ),

          Expanded(
            child: Text(
              titles[paso],

              textAlign: TextAlign.center,

              style: TextStyle(
                color: Colors.white,

                fontSize: 18,

                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          if (onSkip != null)
            TextButton(
              onPressed: onSkip,

              child: Text("Omitir", style: TextStyle(color: accent)),
            )
          else
            SizedBox(width: 52),
        ],
      ),
    );
  }
}

class StepIndicator extends StatelessWidget {
  final int paso;

  const StepIndicator({required this.paso});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),

      child: Row(
        children: List.generate(
          4,

          (i) => Expanded(
            child: AnimatedContainer(
              duration: Duration(milliseconds: 250),

              margin: EdgeInsets.only(right: i < 3 ? 6 : 0),

              height: 4,

              decoration: BoxDecoration(
                color: i <= paso ? primary : Colors.white.withOpacity(.15),

                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BottomButton extends StatelessWidget {
  final int paso;

  final bool publicando;

  final VoidCallback onTap;

  const BottomButton({
    required this.paso,

    required this.publicando,

    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final last = paso == 3;

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 10, 22, 22),

      child: GestureDetector(
        onTap: publicando ? null : onTap,

        child: Container(
          height: 56,

          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primary, accent]),

            borderRadius: BorderRadius.circular(40),

            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(.35),

                blurRadius: 20,

                offset: Offset(0, 8),
              ),
            ],
          ),

          child: Center(
            child: publicando
                ? CircularProgressIndicator(color: Colors.white)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Text(
                        last ? "Publicar" : "Siguiente",

                        style: TextStyle(
                          color: Colors.white,

                          fontSize: 16,

                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      SizedBox(width: 8),

                      Icon(
                        last
                            ? PhosphorIcons.paperPlaneTilt()
                            : PhosphorIcons.arrowRight(),

                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class StepFotos extends StatefulWidget {
  final List<File> imagenes;

  final VoidCallback onGaleria;

  final VoidCallback onCamara;

  final Function(int) onDelete;

  const StepFotos({
    required this.imagenes,

    required this.onGaleria,

    required this.onCamara,

    required this.onDelete,
  });

  @override
  State<StepFotos> createState() => _StepFotosState();
}

class _StepFotosState extends State<StepFotos> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final imagenes = widget.imagenes;

    if (selectedIndex >= imagenes.length) {
      selectedIndex = 0;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 22),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            "Hasta 5 fotos • ${imagenes.length}/5",

            style: TextStyle(color: Colors.white38),
          ),

          SizedBox(height: 18),

          /// imagen principal
          Container(
            height: 240,

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),

              border: Border.all(color: Colors.white.withOpacity(.08)),
            ),

            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),

              child: imagenes.isEmpty
                  ? _placeholderImagen()
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedSwitcher(
                            duration: Duration(milliseconds: 250),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,

                                child: ScaleTransition(
                                  scale: Tween(
                                    begin: .97,
                                    end: 1.0,
                                  ).animate(animation),

                                  child: child,
                                ),
                              );
                            },

                            child: Container(
                              key: ValueKey(imagenes[selectedIndex].path),

                              color: Colors.black,

                              alignment: Alignment.center,

                              child: Image.file(
                                imagenes[selectedIndex],

                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),

                        /// indicador carrusel
                        if (imagenes.length > 1)
                          Positioned(
                            top: 12,

                            right: 12,

                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,

                                vertical: 5,
                              ),

                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(.45),

                                borderRadius: BorderRadius.circular(20),
                              ),

                              child: Text(
                                "${selectedIndex + 1}/${imagenes.length}",

                                style: TextStyle(
                                  color: Colors.white,

                                  fontSize: 12,

                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),

          SizedBox(height: 12),

          /// thumbnails
          if (imagenes.isNotEmpty)
            SizedBox(
              height: 64,

              child: ListView.separated(
                scrollDirection: Axis.horizontal,

                itemCount: imagenes.length,

                separatorBuilder: (_, __) => SizedBox(width: 10),

                itemBuilder: (_, i) {
                  final selected = i == selectedIndex;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedIndex = i;
                      });
                    },

                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 180),

                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(
                          color: selected ? accent : Colors.transparent,

                          width: 1.5,
                        ),
                      ),

                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),

                        child: Image.file(
                          imagenes[i],

                          width: selected ? 64 : 56,

                          height: selected ? 64 : 56,

                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          SizedBox(height: 22),

          /// botones galeria camara
          Row(
            children: [
              Expanded(
                child: PhotoButton(
                  icon: PhosphorIcons.images(),

                  label: "Galería",

                  onTap: widget.onGaleria,
                ),
              ),

              SizedBox(width: 14),

              Expanded(
                child: PhotoButton(
                  icon: PhosphorIcons.camera(),

                  label: "Cámara",

                  onTap: widget.onCamara,
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          InfoBox(),

          SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _placeholderImagen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(.04),
            Colors.white.withOpacity(.02),
          ],
        ),
      ),

      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Container(
              width: 56,
              height: 56,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                gradient: LinearGradient(colors: [primary, accent]),
              ),

              child: Icon(
                PhosphorIcons.images(),

                color: Colors.white,

                size: 26,
              ),
            ),

            SizedBox(height: 12),

            Text(
              "Tu publicación",

              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class PhotoButton extends StatelessWidget {
  final IconData icon;

  final String label;

  final VoidCallback onTap;

  const PhotoButton({
    required this.icon,

    required this.label,

    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        height: 110,

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),

          gradient: LinearGradient(
            colors: [
              Color(0xFF0D9488).withOpacity(.22),
              Color(0xFF34D399).withOpacity(.12),
            ],
          ),

          border: Border.all(color: accent.withOpacity(.35)),
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Container(
              width: 42,

              height: 42,

              decoration: BoxDecoration(
                color: accent.withOpacity(.15),

                borderRadius: BorderRadius.circular(12),
              ),

              child: Icon(icon, color: accent),
            ),

            SizedBox(height: 10),

            Text(label, style: TextStyle(color: Colors.white.withOpacity(.75))),
          ],
        ),
      ),
    );
  }
}

class InfoBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: primary.withOpacity(.3)),

        color: Colors.white.withOpacity(.04),
      ),

      child: Row(
        children: [
          Icon(PhosphorIcons.info(), color: accent),

          SizedBox(width: 10),

          Expanded(
            child: Text(
              "Podés subir hasta 5 fotos. El orden podrá editarse próximamente.",

              style: TextStyle(color: Colors.white38, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class StepCaption extends StatelessWidget {
  final TextEditingController captionCtrl;
  final TextEditingController ubicacionCtrl;
  final List<File> imagenes;

  final Function(PlacePrediction, PlaceDetail?) onLocation;

  const StepCaption({
    required this.captionCtrl,
    required this.ubicacionCtrl,
    required this.onLocation,
    required this.imagenes,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 22),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          if (imagenes.isNotEmpty)
            Container(
              margin: EdgeInsets.only(bottom: 18),

              height: 120,

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),

                border: Border.all(color: Colors.white.withOpacity(.08)),
              ),

              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),

                child: Image.file(
                  imagenes.first,

                  fit: BoxFit.cover,

                  width: double.infinity,
                ),
              ),
            ),
          Label(icon: PhosphorIcons.pencilSimple(), text: "Descripción"),

          SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.03),

              borderRadius: BorderRadius.circular(16),

              border: Border.all(color: Colors.white.withOpacity(.12)),
            ),

            child: TextField(
              controller: captionCtrl,

              maxLines: 5,

              maxLength: 500,

              style: TextStyle(color: Colors.white, fontSize: 16, height: 1.6),

              decoration: InputDecoration(
                hintText: "Contá algo sobre este momento...",

                hintStyle: TextStyle(color: Colors.white30),

                border: InputBorder.none,

                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),

          SizedBox(height: 22),

          Label(icon: PhosphorIcons.mapPin(), text: "Ubicación"),

          SizedBox(height: 10),

          LocationAutocompleteField(
            controller: ubicacionCtrl,

            hint: "Ej: Montevideo, Uruguay",

            dark: true,

            onSelected: onLocation,
          ),
        ],
      ),
    );
  }
}

class StepMusica extends StatefulWidget {
  final SpotifyTrack? track;

  final Function(SpotifyTrack) onSelected;

  final VoidCallback onRemove;

  const StepMusica({
    required this.track,

    required this.onSelected,

    required this.onRemove,
  });

  @override
  State<StepMusica> createState() => _StepMusicaState();
}

class _StepMusicaState extends State<StepMusica> {
  final searchCtrl = TextEditingController();

  final audio = AudioPlayer();

  List<SpotifyTrack> results = [];

  String? playingId;

  Timer? debounce;

  bool loading = false;

  @override
  void dispose() {
    debounce?.cancel();

    searchCtrl.dispose();

    audio.dispose();

    super.dispose();
  }

  void search(String q) {
    debounce?.cancel();

    if (q.length < 2) {
      setState(() => results = []);

      return;
    }

    debounce = Timer(Duration(milliseconds: 350), () async {
      setState(() => loading = true);

      results = await SpotifyService.search(q);

      setState(() => loading = false);
    });
  }

  Future preview(SpotifyTrack t) async {
    if (t.previewUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Spotify no tiene preview para esta canción")),
      );

      return;
    }

    if (playingId == t.id) {
      await audio.stop();

      setState(() => playingId = null);

      return;
    }

    try {
      await audio.stop();

      await audio.setUrl(t.previewUrl!);

      await audio.play();

      setState(() {
        playingId = t.id;
      });
    } catch (e) {
      setState(() => playingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 22),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          /// preview contextual
          Container(
            height: 110,

            margin: EdgeInsets.only(bottom: 18),

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),

              gradient: LinearGradient(
                colors: [primary.withOpacity(.18), accent.withOpacity(.08)],
              ),

              border: Border.all(color: accent.withOpacity(.25)),
            ),

            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(PhosphorIcons.musicNotes(), color: accent),

                  SizedBox(width: 8),

                  Text(
                    "Elegí el mood de tu post",

                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          Label(icon: PhosphorIcons.magnifyingGlass(), text: "Buscar canción"),

          SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.05),

              borderRadius: BorderRadius.circular(14),
            ),

            child: TextField(
              controller: searchCtrl,

              onChanged: search,

              style: TextStyle(color: Colors.white),

              decoration: InputDecoration(
                hintText: "Ej: Coldplay",

                hintStyle: TextStyle(color: Colors.white30),

                border: InputBorder.none,

                prefixIcon: Icon(
                  PhosphorIcons.magnifyingGlass(),

                  color: accent,
                ),
              ),
            ),
          ),

          SizedBox(height: 18),
          if (widget.track != null)
            SelectedTrack(track: widget.track!, onRemove: widget.onRemove),

          /// chips
          Wrap(
            spacing: 8,

            runSpacing: 8,

            children: [
              chip("Chill"),
              chip("Viaje"),
              chip("Focus"),
              chip("Romance"),
              chip("Energía"),
              chip("Fiesta"),
            ],
          ),

          SizedBox(height: 20),

          if (loading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: accent),
              ),
            ),

          if (!loading && results.isEmpty && searchCtrl.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40),

              child: Center(
                child: Column(
                  children: [
                    Icon(
                      PhosphorIcons.musicNote(),
                      color: Colors.white24,
                      size: 36,
                    ),

                    SizedBox(height: 10),

                    Text(
                      "No encontramos resultados",

                      style: TextStyle(color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ),

          ...results.map(
            (t) => TrackTile(
              track: t,

              playing: playingId == t.id,

              onPreview: () => preview(t),

              onSelect: () {
                audio.stop();

                widget.onSelected(t);
              },
            ),
          ),

          SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget chip(String texto) {
    return GestureDetector(
      onTap: () {
        searchCtrl.text = texto;

        search(texto);
      },

      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),

          color: Colors.white.withOpacity(.05),

          border: Border.all(color: Colors.white.withOpacity(.12)),
        ),

        child: Text(
          texto,

          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
    );
  }
}

class TrackTile extends StatelessWidget {
  final SpotifyTrack track;
  final bool playing;
  final VoidCallback onPreview;
  final VoidCallback onSelect;

  const TrackTile({
    required this.track,
    required this.playing,
    required this.onPreview,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final hasPreview = track.previewUrl != null;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),

      margin: EdgeInsets.only(bottom: 12),

      padding: EdgeInsets.all(12),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),

        gradient: playing
            ? LinearGradient(
                colors: [spotify.withOpacity(.18), primary.withOpacity(.12)],
              )
            : null,

        color: playing ? null : Colors.white.withOpacity(.04),

        border: Border.all(
          color: playing
              ? spotify.withOpacity(.6)
              : Colors.white.withOpacity(.05),
        ),
      ),

      child: Row(
        children: [
          /// album art
          ClipRRect(
            borderRadius: BorderRadius.circular(10),

            child: track.albumArt != null
                ? Image.network(
                    track.albumArt!,

                    width: 52,
                    height: 52,

                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 52,
                    height: 52,

                    color: Colors.black26,

                    child: Icon(PhosphorIcons.musicNote(), color: accent),
                  ),
          ),

          SizedBox(width: 12),

          /// track info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  track.name,

                  style: TextStyle(
                    color: Colors.white,

                    fontWeight: FontWeight.w600,
                  ),

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: 2),

                Text(
                  track.artist,

                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),

                SizedBox(height: 6),

                /// fake waveform animation
                AnimatedOpacity(
                  duration: Duration(milliseconds: 200),

                  opacity: playing ? 1 : 0,

                  child: Container(
                    height: 4,

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),

                      gradient: LinearGradient(colors: [accent, spotify]),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 8),

          /// preview button
          IconButton(
            onPressed: hasPreview ? onPreview : null,

            icon: Icon(
              hasPreview
                  ? (playing
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline)
                  : PhosphorIcons.musicNote(),

              color: hasPreview ? accent : Colors.white24,

              size: 28,
            ),
          ),

          /// select button
          TextButton(
            onPressed: onSelect,

            child: Text(
              "Usar",

              style: TextStyle(color: accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class SelectedTrack extends StatelessWidget {
  final SpotifyTrack track;

  final VoidCallback onRemove;

  const SelectedTrack({required this.track, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),

      margin: EdgeInsets.only(bottom: 18),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),

        gradient: LinearGradient(
          colors: [spotify.withOpacity(.18), primary.withOpacity(.12)],
        ),

        border: Border.all(color: spotify.withOpacity(.5)),
      ),

      child: Row(
        children: [
          Icon(PhosphorIcons.musicNote(), color: spotify),

          SizedBox(width: 12),

          Expanded(
            child: Text(
              "${track.name} — ${track.artist}",

              style: TextStyle(color: Colors.white),

              overflow: TextOverflow.ellipsis,
            ),
          ),

          IconButton(icon: Icon(Icons.close), onPressed: onRemove),
        ],
      ),
    );
  }
}

class StepPreview extends StatelessWidget {
  final List<File> imagenes;

  final String caption;

  final String? location;

  final SpotifyTrack? track;

  const StepPreview({
    required this.imagenes,

    required this.caption,

    this.location,

    this.track,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 22),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),

              color: Colors.white.withOpacity(.05),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.3),

                  blurRadius: 20,

                  offset: Offset(0, 10),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),

                  child: SizedBox(
                    height: 240,

                    child: Stack(
                      children: [
                        /// carrusel
                        PageView.builder(
                          itemCount: imagenes.length,

                          itemBuilder: (_, i) {
                            return Image.file(
                              imagenes[i],

                              width: double.infinity,

                              fit: BoxFit.cover,
                            );
                          },
                        ),

                        /// indicador cantidad fotos
                        if (imagenes.length > 1)
                          Positioned(
                            top: 10,
                            right: 10,

                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),

                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(.45),

                                borderRadius: BorderRadius.circular(20),
                              ),

                              child: Text(
                                "1/${imagenes.length}",

                                style: TextStyle(
                                  color: Colors.white,

                                  fontSize: 11,

                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                        /// sticker musica
                        if (track != null)
                          Positioned(
                            left: 12,
                            bottom: 12,

                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),

                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),

                                gradient: LinearGradient(
                                  colors: [
                                    spotify.withOpacity(.9),

                                    primary.withOpacity(.9),
                                  ],
                                ),

                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.35),

                                    blurRadius: 12,

                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),

                              child: Row(
                                mainAxisSize: MainAxisSize.min,

                                children: [
                                  Icon(
                                    PhosphorIcons.musicNotes(),
                                    color: Colors.white,
                                    size: 16,
                                  ),

                                  SizedBox(width: 6),

                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: 160),

                                    child: Text(
                                      "${track!.name} — ${track!.artist}",

                                      overflow: TextOverflow.ellipsis,

                                      style: TextStyle(
                                        color: Colors.white,

                                        fontSize: 12,

                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(14),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      if (caption.isNotEmpty)
                        Text(caption, style: TextStyle(color: Colors.white)),

                      if (location != null)
                        Padding(
                          padding: EdgeInsets.only(top: 6),

                          child: Text(
                            location!,

                            style: TextStyle(color: accent),
                          ),
                        ),
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

class Label extends StatelessWidget {
  final IconData icon;

  final String text;

  const Label({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: primary),

        SizedBox(width: 6),

        Text(
          text,

          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

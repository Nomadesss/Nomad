import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../l10n/app_localizations.dart';
import '../../core/widgets/language_picker_sheet.dart';

import '../feed/widgets/bottom_nav.dart';
import 'edit_profile_screen.dart';
import '../feed/crear_evento_screen.dart';
import '../feed/mensaje_comunidad_screen.dart';
import '../feed/nueva_historia_screen.dart';
import '../feed/widgets/like_button.dart';
import '../feed/widgets/save_button.dart';
import '../feed/widgets/share_sheet.dart';
import '../feed/widgets/post_options_sheet.dart'; // exporta showPostOptions()
import '../feed/widgets/comments_screen.dart';
import '../../services/social_service.dart';
import '../../services/post_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// perfil_screen.dart  –  Nomad App
// ─────────────────────────────────────────────────────────────────────────────

const _teal = Color(0xFF0D9488);
const _tealLight = Color(0xFF5EEAD4);
const _tealDark = Color(0xFF134E4A);
const _tealBg = Color(0xFFF0FAF9);
const _bgMain = Color(0xFFF8FFFE);

class PerfilPropio extends StatefulWidget {
  const PerfilPropio({super.key});

  @override
  State<PerfilPropio> createState() => _PerfilPropioState();
}

class _PerfilPropioState extends State<PerfilPropio>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabIndex = 0;

  final _firestore = FirebaseFirestore.instance;
  String _nombre = '';
  String _username = '';
  String _bio = '';
  List<Map<String, String>> _lugaresVividos = [];
  List<Map<String, dynamic>> _highlights = [];
  int _seguidoresCount = 0;
  int _siguiendoCount = 0;
  int _publicacionesCount = 0;
  bool _datosLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() => _tabIndex = _tabController.index));
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!mounted) return;
    final data = doc.data();
    final ciudadesRaw = data?['ciudadesVividas'];
    final List<Map<String, String>> ciudades = ciudadesRaw is List
        ? ciudadesRaw.map((e) => Map<String, String>.from(e as Map)).toList()
        : [];

    int seguidoresTemp = 0;
    int siguiendoTemp = 0;
    int publicacionesTemp = 0;
    try {
      // seguidores
      final followersSnapshot = await _firestore
          .collection('follows')
          .where('followingId', isEqualTo: user.uid)
          .get();

      // seguidos
      final followingSnapshot = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: user.uid)
          .get();

      // publicaciones
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: user.uid)
          .get();

      seguidoresTemp = followersSnapshot.size;
      siguiendoTemp = followingSnapshot.size;
      publicacionesTemp = postsSnapshot.size;
    } catch (e) {
      debugPrint('Error al cargar estadísticas: $e');
    }

    try {
      final highlightsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('highlights')
          .orderBy('order')
          .get();
      final loadedHighlights = highlightsSnapshot.docs.map((d) {
        final data = d.data();
        return {
          "id": d.id,
          "title": data["title"] ?? "Destacada",
          "emoji": data["emoji"] ?? "⭐",
          "coverUrl": data["coverUrl"],
        };
      }).toList();
      setState(() => _highlights = loadedHighlights);
    } catch (e) {
      debugPrint("error highlights $e");
    }

    setState(() {
      _nombre =
          data?['displayName'] ??
          user.displayName ??
          user.email?.split('@')[0] ??
          'Usuario';
      _username =
          data?['username'] ?? _nombre.toLowerCase().replaceAll(' ', '_');
      _bio = data?['bio'] ?? '';
      _lugaresVividos = ciudades;
      _seguidoresCount = seguidoresTemp;
      _siguiendoCount = siguiendoTemp;
      _publicacionesCount = publicacionesTemp;
      _datosLoaded = true;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String nombre = _datosLoaded
        ? _nombre
        : (user?.displayName ?? user?.email?.split('@')[0] ?? 'Usuario');
    final String username = _datosLoaded
        ? _username
        : nombre.toLowerCase().replaceAll(' ', '_');

    return Scaffold(
      backgroundColor: _bgMain,
      body: NestedScrollView(
        physics: const ClampingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverHeader(
            context,
            user,
            nombre,
            username,
            innerBoxIsScrolled,
          ),
        ],
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _TabPublicacionesFirebase(),
                  _TabEventosFirebase(),
                  _TabMensajesFirebase(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  Widget _buildSliverHeader(
    BuildContext context,
    User? user,
    String nombre,
    String username,
    bool innerBoxIsScrolled,
  ) {
    return SliverAppBar(
      expandedHeight: 520,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      leading: const SizedBox.shrink(),
      actions: [
        IconButton(
          icon: const Icon(Icons.menu_rounded, color: _tealDark),
          onPressed: () => _showConfiguracion(context),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _ProfileHeader(
          user: user,
          nombre: nombre,
          username: username,
          bio: _bio,
          highlights: _highlights,
          lugaresVividos: _lugaresVividos,
          seguidoresCount: _seguidoresCount,
          siguiendoCount: _siguiendoCount,
          publicacionesCount: _publicacionesCount,
          onEditarPerfil: () => _showEditarPerfil(context),
          onFoto: () => _showFotoOptions(context, user),
          onEditarPortada: () => _showPortadaOptions(context),
          onCrearHighlight: _crearHighlight,
          onAbrirHighlight: _abrirHighlight,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      (Icons.grid_on_rounded, 'Posts'),
      (Icons.event_outlined, 'Eventos'),
      (Icons.campaign_outlined, 'Mensajes'),
    ];

    return Container(
      color: Colors.white,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _tabController.animateTo(i);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _teal : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Icon(
                  tabs[i].$1,
                  size: 22,
                  color: selected ? _teal : const Color(0xFFB0C4C3),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showEditarPerfil(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    ).then((_) => _cargarDatosUsuario());
  }

  void _showFotoOptions(BuildContext context, User? user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FotoOptionsSheet(user: user),
    );
  }

  void _showPortadaOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PortadaOptionsSheet(),
    );
  }

  void _showConfiguracion(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ConfiguracionSheet(),
    );
  }

  Future<void> _crearHighlight(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NuevaHistoriaScreen()),
    );
    _cargarDatosUsuario();
  }

  void _abrirHighlight(BuildContext context, String highlightId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HighlightStoriesScreen(highlightId: highlightId),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header del perfil
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final User? user;
  final String nombre;
  final String username;
  final String bio;
  final List<Map<String, dynamic>> highlights;
  final List<Map<String, String>> lugaresVividos;
  final int seguidoresCount;
  final int siguiendoCount;
  final int publicacionesCount;
  final VoidCallback onEditarPerfil;
  final VoidCallback onFoto;
  final VoidCallback onEditarPortada;
  final Function(BuildContext) onCrearHighlight;
  final Function(BuildContext, String) onAbrirHighlight;

  const _ProfileHeader({
    required this.user,
    required this.nombre,
    required this.username,
    required this.bio,
    required this.highlights,
    required this.lugaresVividos,
    required this.seguidoresCount,
    required this.siguiendoCount,
    required this.publicacionesCount,
    required this.onEditarPerfil,
    required this.onFoto,
    required this.onEditarPortada,
    required this.onCrearHighlight,
    required this.onAbrirHighlight,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCoverAndAvatar(context, onEditarPortada),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _tealDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            '@$username',
                            style: const TextStyle(
                              fontSize: 13,
                              color: _teal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _EditButton(label: AppLocalizations.of(context).profileEditButton, onTap: onEditarPerfil),
                  ],
                ),
                const SizedBox(height: 10),
                if (bio.isNotEmpty) _BioExpandable(text: bio),
                const SizedBox(height: 14),
                _buildLugaresVividos(),
                const SizedBox(height: 18),
              ],
            ),
          ),
          _buildHighlights(context),
          const SizedBox(height: 8),
          Container(height: 0.5, color: const Color(0xFFE2F0EF)),
        ],
      ),
    );
  }

  Widget _buildCoverAndAvatar(
    BuildContext context,
    VoidCallback onEditarPortada,
  ) {
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 160,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_teal, _tealDark]),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800&q=70',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 120,
            right: 14,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onEditarPortada,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context).profileEditCover,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 115,
            left: 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: onFoto,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [_teal, _tealLight]),
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 41,
                        backgroundColor: const Color(0xFFCCFBF1),
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL == null
                            ? Text(
                                (user?.displayName?.isNotEmpty == true
                                        ? user!.displayName!
                                        : (user?.email ?? 'U'))
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: _teal,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Material(
                    color: _teal,
                    shape: const CircleBorder(),
                    elevation: 4,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onFoto,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 170,
            left: 150,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatBubble(
                  value: seguidoresCount.toString(),
                  label: 'Seguidores',
                ),
                const SizedBox(width: 16),
                _StatBubble(
                  value: siguiendoCount.toString(),
                  label: 'Siguiendo',
                ),
                const SizedBox(width: 16),
                _StatBubble(
                  value: publicacionesCount.toString(),
                  label: 'Publicaciones',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLugaresVividos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.flight_rounded, size: 14, color: _teal),
            SizedBox(width: 6),
            Text(
              'Mi ruta migrante',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _teal,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (lugaresVividos.isEmpty)
                GestureDetector(
                  onTap: onEditarPerfil,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _tealBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _tealLight.withOpacity(0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.add_location_alt_outlined,
                          size: 14,
                          color: _teal,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Agregá tus ciudades',
                          style: TextStyle(
                            fontSize: 12,
                            color: _teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...lugaresVividos.asMap().entries.map((e) {
                  final i = e.key;
                  final lugar = e.value;
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _tealBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _tealLight.withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${lugar['emoji'] ?? '🌍'} ${lugar['ciudad']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _tealDark,
                              ),
                            ),
                            if ((lugar['años'] ?? '').isNotEmpty)
                              Text(
                                lugar['años']!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _teal,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (i < lugaresVividos.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: _tealLight,
                          ),
                        ),
                    ],
                  );
                }),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEditarPerfil,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _tealLight),
                    color: _tealBg,
                  ),
                  child: const Icon(Icons.add_rounded, size: 18, color: _teal),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHighlights(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _HighlightItem(
            title: 'Nuevo',
            isCreate: true,
            onTap: () => onCrearHighlight(context),
          ),
          ...highlights.map(
            (h) => _HighlightItem(
              title: h['title'],
              emoji: h['emoji'],
              imageUrl: h['coverUrl'],
              onTap: () {
                final id = h["id"];
                if (id != null) onAbrirHighlight(context, id);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detalle de publicación
// ─────────────────────────────────────────────────────────────────────────────

class _TabPublicacionesFirebase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    // Lee de la colección 'posts' (donde escribe PostService)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _teal));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library_outlined, size: 48, color: _tealLight),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).profileNoPostsTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    color: _tealDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).profileNoPostsSubtitle,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            // PostService guarda las imágenes en el campo 'images' (List<String>)
            final images = List<String>.from(data['images'] as List? ?? []);
            final thumbUrl = images.isNotEmpty ? images.first : null;
            final multipleImages = images.length > 1;
            final uid = FirebaseAuth.instance.currentUser!.uid;

            return GestureDetector(
              onTap: () => _abrirDetalle(context, doc.id, uid, data),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbUrl != null)
                    Image.network(
                      thumbUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, p) => p == null
                          ? child
                          : Container(
                              color: _tealBg,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: _teal,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                      errorBuilder: (_, __, ___) =>
                          const _PostPlaceholder(tipo: 'imagen'),
                    )
                  else
                    const _PostPlaceholder(tipo: 'imagen'),
                  if (multipleImages)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.collections_rounded,
                        color: Colors.white,
                        size: 18,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _abrirDetalle(
    BuildContext context,
    String postId,
    String autorId,
    Map<String, dynamic> data,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _PublicacionDetalle(postId: postId, autorId: autorId, data: data),
    );
  }
}

class _PostPlaceholder extends StatelessWidget {
  final String tipo;
  const _PostPlaceholder({required this.tipo});
  @override
  Widget build(BuildContext context) {
    const map = {
      'imagen': (Icons.image_outlined, 0xFF0D9488),
      'video': (Icons.videocam_outlined, 0xFF0891B2),
      'audio': (Icons.mic_outlined, 0xFF7C3AED),
    };
    final entry = map[tipo] ?? (Icons.photo_outlined, 0xFF0D9488);
    return Container(
      color: Color(entry.$2).withOpacity(0.12),
      child: Center(child: Icon(entry.$1, color: Color(entry.$2), size: 28)),
    );
  }
}

class _PublicacionDetalle extends StatefulWidget {
  final String postId;
  final String autorId;
  final Map<String, dynamic> data;

  const _PublicacionDetalle({
    required this.postId,
    required this.autorId,
    required this.data,
  });

  @override
  State<_PublicacionDetalle> createState() => _PublicacionDetalleState();
}

class _PublicacionDetalleState extends State<_PublicacionDetalle> {
  int _currentImageIndex = 0;

  // PostService usa 'createdAt' (Timestamp). La colección vieja usaba 'timestamp'.
  String _fechaStr() {
    final ts = widget.data['createdAt'] ?? widget.data['timestamp'];
    if (ts == null) return '';
    try {
      final dt = (ts as dynamic).toDate() as DateTime;
      const meses = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ];
      return '${dt.day} ${meses[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // PostService guarda en 'images' (List). Soporte también para 'mediaUrl' legacy.
    final images = List<String>.from(widget.data['images'] as List? ?? []);
    if (images.isEmpty && widget.data['mediaUrl'] != null) {
      images.add(widget.data['mediaUrl'] as String);
    }

    final caption = widget.data['caption'] as String? ?? '';
    final username = widget.data['username'] as String? ?? '';
    final city = widget.data['city'] as String?;
    final countryFlag = widget.data['countryFlag'] as String?;
    final likesCount = (widget.data['likesCount'] as num?)?.toInt() ?? 0;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final esPropio = widget.autorId == myUid;

    // Spotify
    final spotifyTrackName = widget.data['spotifyTrackName'] as String?;
    final spotifyArtist = widget.data['spotifyArtist'] as String?;
    final spotifyAlbumArt = widget.data['spotifyAlbumArt'] as String?;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          children: [
            // ── Handle ────────────────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header: avatar + nombre + ciudad ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _tealBg,
                    backgroundImage:
                        FirebaseAuth.instance.currentUser?.photoURL != null
                        ? NetworkImage(
                            FirebaseAuth.instance.currentUser!.photoURL!,
                          )
                        : null,
                    child: FirebaseAuth.instance.currentUser?.photoURL == null
                        ? Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: _teal,
                              fontWeight: FontWeight.bold,
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
                          username,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _tealDark,
                          ),
                        ),
                        if (city != null || countryFlag != null)
                          Row(
                            children: [
                              if (countryFlag != null)
                                Text(
                                  countryFlag,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (countryFlag != null && city != null)
                                const SizedBox(width: 4),
                              if (city != null)
                                Text(
                                  city,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _teal,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (esPropio) {
                        PerfilPostOptionsSheet.show(
                          context,
                          postId: widget.postId,
                          autorId: widget.autorId,
                        );
                      } else {
                        showPostOptions(
                          context: context,
                          postId: widget.postId,
                          postAuthorId: widget.autorId,
                          username: username,
                          onDismissPost: () => Navigator.pop(context),
                        );
                      }
                    },
                    child: const Icon(
                      Icons.more_horiz_rounded,
                      size: 24,
                      color: _tealDark,
                    ),
                  ),
                ],
              ),
            ),

            // ── Carousel de imágenes ───────────────────────────────────────────
            if (images.isNotEmpty)
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  SizedBox(
                    height: 360,
                    child: PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (i) =>
                          setState(() => _currentImageIndex = i),
                      itemBuilder: (_, i) => Image.network(
                        images[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          height: 360,
                          color: _tealBg,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: _tealLight,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Dots indicadores (solo si hay más de 1 imagen)
                  if (images.length > 1)
                    Positioned(
                      bottom: 10,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          images.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentImageIndex == i ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == i
                                  ? _teal
                                  : Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

            // ── Barra de interacciones ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  LikeButton(
                    postId: widget.postId,
                    postAuthorId: widget.autorId,
                  ),
                  const SizedBox(width: 20),
                  StreamBuilder<int>(
                    stream: SocialService.commentsCountStream(widget.postId),
                    builder: (_, snap) {
                      final count = snap.data ?? 0;
                      return GestureDetector(
                        onTap: () => CommentsScreen.show(
                          context,
                          postId: widget.postId,
                          postAuthorId: widget.autorId,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 24,
                              color: _tealDark,
                            ),
                            const SizedBox(width: 5),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                '$count',
                                key: ValueKey(count),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _tealDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => ShareSheet.show(
                      context,
                      postId: widget.postId,
                      username: username,
                    ),
                    child: const Icon(
                      Icons.send_outlined,
                      size: 22,
                      color: _tealDark,
                    ),
                  ),
                  const Spacer(),
                  SaveButton(postId: widget.postId),
                ],
              ),
            ),

            // ── Likes count ────────────────────────────────────────────────────
            if (likesCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  '$likesCount Me gusta',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _tealDark,
                  ),
                ),
              ),

            // ── Caption ────────────────────────────────────────────────────────
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: _tealDark,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: '$username ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: caption),
                    ],
                  ),
                ),
              ),

            // ── Spotify chip ───────────────────────────────────────────────────
            if (spotifyTrackName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1DB954).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (spotifyAlbumArt != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            spotifyAlbumArt,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox(width: 36, height: 36),
                          ),
                        ),
                      if (spotifyAlbumArt != null) const SizedBox(width: 10),
                      const Icon(
                        Icons.music_note_rounded,
                        color: Color(0xFF1DB954),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spotifyTrackName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _tealDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (spotifyArtist != null)
                              Text(
                                spotifyArtist,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Fecha ──────────────────────────────────────────────────────────
            if (_fechaStr().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  _fechaStr(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Divider(color: Color(0xFFE2F0EF), height: 1),
            ),

            // ── Ver comentarios ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: StreamBuilder<int>(
                stream: SocialService.commentsCountStream(widget.postId),
                builder: (_, snap) {
                  final count = snap.data ?? 0;
                  return GestureDetector(
                    onTap: () => CommentsScreen.show(
                      context,
                      postId: widget.postId,
                      postAuthorId: widget.autorId,
                    ),
                    child: Text(
                      count == 0
                          ? 'Sé el primero en comentar'
                          : 'Ver los $count comentarios',
                      style: TextStyle(
                        fontSize: 13,
                        color: count == 0 ? const Color(0xFF94A3B8) : _teal,
                        fontWeight: count == 0
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Campo de comentario ────────────────────────────────────────────
            GestureDetector(
              onTap: () => CommentsScreen.show(
                context,
                postId: widget.postId,
                postAuthorId: widget.autorId,
              ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _tealBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _tealLight.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Agregá un comentario…',
                        style: TextStyle(fontSize: 13, color: _tealLight),
                      ),
                    ),
                    Icon(Icons.send_rounded, size: 18, color: _tealLight),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet de opciones del perfil propio
// ─────────────────────────────────────────────────────────────────────────────

class PerfilPostOptionsSheet {
  static void show(
    BuildContext context, {
    required String postId,
    required String autorId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) =>
          _PerfilPostOptionsContent(postId: postId, autorId: autorId),
    );
  }
}

class _PerfilPostOptionsContent extends StatefulWidget {
  final String postId;
  final String autorId;
  const _PerfilPostOptionsContent({
    required this.postId,
    required this.autorId,
  });
  @override
  State<_PerfilPostOptionsContent> createState() =>
      _PerfilPostOptionsContentState();
}

class _PerfilPostOptionsContentState extends State<_PerfilPostOptionsContent> {
  bool _ocultarLikes = false;
  bool _ocultarCompartidos = false;
  bool _comentariosActivos = true;
  bool _fijado = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();
      if (!mounted) return;
      final d = doc.data() ?? {};
      setState(() {
        _ocultarLikes = d['ocultarLikes'] as bool? ?? false;
        _ocultarCompartidos = d['ocultarCompartidos'] as bool? ?? false;
        _comentariosActivos = d['comentariosActivos'] as bool? ?? true;
        _fijado = d['fijado'] as bool? ?? false;
      });
    } catch (_) {}
  }

  Future<void> _actualizar(Map<String, dynamic> fields) async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update(fields);
    } catch (e) {
      if (mounted) _snack('Error al guardar. Intentá de nuevo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _archivar() async {
    Navigator.pop(context);
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({'archivado': true});
      if (mounted) _snack('Publicación archivada');
    } catch (_) {
      if (mounted) _snack('Error al archivar');
    }
  }

  Future<void> _eliminar() async {
    Navigator.pop(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(context).profileDeletePostTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, color: _tealDark),
        ),
        content: Text(
          AppLocalizations.of(context).profileDeletePostContent,
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: _teal)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .delete();
      if (mounted) _snack('Publicación eliminada');
    } catch (_) {
      if (mounted) _snack('Error al eliminar');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _teal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F2422),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2D5550),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _QuickIconButton(
                    icon: Icons.bookmark_outline_rounded,
                    label: 'Guardar',
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await SocialService.toggleSave(widget.postId);
                        if (mounted) _snack('Guardado');
                      } catch (_) {}
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickIconButton(
                    icon: Icons.qr_code_2_rounded,
                    label: 'Código QR',
                    onTap: () {
                      Navigator.pop(context);
                      _snack('Código QR — próximamente');
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _OptionsGroup(
            children: [
              _OptionRow(
                icon: Icons.archive_outlined,
                label: 'Archivar',
                onTap: _archivar,
              ),
              const _OptionDivider(),
              _OptionRow(
                icon: Icons.favorite_border_rounded,
                label: 'Ocultar recuento de Me gusta',
                trailing: Switch(
                  value: _ocultarLikes,
                  onChanged: (v) {
                    setState(() => _ocultarLikes = v);
                    _actualizar({'ocultarLikes': v});
                  },
                  activeColor: _teal,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onTap: () {
                  final v = !_ocultarLikes;
                  setState(() => _ocultarLikes = v);
                  _actualizar({'ocultarLikes': v});
                },
              ),
              const _OptionDivider(),
              _OptionRow(
                icon: Icons.send_outlined,
                label: 'Ocultar veces que se compartió',
                trailing: Switch(
                  value: _ocultarCompartidos,
                  onChanged: (v) {
                    setState(() => _ocultarCompartidos = v);
                    _actualizar({'ocultarCompartidos': v});
                  },
                  activeColor: _teal,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onTap: () {
                  final v = !_ocultarCompartidos;
                  setState(() => _ocultarCompartidos = v);
                  _actualizar({'ocultarCompartidos': v});
                },
              ),
              const _OptionDivider(),
              _OptionRow(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Desactivar comentarios',
                trailing: Switch(
                  value: !_comentariosActivos,
                  onChanged: (v) {
                    setState(() => _comentariosActivos = !v);
                    _actualizar({'comentariosActivos': !v});
                  },
                  activeColor: _teal,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onTap: () {
                  final v = !_comentariosActivos;
                  setState(() => _comentariosActivos = !v);
                  _actualizar({'comentariosActivos': !v});
                },
              ),
              const _OptionDivider(),
              _OptionRow(
                icon: Icons.edit_outlined,
                label: 'Editar',
                onTap: () {
                  Navigator.pop(context);
                  _snack('Edición de publicación — próximamente');
                },
              ),
              const _OptionDivider(),
              _OptionRow(
                icon: Icons.crop_rounded,
                label: 'Ajustar vista previa',
                onTap: () {
                  Navigator.pop(context);
                  _snack('Ajuste de vista previa — próximamente');
                },
              ),
              const _OptionDivider(),
              _OptionRow(
                icon: _fijado
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                label: _fijado
                    ? 'Desfijar de la cuadrícula'
                    : 'Fijar en la cuadrícula principal',
                trailing: _fijado
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppLocalizations.of(context).pinned,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4DC9C2),
                          ),
                        ),
                      )
                    : null,
                onTap: () {
                  final v = !_fijado;
                  setState(() => _fijado = v);
                  _actualizar({'fijado': v});
                  _snack(v ? 'Fijado en la cuadrícula' : 'Desfijado');
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          _OptionsGroup(
            children: [
              _OptionRow(
                icon: Icons.delete_outline_rounded,
                label: 'Eliminar',
                labelColor: const Color(0xFFF87171),
                iconColor: const Color(0xFFF87171),
                onTap: _eliminar,
              ),
            ],
          ),
          SizedBox(height: bottom + 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabs de eventos y mensajes
// ─────────────────────────────────────────────────────────────────────────────

class _TabEventosFirebase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('authorId', isEqualTo: user.uid)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _teal));
        }
        final docs = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ActionChip(
              icon: Icons.add_rounded,
              label: 'Crear evento',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CrearEventoScreen()),
              ),
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty) ...[
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.event_outlined, size: 48, color: _tealLight),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).profileNoEventsTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        color: _tealDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(context).profileNoEventsSubtitle,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ] else
              ...docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return _EventCard(
                  evento: {
                    'titulo': d['title'] ?? d['titulo'] ?? 'Evento',
                    'fecha': _fmtFecha(d['fecha']),
                    'lugar': d['location'] ?? d['lugar'] ?? '',
                    'emoji': d['tipo'] == 'Cultural'
                        ? '🎭'
                        : d['tipo'] == 'Gastronómico'
                        ? '🍽️'
                        : d['tipo'] == 'Deportivo'
                        ? '⚽'
                        : '🤝',
                    'asistentes': d['attendeesCount'] ?? d['asistentes'] ?? 0,
                  },
                );
              }),
          ],
        );
      },
    );
  }

  String _fmtFecha(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts as dynamic).toDate() as DateTime;
      const m = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class _TabMensajesFirebase extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community_messages')
          .where('authorId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _teal));
        }
        final docs = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ActionChip(
              icon: Icons.campaign_outlined,
              label: 'Nuevo mensaje a la comunidad',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MensajeComunidadScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty) ...[
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.campaign_outlined, size: 48, color: _tealLight),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).profileNoMessagesTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        color: _tealDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(context).profileNoMessagesSubtitle,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ] else
              ...docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return _MensajeCard(
                  mensaje: {
                    'texto': d['mensaje'] ?? d['texto'] ?? '',
                    'fecha': _timeAgo(d['createdAt'] ?? d['timestamp']),
                    'likes': d['likes'] ?? 0,
                    'emoji': _emojiCat(d['categoria'] as String?),
                  },
                );
              }),
          ],
        );
      },
    );
  }

  String _emojiCat(String? cat) {
    const m = {
      'Info': '📢',
      'Urgente': '🚨',
      'Pregunta': '❓',
      'Oferta': '🎁',
      'Alerta': '⚠️',
    };
    return m[cat] ?? '💬';
  }

  String _timeAgo(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts as dynamic).toDate() as DateTime;
      final d = DateTime.now().difference(dt);
      if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
      if (d.inHours < 24) return 'hace ${d.inHours}h';
      if (d.inDays < 7) return 'hace ${d.inDays} días';
      return 'hace ${(d.inDays / 7).floor()} semanas';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets reutilizables internos del perfil
// Nota: _OptionTile NO está aquí — viene del import de post_options_sheet.dart
// ─────────────────────────────────────────────────────────────────────────────

class _StatBubble extends StatelessWidget {
  final String value;
  final String label;
  const _StatBubble({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _tealDark,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}

class _EditButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _EditButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _tealBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _tealLight),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _teal,
          ),
        ),
      ),
    );
  }
}

class _HighlightItem extends StatelessWidget {
  final String title;
  final String? emoji;
  final String? imageUrl;
  final bool isCreate;
  final VoidCallback onTap;

  const _HighlightItem({
    required this.title,
    required this.onTap,
    this.emoji,
    this.imageUrl,
    this.isCreate = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0D9488), width: 2),
              ),
              child: ClipOval(
                child: isCreate
                    ? Container(
                        color: const Color(0xFFF0FAF9),
                        child: const Icon(Icons.add, color: Color(0xFF0D9488)),
                      )
                    : imageUrl != null
                    ? Image.network(imageUrl!, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          emoji ?? "⭐",
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 70,
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _teal,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> evento;
  const _EventCard({required this.evento});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _tealBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                evento['emoji'] as String,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evento['titulo'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _tealDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: _teal,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      evento['fecha'] as String,
                      style: const TextStyle(fontSize: 11, color: _teal),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.location_on_outlined,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      evento['lugar'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${evento['asistentes']} asistentes',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
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

class _MensajeCard extends StatelessWidget {
  final Map<String, dynamic> mensaje;
  const _MensajeCard({required this.mensaje});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                mensaje['emoji'] as String,
                style: const TextStyle(fontSize: 20),
              ),
              const Spacer(),
              Text(
                mensaje['fecha'] as String,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mensaje['texto'] as String,
            style: const TextStyle(
              fontSize: 13.5,
              color: _tealDark,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.favorite_outline_rounded,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                '${mensaje['likes']}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.comment_outlined,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context).profileViewComments,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets internos del sheet de opciones del perfil propio
// (NO son los mismos que _OptionTile/_OptionDivider de post_options_sheet.dart)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A36),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2D5550)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFCCFBF1), size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFCCFBF1),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionsGroup extends StatelessWidget {
  final List<Widget> children;
  const _OptionsGroup({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D5550)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _OptionDivider extends StatelessWidget {
  const _OptionDivider();
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.only(left: 52),
    color: const Color(0xFF2D5550),
  );
}

class _OptionRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _OptionRow({
    required this.icon,
    required this.label,
    this.labelColor,
    this.iconColor,
    this.trailing,
    required this.onTap,
  });
  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _pressed
            ? const Color(0xFF0D9488).withOpacity(0.1)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (widget.iconColor ?? const Color(0xFF4DC9C2))
                    .withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 18,
                color: widget.iconColor ?? const Color(0xFF4DC9C2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.labelColor ?? const Color(0xFFCCFBF1),
                ),
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 8),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheets de foto, portada y configuración
// ─────────────────────────────────────────────────────────────────────────────

class _FotoOptionsSheet extends StatelessWidget {
  final User? user;
  const _FotoOptionsSheet({this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          if (user?.photoURL != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(user!.photoURL!),
              ),
            ),
          // Usamos ListTile directo aquí — sin depender de _OptionTile externo
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: _teal),
            title: Text(
              AppLocalizations.of(context).takePhoto,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _tealDark,
              ),
            ),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: _teal),
            title: Text(
              AppLocalizations.of(context).chooseFromGallery,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _tealDark,
              ),
            ),
            onTap: () => Navigator.pop(context),
          ),
          if (user?.photoURL != null)
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
              ),
              title: Text(
                AppLocalizations.of(context).deleteCurrentPhoto,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}

class _PortadaOptionsSheet extends StatelessWidget {
  const _PortadaOptionsSheet();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).profileEditCover,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _tealDark,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: _teal),
            title: Text(
              AppLocalizations.of(context).takePhoto,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _tealDark,
              ),
            ),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: _teal),
            title: Text(
              AppLocalizations.of(context).chooseFromGallery,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _tealDark,
              ),
            ),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _ConfiguracionSheet extends StatelessWidget {
  const _ConfiguracionSheet();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.settings,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _tealDark,
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  _SettingGroup(l10n.settingsAccount, [
                    _SettingItem(
                      Icons.notifications_outlined,
                      l10n.settingsNotifications,
                      onTap: () {},
                    ),
                    _SettingItem(
                      Icons.vpn_key_outlined,
                      l10n.settingsPassword,
                      onTap: () {},
                    ),
                    _SettingItem(
                      Icons.language_outlined,
                      l10n.settingsLanguage,
                      onTap: () => showLanguagePicker(context),
                    ),
                    _SettingItem(
                      Icons.devices_outlined,
                      l10n.settingsActiveDevices,
                      onTap: () {},
                    ),
                  ]),
                  _SettingGroup(l10n.settingsPrivacy, [
                    _SettingItem(
                      Icons.lock_outline_rounded,
                      l10n.settingsAccountPrivacy,
                      onTap: () {},
                    ),
                    _SettingItem(
                      Icons.block_outlined,
                      l10n.settingsBlockedUsers,
                      onTap: () {},
                    ),
                  ]),
                  _SettingGroup(l10n.settingsSupport, [
                    _SettingItem(
                      Icons.help_outline_rounded,
                      l10n.settingsHelpCenter,
                      onTap: () {},
                    ),
                    _SettingItem(
                      Icons.info_outline_rounded,
                      l10n.settingsAbout,
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: TextButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (_) => false);
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.red),
                      label: Text(
                        l10n.logout,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingGroup extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _SettingGroup(this.title, this.items);
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _teal,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingItem(this.icon, this.label, {required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _tealDark, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _tealDark,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: Color(0xFFCBD5E1),
      ),
      onTap: onTap,
    );
  }
}

class _BioExpandable extends StatefulWidget {
  final String text;
  const _BioExpandable({required this.text});
  @override
  State<_BioExpandable> createState() => _BioExpandableState();
}

class _BioExpandableState extends State<_BioExpandable> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 13.5,
      color: Color(0xFF4B7B78),
      height: 1.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: style,
          maxLines: expanded ? null : 3,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (widget.text.length > 120)
          GestureDetector(
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                expanded ? AppLocalizations.of(context).seeLess : AppLocalizations.of(context).seeMore,
                style: const TextStyle(
                  fontSize: 12,
                  color: _teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class HighlightStoriesScreen extends StatelessWidget {
  final String highlightId;
  const HighlightStoriesScreen({required this.highlightId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('stories')
            .where('highlightId', isEqualTo: highlightId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stories = snapshot.data!.docs;
          return PageView.builder(
            itemCount: stories.length,
            itemBuilder: (_, i) {
              final story = stories[i];
              return Image.network(story['mediaUrl'], fit: BoxFit.cover);
            },
          );
        },
      ),
    );
  }
}

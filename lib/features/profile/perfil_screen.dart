import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../feed/widgets/bottom_nav.dart';
import 'edit_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// perfil_screen.dart  –  Nomad App
// Pantalla de perfil propio, estilo Instagram, orientada a migrantes.
// ─────────────────────────────────────────────────────────────────────────────

// Paleta
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

  // ── Datos desde Firestore ─────────────────────────────────────────────────
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
    _tabController = TabController(length: 4, vsync: this)
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

    // Obtener estadísticas
    int seguidoresTemp = 0;
    int siguiendoTemp = 0;
    int publicacionesTemp = 0;
    try {
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('followers')
          .get();
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('following')
          .get();
      final postsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('publicaciones')
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

      if (highlightsSnapshot.docs.isEmpty) {
        final defaults = [
          {"title": "Llegada", "emoji": "✈️"},
          {"title": "Trabajo", "emoji": "💼"},
          {"title": "Trámites", "emoji": "📄"},
          {"title": "Vida diaria", "emoji": "🏡"},
          {"title": "Comunidad", "emoji": "🤝"},
        ];

        for (int i = 0; i < defaults.length; i++) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('highlights')
              .add({
                "title": defaults[i]["title"],
                "emoji": defaults[i]["emoji"],
                "coverUrl": null,
                "order": i,
              });
        }

        return _cargarDatosUsuario();
      }

      _highlights = highlightsSnapshot.docs.map((d) {
        final data = d.data();

        return {
          "id": d.id,

          "title": data["title"] ?? "Highlight",

          "emoji": data["emoji"] ?? "📍",

          "coverUrl": data["coverUrl"],
        };
      }).toList();
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
    // Usamos datos de Firestore si ya cargaron, sino fallback a FirebaseAuth
    final String nombre = _datosLoaded
        ? _nombre
        : (user?.displayName ?? user?.email?.split('@')[0] ?? 'Usuario');
    final String username = _datosLoaded
        ? _username
        : nombre.toLowerCase().replaceAll(' ', '_');

    return Scaffold(
      backgroundColor: _bgMain,
      body: NestedScrollView(
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
                  _TabPublicaciones(),
                  _TabEventos(),
                  _TabMensajes(),
                  _TabActividad(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  // ── Sliver App Bar con toda la info del perfil ────────────────────────────

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

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = [
      (Icons.grid_on_rounded, 'Posts'),
      (Icons.event_outlined, 'Eventos'),
      (Icons.campaign_outlined, 'Mensajes'),
      (Icons.timeline_rounded, 'Actividad'),
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

  // ── Modales ───────────────────────────────────────────────────────────────

  void _showEditarPerfil(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    ).then((_) {
      // Recargar datos al volver de editar
      _cargarDatosUsuario();
    });
  }

  void _showFotoOptions(BuildContext context, User? user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FotoOptionsSheet(user: user),
    );
  }

  // MODIFICACIÓN: Nueva función para mostrar las opciones de portada
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('highlights')
        .add({
          "title": "Nuevo",
          "emoji": "📍",
          "coverUrl": null,
          "order": DateTime.now().millisecondsSinceEpoch,
        });

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
          // Cover + Avatar
          _buildCoverAndAvatar(context, onEditarPortada),
          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre + botón editar
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
                    _EditButton(label: 'Editar perfil', onTap: onEditarPerfil),
                  ],
                ),

                const SizedBox(height: 10),

                // Bio (dinámica desde Firestore)
                if (bio.isNotEmpty) _BioExpandable(text: bio),

                const SizedBox(height: 14),

                // Lugares vividos
                _buildLugaresVividos(),

                const SizedBox(height: 18),
              ],
            ),
          ),

          // Historias + destacadas
          _buildHighlights(context),

          const SizedBox(height: 8),

          // Divisor
          Container(height: 0.5, color: const Color(0xFFE2F0EF)),
        ],
      ),
    );
  }

  // MODIFICACIÓN: Acepta onEditarPortada como argumento
  Widget _buildCoverAndAvatar(
    BuildContext context,
    VoidCallback onEditarPortada,
  ) {
    return Container(
      // Definimos una altura fija para el contenedor padre para evitar el error de 'infinite height'
      height: 210,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. PORTADA
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
                // Gradiente oscuro para que resalte el botón de editar
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

          // 2. BOTÓN EDITAR PORTADA
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
                  child: const Row(
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Editar portada',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. AVATAR Y BOTÓN "+"
          Positioned(
            top: 115,
            left: 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Círculo de la foto
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

                // BOTÓN "+" (Corregido con Material e InkWell para asegurar el click)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Material(
                    color: _teal,
                    shape: const CircleBorder(),
                    elevation: 4,
                    clipBehavior: Clip
                        .antiAlias, // Asegura que el efecto splash sea circular
                    child: InkWell(
                      onTap: () {
                        debugPrint("Botón + presionado");
                        onFoto();
                      },
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

          // 4. ESTADÍSTICAS - a la derecha del avatar, centradas verticalmente
          Positioned(
            top: 170,
            left: 150, // avatar left(20) + diámetro aprox(90)
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
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

  Widget _buildStats() {
    return Row(
      children: [
        _StatBubble(value: '42', label: 'Posts'),
        const SizedBox(width: 24),
        _StatBubble(value: '1.2k', label: 'Seguidores'),
        const SizedBox(width: 24),
        _StatBubble(value: '380', label: 'Siguiendo'),
        const SizedBox(width: 24),
        _StatBubble(value: '3', label: 'Países'),
      ],
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
              // Ciudades dinámicas desde Firestore
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

                if (id != null) {
                  onAbrirHighlight(context, id);
                }
              },
            ),
          ),
        ],
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
                          emoji ?? "📍",
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
    final style = const TextStyle(
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
                expanded ? "ver menos" : "ver más",
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

// ─────────────────────────────────────────────────────────────────────────────
// Tabs de contenido
// ─────────────────────────────────────────────────────────────────────────────

class _TabPublicaciones extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 15,
      itemBuilder: (context, i) {
        final colors = [
          0xFF0D9488,
          0xFF0891B2,
          0xFF7C3AED,
          0xFF059669,
          0xFFD97706,
        ];
        return Container(
          color: Color(
            colors[i % colors.length],
          ).withOpacity(0.15 + (i % 4) * 0.1),
          child: Center(
            child: Icon(
              [
                Icons.image_outlined,
                Icons.videocam_outlined,
                Icons.mic_outlined,
              ][i % 3],
              color: Color(colors[i % colors.length]),
              size: 28,
            ),
          ),
        );
      },
    );
  }
}

class _TabEventos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final eventos = [
      {
        'titulo': 'Encuentro de migrantes latinoamericanos',
        'fecha': '15 Abr 2025',
        'lugar': 'Ciudad de México',
        'emoji': '🎉',
        'asistentes': 34,
      },
      {
        'titulo': 'Taller: Cómo abrir cuenta bancaria en el extranjero',
        'fecha': '22 Abr 2025',
        'lugar': 'Online',
        'emoji': '💳',
        'asistentes': 120,
      },
      {
        'titulo': 'Cena de integración – comunidad Nomad',
        'fecha': '1 May 2025',
        'lugar': 'Barcelona',
        'emoji': '🍽️',
        'asistentes': 18,
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ActionChip(
          icon: Icons.add_rounded,
          label: 'Crear evento',
          onTap: () {},
        ),
        const SizedBox(height: 16),
        ...eventos.map((e) => _EventCard(evento: e)),
      ],
    );
  }
}

class _TabMensajes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mensajes = [
      {
        'texto':
            '¿Cómo tramitar el NIE en España sin morir en el intento? Acá va mi guía completa 🇪🇸',
        'fecha': 'hace 2 días',
        'likes': 87,
        'emoji': '📋',
      },
      {
        'texto':
            'El primer mes en un país nuevo es el más difícil, pero también el más transformador. ¿Lo sentiste así? 💬',
        'fecha': 'hace 1 semana',
        'likes': 213,
        'emoji': '✈️',
      },
      {
        'texto':
            'Buscando compañía para explorar el Zócalo este domingo. ¡Nomads bienvenidos! 🗺️',
        'fecha': 'hace 2 semanas',
        'likes': 45,
        'emoji': '🗺️',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ActionChip(
          icon: Icons.campaign_outlined,
          label: 'Nuevo mensaje a la comunidad',
          onTap: () {},
        ),
        const SizedBox(height: 16),
        ...mensajes.map((m) => _MensajeCard(mensaje: m)),
      ],
    );
  }
}

class _TabActividad extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actividades = [
      {
        'texto': 'Carlos M. comenzó a seguirte',
        'tiempo': 'hace 5 min',
        'icon': Icons.person_add_outlined,
        'color': 0xFF0D9488,
      },
      {
        'texto': 'Tu post recibió 12 nuevos likes',
        'tiempo': 'hace 1h',
        'icon': Icons.favorite_outline_rounded,
        'color': 0xFFE11D48,
      },
      {
        'texto': 'Lucía comentó en tu evento',
        'tiempo': 'hace 3h',
        'icon': Icons.comment_outlined,
        'color': 0xFF0891B2,
      },
      {
        'texto': 'Tu historia fue vista por 84 personas',
        'tiempo': 'hace 6h',
        'icon': Icons.remove_red_eye_outlined,
        'color': 0xFF7C3AED,
      },
      {
        'texto': 'Nomad te mencionó en un post',
        'tiempo': 'ayer',
        'icon': Icons.alternate_email_rounded,
        'color': 0xFFD97706,
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: actividades.map((a) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(a['color'] as int).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  a['icon'] as IconData,
                  color: Color(a['color'] as int),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a['texto'] as String,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: _tealDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a['tiempo'] as String,
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
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets reutilizables
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
        child: const Text(
          'Editar perfil',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _teal,
          ),
        ),
      ),
    );
  }
}

class _HistoriaItem extends StatelessWidget {
  final String label;
  final int color;
  final IconData icon;
  final VoidCallback onTap;
  final bool isNew;

  const _HistoriaItem({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isNew = false,
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
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isNew
                    ? null
                    : LinearGradient(
                        colors: [Color(color), Color(color).withOpacity(0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: isNew ? _tealBg : null,
                border: Border.all(
                  color: isNew ? _tealLight : Color(color).withOpacity(0.3),
                  width: isNew ? 1.5 : 2.5,
                ),
              ),
              child: Icon(icon, color: isNew ? _teal : Colors.white, size: 26),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: _tealDark,
                fontWeight: FontWeight.w500,
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
              const Text(
                'Ver comentarios',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheets (modales)
// ─────────────────────────────────────────────────────────────────────────────

class _EditarPerfilSheet extends StatelessWidget {
  const _EditarPerfilSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
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
            const Text(
              'Editar perfil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _tealDark,
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _SectionLabel('Información personal'),
                  _InputField(label: 'Nombre completo', hint: 'Tu nombre'),
                  _InputField(label: 'Username', hint: '@usuario', prefix: '@'),
                  _InputField(
                    label: 'Bio',
                    hint: 'Cuéntale al mundo quién sos...',
                    maxLines: 3,
                  ),
                  _InputField(label: 'Sitio web', hint: 'https://'),
                  const SizedBox(height: 8),
                  _SectionLabel('Tu ruta migrante'),
                  const Text(
                    'Contá los lugares donde viviste. Esto ayuda a conectarte con personas con recorridos similares.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Lugares
                  ...[
                    {
                      'ciudad': 'Buenos Aires',
                      'emoji': '🇦🇷',
                      'años': '1995–2018',
                    },
                    {
                      'ciudad': 'Barcelona',
                      'emoji': '🇪🇸',
                      'años': '2018–2021',
                    },
                    {
                      'ciudad': 'México DF',
                      'emoji': '🇲🇽',
                      'años': '2021–hoy',
                    },
                  ].map(
                    (l) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _tealBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _tealLight.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            l['emoji']!,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l['ciudad']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _tealDark,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  l['años']!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.drag_handle_rounded,
                            color: Color(0xFFCBD5E1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _tealLight, width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: _teal, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Agregar lugar',
                            style: TextStyle(
                              color: _teal,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionLabel('Privacidad'),
                  _SwitchTile(
                    label: 'Cuenta privada',
                    subtitle: 'Solo seguidores aprobados ven tu contenido',
                    value: false,
                    onChanged: (_) {},
                  ),
                  _SwitchTile(
                    label: 'Mostrar mi ruta en el mapa',
                    subtitle: 'Visible para la comunidad Nomad',
                    value: true,
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Guardar cambios',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          _OptionTile(
            icon: Icons.camera_alt_rounded,
            label: 'Tomar foto',
            onTap: () => Navigator.pop(context),
          ),
          _OptionTile(
            icon: Icons.photo_library_rounded,
            label: 'Elegir de galería',
            onTap: () => Navigator.pop(context),
          ),
          if (user?.photoURL != null)
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Eliminar foto actual',
              color: Colors.red,
              onTap: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}

// MODIFICACIÓN: Nuevo modal específico para las opciones de portada
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
          const Text(
            'Editar portada',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _tealDark,
            ),
          ),
          const SizedBox(height: 12),
          _OptionTile(
            icon: Icons.camera_alt_rounded,
            label: 'Tomar foto',
            onTap: () => Navigator.pop(context),
          ),
          _OptionTile(
            icon: Icons.photo_library_rounded,
            label: 'Elegir de galería',
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
            const Text(
              'Configuración',
              style: TextStyle(
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
                  _SettingGroup('Cuenta', [
                    _SettingItem(
                      Icons.notifications_outlined,
                      'Notificaciones',
                      onTap: () {},
                    ),
                    _SettingItem(
                      Icons.vpn_key_outlined,
                      'Contraseña',
                      onTap: () {},
                    ),
                    _SettingItem(
                      Icons.language_outlined,
                      'Idioma',
                      onTap: () {},
                    ),
                    _SettingItem(
                      Icons.devices_outlined,
                      'Dispositivos activos',
                      onTap: () {},
                    ),
                  ]),
                  _SettingGroup('Privacidad', [
                    _SettingItem(
                      Icons.lock_outline_rounded,
                      'Privacidad de la cuenta',
                      onTap: () {},
                    ),
                    _SettingItem(
                      Icons.block_outlined,
                      'Usuarios bloqueados',
                      onTap: () {},
                    ),
                  ]),
                  _SettingGroup('Soporte', [
                    _SettingItem(
                      Icons.help_outline_rounded,
                      'Centro de ayuda',
                      onTap: () {},
                    ),
                    _SettingItem(
                      Icons.info_outline_rounded,
                      'Acerca de Nomad',
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
                      label: const Text(
                        'Cerrar sesión',
                        style: TextStyle(
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de UI
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _teal,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final String hint;
  final String? prefix;
  final int maxLines;
  const _InputField({
    required this.label,
    required this.hint,
    this.prefix,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _teal,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              prefixText: prefix,
              hintStyle: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 14,
              ),
              filled: true,
              fillColor: _tealBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _teal, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatefulWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SwitchTile> createState() => _SwitchTileState();
}

class _SwitchTileState extends State<_SwitchTile> {
  late bool _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _tealDark,
                  ),
                ),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _val,
            onChanged: (v) {
              setState(() => _val = v);
              widget.onChanged(v);
            },
            activeColor: _teal,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = _teal,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color == Colors.red ? Colors.red : _tealDark,
        ),
      ),
      onTap: onTap,
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

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// visitor_profile_screen.dart  –  Nomad App
// Pantalla de perfil visto por OTRO usuario (no el propio).
//
// Navegación:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => VisitorProfileScreen(targetUserId: 'uid_del_otro'),
//   ));
// ─────────────────────────────────────────────────────────────────────────────

// Paleta (igual que perfil_screen.dart para consistencia)
const _teal = Color(0xFF0D9488);
const _tealLight = Color(0xFF5EEAD4);
const _tealDark = Color(0xFF134E4A);
const _tealBg = Color(0xFFF0FAF9);
const _bgMain = Color(0xFFF8FFFE);

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────────────────────

class VisitorProfileScreen extends StatefulWidget {
  /// UID de Firestore del usuario cuyo perfil se está visitando.
  final String targetUserId;

  const VisitorProfileScreen({super.key, required this.targetUserId});

  @override
  State<VisitorProfileScreen> createState() => _VisitorProfileScreenState();
}

class _VisitorProfileScreenState extends State<VisitorProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Datos del perfil visitado
  String _nombre = '';
  String _username = '';
  String _bio = '';
  String? _photoURL;
  String? _coverURL;
  List<Map<String, String>> _lugaresVividos = [];
  List<String> _areasAyuda = [];
  int _seguidoresCount = 0;
  int _siguiendoCount = 0;
  int _publicacionesCount = 0;

  // Estado de relación con el visitante
  bool _esSeguido = false;
  bool _loadingFollow = false;
  bool _datosLoaded = false;

  // Contexto dinámico (por qué este perfil es relevante para el visitante)
  String? _bannerContexto;

  // Contactos en común
  List<Map<String, String>> _contactosComun = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Carga de datos ──────────────────────────────────────────────────────────

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarPerfilVisitado(),
      _cargarEstadoSeguimiento(),
      _cargarContactosComun(),
    ]);
    await _calcularContexto();
    if (mounted) setState(() => _datosLoaded = true);
  }

  Future<void> _cargarPerfilVisitado() async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(widget.targetUserId)
          .get();
      final data = doc.data();
      if (data == null) return;

      final ciudadesRaw = data['ciudadesVividas'];
      final List<Map<String, String>> ciudades = ciudadesRaw is List
          ? ciudadesRaw.map((e) => Map<String, String>.from(e as Map)).toList()
          : [];

      final areasRaw = data['areasAyuda'];
      final List<String> areas = areasRaw is List
          ? List<String>.from(areasRaw)
          : [];

      final followersSnap = await _firestore
          .collection('users')
          .doc(widget.targetUserId)
          .collection('followers')
          .get();
      final followingSnap = await _firestore
          .collection('users')
          .doc(widget.targetUserId)
          .collection('following')
          .get();
      final postsSnap = await _firestore
          .collection('users')
          .doc(widget.targetUserId)
          .collection('publicaciones')
          .get();

      if (!mounted) return;
      setState(() {
        _nombre = data['displayName'] ?? 'Usuario';
        _username = data['username'] ?? '';
        _bio = data['bio'] ?? '';
        _photoURL = data['photoURL'] as String?;
        _coverURL = data['coverURL'] as String?;
        _lugaresVividos = ciudades;
        _areasAyuda = areas;
        _seguidoresCount = followersSnap.size;
        _siguiendoCount = followingSnap.size;
        _publicacionesCount = postsSnap.size;
      });
    } catch (e) {
      debugPrint('Error cargando perfil visitado: $e');
    }
  }

  Future<void> _cargarEstadoSeguimiento() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(widget.targetUserId)
          .collection('followers')
          .doc(myUid)
          .get();
      if (mounted) setState(() => _esSeguido = doc.exists);
    } catch (e) {
      debugPrint('Error cargando seguimiento: $e');
    }
  }

  Future<void> _cargarContactosComun() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    try {
      // IDs que yo sigo
      final myFollowingSnap = await _firestore
          .collection('users')
          .doc(myUid)
          .collection('following')
          .get();
      final myFollowingIds = myFollowingSnap.docs.map((d) => d.id).toSet();

      // Seguidores del perfil visitado
      final theirFollowersSnap = await _firestore
          .collection('users')
          .doc(widget.targetUserId)
          .collection('followers')
          .get();
      final theirFollowerIds = theirFollowersSnap.docs.map((d) => d.id).toSet();

      // Intersección: personas que yo sigo y que también siguen al visitado
      final comunIds = myFollowingIds.intersection(theirFollowerIds).take(5);

      final List<Map<String, String>> comun = [];
      for (final uid in comunIds) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        final data = userDoc.data();
        if (data != null) {
          comun.add({
            'uid': uid,
            'nombre': data['displayName'] as String? ?? 'Usuario',
            'username': data['username'] as String? ?? '',
            'photoURL': data['photoURL'] as String? ?? '',
          });
        }
      }
      if (mounted) setState(() => _contactosComun = comun);
    } catch (e) {
      debugPrint('Error cargando contactos en común: $e');
    }
  }

  /// Genera el banner de contexto personalizado comparando la ruta del
  /// visitante con la del perfil visitado.
  Future<void> _calcularContexto() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    try {
      final myDoc = await _firestore.collection('users').doc(myUid).get();
      final myData = myDoc.data();
      if (myData == null) return;

      final myCiudadesRaw = myData['ciudadesVividas'];
      final List<Map<String, String>> misCiudades = myCiudadesRaw is List
          ? myCiudadesRaw
                .map((e) => Map<String, String>.from(e as Map))
                .toList()
          : [];

      if (misCiudades.isEmpty || _lugaresVividos.isEmpty) return;

      final misCiudadNombres = misCiudades
          .map((c) => c['ciudad']?.toLowerCase() ?? '')
          .toSet();
      final susCiudadNombres = _lugaresVividos
          .map((c) => c['ciudad']?.toLowerCase() ?? '')
          .toSet();

      // Ciudad actual del visitado (última de su lista)
      final suCiudadActual = _lugaresVividos.last;
      // Mi ciudad actual
      final miCiudadActual = misCiudades.last;

      // Ciudades que él vivió y yo también
      final enComun = susCiudadNombres.intersection(misCiudadNombres);

      String? contexto;

      // Caso 1: está donde yo quiero ir (su ciudad actual coincide con alguna mía futura)
      // Simplificación: si su ciudad actual no está en mis ciudades = posible destino
      if (!misCiudadNombres.contains(suCiudadActual['ciudad']?.toLowerCase())) {
        final ciudadesEnComun = enComun.isNotEmpty
            ? 'Pasó por ${_capitalized(enComun.first)} como vos'
            : null;
        final destino =
            'Está en ${suCiudadActual['ciudad']} donde podrías migrar';
        contexto = ciudadesEnComun != null
            ? '$ciudadesEnComun · $destino'
            : destino;
      }
      // Caso 2: vivió donde yo vivo ahora (mismo origen)
      else if (enComun.isNotEmpty &&
          suCiudadActual['ciudad']?.toLowerCase() !=
              miCiudadActual['ciudad']?.toLowerCase()) {
        contexto =
            'Vivió en ${_capitalized(enComun.first)} como vos · Ahora en ${suCiudadActual['ciudad']}';
      }
      // Caso 3: están en la misma ciudad ahora
      else if (suCiudadActual['ciudad']?.toLowerCase() ==
          miCiudadActual['ciudad']?.toLowerCase()) {
        contexto = 'Estás en la misma ciudad · ${suCiudadActual['ciudad']}';
      }

      if (mounted) setState(() => _bannerContexto = contexto);
    } catch (e) {
      debugPrint('Error calculando contexto: $e');
    }
  }

  String _capitalized(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Acción seguir / dejar de seguir ────────────────────────────────────────

  Future<void> _toggleSeguir() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    if (_loadingFollow) return;

    setState(() => _loadingFollow = true);
    try {
      final followersRef = _firestore
          .collection('users')
          .doc(widget.targetUserId)
          .collection('followers')
          .doc(myUid);
      final followingRef = _firestore
          .collection('users')
          .doc(myUid)
          .collection('following')
          .doc(widget.targetUserId);

      if (_esSeguido) {
        await followersRef.delete();
        await followingRef.delete();
        setState(() {
          _esSeguido = false;
          _seguidoresCount = (_seguidoresCount - 1).clamp(0, 999999);
        });
      } else {
        final myDoc = await _firestore.collection('users').doc(myUid).get();
        final myData = myDoc.data() ?? {};
        await followersRef.set({
          'uid': myUid,
          'nombre': myData['displayName'] ?? '',
          'username': myData['username'] ?? '',
          'photoURL': myData['photoURL'] ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        });
        await followingRef.set({
          'uid': widget.targetUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        setState(() {
          _esSeguido = true;
          _seguidoresCount = _seguidoresCount + 1;
        });
      }
    } catch (e) {
      debugPrint('Error al seguir/dejar de seguir: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar seguimiento')),
      );
    } finally {
      if (mounted) setState(() => _loadingFollow = false);
    }
  }

  // ── Abrir chat directo ──────────────────────────────────────────────────────

  void _abrirMensaje() {
    // TODO: navegar a la pantalla de chat pasando targetUserId
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo chat con @$_username...'),
        backgroundColor: _teal,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgMain,
      body: _datosLoaded
          ? _buildBody()
          : const Center(child: CircularProgressIndicator(color: _teal)),
    );
  }

  Widget _buildBody() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        _buildSliverHeader(innerBoxIsScrolled),
      ],
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TabPostsVisitor(targetUserId: widget.targetUserId),
                _TabRutaDetalle(lugaresVividos: _lugaresVividos),
                _TabAreasAyuda(
                  areas: _areasAyuda,
                  username: _username,
                  onPreguntar: _abrirMensaje,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliver header ───────────────────────────────────────────────────────────

  SliverAppBar _buildSliverHeader(bool innerBoxIsScrolled) {
    return SliverAppBar(
      expandedHeight: _bannerContexto != null ? 530 : 500,
      pinned: true,
      backgroundColor: _bgMain,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: _tealDark),
        onPressed: () => Navigator.pop(context),
      ),
      title: AnimatedOpacity(
        opacity: innerBoxIsScrolled ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          '@$_username',
          style: const TextStyle(
            color: _tealDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded, color: _tealDark),
          onPressed: _showMoreOptions,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _VisitorHeader(
          nombre: _nombre,
          username: _username,
          bio: _bio,
          photoURL: _photoURL,
          coverURL: _coverURL,
          lugaresVividos: _lugaresVividos,
          areasAyuda: _areasAyuda,
          seguidoresCount: _seguidoresCount,
          siguiendoCount: _siguiendoCount,
          publicacionesCount: _publicacionesCount,
          esSeguido: _esSeguido,
          loadingFollow: _loadingFollow,
          bannerContexto: _bannerContexto,
          contactosComun: _contactosComun,
          onSeguir: _toggleSeguir,
          onMensaje: _abrirMensaje,
        ),
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = [
      (Icons.grid_on_rounded, 'Posts'),
      (Icons.flight_rounded, 'Ruta'),
      (Icons.lightbulb_outline_rounded, 'Puede ayudar'),
    ];
    return Container(
      color: Colors.white,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _tabController.index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(i);
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _teal : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[i].$1,
                      size: 16,
                      color: selected ? _teal : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tabs[i].$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: selected ? _teal : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Opciones adicionales ────────────────────────────────────────────────────

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _BottomSheetOption(
              icon: Icons.block_rounded,
              label: 'Bloquear usuario',
              color: Colors.redAccent,
              onTap: () => Navigator.pop(context),
            ),
            _BottomSheetOption(
              icon: Icons.flag_outlined,
              label: 'Reportar perfil',
              color: Colors.redAccent,
              onTap: () => Navigator.pop(context),
            ),
            _BottomSheetOption(
              icon: Icons.share_outlined,
              label: 'Compartir perfil',
              color: _tealDark,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VisitorHeader: toda la sección superior del perfil visitado
// ─────────────────────────────────────────────────────────────────────────────

class _VisitorHeader extends StatelessWidget {
  final String nombre;
  final String username;
  final String bio;
  final String? photoURL;
  final String? coverURL;
  final List<Map<String, String>> lugaresVividos;
  final List<String> areasAyuda;
  final int seguidoresCount;
  final int siguiendoCount;
  final int publicacionesCount;
  final bool esSeguido;
  final bool loadingFollow;
  final String? bannerContexto;
  final List<Map<String, String>> contactosComun;
  final VoidCallback onSeguir;
  final VoidCallback onMensaje;

  const _VisitorHeader({
    required this.nombre,
    required this.username,
    required this.bio,
    required this.photoURL,
    required this.coverURL,
    required this.lugaresVividos,
    required this.areasAyuda,
    required this.seguidoresCount,
    required this.siguiendoCount,
    required this.publicacionesCount,
    required this.esSeguido,
    required this.loadingFollow,
    required this.bannerContexto,
    required this.contactosComun,
    required this.onSeguir,
    required this.onMensaje,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de contexto dinámico (¿por qué este perfil te es relevante?)
          if (bannerContexto != null) _buildContextBanner(),

          // Cover + avatar + stats
          _buildCoverAndAvatar(),

          // Nombre, handle, bio
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
                  style: const TextStyle(fontSize: 13, color: _teal),
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    bio,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Botones Seguir / Mensaje
          _buildActionButtons(),

          // Ruta migrante
          if (lugaresVividos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _buildRutaMigrante(),
            ),

          // Puede ayudarte con
          if (areasAyuda.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _buildAreasAyuda(),
            ),

          // Contactos en común
          if (contactosComun.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _buildContactosComun(),
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Banner de contexto ──────────────────────────────────────────────────────

  Widget _buildContextBanner() {
    return Container(
      width: double.infinity,
      color: _tealBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 15, color: _teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bannerContexto!,
              style: const TextStyle(
                fontSize: 12,
                color: _tealDark,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cover + avatar + stats ──────────────────────────────────────────────────

  Widget _buildCoverAndAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover
        Container(
          height: 160,
          width: double.infinity,
          color: _tealDark,
          child: coverURL != null
              ? Image.network(coverURL!, fit: BoxFit.cover)
              : CustomPaint(painter: _GridPatternPainter()),
        ),

        // Avatar
        Positioned(
          top: 115,
          left: 16,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: _tealLight,
              backgroundImage: photoURL != null
                  ? NetworkImage(photoURL!)
                  : null,
              child: photoURL == null
                  ? Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
        ),

        // Stats inline (a la derecha del avatar)
        Positioned(
          top: 168,
          left: 115,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatBubble(
                value: _formatCount(seguidoresCount),
                label: 'Seguidores',
              ),
              _StatBubble(
                value: _formatCount(siguiendoCount),
                label: 'Siguiendo',
              ),
              _StatBubble(
                value: _formatCount(publicacionesCount),
                label: 'Posts',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Botones de acción ───────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onSeguir,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: esSeguido ? _tealBg : _teal,
                  borderRadius: BorderRadius.circular(24),
                  border: esSeguido ? Border.all(color: _tealLight) : null,
                ),
                child: Center(
                  child: loadingFollow
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: esSeguido ? _teal : Colors.white,
                          ),
                        )
                      : Text(
                          esSeguido ? 'Siguiendo ✓' : '+ Seguir',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: esSeguido ? _teal : Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onMensaje,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _tealBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _tealLight),
                ),
                child: const Center(
                  child: Text(
                    '✉ Mensaje',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _teal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ruta migrante ───────────────────────────────────────────────────────────

  Widget _buildRutaMigrante() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.flight_rounded, size: 14, color: _teal),
            SizedBox(width: 6),
            Text(
              'Ruta migrante',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _teal,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...lugaresVividos.asMap().entries.map((entry) {
                final i = entry.key;
                final lugar = entry.value;
                final esActual = i == lugaresVividos.length - 1;
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: esActual ? _teal : _tealBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: esActual ? _teal : _tealLight.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${lugar['emoji'] ?? '🌍'} ${lugar['ciudad']}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: esActual ? Colors.white : _tealDark,
                            ),
                          ),
                          if ((lugar['años'] ?? '').isNotEmpty)
                            Text(
                              esActual
                                  ? '${lugar['años']} · hoy'
                                  : lugar['años']!,
                              style: TextStyle(
                                fontSize: 10,
                                color: esActual ? Colors.white70 : _teal,
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
            ],
          ),
        ),
      ],
    );
  }

  // ── Áreas de ayuda ──────────────────────────────────────────────────────────

  Widget _buildAreasAyuda() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 14, color: _teal),
            SizedBox(width: 6),
            Text(
              'Puede ayudarte con',
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
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...areasAyuda.map(
              (area) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _tealBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _tealLight.withOpacity(0.6)),
                ),
                child: Text(
                  area,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _tealDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Botón Preguntarle
            GestureDetector(
              onTap: onMensaje,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _teal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Preguntarle →',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Contactos en común ──────────────────────────────────────────────────────

  Widget _buildContactosComun() {
    final nombres = contactosComun.map((c) => c['nombre'] ?? '').toList();
    String texto;
    if (nombres.length == 1) {
      texto = 'Seguido por ${nombres[0]}';
    } else if (nombres.length == 2) {
      texto = 'Seguido por ${nombres[0]} y ${nombres[1]}';
    } else {
      texto =
          'Seguido por ${nombres[0]}, ${nombres[1]} y ${nombres.length - 2} más que conocés';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.people_outline_rounded, size: 14, color: _teal),
            SizedBox(width: 6),
            Text(
              'Contactos en común',
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
        Row(
          children: [
            // Avatares apilados
            SizedBox(
              width: 16.0 + (contactosComun.length - 1) * 18.0,
              height: 28,
              child: Stack(
                children: contactosComun.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  final initials = (c['nombre'] ?? 'U').isNotEmpty
                      ? (c['nombre']!)[0].toUpperCase()
                      : 'U';
                  return Positioned(
                    left: i * 18.0,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: [
                        _teal,
                        const Color(0xFF7C3AED),
                        const Color(0xFFD97706),
                        _tealDark,
                      ][i % 4],
                      backgroundImage: (c['photoURL'] ?? '').isNotEmpty
                          ? NetworkImage(c['photoURL']!)
                          : null,
                      child: (c['photoURL'] ?? '').isEmpty
                          ? Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabs
// ─────────────────────────────────────────────────────────────────────────────

class _TabPostsVisitor extends StatelessWidget {
  final String targetUserId;
  const _TabPostsVisitor({required this.targetUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('publicaciones')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _teal));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Sin publicaciones aún',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          );
        }
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1.5,
            mainAxisSpacing: 1.5,
          ),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final imageUrl = data['imageUrl'] as String?;
            return Container(
              color: _tealBg,
              child: imageUrl != null
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : const Icon(Icons.image_outlined, color: _tealLight),
            );
          },
        );
      },
    );
  }
}

class _TabRutaDetalle extends StatelessWidget {
  final List<Map<String, String>> lugaresVividos;
  const _TabRutaDetalle({required this.lugaresVividos});

  @override
  Widget build(BuildContext context) {
    if (lugaresVividos.isEmpty) {
      return const Center(
        child: Text(
          'No ha agregado ciudades aún',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: lugaresVividos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, i) {
        final lugar = lugaresVividos[i];
        final esActual = i == lugaresVividos.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Línea de tiempo
              Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: esActual ? _teal : _tealLight,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  if (i < lugaresVividos.length - 1)
                    Expanded(child: Container(width: 2, color: _tealBg)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${lugar['emoji'] ?? '🌍'} ${lugar['ciudad'] ?? ''}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: esActual ? _teal : _tealDark,
                        ),
                      ),
                      if ((lugar['años'] ?? '').isNotEmpty)
                        Text(
                          esActual ? '${lugar['años']} · hoy' : lugar['años']!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      if (esActual)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _tealBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _tealLight),
                          ),
                          child: const Text(
                            'Ubicación actual',
                            style: TextStyle(
                              fontSize: 11,
                              color: _teal,
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
        );
      },
    );
  }
}

class _TabAreasAyuda extends StatelessWidget {
  final List<String> areas;
  final String username;
  final VoidCallback onPreguntar;

  const _TabAreasAyuda({
    required this.areas,
    required this.username,
    required this.onPreguntar,
  });

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) {
      return const Center(
        child: Text(
          'No ha definido áreas de ayuda aún',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '@$username puede orientarte en:',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        ...areas.map(
          (area) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _tealBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _tealLight.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    area,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _tealDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onPreguntar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _teal,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Preguntar',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onPreguntar,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _teal,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                '✉ Enviar mensaje directo',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
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

class _BottomSheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BottomSheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Painter para el patrón de grilla del cover (cuando no hay imagen).
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.8;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Dos puntos de ruta decorativos
    final dotPaint = Paint()..color = const Color(0xFF4fffc8);
    canvas.drawCircle(const Offset(100, 90), 4, dotPaint);
    canvas.drawCircle(const Offset(220, 60), 4, dotPaint);
    final linePaint = Paint()
      ..color = const Color(0xFF4fffc8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(100, 90)
      ..lineTo(220, 60);
    canvas.drawPath(
      dashPath(path, dashArray: CircularIntervalList([6, 4])),
      linePaint,
    );
  }

  /// Genera un path punteado a partir de uno sólido.
  Path dashPath(Path source, {required CircularIntervalList dashArray}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double dist = 0;
      bool draw = true;
      while (dist < metric.length) {
        final len = dashArray.next;
        if (draw) {
          dest.addPath(metric.extractPath(dist, dist + len), Offset.zero);
        }
        dist += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CircularIntervalList<T> {
  CircularIntervalList(this._values);
  final List<T> _values;
  int _index = 0;
  T get next {
    if (_index >= _values.length) _index = 0;
    return _values[_index++];
  }
}

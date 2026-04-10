import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';

import '../feed/widgets/post_card.dart';
import '../feed/widgets/share_sheet.dart';
import '../feed/widgets/comments_screen.dart';
import '../../services/social_service.dart';
import '../chat/chat_screen.dart';
import '../feed/widgets/bottom_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
// visitor_profile_screen.dart  –  Nomad App
// Pantalla de perfil visto por OTRO usuario (no el propio).
//
// Navegación:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => VisitorProfileScreen(targetUserId: 'uid_del_otro'),
//   ));
// ─────────────────────────────────────────────────────────────────────────────

// Paleta
const _teal = Color(0xFF0D9488);
const _tealLight = Color(0xFF5EEAD4);
const _tealDark = Color(0xFF134E4A);
const _tealBg = Color(0xFFF0FAF9);
const _bgMain = Color(0xFFF8FFFE);

// ─────────────────────────────────────────────────────────────────────────────
// Estado de relación social entre el visitante y el perfil visitado
// ─────────────────────────────────────────────────────────────────────────────

enum _RelationState {
  loading,
  notFollowing, // no sigo al usuario
  following, // lo sigo, él no me sigue
  followingBack, // nos seguimos mutuamente (amigos)
  requestSent, // yo envié solicitud de amistad, pendiente
  requestReceived, // él me envió solicitud, pendiente de aceptar
}

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

  // Estado de relación
  _RelationState _relation = _RelationState.loading;

  bool _datosLoaded = false;

  // Contexto dinámico
  String? _bannerContexto;
  final ScrollController _scrollController = ScrollController();
  bool _showBottomBar = true;

  // Contactos en común
  List<Map<String, String>> _contactosComun = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
    _cargarTodo();
  }

  void _onScroll() {
    final direction = _scrollController.position.userScrollDirection;

    if (direction == ScrollDirection.reverse) {
      if (_showBottomBar) {
        setState(() => _showBottomBar = false);
      }
    }

    if (direction == ScrollDirection.forward) {
      if (!_showBottomBar) {
        setState(() => _showBottomBar = true);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Carga de datos ──────────────────────────────────────────────────────────
  //
  // Etapa 1: datos esenciales del doc del usuario → desbloquea el spinner.
  // Etapa 2: contadores y datos secundarios → se actualizan en segundo plano.

  Future<void> _cargarTodo() async {
    // Etapa 1 — solo el doc del usuario. Rápido y sin queries adicionales.
    await _cargarPerfilBasico();
    if (mounted) setState(() => _datosLoaded = true);

    // Etapa 2 — el resto en paralelo, actualiza la UI cuando llegan.
    await Future.wait([
      _cargarContadores(),
      _cargarRelacion(),
      _cargarContactosComun(),
      _calcularContexto(),
    ]);
  }

  /// Lee ÚNICAMENTE el documento /users/{targetUserId}.
  /// No hace queries adicionales, por eso nunca falla silenciosamente.
  Future<void> _cargarPerfilBasico() async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(widget.targetUserId)
          .get();
      final data = doc.data();
      if (data == null) {
        debugPrint(
          '[VisitorProfile] Doc no encontrado: ${widget.targetUserId}',
        );
        return;
      }

      final ciudadesRaw = data['ciudadesVividas'];
      final List<Map<String, String>> ciudades = ciudadesRaw is List
          ? ciudadesRaw.map((e) => Map<String, String>.from(e as Map)).toList()
          : [];

      final areasRaw = data['areasAyuda'];
      final List<String> areas = areasRaw is List
          ? List<String>.from(areasRaw)
          : [];

      if (!mounted) return;
      setState(() {
        // Intentar displayName primero, luego nombre, luego fallback.
        final rawName = (data['displayName'] as String?)?.trim();
        final rawNombre = (data['name'] as String?)?.trim();
        _nombre =
            (rawName?.isNotEmpty == true ? rawName : rawNombre) ?? 'Usuario';
        _username = (data['username'] as String?) ?? '';
        _bio = (data['bio'] as String?) ?? '';
        _photoURL = data['photo'] as String?;
        _coverURL = data['coverURL'] as String?;
        _lugaresVividos = ciudades;
        _areasAyuda = areas;
      });
    } catch (e) {
      debugPrint('[VisitorProfile] Error cargando perfil básico: $e');
    }
  }

  /// Obtiene los conteos de seguidores, siguiendo y posts.
  /// Usa .get().docs.length (sin índices de agregación) para máxima compatibilidad.
  Future<void> _cargarContadores() async {
    try {
      final results = await Future.wait([
        // seguidores
        _firestore
            .collection('follows')
            .where('followingId', isEqualTo: widget.targetUserId)
            .get(),

        // siguiendo
        _firestore
            .collection('follows')
            .where('followerId', isEqualTo: widget.targetUserId)
            .get(),

        // posts
        _firestore
            .collection('posts')
            .where('authorId', isEqualTo: widget.targetUserId)
            .where('visibility', isEqualTo: 'public')
            .get(),
      ]);

      if (!mounted) return;

      setState(() {
        _seguidoresCount = results[0].docs.length;

        _siguiendoCount = results[1].docs.length;

        _publicacionesCount = results[2].docs.length;
      });
    } catch (e) {
      debugPrint('[VisitorProfile] Error cargando contadores: $e');
    }
  }

  /// Determina el estado completo de la relación con el perfil visitado.
  Future<void> _cargarRelacion() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) {
      if (mounted) setState(() => _relation = _RelationState.notFollowing);
      return;
    }
    try {
      // ¿Yo sigo al otro?
      final iFollow = await _firestore
          .collection('follows')
          .doc('${myUid}_${widget.targetUserId}')
          .get();

      final theyFollow = await _firestore
          .collection('follows')
          .doc('${widget.targetUserId}_${myUid}')
          .get();

      // ¿Hay solicitud de amistad pendiente?
      final reqSent = await _firestore
          .collection('friend_requests')
          .where('from', isEqualTo: myUid)
          .where('to', isEqualTo: widget.targetUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      final reqReceived = await _firestore
          .collection('friend_requests')
          .where('from', isEqualTo: widget.targetUserId)
          .where('to', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (!mounted) return;
      _RelationState state;
      if (iFollow.exists && theyFollow.exists) {
        state = _RelationState.followingBack;
      } else if (iFollow.exists) {
        state = _RelationState.following;
      } else if (reqSent.docs.isNotEmpty) {
        state = _RelationState.requestSent;
      } else if (reqReceived.docs.isNotEmpty) {
        state = _RelationState.requestReceived;
      } else {
        state = _RelationState.notFollowing;
      }
      setState(() => _relation = state);
    } catch (e) {
      debugPrint('[VisitorProfile] Error cargando relación: $e');
      if (mounted) setState(() => _relation = _RelationState.notFollowing);
    }
  }

  Future<void> _cargarContactosComun() async {
    final myUid = _auth.currentUser?.uid;

    if (myUid == null) return;

    try {
      final myFollowingSnap = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: myUid)
          .get();

      final myFollowingIds = myFollowingSnap.docs
          .map((d) => d['followingId'])
          .toSet();

      final theirFollowersSnap = await _firestore
          .collection('follows')
          .where('followingId', isEqualTo: widget.targetUserId)
          .get();

      final theirFollowerIds = theirFollowersSnap.docs
          .map((d) => d['followerId'])
          .toSet();

      final comunIds = myFollowingIds.intersection(theirFollowerIds).take(5);

      List<Map<String, String>> comun = [];

      for (final uid in comunIds) {
        final userDoc = await _firestore.collection('users').doc(uid).get();

        final data = userDoc.data();

        if (data != null) {
          comun.add({
            "uid": uid,
            "nombre": data["displayName"] ?? "Usuario",
            "username": data["username"] ?? "",
            "photoURL": data["photoURL"] ?? "",
          });
        }
      }

      if (mounted) {
        setState(() => _contactosComun = comun);
      }
    } catch (e) {
      debugPrint("[VisitorProfile] contactosComun error $e");
    }
  }

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

      final suCiudadActual = _lugaresVividos.last;
      final miCiudadActual = misCiudades.last;
      final enComun = susCiudadNombres.intersection(misCiudadNombres);

      String? contexto;
      if (!misCiudadNombres.contains(suCiudadActual['ciudad']?.toLowerCase())) {
        final extra = enComun.isNotEmpty
            ? 'Pasó por ${_capitalized(enComun.first)} como vos'
            : null;
        final destino =
            'Está en ${suCiudadActual['ciudad']} donde podrías migrar';
        contexto = extra != null ? '$extra · $destino' : destino;
      } else if (enComun.isNotEmpty &&
          suCiudadActual['ciudad']?.toLowerCase() !=
              miCiudadActual['ciudad']?.toLowerCase()) {
        contexto =
            'Vivió en ${_capitalized(enComun.first)} como vos · Ahora en ${suCiudadActual['ciudad']}';
      } else if (suCiudadActual['ciudad']?.toLowerCase() ==
          miCiudadActual['ciudad']?.toLowerCase()) {
        contexto = 'Estás en la misma ciudad · ${suCiudadActual['ciudad']}';
      }

      if (mounted) setState(() => _bannerContexto = contexto);
    } catch (e) {
      debugPrint('[VisitorProfile] Error calculando contexto: $e');
    }
  }

  String _capitalized(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ── Acciones de relación ────────────────────────────────────────────────────

  Future<void> _handleMainAction() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    switch (_relation) {
      case _RelationState.notFollowing:
        await _seguir(myUid);
        break;
      case _RelationState.following:
        _confirmarDejarDeSeguir(myUid);
        break;
      case _RelationState.followingBack:
        _confirmarDejarDeSeguir(myUid);
        break;
      case _RelationState.requestSent:
        await _cancelarSolicitud(myUid);
        break;
      case _RelationState.requestReceived:
        await _aceptarSolicitud(myUid);
        break;
      case _RelationState.loading:
        break;
    }
  }

  Future<void> _seguir(String myUid) async {
    setState(() => _relation = _RelationState.loading);

    try {
      await SocialService.followOrRequestUser(widget.targetUserId);

      await _cargarRelacion();

      await _cargarContadores();
    } catch (e) {
      debugPrint('[VisitorProfile] follow error $e');
    }
  }

  Future<void> _dejarDeSeguir(String myUid) async {
    setState(() => _relation = _RelationState.loading);

    try {
      await SocialService.unfollowUser(widget.targetUserId);

      if (mounted) {
        setState(() {
          _seguidoresCount = (_seguidoresCount - 1).clamp(0, 999999);

          _relation = _RelationState.notFollowing;
        });
      }
    } catch (e) {
      debugPrint('[VisitorProfile] unfollow error $e');

      if (mounted) {
        await _cargarRelacion();
      }
    }
  }

  void _confirmarDejarDeSeguir(String myUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        title: '¿Dejar de seguir a @$_username?',
        subtitle:
            'Dejará de aparecer en tu feed. Siempre podés volver a seguirlo.',
        confirmLabel: 'Dejar de seguir',
        confirmColor: Colors.redAccent,
        onConfirm: () => _dejarDeSeguir(myUid),
      ),
    );
  }

  Future<void> _enviarSolicitudAmistad(String myUid) async {
    setState(() => _relation = _RelationState.loading);
    try {
      await _firestore.collection('friend_requests').add({
        'from': myUid,
        'to': widget.targetUserId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _relation = _RelationState.requestSent);
    } catch (e) {
      debugPrint('[VisitorProfile] Error enviando solicitud: $e');
      if (mounted) await _cargarRelacion();
    }
  }

  Future<void> _cancelarSolicitud(String myUid) async {
    setState(() => _relation = _RelationState.loading);
    try {
      final snap = await _firestore
          .collection('friend_requests')
          .where('from', isEqualTo: myUid)
          .where('to', isEqualTo: widget.targetUserId)
          .where('status', isEqualTo: 'pending')
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
      if (mounted) setState(() => _relation = _RelationState.notFollowing);
    } catch (e) {
      debugPrint('[VisitorProfile] Error cancelando solicitud: $e');
      if (mounted) await _cargarRelacion();
    }
  }

  Future<void> _aceptarSolicitud(String myUid) async {
    setState(() => _relation = _RelationState.loading);
    try {
      // Marcar solicitud como aceptada
      final snap = await _firestore
          .collection('friend_requests')
          .where('from', isEqualTo: widget.targetUserId)
          .where('to', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({'status': 'accepted'});
      }
      // Seguir mutuamente
      await _seguir(myUid);
      if (mounted) setState(() => _relation = _RelationState.followingBack);
    } catch (e) {
      debugPrint('[VisitorProfile] Error aceptando solicitud: $e');
      if (mounted) await _cargarRelacion();
    }
  }

  void _rechazarSolicitud(String myUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        title: '¿Rechazar solicitud de @$_username?',
        subtitle: 'No sabrá que rechazaste su solicitud.',
        confirmLabel: 'Rechazar',
        confirmColor: Colors.redAccent,
        onConfirm: () async {
          setState(() => _relation = _RelationState.loading);
          try {
            final snap = await _firestore
                .collection('friend_requests')
                .where('from', isEqualTo: widget.targetUserId)
                .where('to', isEqualTo: myUid)
                .where('status', isEqualTo: 'pending')
                .get();
            for (final doc in snap.docs) {
              await doc.reference.update({'status': 'rejected'});
            }
            if (mounted)
              setState(() => _relation = _RelationState.notFollowing);
          } catch (e) {
            debugPrint('[VisitorProfile] Error rechazando solicitud: $e');
          }
        },
      ),
    );
  }

  // ── Mensaje directo ─────────────────────────────────────────────────────────

  void _abrirMensaje() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    // chatId determinístico: los dos UIDs ordenados alfabéticamente, unidos con "_"
    // Garantiza que ambos usuarios siempre acceden al mismo chat sin duplicados.
    final ids = [myUid, widget.targetUserId]..sort();
    final chatId = '${ids[0]}_${ids[1]}';

    // Asegurarse de que el documento del chat existe en Firestore
    _ensureChatDoc(chatId, myUid);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserId: widget.targetUserId,
          otherUsername: _username,
          otherAvatarUrl: _photoURL,
          otherName: _nombre,
        ),
      ),
    );
  }

  /// Crea el documento /chats/{chatId} si no existe todavía.
  Future<void> _ensureChatDoc(String chatId, String myUid) async {
    final ref = _firestore.collection('chats').doc(chatId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participantIds': [myUid, widget.targetUserId],
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': {myUid: 0, widget.targetUserId: 0},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Bloquear usuario ────────────────────────────────────────────────────────

  Future<void> _bloquearUsuario() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        title: '¿Bloquear a @$_username?',
        subtitle: 'No podrá ver tu perfil ni interactuar con vos.',
        confirmLabel: 'Bloquear',
        confirmColor: Colors.redAccent,
        onConfirm: () async {
          try {
            await _firestore
                .collection('users')
                .doc(myUid)
                .collection('blocked')
                .doc(widget.targetUserId)
                .set({'blockedAt': FieldValue.serverTimestamp()});
            if (mounted) Navigator.pop(context);
          } catch (e) {
            debugPrint('[VisitorProfile] Error bloqueando: $e');
          }
        },
      ),
    );
  }

  // ── Reportar perfil ─────────────────────────────────────────────────────────

  void _reportarPerfil() {
    Navigator.pop(context); // cerrar more options
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _ReportSheet(targetUserId: widget.targetUserId, username: _username),
    );
  }

  // ── Compartir perfil ────────────────────────────────────────────────────────

  void _compartirPerfil() {
    Navigator.pop(context);
    Share.share(
      'Mirá el perfil de @$_username en Nomad: https://nomad.app/u/${widget.targetUserId}',
      subject: 'Perfil en Nomad',
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
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: _showBottomBar ? Offset.zero : const Offset(0, 1),

        child: const BottomNav(currentIndex: 3),
      ),
    );
  }

  Widget _buildBody() {
    return NestedScrollView(
      controller: _scrollController,
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
      expandedHeight: _bannerContexto != null ? 510 : 480,
      pinned: true,
      backgroundColor: _bgMain,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
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
        // Botón seguir compacto visible al hacer scroll
        AnimatedOpacity(
          opacity: innerBoxIsScrolled ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: _RelationButton(
              relation: _relation,
              compact: true,
              onTap: _handleMainAction,
            ),
          ),
        ),
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
          relation: _relation,
          bannerContexto: _bannerContexto,
          contactosComun: _contactosComun,
          onMainAction: _handleMainAction,
          onMensaje: _abrirMensaje,
          onRechazarSolicitud: () {
            final myUid = _auth.currentUser?.uid;
            if (myUid != null) _rechazarSolicitud(myUid);
          },
        ),
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = [
      (PhosphorIcons.gridFour(), 'Posts'),
      (PhosphorIcons.airplaneTilt(), 'Ruta'),
      (PhosphorIcons.lightbulb(), 'Puede ayudar'),
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
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreOptionsSheet(
        username: _username,
        targetUserId: widget.targetUserId,
        onBloquear: _bloquearUsuario,
        onReportar: _reportarPerfil,
        onCompartir: _compartirPerfil,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VisitorHeader
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
  final _RelationState relation;
  final String? bannerContexto;
  final List<Map<String, String>> contactosComun;
  final VoidCallback onMainAction;
  final VoidCallback onMensaje;
  final VoidCallback onRechazarSolicitud;

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
    required this.relation,
    required this.bannerContexto,
    required this.contactosComun,
    required this.onMainAction,
    required this.onMensaje,
    required this.onRechazarSolicitud,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de contexto dinámico
          if (bannerContexto != null) _buildContextBanner(),

          // Cover + avatar + stats
          _buildCoverAndAvatar(),

          // Nombre, handle, bio + botones — misma estructura que perfil propio
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila nombre + botones de acción (igual al perfil propio)
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
                    const SizedBox(width: 10),
                    // Botones Seguir + Mensaje alineados con el nombre
                    _buildActionButtons(),
                  ],
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _BioExpandable(text: bio),
                ],
              ],
            ),
          ),

          // Banner solicitud recibida
          if (relation == _RelationState.requestReceived)
            _buildRequestReceivedBanner(),

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

  Widget _buildCoverAndAvatar() {
    // Misma arquitectura que el perfil propio:
    // SizedBox fijo de 210px contiene el Stack para que el avatar
    // sobresalga del cover sin romper el layout.
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Cover ─────────────────────────────────────────────────────────
          Container(
            height: 160,
            width: double.infinity,
            color: _tealDark,
            child: Stack(
              children: [
                Positioned.fill(
                  child: coverURL != null
                      ? Image.network(
                          coverURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              CustomPaint(painter: _GridPatternPainter()),
                        )
                      : CustomPaint(painter: _GridPatternPainter()),
                ),
                // Degradado inferior suave (igual al perfil propio)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.25),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Avatar ────────────────────────────────────────────────────────
          Positioned(
            top: 115,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Ring teal si son amigos, blanco normal si no
                gradient: relation == _RelationState.followingBack
                    ? const LinearGradient(colors: [_teal, _tealLight])
                    : null,
                color: relation == _RelationState.followingBack
                    ? null
                    : Colors.white,
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xFFCCFBF1),
                backgroundImage: photoURL != null
                    ? NetworkImage(photoURL!)
                    : null,
                child: photoURL == null
                    ? Text(
                        nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
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

          // ── Badge "Amigos" bajo el avatar ─────────────────────────────────
          if (relation == _RelationState.followingBack)
            Positioned(
              top: 204,
              left: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _teal,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Text(
                  '✓ Amigos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          // ── Stats a la derecha del avatar (misma posición que perfil propio) ─
          Positioned(
            top: 170,
            left: 155,
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
      ),
    );
  }

  /// Devuelve los botones Seguir + Mensaje como Column (sin Padding propio).
  /// Se ubica dentro de la Row del nombre, igual al botón "Editar" del perfil propio.
  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila Seguir / Mensaje
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RelationButton(
              relation: relation,
              compact: true,
              onTap: onMainAction,
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onMensaje,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _tealBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _tealLight),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mail_outline_rounded, size: 14, color: _teal),
                    SizedBox(width: 4),
                    Text(
                      'Mensaje',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequestReceivedBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_add_alt_1_rounded,
            size: 18,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '@$username te envió una solicitud de amistad',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRechazarSolicitud,
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

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
// _RelationButton — botón principal que cambia según el estado de la relación
// ─────────────────────────────────────────────────────────────────────────────

class _RelationButton extends StatelessWidget {
  final _RelationState relation;
  final bool compact;
  final VoidCallback onTap;

  const _RelationButton({
    required this.relation,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (relation == _RelationState.loading) {
      return const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
          ),
        ),
      );
    }

    final config = _buttonConfig();
    final height = compact ? 34.0 : 40.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 0),
        decoration: BoxDecoration(
          color: config.bgColor,
          borderRadius: BorderRadius.circular(compact ? 20 : 24),
          border: config.border,
        ),
        child: Center(
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(config.icon, size: 14, color: config.textColor),
              const SizedBox(width: 5),
              Text(
                config.label,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  color: config.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ButtonConfig _buttonConfig() {
    switch (relation) {
      case _RelationState.notFollowing:
        return _ButtonConfig(
          label: 'Seguir',
          icon: Icons.person_add_alt_1_rounded,
          bgColor: _teal,
          textColor: Colors.white,
        );
      case _RelationState.following:
        return _ButtonConfig(
          label: 'Siguiendo',
          icon: Icons.person_rounded,
          bgColor: _tealBg,
          textColor: _teal,
          border: Border.all(color: _tealLight),
        );
      case _RelationState.followingBack:
        return _ButtonConfig(
          label: 'Amigos',
          icon: Icons.people_alt_rounded,
          bgColor: _tealBg,
          textColor: _teal,
          border: Border.all(color: _tealLight),
        );
      case _RelationState.requestSent:
        return _ButtonConfig(
          label: 'Solicitud enviada',
          icon: Icons.schedule_rounded,
          bgColor: const Color(0xFFF3F4F6),
          textColor: const Color(0xFF6B7280),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        );
      case _RelationState.requestReceived:
        return _ButtonConfig(
          label: 'Aceptar solicitud',
          icon: Icons.check_circle_outline_rounded,
          bgColor: const Color(0xFFFFF7ED),
          textColor: const Color(0xFFD97706),
          border: Border.all(color: const Color(0xFFFDE68A)),
        );
      case _RelationState.loading:
        return _ButtonConfig(
          label: '',
          icon: Icons.hourglass_empty_rounded,
          bgColor: _tealBg,
          textColor: _teal,
        );
    }
  }
}

class _ButtonConfig {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color textColor;
  final BoxBorder? border;
  const _ButtonConfig({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.textColor,
    this.border,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabs
// ─────────────────────────────────────────────────────────────────────────────

/// Tab de posts: grilla 3×3 con tap para ver el post completo
class _TabPostsVisitor extends StatelessWidget {
  final String targetUserId;
  const _TabPostsVisitor({required this.targetUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: targetUserId)
          .where('visibility', isEqualTo: 'public')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _teal));
        }
        if (snapshot.hasError) {
          debugPrint(
            '[VisitorProfile] Error en posts stream: ${snapshot.error}',
          );
        }
        // Ordenar en memoria para evitar necesidad de índice compuesto en Firestore
        final docs = [...(snapshot.data?.docs ?? [])]
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTs = aData['createdAt'];
            final bTs = bData['createdAt'];
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return (bTs as Timestamp).compareTo(aTs as Timestamp);
          });
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.grid_off_rounded,
                  size: 48,
                  color: _tealLight.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sin publicaciones aún',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
              ],
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
            final postId = docs[i].id;
            final images = List<String>.from(data['images'] ?? []);
            final imageUrl = images.isNotEmpty
                ? images[0]
                : data['imageUrl'] as String?;

            return GestureDetector(
              onTap: () => _openPostDetail(context, docs[i].id, data),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: _tealBg,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.image_not_supported_outlined,
                              color: _tealLight,
                            ),
                          )
                        : const Icon(Icons.image_outlined, color: _tealLight),
                  ),
                  // Indicador multi-imagen
                  if (images.length > 1)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: Colors.white,
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

  void _openPostDetail(
    BuildContext context,
    String postId,
    Map<String, dynamic> data,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: PostCard(
                    postId: postId,
                    postAuthorId: targetUserId,
                    username: data['username'] as String? ?? '',
                    images: List<String>.from(data['images'] ?? []),
                    caption: data['caption'] as String? ?? '',
                    userCountryFlag: data['countryFlag'] as String?,
                    userCity: data['city'] as String?,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabRutaDetalle extends StatelessWidget {
  final List<Map<String, String>> lugaresVividos;
  const _TabRutaDetalle({required this.lugaresVividos});

  @override
  Widget build(BuildContext context) {
    if (lugaresVividos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight_outlined,
              size: 48,
              color: _tealLight.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'No ha agregado ciudades aún',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ],
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 48,
              color: _tealLight.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'No ha definido áreas de ayuda aún',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ],
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
// Sheets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

/// Sheet de confirmación genérico (dejar de seguir, bloquear, rechazar)
class _ConfirmSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _ConfirmSheet({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet de reporte de perfil
class _ReportSheet extends StatelessWidget {
  final String targetUserId;
  final String username;

  static const _reasons = [
    'Spam o contenido no deseado',
    'Información falsa o engañosa',
    'Acoso o bullying',
    'Discurso de odio',
    'Contenido inapropiado',
    'Cuenta falsa o suplantación',
    'Otro motivo',
  ];

  const _ReportSheet({required this.targetUserId, required this.username});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            '¿Por qué querés reportar este perfil?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No le diremos a @$username quién envió el reporte.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 16),
          ..._reasons.map(
            (reason) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                reason,
                style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFFD1D5DB),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final myUid = FirebaseAuth.instance.currentUser?.uid;
                  if (myUid == null) return;
                  await FirebaseFirestore.instance.collection('reports').add({
                    'type': 'profile',
                    'targetId': targetUserId,
                    'reportedBy': myUid,
                    'reason': reason,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reporte enviado. Gracias.'),
                      backgroundColor: _teal,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  debugPrint('[VisitorProfile] Error reportando: $e');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet de opciones adicionales (⋯)
class _MoreOptionsSheet extends StatelessWidget {
  final String username;
  final String targetUserId;
  final VoidCallback onBloquear;
  final VoidCallback onReportar;
  final VoidCallback onCompartir;

  const _MoreOptionsSheet({
    required this.username,
    required this.targetUserId,
    required this.onBloquear,
    required this.onReportar,
    required this.onCompartir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          _OptionTile(
            icon: Icons.share_outlined,
            label: 'Compartir perfil',
            color: _tealDark,
            onTap: onCompartir,
          ),
          _OptionTile(
            icon: Icons.block_rounded,
            label: 'Bloquear a @$username',
            color: Colors.redAccent,
            onTap: () {
              Navigator.pop(context);
              onBloquear();
            },
          ),
          _OptionTile(
            icon: Icons.flag_outlined,
            label: 'Reportar perfil',
            color: Colors.redAccent,
            onTap: () {
              Navigator.pop(context);
              onReportar();
            },
          ),
          const SizedBox(height: 4),
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

// ─────────────────────────────────────────────────────────────────────────────
// Bio expandable (igual a la del perfil propio)
// ─────────────────────────────────────────────────────────────────────────────

class _BioExpandable extends StatefulWidget {
  final String text;
  const _BioExpandable({required this.text});
  @override
  State<_BioExpandable> createState() => _BioExpandableState();
}

class _BioExpandableState extends State<_BioExpandable> {
  bool _expanded = false;
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
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (widget.text.length > 120)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded ? 'ver menos' : 'ver más',
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

/// Painter para el patrón de grilla del cover (cuando no hay imagen)
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
      _dashPath(path, dashArray: _CircularIntervalList([6, 4])),
      linePaint,
    );
  }

  Path _dashPath(Path source, {required _CircularIntervalList dashArray}) {
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

class _CircularIntervalList<T> {
  _CircularIntervalList(this._values);
  final List<T> _values;
  int _index = 0;
  T get next {
    if (_index >= _values.length) _index = 0;
    return _values[_index++];
  }
}

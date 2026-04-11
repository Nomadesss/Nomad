import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/discover_service.dart';
import 'matches_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// discover_screen.dart  –  Nomad App
// ─────────────────────────────────────────────────────────────────────────────

const _teal = Color(0xFF0D9488);
const _tealLight = Color(0xFF5EEAD4);
const _tealDark = Color(0xFF134E4A);
const _tealBg = Color(0xFFF0FAF9);

// ── Helper: primer nombre ──────────────────────────────────────────────────
String _firstName(Map<String, dynamic> profile) {
  final nombres = profile['nombres'] as String?;
  if (nombres != null && nombres.isNotEmpty) return nombres.split(' ').first;
  final display = profile['displayName'] as String?;
  if (display != null && display.isNotEmpty) return display.trim().split(' ').first;
  return 'Nomad';
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with TickerProviderStateMixin {
  // ── Estado ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _profiles = [];
  bool _loading = true;
  bool _processing = false;

  // Filtros activos
  String? _filterPais;
  String? _filterCiudad;
  String? _filterObjetivo;
  int? _filterEdadMin;
  int? _filterEdadMax;
  String? _filterGenero;

  // Animación de swipe
  late AnimationController _swipeCtrl;
  late Animation<Offset> _swipeOffset;
  late Animation<double> _swipeAngle;
  Offset _dragStart = Offset.zero;
  Offset _dragDelta = Offset.zero;
  bool _isDragging = false;

  // Overlay de match
  Map<String, dynamic>? _matchProfile;
  bool _matchIsSuperLike = false;
  late AnimationController _matchCtrl;
  late Animation<double> _matchScale;
  late Animation<double> _matchFade;

  double get _swipeProgress {
    if (!_isDragging) return 0;
    final screenW = MediaQuery.of(context).size.width;
    return (_dragDelta.dx / (screenW * 0.4)).clamp(-1.0, 1.0);
  }

  @override
  void initState() {
    super.initState();

    _swipeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _swipeOffset = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOut));
    _swipeAngle = Tween<double>(begin: 0, end: 0).animate(_swipeCtrl);

    _matchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _matchScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _matchCtrl, curve: Curves.elasticOut),
    );
    _matchFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _matchCtrl, curve: Curves.easeIn),
    );

    _loadFiltersAndProfiles();
  }

  @override
  void dispose() {
    _swipeCtrl.dispose();
    _matchCtrl.dispose();
    super.dispose();
  }

  // ── Carga ──────────────────────────────────────────────────────────────────

  Future<void> _loadFiltersAndProfiles() async {
    setState(() => _loading = true);
    try {
      final filters = await DiscoverService.loadFilters();
      _filterPais = filters['paisOrigen'] as String?;
      _filterCiudad = filters['ciudad'] as String?;
      _filterObjetivo = filters['objetivo'] as String?;
      _filterEdadMin = filters['edadMin'] as int?;
      _filterEdadMax = filters['edadMax'] as int?;
      _filterGenero = filters['genero'] as String?;

      await _loadProfiles();

      // Onboarding: mostrar filtros la primera vez
      final onboardingDone = await DiscoverService.isOnboardingDone();
      if (!onboardingDone && mounted) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _showFilters(isOnboarding: true);
      }
    } catch (e) {
      debugPrint('[Discover] Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProfiles() async {
    final profiles = await DiscoverService.loadProfiles(
      filterPaisOrigen: _filterPais,
      filterCiudad: _filterCiudad,
      filterObjetivo: _filterObjetivo,
      filterEdadMin: _filterEdadMin,
      filterEdadMax: _filterEdadMax,
      filterGenero: _filterGenero,
    );
    if (mounted) setState(() => _profiles = profiles);
  }

  // ── Acciones ───────────────────────────────────────────────────────────────

  Future<void> _handleLike() async {
    if (_profiles.isEmpty || _processing) return;
    _processing = true;
    HapticFeedback.mediumImpact();
    final profile = _profiles.first;
    final targetUid = profile['uid'] as String;
    await _animateSwipe(right: true);
    final isMatch = await DiscoverService.like(targetUid);
    setState(() => _profiles.removeAt(0));
    _processing = false;
    if (isMatch && mounted) _showMatchOverlay(profile, isSuperLike: false);
  }

  Future<void> _handleDislike() async {
    if (_profiles.isEmpty || _processing) return;
    _processing = true;
    HapticFeedback.lightImpact();
    final targetUid = _profiles.first['uid'] as String;
    await _animateSwipe(right: false);
    await DiscoverService.dislike(targetUid);
    setState(() => _profiles.removeAt(0));
    _processing = false;
  }

  Future<void> _handleSuperLike() async {
    if (_profiles.isEmpty || _processing) return;
    _processing = true;
    HapticFeedback.heavyImpact();
    final profile = _profiles.first;
    final targetUid = profile['uid'] as String;
    await _animateSwipe(right: true);
    final isMatch = await DiscoverService.superLike(targetUid);
    setState(() => _profiles.removeAt(0));
    _processing = false;
    if (isMatch && mounted) _showMatchOverlay(profile, isSuperLike: true);
  }

  Future<void> _animateSwipe({required bool right}) async {
    final screenW = MediaQuery.of(context).size.width;
    final endOffset = Offset(right ? screenW * 1.5 : -screenW * 1.5, 0);
    final endAngle = right ? 0.3 : -0.3;

    _swipeOffset = Tween<Offset>(begin: _dragDelta, end: endOffset)
        .animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOut));
    _swipeAngle = Tween<double>(begin: _dragDelta.dx * 0.001, end: endAngle)
        .animate(_swipeCtrl);

    _swipeCtrl.reset();
    await _swipeCtrl.forward();

    _dragDelta = Offset.zero;
    _isDragging = false;
    _swipeCtrl.reset();
    _swipeOffset = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(_swipeCtrl);
    _swipeAngle = Tween<double>(begin: 0, end: 0).animate(_swipeCtrl);
  }

  void _showMatchOverlay(Map<String, dynamic> profile,
      {required bool isSuperLike}) {
    setState(() {
      _matchProfile = profile;
      _matchIsSuperLike = isSuperLike;
    });
    _matchCtrl.forward();
  }

  void _dismissMatchOverlay() {
    _matchCtrl.reverse().then((_) {
      if (mounted) setState(() => _matchProfile = null);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFE),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
              _buildActionButtons(),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
            ],
          ),
          if (_matchProfile != null) _buildMatchOverlay(),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        14,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF0FAF9)],
        ),
        boxShadow: [
          BoxShadow(
            color: _teal.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Volver
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _tealBg,
                shape: BoxShape.circle,
                border: Border.all(color: _tealLight.withOpacity(0.5)),
              ),
              child: const Icon(Icons.close_rounded, color: _tealDark, size: 20),
            ),
          ),
          const Spacer(),
          // Título
          Column(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_tealDark, _teal],
                ).createShader(bounds),
                child: const Text(
                  '✈️ Nomad Connect',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Text(
                'Conectá con migrantes',
                style: TextStyle(
                  fontSize: 11,
                  color: _teal.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Botones
          Row(
            children: [
              // Matches
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MatchesScreen()),
                ),
                child: Stack(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _tealBg,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: _tealLight.withOpacity(0.5)),
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          color: _teal, size: 20),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: DiscoverService.matchesStream(),
                      builder: (_, snap) {
                        final count = snap.data?.docs.length ?? 0;
                        if (count == 0) return const SizedBox.shrink();
                        return Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Filtros
              GestureDetector(
                onTap: () => _showFilters(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _hasActiveFilters ? _teal : _tealBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _hasActiveFilters ? _teal : _tealLight,
                    ),
                    boxShadow: _hasActiveFilters
                        ? [
                            BoxShadow(
                              color: _teal.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 14,
                        color: _hasActiveFilters ? Colors.white : _teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _hasActiveFilters
                            ? 'Filtros ($_activeFilterCount)'
                            : 'Filtros',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _hasActiveFilters ? Colors.white : _teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasActiveFilters =>
      _filterPais != null ||
      _filterCiudad != null ||
      _filterObjetivo != null ||
      _filterEdadMin != null ||
      _filterGenero != null;

  int get _activeFilterCount => [
        _filterPais,
        _filterCiudad,
        _filterObjetivo,
        _filterEdadMin,
        _filterGenero,
      ].where((f) => f != null).length;

  // ── Cuerpo principal ──────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _teal));
    }

    if (_profiles.isEmpty) return _buildEmptyState();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_profiles.length > 1)
            Positioned.fill(
              child: Transform.scale(
                scale: 0.94,
                child: Transform.translate(
                  offset: const Offset(0, 12),
                  child: _DiscoverCard(
                    profile: _profiles[1],
                    swipeProgress: 0,
                    isTop: false,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: GestureDetector(
              onPanStart: _onDragStart,
              onPanUpdate: _onDragUpdate,
              onPanEnd: _onDragEnd,
              child: AnimatedBuilder(
                animation: _swipeCtrl,
                builder: (context, child) {
                  final offset =
                      _isDragging ? _dragDelta : _swipeOffset.value;
                  final angle = _isDragging
                      ? _dragDelta.dx * 0.0008
                      : _swipeAngle.value;
                  return Transform.translate(
                    offset: offset,
                    child: Transform.rotate(angle: angle, child: child),
                  );
                },
                child: _DiscoverCard(
                  profile: _profiles[0],
                  swipeProgress: _swipeProgress,
                  isTop: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDragStart(DragStartDetails d) {
    _dragStart = d.globalPosition;
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _dragDelta = d.globalPosition - _dragStart);
  }

  void _onDragEnd(DragEndDetails d) {
    setState(() => _isDragging = false);
    final threshold = MediaQuery.of(context).size.width * 0.35;
    if (_dragDelta.dx > threshold) {
      _handleLike();
    } else if (_dragDelta.dx < -threshold) {
      _handleDislike();
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    _swipeOffset = Tween<Offset>(begin: _dragDelta, end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _swipeCtrl, curve: Curves.elasticOut));
    _swipeAngle = Tween<double>(begin: _dragDelta.dx * 0.0008, end: 0)
        .animate(_swipeCtrl);
    _swipeCtrl.reset();
    _swipeCtrl.forward().then((_) {
      _dragDelta = Offset.zero;
      _swipeCtrl.reset();
    });
  }

  // ── Botones de acción ─────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    final hasProfiles = _profiles.isNotEmpty && !_loading;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionBtn(
            icon: Icons.close_rounded,
            color: const Color(0xFFEF4444),
            size: 56,
            onTap: hasProfiles ? _handleDislike : null,
          ),
          _ActionBtn(
            icon: Icons.star_rounded,
            color: const Color(0xFF3B82F6),
            size: 44,
            onTap: hasProfiles ? _handleSuperLike : null,
          ),
          _ActionBtn(
            icon: Icons.favorite_rounded,
            color: _teal,
            size: 56,
            onTap: hasProfiles ? _handleLike : null,
          ),
        ],
      ),
    );
  }

  // ── Estado vacío ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _tealBg,
                shape: BoxShape.circle,
                border: Border.all(color: _tealLight, width: 2),
              ),
              child: const Center(
                child: Text('✈️', style: TextStyle(fontSize: 42)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No hay más perfiles por ahora',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _tealDark,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Cambiá los filtros o volvé más tarde\ncuando se sumen nuevos nomads.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => _showFilters(),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Cambiar filtros'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Match overlay ─────────────────────────────────────────────────────────

  Widget _buildMatchOverlay() {
    final profile = _matchProfile!;
    final name = _firstName(profile);
    final photo = profile['photoURL'] as String?;
    final myPhoto = FirebaseAuth.instance.currentUser?.photoURL;

    return FadeTransition(
      opacity: _matchFade,
      child: Container(
        color: Colors.black.withOpacity(0.88),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: _matchIsSuperLike
                      ? [const Color(0xFF3B82F6), const Color(0xFF93C5FD)]
                      : [_teal, _tealLight],
                ).createShader(bounds),
                child: Text(
                  _matchIsSuperLike ? '⭐ Super Match!' : '¡Es un match!',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vos y $name se gustaron mutuamente 🎉',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ScaleTransition(
                scale: _matchScale,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MatchAvatar(photoURL: myPhoto, isMe: true),
                    const SizedBox(width: 16),
                    Text(
                      _matchIsSuperLike ? '⭐' : '❤️',
                      style: const TextStyle(fontSize: 36),
                    ),
                    const SizedBox(width: 16),
                    _MatchAvatar(photoURL: photo, name: name),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _dismissMatchOverlay();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _matchIsSuperLike
                              ? const Color(0xFF3B82F6)
                              : _teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Enviar mensaje',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _dismissMatchOverlay,
                      child: Text(
                        'Seguir descubriendo',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filtros ────────────────────────────────────────────────────────────────

  void _showFilters({bool isOnboarding = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !isOnboarding,
      enableDrag: !isOnboarding,
      builder: (_) => _FiltersSheet(
        initialPais: _filterPais,
        initialCiudad: _filterCiudad,
        initialObjetivo: _filterObjetivo,
        initialEdadMin: _filterEdadMin,
        initialEdadMax: _filterEdadMax,
        initialGenero: _filterGenero,
        isOnboarding: isOnboarding,
        onApply: (pais, ciudad, objetivo, edadMin, edadMax, genero) async {
          Navigator.pop(context);
          setState(() {
            _filterPais = pais;
            _filterCiudad = ciudad;
            _filterObjetivo = objetivo;
            _filterEdadMin = edadMin;
            _filterEdadMax = edadMax;
            _filterGenero = genero;
            _loading = true;
          });
          await DiscoverService.saveFilters(
            paisOrigen: pais,
            ciudad: ciudad,
            objetivo: objetivo,
            edadMin: edadMin,
            edadMax: edadMax,
            genero: genero,
          );
          if (isOnboarding) await DiscoverService.markOnboardingDone();
          await _loadProfiles();
          if (mounted) setState(() => _loading = false);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DiscoverCard — tarjeta con carrusel de fotos
// ─────────────────────────────────────────────────────────────────────────────

class _DiscoverCard extends StatefulWidget {
  final Map<String, dynamic> profile;
  final double swipeProgress;
  final bool isTop;

  const _DiscoverCard({
    required this.profile,
    required this.swipeProgress,
    required this.isTop,
  });

  @override
  State<_DiscoverCard> createState() => _DiscoverCardState();
}

class _DiscoverCardState extends State<_DiscoverCard> {
  int _photoIndex = 0;

  List<String> _buildPhotoList() {
    final extra = widget.profile['discoverPhotos'];
    final list = <String>[];
    if (extra is List) {
      for (final p in extra) {
        if (p is String && p.isNotEmpty) list.add(p);
      }
    }
    final main = widget.profile['photoURL'] as String?;
    if (main != null && main.isNotEmpty && !list.contains(main)) {
      list.insert(0, main);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final name = _firstName(profile);
    final username = (profile['username'] as String?) ?? '';
    final bio = (profile['bio'] as String?) ?? '';
    final edad = profile['edad'] as int?;
    final pais = profile['paisOrigen'] as String?;
    final flag = profile['countryFlag'] as String?;
    final ciudad = profile['ciudadActual'] as String?;
    final objetivo = profile['migracionObjetivo'] as String?;
    final ciudades = profile['ciudadesVividas'] as List?;
    final areas = List<String>.from(profile['areasAyuda'] as List? ?? []);
    final photos = _buildPhotoList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Foto actual ─────────────────────────────────────────────────
          photos.isNotEmpty
              ? Image.network(
                  photos[_photoIndex],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildGradientBg(name),
                )
              : _buildGradientBg(name),

          // ── Degradado inferior ──────────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.35, 0.7, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),

          // ── Indicadores de fotos (top) ──────────────────────────────────
          if (widget.isTop && photos.length > 1)
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                children: List.generate(photos.length, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(right: i < photos.length - 1 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: i == _photoIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

          // ── Zonas de tap para navegar fotos ────────────────────────────
          if (widget.isTop && photos.length > 1)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_photoIndex > 0) {
                          setState(() => _photoIndex--);
                        }
                      },
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_photoIndex < photos.length - 1) {
                          setState(() => _photoIndex++);
                        }
                      },
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),
                ],
              ),
            ),

          // ── Indicador LIKE / NOPE ───────────────────────────────────────
          if (widget.isTop && widget.swipeProgress.abs() > 0.1) ...[
            Positioned(
              top: 40,
              left: 20,
              child: AnimatedOpacity(
                duration: Duration.zero,
                opacity: widget.swipeProgress.clamp(0, 1),
                child: Transform.rotate(
                  angle: -0.2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(color: _teal, width: 3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'LIKE',
                      style: TextStyle(
                        color: _teal,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: AnimatedOpacity(
                duration: Duration.zero,
                opacity: (-widget.swipeProgress).clamp(0, 1),
                child: Transform.rotate(
                  angle: 0.2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFEF4444), width: 3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NOPE',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // ── Info inferior ───────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          edad != null ? '$name, $edad' : name,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black45),
                            ],
                          ),
                        ),
                      ),
                      if (flag != null)
                        Text(flag, style: const TextStyle(fontSize: 26)),
                    ],
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (ciudad != null)
                        _CardBadge(icon: Icons.place_rounded, label: ciudad),
                      if (objetivo != null)
                        _CardBadge(
                          icon: Icons.flight_takeoff_rounded,
                          label: _objetivoLabel(objetivo),
                        ),
                      if (pais != null)
                        _CardBadge(
                          icon: Icons.flag_rounded,
                          label: pais,
                          color: _tealLight,
                        ),
                    ],
                  ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (ciudades != null && ciudades.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...ciudades.take(3).map((c) {
                            final m = c as Map?;
                            final emoji = m?['emoji'] as String? ?? '🌍';
                            final cName = m?['ciudad'] as String? ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '$emoji $cName',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (ciudades.length > 3)
                            Text(
                              '+${ciudades.length - 3}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (areas.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: areas
                          .take(3)
                          .map(
                            (a) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _teal.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                a,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBg(String name) {
    final colors = [
      [const Color(0xFF0D9488), const Color(0xFF134E4A)],
      [const Color(0xFF7C3AED), const Color(0xFF4C1D95)],
      [const Color(0xFFD97706), const Color(0xFF92400E)],
      [const Color(0xFFDB2777), const Color(0xFF831843)],
    ];
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors[idx],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _objetivoLabel(String o) {
    const map = {
      'trabajar': 'Trabajar',
      'estudiar': 'Estudiar',
      'emprender': 'Emprender',
      'familia': 'Familia',
      'residir': 'Residir',
      'nomada': 'Nómada digital',
    };
    return map[o] ?? o;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _CardBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CardBadge({
    required this.icon,
    required this.label,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.46),
      ),
    );
  }
}

class _MatchAvatar extends StatelessWidget {
  final String? photoURL;
  final String? name;
  final bool isMe;

  const _MatchAvatar({this.photoURL, this.name, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _tealLight, width: 3),
        boxShadow: [
          BoxShadow(
            color: _teal.withOpacity(0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: photoURL != null
            ? Image.network(photoURL!, fit: BoxFit.cover)
            : Container(
                color: const Color(0xFFCCFBF1),
                child: Center(
                  child: Text(
                    isMe
                        ? '😊'
                        : (name?.isNotEmpty == true
                            ? name![0].toUpperCase()
                            : '?'),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: _teal,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FiltersSheet — hoja de filtros configurables
// ─────────────────────────────────────────────────────────────────────────────

class _FiltersSheet extends StatefulWidget {
  final String? initialPais;
  final String? initialCiudad;
  final String? initialObjetivo;
  final int? initialEdadMin;
  final int? initialEdadMax;
  final String? initialGenero;
  final bool isOnboarding;
  final void Function(String?, String?, String?, int?, int?, String?) onApply;

  const _FiltersSheet({
    this.initialPais,
    this.initialCiudad,
    this.initialObjetivo,
    this.initialEdadMin,
    this.initialEdadMax,
    this.initialGenero,
    this.isOnboarding = false,
    required this.onApply,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String? _pais;
  late String? _ciudad;
  late String? _objetivo;
  late String? _genero;
  late RangeValues _edadRange;
  late TextEditingController _paisCtrl;
  late TextEditingController _ciudadCtrl;

  static const _objetivos = [
    ('trabajar', '💼', 'Trabajar'),
    ('estudiar', '🎓', 'Estudiar'),
    ('emprender', '🚀', 'Emprender'),
    ('familia', '👨‍👩‍👧', 'Familia'),
    ('residir', '🏠', 'Residir'),
    ('nomada', '💻', 'Nómada'),
  ];

  static const _generos = [
    ('masculino', '♂️', 'Hombre'),
    ('femenino', '♀️', 'Mujer'),
    ('no_binario', '⚧️', 'No binario'),
  ];

  @override
  void initState() {
    super.initState();
    _pais = widget.initialPais;
    _ciudad = widget.initialCiudad;
    _objetivo = widget.initialObjetivo;
    _genero = widget.initialGenero;
    _edadRange = RangeValues(
      (widget.initialEdadMin ?? 18).toDouble(),
      (widget.initialEdadMax ?? 60).toDouble(),
    );
    _paisCtrl = TextEditingController(text: _pais ?? '');
    _ciudadCtrl = TextEditingController(text: _ciudad ?? '');
  }

  @override
  void dispose() {
    _paisCtrl.dispose();
    _ciudadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Título
            Row(
              children: [
                Text(
                  widget.isOnboarding ? '👋 Configurá tu Discover' : 'Filtros',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _tealDark,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            if (widget.isOnboarding) ...[
              const SizedBox(height: 6),
              Text(
                'Ajustá tus preferencias para ver los nomads que más te interesan.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 22),

            // Género
            _SectionLabel(label: 'Mostrar'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _generos.map((g) {
                final sel = _genero == g.$1;
                return GestureDetector(
                  onTap: () => setState(() => _genero = sel ? null : g.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? _teal : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? _teal : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      '${g.$2} ${g.$3}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : _tealDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // País de origen
            _SectionLabel(label: 'País de origen'),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => _pais = v.trim().isEmpty ? null : v.trim(),
              controller: _paisCtrl,
              style: const TextStyle(fontSize: 14, color: _tealDark),
              decoration: _inputDecoration('Ej: Uruguay, Argentina, Venezuela…'),
            ),
            const SizedBox(height: 18),

            // Ciudad actual
            _SectionLabel(label: 'Ciudad actual'),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => _ciudad = v.trim().isEmpty ? null : v.trim(),
              controller: _ciudadCtrl,
              style: const TextStyle(fontSize: 14, color: _tealDark),
              decoration: _inputDecoration('Ej: Madrid, Barcelona, Montevideo…'),
            ),
            const SizedBox(height: 18),

            // Objetivo migratorio
            _SectionLabel(label: 'Objetivo migratorio'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _objetivos.map((o) {
                final sel = _objetivo == o.$1;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _objetivo = sel ? null : o.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? _teal : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? _teal : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      '${o.$2} ${o.$3}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : _tealDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            // Rango de edad
            _SectionLabel(label: 'Rango de edad'),
            const SizedBox(height: 4),
            Text(
              '${_edadRange.start.round()} – ${_edadRange.end.round()} años',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _teal,
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _teal,
                inactiveTrackColor: _tealBg,
                thumbColor: _teal,
                overlayColor: _teal.withOpacity(0.1),
                activeTickMarkColor: Colors.transparent,
                inactiveTickMarkColor: Colors.transparent,
                rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: RangeSlider(
                values: _edadRange,
                min: 18,
                max: 70,
                divisions: 52,
                onChanged: (v) => setState(() => _edadRange = v),
              ),
            ),
            const SizedBox(height: 8),

            // Limpiar filtros (solo si no es onboarding)
            if (!widget.isOnboarding)
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    _paisCtrl.clear();
                    _ciudadCtrl.clear();
                    setState(() {
                      _pais = null;
                      _ciudad = null;
                      _objetivo = null;
                      _genero = null;
                      _edadRange = const RangeValues(18, 60);
                    });
                    widget.onApply(null, null, null, null, null, null);
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: Color(0xFFEF4444)),
                  label: const Text(
                    'Limpiar todos los filtros',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // Aplicar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onApply(
                  _pais,
                  _ciudad,
                  _objetivo,
                  _edadRange.start.round(),
                  _edadRange.end.round(),
                  _genero,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.isOnboarding ? 'Empezar a descubrir ✈️' : 'Aplicar',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
        filled: true,
        fillColor: _tealBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _teal,
        letterSpacing: 0.3,
      ),
    );
  }
}

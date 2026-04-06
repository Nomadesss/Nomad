import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../feed/widgets/bottom_nav.dart';
import '../profile/visitor_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// map_screen.dart  –  Nomad App
// Pantalla de mapa para conectar migrantes entre sí y con lugares de interés.
//
// Características:
//  · Usuarios migrantes del mismo país de origen aparecen destacados
//  · Lugares de interés: consulados, embajadas, restaurantes típicos,
//    tiendas de productos del país, centros culturales, grupos de ayuda
//  · Filtros por categoría
//  · Panel inferior deslizable con detalle de cada marcador
//  · Solicitud de permiso de ubicación con explicación clara
//  · Compartir ubicación (toggle on/off en tiempo real)
// ─────────────────────────────────────────────────────────────────────────────

const _teal = Color(0xFF0D9488);
const _tealLight = Color(0xFF5EEAD4);
const _tealDark = Color(0xFF134E4A);
const _tealBg = Color(0xFFF0FAF9);
const _bgMain = Color(0xFFF8FFFE);

// ── Categorías de lugares de interés ────────────────────────────────────────

enum _PlaceCategory {
  migrantes,
  consulados,
  restaurantes,
  tiendas,
  centrosCulturales,
  ayuda,
}

extension _PlaceCategoryExt on _PlaceCategory {
  String get label {
    switch (this) {
      case _PlaceCategory.migrantes:
        return 'Migrantes';
      case _PlaceCategory.consulados:
        return 'Consulados';
      case _PlaceCategory.restaurantes:
        return 'Restaurantes';
      case _PlaceCategory.tiendas:
        return 'Tiendas';
      case _PlaceCategory.centrosCulturales:
        return 'Cultural';
      case _PlaceCategory.ayuda:
        return 'Ayuda';
    }
  }

  String get emoji {
    switch (this) {
      case _PlaceCategory.migrantes:
        return '🧑‍🤝‍🧑';
      case _PlaceCategory.consulados:
        return '🏛️';
      case _PlaceCategory.restaurantes:
        return '🍽️';
      case _PlaceCategory.tiendas:
        return '🛍️';
      case _PlaceCategory.centrosCulturales:
        return '🎭';
      case _PlaceCategory.ayuda:
        return '🤝';
    }
  }

  Color get color {
    switch (this) {
      case _PlaceCategory.migrantes:
        return _teal;
      case _PlaceCategory.consulados:
        return const Color(0xFF1D4ED8);
      case _PlaceCategory.restaurantes:
        return const Color(0xFFD97706);
      case _PlaceCategory.tiendas:
        return const Color(0xFF7C3AED);
      case _PlaceCategory.centrosCulturales:
        return const Color(0xFFDB2777);
      case _PlaceCategory.ayuda:
        return const Color(0xFF059669);
    }
  }
}

// ── Modelos ──────────────────────────────────────────────────────────────────

class _MapMarkerData {
  final String id;
  final LatLng position;
  final _PlaceCategory category;
  final String title;
  final String? subtitle;
  final String? photoURL;
  final String? userId; // solo para migrantes
  final String? countryFlag;
  final String? countryName;
  final String? distance; // calculada en tiempo real

  const _MapMarkerData({
    required this.id,
    required this.position,
    required this.category,
    required this.title,
    this.subtitle,
    this.photoURL,
    this.userId,
    this.countryFlag,
    this.countryName,
    this.distance,
  });

  _MapMarkerData copyWith({String? distance}) => _MapMarkerData(
    id: id,
    position: position,
    category: category,
    title: title,
    subtitle: subtitle,
    photoURL: photoURL,
    userId: userId,
    countryFlag: countryFlag,
    countryName: countryName,
    distance: distance ?? this.distance,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MapScreen
// ─────────────────────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  // ── Mapa ─────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  Position? _myPosition;
  bool _locationGranted = false;
  bool _locationLoading = true;
  bool _sharingLocation = false;

  // ── Datos ─────────────────────────────────────────────────────────────────
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _myCountryName;
  String? _myCountryFlag;

  List<_MapMarkerData> _allMarkers = [];
  Set<Marker> _gmapMarkers = {};

  // ── Filtros ────────────────────────────────────────────────────────────────
  final Set<_PlaceCategory> _activeFilters = {
    _PlaceCategory.migrantes,
    _PlaceCategory.consulados,
    _PlaceCategory.restaurantes,
  };

  // ── Panel inferior ─────────────────────────────────────────────────────────
  _MapMarkerData? _selectedMarker;
  late AnimationController _panelAnim;
  late Animation<double> _panelSlide;

  // ── Streams ────────────────────────────────────────────────────────────────
  StreamSubscription? _usersSub;

  @override
  void initState() {
    super.initState();
    _panelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _panelSlide = CurvedAnimation(
      parent: _panelAnim,
      curve: Curves.easeOutCubic,
    );
    _initLocation();
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _mapController?.dispose();
    _panelAnim.dispose();
    super.dispose();
  }

  // ── Inicialización de ubicación ───────────────────────────────────────────

  Future<void> _initLocation() async {
    setState(() => _locationLoading = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _locationLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locationLoading = false);
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _myPosition = pos;
        _locationGranted = true;
        _locationLoading = false;
      });
      await _loadMyProfile();
      await _loadMarkers();
      _listenToUsers();
    } catch (e) {
      debugPrint('[MapScreen] Error obteniendo ubicación: $e');
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  // ── Cargar perfil propio para filtrar por país ────────────────────────────

  Future<void> _loadMyProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return;

      // Intentar obtener país de origen de varias formas
      final ciudades = data['ciudadesVividas'] as List?;
      String? pais;
      String? flag;

      if (ciudades != null && ciudades.isNotEmpty) {
        final primero = ciudades.first as Map?;
        pais = primero?['pais'] as String?;
        flag = primero?['emoji'] as String?;
      }

      // Fallback a campo directo
      pais ??= data['paisOrigen'] as String?;
      flag ??= data['countryFlag'] as String?;

      if (mounted) {
        setState(() {
          _myCountryName = pais;
          _myCountryFlag = flag;
        });
      }
    } catch (e) {
      debugPrint('[MapScreen] Error cargando perfil: $e');
    }
  }

  // ── Cargar marcadores de lugares de interés ───────────────────────────────

  Future<void> _loadMarkers() async {
    if (_myPosition == null) return;

    // En producción esto vendría de una colección Firestore 'places'
    // o de la API de Google Places filtrada por tipo.
    // Aquí armamos marcadores de ejemplo cerca de la posición del usuario.
    final lat = _myPosition!.latitude;
    final lng = _myPosition!.longitude;

    final List<_MapMarkerData> places = [
      // Consulados / Embajadas
      _MapMarkerData(
        id: 'consulado_1',
        position: LatLng(lat + 0.01, lng + 0.015),
        category: _PlaceCategory.consulados,
        title: 'Consulado de México',
        subtitle: 'Av. Libertador 1234 · Lun–Vie 9–14h',
        countryFlag: '🇲🇽',
        countryName: 'México',
      ),
      _MapMarkerData(
        id: 'consulado_2',
        position: LatLng(lat - 0.008, lng + 0.012),
        category: _PlaceCategory.consulados,
        title: 'Embajada de Colombia',
        subtitle: 'Bulevar Artigas 1257 · Lun–Vie 8–13h',
        countryFlag: '🇨🇴',
        countryName: 'Colombia',
      ),
      _MapMarkerData(
        id: 'consulado_3',
        position: LatLng(lat + 0.005, lng - 0.018),
        category: _PlaceCategory.consulados,
        title: 'Consulado de Venezuela',
        subtitle: 'Dr. Luis Morquio 1496 · Lun–Jue 9–12h',
        countryFlag: '🇻🇪',
        countryName: 'Venezuela',
      ),
      // Restaurantes típicos
      _MapMarkerData(
        id: 'rest_1',
        position: LatLng(lat + 0.007, lng - 0.006),
        category: _PlaceCategory.restaurantes,
        title: 'El Rincón Venezolano',
        subtitle: 'Arepas, cachapas y más · Abierto ahora',
        countryFlag: '🇻🇪',
        countryName: 'Venezuela',
      ),
      _MapMarkerData(
        id: 'rest_2',
        position: LatLng(lat - 0.012, lng - 0.009),
        category: _PlaceCategory.restaurantes,
        title: 'Sabores de Colombia',
        subtitle: 'Bandeja paisa, ajiaco · Cierra 22h',
        countryFlag: '🇨🇴',
        countryName: 'Colombia',
      ),
      _MapMarkerData(
        id: 'rest_3',
        position: LatLng(lat + 0.014, lng + 0.007),
        category: _PlaceCategory.restaurantes,
        title: 'La Taquería MX',
        subtitle: 'Tacos, sopes, horchata · Abierto ahora',
        countryFlag: '🇲🇽',
        countryName: 'México',
      ),
      // Tiendas
      _MapMarkerData(
        id: 'tienda_1',
        position: LatLng(lat - 0.006, lng + 0.018),
        category: _PlaceCategory.tiendas,
        title: 'Supermercado Latino',
        subtitle: 'Productos importados de toda América',
        countryFlag: '🌎',
      ),
      _MapMarkerData(
        id: 'tienda_2',
        position: LatLng(lat + 0.018, lng - 0.012),
        category: _PlaceCategory.tiendas,
        title: 'Bazar Venezolano',
        subtitle: 'Harina P.A.N., papelón, café venezolano',
        countryFlag: '🇻🇪',
        countryName: 'Venezuela',
      ),
      // Centros culturales
      _MapMarkerData(
        id: 'cultural_1',
        position: LatLng(lat - 0.015, lng - 0.016),
        category: _PlaceCategory.centrosCulturales,
        title: 'Centro Cultural Latinoamericano',
        subtitle: 'Eventos, música, teatro · Entrada libre',
      ),
      _MapMarkerData(
        id: 'cultural_2',
        position: LatLng(lat + 0.009, lng + 0.02),
        category: _PlaceCategory.centrosCulturales,
        title: 'Casa de la Cultura Colombiana',
        subtitle: 'Clases de salsa, vallenato · Sab–Dom',
        countryFlag: '🇨🇴',
        countryName: 'Colombia',
      ),
      // Grupos de ayuda
      _MapMarkerData(
        id: 'ayuda_1',
        position: LatLng(lat - 0.011, lng + 0.005),
        category: _PlaceCategory.ayuda,
        title: 'ONG Migrantes Unidos',
        subtitle: 'Asesoría legal, trámites migratorios',
      ),
      _MapMarkerData(
        id: 'ayuda_2',
        position: LatLng(lat + 0.003, lng - 0.02),
        category: _PlaceCategory.ayuda,
        title: 'Centro de Integración Social',
        subtitle: 'Cursos de idioma, bolsa de trabajo',
      ),
    ];

    // Calcular distancias
    final withDist = places.map((p) {
      final dist = _distanceKm(
        _myPosition!.latitude,
        _myPosition!.longitude,
        p.position.latitude,
        p.position.longitude,
      );
      return p.copyWith(distance: _formatDist(dist));
    }).toList();

    if (mounted) {
      setState(() {
        _allMarkers = [
          ..._allMarkers.where((m) => m.category == _PlaceCategory.migrantes),
          ...withDist,
        ];
      });
      _rebuildGmapMarkers();
    }
  }

  // ── Escuchar usuarios con ubicación compartida ────────────────────────────

  void _listenToUsers() {
    final uid = _auth.currentUser?.uid;
    _usersSub = _firestore
        .collection('users')
        .where('sharingLocation', isEqualTo: true)
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          final migrants = <_MapMarkerData>[];
          for (final doc in snap.docs) {
            if (doc.id == uid) continue; // no mostrarme a mí mismo
            final data = doc.data();
            final lat = data['locationLat'] as double?;
            final lng = data['locationLng'] as double?;
            if (lat == null || lng == null) continue;

            final nombre =
                (data['displayName'] as String?)?.trim() ?? 'Usuario';
            final username = (data['username'] as String?) ?? '';
            final photo = data['photoURL'] as String?;
            final flag = data['countryFlag'] as String?;
            final pais = data['paisOrigen'] as String?;

            final dist = _myPosition != null
                ? _formatDist(
                    _distanceKm(
                      _myPosition!.latitude,
                      _myPosition!.longitude,
                      lat,
                      lng,
                    ),
                  )
                : null;

            // ¿Es del mismo país?
            final sameCountry =
                _myCountryName != null &&
                pais != null &&
                pais.toLowerCase() == _myCountryName!.toLowerCase();

            migrants.add(
              _MapMarkerData(
                id: doc.id,
                position: LatLng(lat, lng),
                category: _PlaceCategory.migrantes,
                title: nombre,
                subtitle:
                    '@$username${sameCountry ? ' · Tu compatriota 🤝' : ''}',
                photoURL: photo,
                userId: doc.id,
                countryFlag: flag,
                countryName: pais,
                distance: dist,
              ),
            );
          }

          setState(() {
            _allMarkers = [
              ...migrants,
              ..._allMarkers.where(
                (m) => m.category != _PlaceCategory.migrantes,
              ),
            ];
          });
          _rebuildGmapMarkers();
        });
  }

  // ── Construir marcadores de Google Maps ───────────────────────────────────

  void _rebuildGmapMarkers() {
    final filtered = _allMarkers
        .where((m) => _activeFilters.contains(m.category))
        .toList();

    final markers = filtered.map((m) {
      // Color del marcador según categoría
      final hue = _categoryHue(m.category);
      return Marker(
        markerId: MarkerId(m.id),
        position: m.position,
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        onTap: () => _selectMarker(m),
        infoWindow: InfoWindow.noText,
      );
    }).toSet();

    if (mounted) setState(() => _gmapMarkers = markers);
  }

  double _categoryHue(_PlaceCategory cat) {
    switch (cat) {
      case _PlaceCategory.migrantes:
        return BitmapDescriptor.hueGreen;
      case _PlaceCategory.consulados:
        return BitmapDescriptor.hueBlue;
      case _PlaceCategory.restaurantes:
        return BitmapDescriptor.hueOrange;
      case _PlaceCategory.tiendas:
        return BitmapDescriptor.hueViolet;
      case _PlaceCategory.centrosCulturales:
        return BitmapDescriptor.hueRose;
      case _PlaceCategory.ayuda:
        return BitmapDescriptor.hueCyan;
    }
  }

  // ── Seleccionar marcador → mostrar panel ──────────────────────────────────

  void _selectMarker(_MapMarkerData marker) {
    setState(() => _selectedMarker = marker);
    _panelAnim.forward();
    // Centrar mapa en el marcador, ligeramente hacia arriba para que el panel no tape
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(marker.position.latitude - 0.003, marker.position.longitude),
        15,
      ),
    );
  }

  void _closePanel() {
    _panelAnim.reverse().then((_) {
      if (mounted) setState(() => _selectedMarker = null);
    });
  }

  // ── Toggle compartir ubicación ────────────────────────────────────────────

  Future<void> _toggleSharingLocation() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final newVal = !_sharingLocation;
    setState(() => _sharingLocation = newVal);

    try {
      if (newVal && _myPosition != null) {
        await _firestore.collection('users').doc(uid).update({
          'sharingLocation': true,
          'locationLat': _myPosition!.latitude,
          'locationLng': _myPosition!.longitude,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('users').doc(uid).update({
          'sharingLocation': false,
        });
      }
    } catch (e) {
      debugPrint('[MapScreen] Error actualizando ubicación: $e');
      if (mounted) setState(() => _sharingLocation = !newVal);
    }
  }

  // ── Toggle filtro ─────────────────────────────────────────────────────────

  void _toggleFilter(_PlaceCategory cat) {
    setState(() {
      if (_activeFilters.contains(cat)) {
        if (_activeFilters.length > 1) _activeFilters.remove(cat);
      } else {
        _activeFilters.add(cat);
      }
    });
    _rebuildGmapMarkers();
    HapticFeedback.selectionClick();
  }

  // ── Helpers de distancia ──────────────────────────────────────────────────

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  String _formatDist(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgMain,
      extendBody: true,
      body: _locationLoading
          ? _buildLoadingState()
          : !_locationGranted
          ? _buildPermissionState()
          : _buildMap(),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }

  // ── Estado de carga ───────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _teal),
          SizedBox(height: 16),
          Text(
            'Obteniendo tu ubicación…',
            style: TextStyle(color: _tealDark, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Sin permiso de ubicación ──────────────────────────────────────────────

  Widget _buildPermissionState() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _tealBg,
                shape: BoxShape.circle,
                border: Border.all(color: _tealLight, width: 2),
              ),
              child: const Icon(
                Icons.location_off_rounded,
                size: 46,
                color: _teal,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Activá tu ubicación',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _tealDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Para ver migrantes cerca tuyo y lugares de interés '
              'necesitamos acceso a tu ubicación. '
              'Solo se comparte si vos lo activás.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _initLocation,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Permitir ubicación'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Geolocator.openAppSettings(),
              child: const Text(
                'Ir a configuración',
                style: TextStyle(color: _teal, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mapa principal ────────────────────────────────────────────────────────

  Widget _buildMap() {
    final initialPos = _myPosition != null
        ? LatLng(_myPosition!.latitude, _myPosition!.longitude)
        : const LatLng(-34.9011, -56.1645); // Montevideo por defecto

    return Stack(
      children: [
        // ── Google Map ───────────────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initialPos, zoom: 14),
          onMapCreated: (c) => _mapController = c,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: _gmapMarkers,
          onTap: (_) => _closePanel(),
          padding: const EdgeInsets.only(bottom: 160),
        ),

        // ── AppBar flotante ──────────────────────────────────────────────────
        Positioned(top: 0, left: 0, right: 0, child: _buildFloatingAppBar()),

        // ── Filtros de categoría ─────────────────────────────────────────────
        Positioned(top: 110, left: 0, right: 0, child: _buildFilterChips()),

        // ── Botones flotantes derecha ─────────────────────────────────────────
        Positioned(right: 14, bottom: 200, child: _buildFloatingButtons()),

        // ── Panel inferior deslizable ─────────────────────────────────────────
        if (_selectedMarker != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(_panelSlide),
              child: _buildDetailPanel(_selectedMarker!),
            ),
          ),

        // ── Leyenda de compatriotas (si hay del mismo país) ──────────────────
        if (_myCountryName != null &&
            _activeFilters.contains(_PlaceCategory.migrantes))
          Positioned(top: 164, left: 14, child: _buildCompatriotasLegend()),
      ],
    );
  }

  // ── AppBar flotante ───────────────────────────────────────────────────────

  Widget _buildFloatingAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              // Título
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mapa Nomad',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _tealDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Conectá con migrantes cerca tuyo',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              // Contador de usuarios visibles
              if (_activeFilters.contains(_PlaceCategory.migrantes))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _tealBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _tealLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        size: 14,
                        color: _teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_allMarkers.where((m) => m.category == _PlaceCategory.migrantes).length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _teal,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 10),
              // Botón de compartir ubicación
              GestureDetector(
                onTap: _toggleSharingLocation,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _sharingLocation ? _teal : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sharingLocation
                            ? Icons.location_on_rounded
                            : Icons.location_off_rounded,
                        size: 14,
                        color: _sharingLocation
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sharingLocation ? 'Visible' : 'Oculto',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _sharingLocation
                              ? Colors.white
                              : const Color(0xFF94A3B8),
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
    );
  }

  // ── Chips de filtro ───────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        children: _PlaceCategory.values.map((cat) {
          final active = _activeFilters.contains(cat);
          return GestureDetector(
            onTap: () => _toggleFilter(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? cat.color : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? cat.color : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Leyenda de compatriotas ───────────────────────────────────────────────

  Widget _buildCompatriotasLegend() {
    final compatriotas = _allMarkers
        .where(
          (m) =>
              m.category == _PlaceCategory.migrantes &&
              m.countryName?.toLowerCase() == _myCountryName?.toLowerCase(),
        )
        .length;

    if (compatriotas == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_myCountryFlag ?? '🌎', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            '$compatriotas compatriota${compatriotas > 1 ? 's' : ''} cerca',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _tealDark,
            ),
          ),
        ],
      ),
    );
  }

  // ── Botones flotantes ─────────────────────────────────────────────────────

  Widget _buildFloatingButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Centrar en mi ubicación
        _FloatBtn(
          icon: Icons.my_location_rounded,
          onTap: () {
            if (_myPosition != null) {
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(_myPosition!.latitude, _myPosition!.longitude),
                  15,
                ),
              );
            }
          },
        ),
        const SizedBox(height: 10),
        // Zoom in
        _FloatBtn(
          icon: Icons.add_rounded,
          onTap: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
        ),
        const SizedBox(height: 6),
        // Zoom out
        _FloatBtn(
          icon: Icons.remove_rounded,
          onTap: () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
        ),
      ],
    );
  }

  // ── Panel de detalle ──────────────────────────────────────────────────────

  Widget _buildDetailPanel(_MapMarkerData marker) {
    final isMigrante = marker.category == _PlaceCategory.migrantes;
    final sameCountry =
        _myCountryName != null &&
        marker.countryName != null &&
        marker.countryName!.toLowerCase() == _myCountryName!.toLowerCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────────
                Row(
                  children: [
                    // Avatar o ícono de categoría
                    isMigrante
                        ? _buildUserAvatar(marker)
                        : _buildCategoryIcon(marker),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  marker.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _tealDark,
                                  ),
                                ),
                              ),
                              if (marker.countryFlag != null)
                                Text(
                                  marker.countryFlag!,
                                  style: const TextStyle(fontSize: 18),
                                ),
                            ],
                          ),
                          if (marker.subtitle != null)
                            Text(
                              marker.subtitle!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          if (marker.distance != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 12,
                                  color: _teal,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${marker.distance} de distancia',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Cerrar
                    GestureDetector(
                      onTap: _closePanel,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),

                // ── Badge compatriota ───────────────────────────────────────
                if (sameCountry) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _tealBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _tealLight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🤝', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          '¡Compatriota de ${marker.countryName}!',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _tealDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Acciones ────────────────────────────────────────────────
                if (isMigrante)
                  Row(
                    children: [
                      Expanded(
                        child: _PanelAction(
                          icon: Icons.person_rounded,
                          label: 'Ver perfil',
                          color: _teal,
                          filled: true,
                          onTap: () {
                            _closePanel();
                            if (marker.userId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VisitorProfileScreen(
                                    targetUserId: marker.userId!,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PanelAction(
                          icon: Icons.mail_outline_rounded,
                          label: 'Mensaje',
                          color: _teal,
                          filled: false,
                          onTap: () {
                            _closePanel();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Abriendo chat con ${marker.title}…',
                                ),
                                backgroundColor: _teal,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _PanelAction(
                          icon: Icons.directions_rounded,
                          label: 'Cómo llegar',
                          color: marker.category.color,
                          filled: true,
                          onTap: () {
                            // TODO: abrir Google Maps con la ruta
                            _closePanel();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PanelAction(
                          icon: Icons.share_rounded,
                          label: 'Compartir',
                          color: marker.category.color,
                          filled: false,
                          onTap: () => _closePanel(),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(_MapMarkerData marker) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [_teal, _tealLight]),
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFFCCFBF1),
        backgroundImage: marker.photoURL != null
            ? NetworkImage(marker.photoURL!)
            : null,
        child: marker.photoURL == null
            ? Text(
                marker.title.isNotEmpty ? marker.title[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _teal,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildCategoryIcon(_MapMarkerData marker) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: marker.category.color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          marker.category.emoji,
          style: const TextStyle(fontSize: 26),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _FloatBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: _tealDark),
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _PanelAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

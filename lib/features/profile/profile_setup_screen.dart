import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:country_picker/country_picker.dart';

import '../../services/location_service.dart';
import '../../services/trust_score_service.dart';
import '../feed/feed_screen.dart';
import '../profile/profile_photo_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  int step = 0;

  final usernameController = TextEditingController();

  String usernameError = "";
  bool usernameAvailable = false;
  bool checkingUsername = false;

  String? selectedCountry;
  String? countryCode;

  LocationData? _locationData;
  bool _loadingLocation = false;

  bool amistad = false;
  bool citas = false;
  bool servicios = false;
  bool foros = false;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _debounceTimer?.cancel();
    usernameController.dispose();
    super.dispose();
  }

  // ── Lógica (sin cambios) ──────────────────────────────────────

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();
    final username = value.trim();

    // Reset inmediato mientras escribe
    setState(() {
      usernameAvailable = false;
      usernameError = "";
      checkingUsername = username.length >= 3;
    });

    if (username.length < 3) return;

    // Esperar 600ms sin escribir antes de consultar Firestore
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      final regex = RegExp(r'^[a-zA-Z0-9_]{6,15}$');

      if (!regex.hasMatch(username)) {
        setState(() {
          usernameError = "Entre 6 y 15 caracteres, solo letras, números y _";
          usernameAvailable = false;
          checkingUsername = false;
        });
        return;
      }

      final result = await FirebaseFirestore.instance
          .collection("users")
          .where("username", isEqualTo: username)
          .get();

      if (!mounted) return;

      if (result.docs.isNotEmpty) {
        setState(() {
          usernameError = "Username ya utilizado";
          usernameAvailable = false;
          checkingUsername = false;
        });
      } else {
        setState(() {
          usernameError = "";
          usernameAvailable = true;
          checkingUsername = false;
        });
      }
    });
  }

  Future<void> getLocation() async {
    setState(() => _loadingLocation = true);

    try {
      final data = await LocationService.collect();
      if (mounted)
        setState(() {
          _locationData = data;
          _loadingLocation = false;
        });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo obtener la ubicación"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Calcular score en el cliente
    final location = _locationData ?? LocationData();
    final scoreResult = TrustScoreService.calculate(
      location: location,
      user: user,
    );

    // Guardar perfil + ubicación + score preliminar en Firestore
    await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
      "username": usernameController.text.trim(),
      "country": selectedCountry,
      "countryCode": countryCode,
      "location": location.toMap(),
      "trustScore": {...scoreResult.toMap(), "pendingCloudValidation": true},
    }, SetOptions(merge: true));

    // Llamar a la Cloud Function para validación server-side
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      await functions.httpsCallable('validateTrustScore').call({
        'uid': user.uid,
        'locationData': location.toMap(),
        'clientScore': scoreResult.score,
      });
    } catch (_) {
      // Si la Cloud Function falla, el score del cliente ya está guardado
      // La función puede reintentarse más tarde
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePhotoScreen()),
    );
  }

  void nextStep() {
    if (step == 0 && !usernameAvailable) return;
    if (step < 3) {
      setState(() => step++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePhotoScreen()),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Stack(
        children: [
          // ── Fondo: imagen de ciudad difuminada ────────────────
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800&q=60',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F0F1A),
                      Color(0xFF1A1A2E),
                      Color(0xFF0F1A14),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Blur sobre la imagen
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),

          // Degradado inferior para que el contenido resalte
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0xCC0F0F14),
                    Color(0xFF0F0F14),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ── Contenido ─────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Logo
                    Hero(
                      tag: "logo",
                      child: Material(
                        color: Colors.transparent,
                        child: const Text(
                          "Nomad",
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Paso ${step + 1} de 4",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Indicador de pasos
                    _progressIndicator(),

                    const SizedBox(height: 36),

                    // Paso actual
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0.05, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Center(child: buildStep()),
                      ),
                    ),

                    // Botón continuar
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5C6EF5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          step == 3 ? "Finalizar" : "Continuar",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Indicador de pasos ────────────────────────────────────────

  Widget _progressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final active = index <= step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: active ? 28 : 10,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF5C6EF5)
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }

  Widget buildStep() {
    switch (step) {
      case 0:
        return usernameStep();
      case 1:
        return countryStep();
      case 2:
        return locationStep();
      case 3:
        return interestsStep();
      default:
        return Container();
    }
  }

  // ── Step 0: Username ──────────────────────────────────────────

  Widget usernameStep() {
    return Column(
      key: const ValueKey(0),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Elegí tu username",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          "Este será tu nombre único en Nomad",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),

        const SizedBox(height: 24),

        TextField(
          controller: usernameController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          onChanged: _onUsernameChanged,
          decoration: InputDecoration(
            hintText: "ej: juan_gomez",
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.alternate_email,
              color: Colors.white.withValues(alpha: 0.35),
              size: 20,
            ),
            suffixIcon: checkingUsername
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF5C6EF5),
                      ),
                    ),
                  )
                : usernameAvailable
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF27AE60),
                    size: 20,
                  )
                : usernameError.isNotEmpty
                ? const Icon(
                    Icons.cancel_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.07),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: usernameError.isNotEmpty
                    ? Colors.redAccent
                    : usernameAvailable
                    ? const Color(0xFF27AE60)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: usernameError.isNotEmpty
                    ? Colors.redAccent
                    : usernameAvailable
                    ? const Color(0xFF27AE60)
                    : const Color(0xFF5C6EF5),
                width: 1.5,
              ),
            ),
          ),
        ),

        if (usernameError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.cancel_rounded,
                  color: Colors.redAccent,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  usernameError,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

        if (usernameAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: const [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF27AE60),
                  size: 13,
                ),
                SizedBox(width: 4),
                Text(
                  "Username disponible",
                  style: TextStyle(
                    color: Color(0xFF27AE60),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        if (!checkingUsername &&
            !usernameAvailable &&
            usernameError.isEmpty &&
            usernameController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              "Mínimo 6 caracteres, solo letras, números y _",
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
      ],
    );
  }

  // ── Step 1: País ──────────────────────────────────────────────

  Widget countryStep() {
    void openCountrySelector() {
      final searchController = TextEditingController();
      List<Country> allCountries = CountryService().getAll();
      List<Country> filtered = List.from(allCountries);
      const suggested = ['AR', 'UY', 'MX', 'CO', 'CL', 'ES', 'US'];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1A1A2E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.8,
                maxChildSize: 0.95,
                minChildSize: 0.5,
                builder: (_, scrollController) {
                  return Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 8),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Text(
                          '¿De qué país sos?',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: TextField(
                          controller: searchController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar país...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.07),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF5C6EF5),
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (v) {
                            setModalState(() {
                              filtered = allCountries
                                  .where(
                                    (c) => c.name.toLowerCase().contains(
                                      v.toLowerCase(),
                                    ),
                                  )
                                  .toList();
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            if (searchController.text.isEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Sugeridos',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    letterSpacing: 0.08,
                                  ),
                                ),
                              ),
                              ...allCountries
                                  .where(
                                    (c) => suggested.contains(c.countryCode),
                                  )
                                  .map(
                                    (c) => _countryTile(c, () {
                                      Navigator.pop(context);
                                      setState(() {
                                        selectedCountry = c.name;
                                        countryCode = c.countryCode;
                                      });
                                    }),
                                  ),
                              Divider(
                                color: Colors.white.withValues(alpha: 0.1),
                                height: 24,
                              ),
                            ],
                            ...filtered
                                .where(
                                  (c) =>
                                      searchController.text.isNotEmpty ||
                                      !suggested.contains(c.countryCode),
                                )
                                .map(
                                  (c) => _countryTile(c, () {
                                    Navigator.pop(context);
                                    setState(() {
                                      selectedCountry = c.name;
                                      countryCode = c.countryCode;
                                    });
                                  }),
                                ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      );
    }

    return Column(
      key: const ValueKey(1),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "¿De qué país sos?",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          "Tu nacionalidad conecta con tu comunidad",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),

        const SizedBox(height: 24),

        GestureDetector(
          onTap: openCountrySelector,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: countryCode != null
                    ? const Color(0xFF5C6EF5).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.public,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 20,
                ),
                const SizedBox(width: 12),
                if (countryCode != null) ...[
                  Text(
                    Country.parse(countryCode!).flagEmoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  selectedCountry ?? "Seleccionar país",
                  style: TextStyle(
                    fontSize: 15,
                    color: selectedCountry != null
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.expand_more_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _countryTile(Country country, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: ListTile(
        dense: true,
        leading: Text(country.flagEmoji, style: const TextStyle(fontSize: 22)),
        title: Text(
          country.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  // ── Step 2: Ubicación ─────────────────────────────────────────

  Widget locationStep() {
    final loc = _locationData;
    final hasGPS = loc != null && loc.gpsGranted && loc.lat != null;
    final hasIP = loc != null && loc.ipResolved;

    return Column(
      key: const ValueKey(2),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF5C6EF5).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF5C6EF5).withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: Color(0xFF5C6EF5),
            size: 28,
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          "Tu ubicación actual",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          "Conectate con compatriotas cerca y construí tu score de confianza.",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),

        const SizedBox(height: 24),

        // Botón detectar
        SizedBox(
          width: double.infinity,
          height: 48,
          child: _loadingLocation
              ? Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF5C6EF5).withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF5C6EF5),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Detectando...",
                          style: TextStyle(
                            color: Color(0xFF5C6EF5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: getLocation,
                  icon: Icon(
                    loc == null
                        ? Icons.my_location_rounded
                        : Icons.refresh_rounded,
                    size: 18,
                  ),
                  label: Text(
                    loc == null
                        ? "Detectar mi ubicación"
                        : "Actualizar ubicación",
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5C6EF5),
                    side: const BorderSide(color: Color(0xFF5C6EF5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
        ),

        if (loc != null) ...[
          const SizedBox(height: 16),

          // GPS
          _locationSignalTile(
            icon: Icons.gps_fixed_rounded,
            title: hasGPS
                ? '${loc.city ?? 'Ciudad desconocida'}, ${loc.country ?? ''}'
                : 'GPS no disponible',
            subtitle: hasGPS
                ? 'Precisión: ${loc.accuracy?.toStringAsFixed(0) ?? '?'} m'
                : 'Permiso denegado o servicio apagado',
            ok: hasGPS,
          ),

          const SizedBox(height: 8),

          // IP
          _locationSignalTile(
            icon: Icons.language_rounded,
            title: hasIP
                ? 'IP: ${loc.ipAddress ?? ''} · ${loc.ipCountry ?? ''}'
                : 'IP no resuelta',
            subtitle: hasIP
                ? loc.ipOrg ?? 'Operadora desconocida'
                : 'Sin conexión o timeout',
            ok: hasIP,
          ),

          const SizedBox(height: 8),

          // Timezone
          _locationSignalTile(
            icon: Icons.access_time_rounded,
            title: 'Zona horaria: ${loc.timezone ?? 'Desconocida'}',
            subtitle:
                'UTC ${loc.timezoneOffsetMinutes >= 0 ? '+' : ''}'
                '${(loc.timezoneOffsetMinutes / 60).toStringAsFixed(1)}h',
            ok: loc.timezone != null,
          ),

          if (hasGPS &&
              hasIP &&
              loc.countryCode != null &&
              loc.ipCountryCode != null &&
              loc.countryCode!.toLowerCase() !=
                  loc.ipCountryCode!.toLowerCase()) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tu IP indica ${loc.ipCountry} pero tu GPS indica ${loc.country}. '
                      'Esto puede bajar tu score de confianza.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.orange.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _locationSignalTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool ok,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ok
            ? const Color(0xFF1A3A2A)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok
              ? const Color(0xFF27AE60).withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: ok
                ? const Color(0xFF27AE60)
                : Colors.white.withValues(alpha: 0.35),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ok
                        ? const Color(0xFF27AE60)
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: ok
                ? const Color(0xFF27AE60)
                : Colors.white.withValues(alpha: 0.2),
            size: 16,
          ),
        ],
      ),
    );
  }

  // ── Step 3: Intereses ─────────────────────────────────────────

  Widget interestsStep() {
    return Column(
      key: const ValueKey(3),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "¿Qué buscás en Nomad?",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          "Podés elegir más de una opción",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),

        const SizedBox(height: 24),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _interestChip(
              "🤝 Amistad",
              amistad,
              () => setState(() => amistad = !amistad),
            ),
            _interestChip(
              "💘 Citas",
              citas,
              () => setState(() => citas = !citas),
            ),
            _interestChip(
              "🛠 Servicios",
              servicios,
              () => setState(() => servicios = !servicios),
            ),
            _interestChip(
              "💬 Foros",
              foros,
              () => setState(() => foros = !foros),
            ),
          ],
        ),
      ],
    );
  }

  Widget _interestChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: selected
              ? const Color(0xFF5C6EF5)
              : Colors.white.withValues(alpha: 0.07),
          border: Border.all(
            color: selected
                ? const Color(0xFF5C6EF5)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

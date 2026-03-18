import 'dart:async';
import 'dart:math' show cos, sin, pi;
import 'dart:ui' show lerpDouble, ImageFilter;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:country_picker/country_picker.dart';

import '../../services/location_service.dart';
import '../../services/trust_score_service.dart';
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
  bool _showCountryList = false;
  String _countrySearch = '';

  LocationData? _locationData;
  bool _loadingLocation = false;
  String? _locationPermission; // 'always' | 'inUse' | 'denied' | null

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
    if (!_canContinue()) return;
    if (step < 3) {
      setState(() => step++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePhotoScreen()),
      );
    }
  }

  bool _canContinue() {
    switch (step) {
      case 0:
        return usernameAvailable && usernameError.isEmpty;
      case 1:
        return countryCode != null;
      case 2:
        return _locationPermission != null && _locationPermission != 'denied';
      case 3:
        return amistad || citas || servicios || foros;
      default:
        return false;
    }
  }

  void _showLocationPermissionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(color: Color(0xFF0F0F14)),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            const Text(
              "Nomad quiere acceder a tu ubicación",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.8,
                height: 1.15,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              "Tu ubicación nos ayuda a conectarte con compatriotas cercanos. No compartimos tu posición exacta.",
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.5,
              ),
            ),

            const Spacer(),

            _permissionOption(
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF38BDF8),
              iconBg: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              title: "Permitir mi ubicación",
              subtitle: "Acceso completo mientras usás la app",
              onTap: () {
                Navigator.pop(context);
                setState(() => _locationPermission = 'always');
                getLocation();
              },
            ),

            const SizedBox(height: 12),

            _permissionOption(
              icon: Icons.refresh_rounded,
              iconColor: const Color(0xFF5C6EF5),
              iconBg: const Color(0xFF5C6EF5).withValues(alpha: 0.15),
              title: "Permitir solo al usar",
              subtitle: "Solo cuando Nomad esté abierta",
              onTap: () {
                Navigator.pop(context);
                setState(() => _locationPermission = 'inUse');
                getLocation();
              },
            ),

            const SizedBox(height: 12),

            _permissionOption(
              icon: Icons.block_rounded,
              iconColor: const Color(0xFFEF4444),
              iconBg: const Color(0xFFEF4444).withValues(alpha: 0.1),
              title: "No permitir",
              subtitle: "No podrás avanzar al siguiente paso",
              titleColor: const Color(0xFFEF4444),
              onTap: () {
                Navigator.pop(context);
                setState(() => _locationPermission = 'denied');
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _permissionOption({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.25),
              size: 20,
            ),
          ],
        ),
      ),
    );
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
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: buildStep(),
                        ),
                      ),
                    ),

                    // Botón continuar
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _canContinue() ? nextStep : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5C6EF5),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white.withValues(
                            alpha: 0.15,
                          ),
                          disabledForegroundColor: Colors.white.withValues(
                            alpha: 0.35,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          step == 3 ? "Continuar" : "Continuar",
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
          "Elige tu nombre de usuario",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          "Este será tu nombre único en Nomad",
          style: TextStyle(
            fontSize: 18,
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
    final allCountries = CountryService().getAll();
    final filtered = _countrySearch.isEmpty
        ? allCountries
        : allCountries
              .where(
                (c) =>
                    c.name.toLowerCase().contains(_countrySearch.toLowerCase()),
              )
              .toList();

    return Column(
      key: const ValueKey(1),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "¿Cuál es tu nacionalidad?",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          "Conectate con tu gente",
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),

        const SizedBox(height: 24),

        // Campo selector
        GestureDetector(
          onTap: () => setState(() {
            _showCountryList = !_showCountryList;
            _countrySearch = '';
          }),
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _showCountryList
                    ? const Color(0xFF5C6EF5)
                    : countryCode != null
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
                AnimatedRotation(
                  turns: _showCountryList ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Lista inline — aparece directamente sin animación
        if (_showCountryList) ...[
          const SizedBox(height: 8),

          // Buscador
          TextField(
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
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
            onChanged: (v) => setState(() => _countrySearch = v),
          ),

          const SizedBox(height: 6),

          // Lista de países con altura fija
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final c = filtered[i];
                return ListTile(
                  dense: true,
                  leading: Text(
                    c.flagEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Text(
                    c.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => setState(() {
                    selectedCountry = c.name;
                    countryCode = c.countryCode;
                    _showCountryList = false;
                    _countrySearch = '';
                  }),
                );
              },
            ),
          ),
        ],
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

    return Column(
      key: const ValueKey(2),
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tu ubicación actual",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          "Acercate a tus compatriotas",
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),

        const SizedBox(height: 60),

        // Círculo de geolocalización centrado
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _loadingLocation
                    ? null
                    : () => _showLocationPermissionDialog(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_loadingLocation)
                      SizedBox(
                        width: 224,
                        height: 224,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.7),
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _locationPermission == 'denied'
                            ? const Color(0xFF3A1E1E)
                            : loc != null
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFF1E3A5F),
                        border: Border.all(
                          color: _locationPermission == 'denied'
                              ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                              : Colors.white.withValues(
                                  alpha: loc != null ? 0.9 : 0.45,
                                ),
                          width: loc != null ? 2.5 : 2.0,
                        ),
                      ),
                      child: Center(
                        child: _loadingLocation
                            ? const SizedBox(
                                width: 56,
                                height: 56,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF38BDF8),
                                ),
                              )
                            : GeoLocationIcon(active: loc != null),
                      ),
                    ),
                    if (loc != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: AnimatedScale(
                          scale: 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0EA5E9),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.check_rounded,
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

              const SizedBox(height: 20),

              Text(
                _loadingLocation
                    ? "Detectando..."
                    : _locationPermission == 'denied'
                    ? "Permiso denegado"
                    : loc != null
                    ? "Toca para actualizar"
                    : "Geolocalizarme",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _locationPermission == 'denied'
                      ? const Color(0xFFEF4444)
                      : Colors.white,
                ),
              ),

              if (loc != null && hasGPS) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF27AE60).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.gps_fixed_rounded,
                        color: Color(0xFF27AE60),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${loc.city ?? 'Ciudad desconocida'}, ${loc.country ?? ''}',
                        style: const TextStyle(
                          color: Color(0xFF27AE60),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "¿Qué buscás en Nomad?",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          "Podés elegir más de una opción",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),

        const SizedBox(height: 40),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _interestCard(
                icon: HugAnimationWidget(hugging: amistad),
                label: 'Amistad',
                desc: 'Conoce compatriotas',
                selected: amistad,
                onTap: () => setState(() => amistad = !amistad),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _interestCard(
                icon: HeartbeatWidget(beating: citas),
                label: 'Citas',
                desc: 'Conecta romanticamante',
                selected: citas,
                onTap: () => setState(() => citas = !citas),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _interestCard(
                icon: BriefcaseWidget(animating: servicios),
                label: 'Servicios',
                desc: 'Empleo y trámites',
                selected: servicios,
                onTap: () => setState(() => servicios = !servicios),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _interestCard(
                icon: MegaphoneWidget(animating: foros),
                label: 'Foros',
                desc: 'Únete a la charla',
                selected: foros,
                onTap: () => setState(() => foros = !foros),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _interestCard({
    required Widget icon,
    required String label,
    required String desc,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const circleBg = Color(0xFF1E3A5F);
    const circleBgSelected = Color(0xFF1E3A8A);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? circleBgSelected : circleBg,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: selected ? 0.9 : 0.45,
                    ),
                    width: selected ? 2.5 : 2.0,
                  ),
                ),
                child: Center(child: icon),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: AnimatedScale(
                  scale: selected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0EA5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.45),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animación del abrazo (CustomPainter) ──────────────────────

class HugAnimationWidget extends StatefulWidget {
  final bool hugging;
  const HugAnimationWidget({super.key, required this.hugging});

  @override
  State<HugAnimationWidget> createState() => _HugAnimationWidgetState();
}

class _HugAnimationWidgetState extends State<HugAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

    if (widget.hugging) _startLoop();
  }

  @override
  void didUpdateWidget(HugAnimationWidget old) {
    super.didUpdateWidget(old);
    if (widget.hugging && !old.hugging) _startLoop();
    if (!widget.hugging && old.hugging) _stopLoop();
  }

  void _startLoop() {
    _ctrl.forward(from: 0).then((_) {
      if (!mounted || !widget.hugging) return;
      // pausa 600ms en el abrazo luego vuelve a separarse
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted || !widget.hugging) return;
        _ctrl.reverse().then((_) {
          if (!mounted || !widget.hugging) return;
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!mounted || !widget.hugging) return;
            _startLoop();
          });
        });
      });
    });
  }

  void _stopLoop() {
    _ctrl.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.scale(
        scale: 1.28,
        child: CustomPaint(
          size: const Size(84, 84),
          painter: _HugPainter(_anim.value),
        ),
      ),
    );
  }
}

class _HugPainter extends CustomPainter {
  final double p;
  const _HugPainter(this.p);

  double _ease(double t) => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final e = _ease(p.clamp(0.0, 1.0));
    final w = size.width;
    final h = size.height;
    final cxc = w / 2;
    final groundY = h - 2;
    const headR = 7.0;
    // Centro visual del dibujo: punto medio entre tope de cabeza y pies
    // headY = groundY - 26, tope = headY - headR, base = groundY
    // midY = (tope + base) / 2 = groundY - 26 - headR + (26 + headR) / 2
    final figureMidY = groundY - (26.0 + headR) / 2;
    final verticalOffset = h / 2 - figureMidY;
    canvas.save();
    canvas.translate(0, verticalOffset);
    final headY = groundY - 26;
    final lx = _lerp(cxc - 14, cxc, e);
    final rx = _lerp(cxc + 14, cxc, e);

    const colL = Color(0xFF38BDF8);
    const colR = Color(0xFF0284C7);

    final paintL = Paint()
      ..color = colL
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final paintR = Paint()
      ..color = colR
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final fillL = Paint()
      ..color = colL
      ..style = PaintingStyle.fill;
    final fillR = Paint()
      ..color = colR
      ..style = PaintingStyle.fill;

    final armLen = _lerp(10.0, 14.0, e);
    final lAngle = _lerp(-0.5, 0.9, e);
    final rAngle = _lerp(3.14 + 0.5, 3.14 - 0.9, e);
    final headOffX = _lerp(0, 6.0, e);

    // Figura izquierda
    canvas.drawLine(
      Offset(lx, headY + headR * 2 + 1),
      Offset(
        lx + cos(lAngle) * armLen,
        headY + headR * 2 + 1 + sin(lAngle) * armLen,
      ),
      paintL,
    );
    canvas.drawLine(
      Offset(lx, groundY - 10),
      Offset(lx - 4.0, groundY),
      paintL,
    );
    canvas.drawLine(
      Offset(lx, groundY - 10),
      Offset(lx + 2.5, groundY),
      paintL,
    );
    canvas.drawLine(
      Offset(lx, headY + headR * 2),
      Offset(lx, groundY - 10),
      paintL,
    );
    canvas.drawCircle(Offset(lx, headY), headR, fillL);

    // Figura derecha
    canvas.drawLine(
      Offset(rx, headY + headR * 2 + 1),
      Offset(
        rx + cos(rAngle) * armLen,
        headY + headR * 2 + 1 + sin(rAngle) * armLen,
      ),
      paintR,
    );
    canvas.drawLine(
      Offset(rx, groundY - 10),
      Offset(rx + 4.0, groundY),
      paintR,
    );
    canvas.drawLine(
      Offset(rx, groundY - 10),
      Offset(rx - 2.5, groundY),
      paintR,
    );
    canvas.drawLine(
      Offset(rx, headY + headR * 2),
      Offset(rx, groundY - 10),
      paintR,
    );
    canvas.drawCircle(Offset(rx + headOffX, headY), headR, fillR);

    // Brazos cruzados
    if (e > 0.5) {
      final a2 = _ease((e - 0.5) / 0.5);

      final paintLArm = Paint()
        ..color = colL.withValues(alpha: a2 * 0.9)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final paintRArm = Paint()
        ..color = colR.withValues(alpha: a2)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path1 = Path()
        ..moveTo(cxc - 2.5, headY + headR * 2 + 1)
        ..cubicTo(
          cxc + 5,
          headY + headR * 2 + 5,
          cxc + 12,
          headY + headR * 2 + 8,
          cxc + 9,
          headY + headR * 2 + 14,
        );
      canvas.drawPath(path1, paintLArm);

      final path2 = Path()
        ..moveTo(cxc + 2.5, headY + headR * 2 + 1)
        ..cubicTo(
          cxc - 5,
          headY + headR * 2 + 5,
          cxc - 12,
          headY + headR * 2 + 8,
          cxc - 9,
          headY + headR * 2 + 14,
        );
      canvas.drawPath(path2, paintRArm);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HugPainter old) => old.p != p;
}

// ── Corazón con latido (CustomPainter) ───────────────────────

class HeartbeatWidget extends StatefulWidget {
  final bool beating;
  const HeartbeatWidget({super.key, required this.beating});

  @override
  State<HeartbeatWidget> createState() => _HeartbeatWidgetState();
}

class _HeartbeatWidgetState extends State<HeartbeatWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _beatScale = 1.0;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _ctrl.addListener(_onTick);
    if (widget.beating) _startBeating();
  }

  @override
  void didUpdateWidget(HeartbeatWidget old) {
    super.didUpdateWidget(old);
    if (widget.beating && !old.beating) _startBeating();
    if (!widget.beating && old.beating) _stopBeating();
  }

  void _startBeating() {
    _running = true;
    _ctrl.repeat();
  }

  void _stopBeating() {
    _running = false;
    _ctrl.stop();
    if (mounted) setState(() => _beatScale = 1.0);
  }

  void _onTick() {
    if (!_running || !mounted) return;
    final tc = _ctrl.value;
    double s;
    if (tc < 0.12)
      s = 1.0 + sin(tc / 0.12 * pi) * 0.32;
    else if (tc < 0.22)
      s = lerpDouble(1.0, 0.88, (tc - 0.12) / 0.10)!;
    else if (tc < 0.34)
      s = 0.88 + sin((tc - 0.22) / 0.12 * pi) * 0.20;
    else
      s = lerpDouble(1.02, 1.0, (tc - 0.34) / 0.66)!;
    setState(() => _beatScale = s);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(84, 84),
      painter: _HeartPainter(_beatScale),
    );
  }
}

class _HeartPainter extends CustomPainter {
  final double scale;
  const _HeartPainter(this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 2;
    const s = 22.0;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale, scale);
    canvas.translate(-cx, -cy);

    final ox = cx - s * 0.9;
    final oy = cy - s * 0.72;

    final path = Path()
      ..moveTo(ox + s * 0.9, oy + s * 0.35)
      ..cubicTo(
        ox + s * 0.85,
        oy - s * 0.05,
        ox,
        oy - s * 0.05,
        ox,
        oy + s * 0.45,
      )
      ..cubicTo(
        ox,
        oy + s * 1.1,
        ox + s * 0.9,
        oy + s * 1.45,
        ox + s * 0.9,
        oy + s * 1.45,
      )
      ..cubicTo(
        ox + s * 0.9,
        oy + s * 1.45,
        ox + s * 1.8,
        oy + s * 1.1,
        ox + s * 1.8,
        oy + s * 0.45,
      )
      ..cubicTo(
        ox + s * 1.8,
        oy - s * 0.05,
        ox + s * 0.95,
        oy - s * 0.05,
        ox + s * 0.9,
        oy + s * 0.35,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF6366F1)
        ..style = PaintingStyle.fill,
    );

    // brillo interno
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 5, cy - 7), width: 11, height: 6),
      Paint()
        ..color = const Color(0xFFA5B4FC).withValues(alpha: 0.38)
        ..style = PaintingStyle.fill,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeartPainter old) => old.scale != scale;
}

// ── Maletín con documento saliendo (CustomPainter) ────────────

class BriefcaseWidget extends StatefulWidget {
  final bool animating;
  const BriefcaseWidget({super.key, required this.animating});

  @override
  State<BriefcaseWidget> createState() => _BriefcaseWidgetState();
}

class _BriefcaseWidgetState extends State<BriefcaseWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (widget.animating) _startLoop();
  }

  @override
  void didUpdateWidget(BriefcaseWidget old) {
    super.didUpdateWidget(old);
    if (widget.animating && !old.animating) _startLoop();
    if (!widget.animating && old.animating) _stopLoop();
  }

  void _startLoop() {
    _ctrl.forward(from: 0).then((_) {
      if (!mounted || !widget.animating) return;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || !widget.animating) return;
        _ctrl.reverse().then((_) {
          if (!mounted || !widget.animating) return;
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!mounted || !widget.animating) return;
            _startLoop();
          });
        });
      });
    });
  }

  void _stopLoop() {
    _ctrl.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        size: const Size(84, 84),
        painter: _BriefcasePainter(_anim.value),
      ),
    );
  }
}

class _BriefcasePainter extends CustomPainter {
  final double p;
  const _BriefcasePainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const col = Color(0xFF818CF8);

    final bx = w * 0.12, by = h * 0.42;
    final bw = w * 0.76, bh = h * 0.44;
    const br = 3.0;

    // Documento saliendo (detrás del maletín)
    if (p > 0) {
      final docW = bw * 0.6;
      final docH = h * 0.32;
      final dx = bx + (bw - docW) / 2;
      final docStartY = by + 4;
      final docEndY = by - docH + 6;
      final dy = docStartY + (docEndY - docStartY) * p;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(dx - 2, 0, docW + 4, by + bh));

      final docPaint = Paint()
        ..color = const Color(0xFFE0E7FF)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(dx, dy, docW, docH),
          const Radius.circular(3),
        ),
        docPaint,
      );

      final linePaint = Paint()
        ..color = col
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < 3; i++) {
        final ly = dy + 5 + i * 4.0;
        canvas.drawLine(
          Offset(dx + 4, ly),
          Offset(dx + docW - 4, ly),
          linePaint,
        );
      }
      canvas.restore();
    }

    // Asa
    final handleW = bw * 0.36;
    final hx = bx + (bw - handleW) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(hx, by - 7, handleW, 7),
        const Radius.circular(3),
      ),
      Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Cuerpo
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw, bh),
        const Radius.circular(br),
      ),
      Paint()
        ..color = col
        ..style = PaintingStyle.fill,
    );

    // Línea central
    canvas.drawLine(
      Offset(bx, by + bh / 2),
      Offset(bx + bw, by + bh / 2),
      Paint()
        ..color = const Color(0xFF4F46E5)
        ..strokeWidth = 1.5,
    );

    // Cierre
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx + bw / 2 - 5, by + bh / 2 - 4, 10, 8),
        const Radius.circular(2),
      ),
      Paint()
        ..color = const Color(0xFF4F46E5)
        ..style = PaintingStyle.fill,
    );

    // Brillo
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx + 4, by + 4, bw - 8, 5),
        const Radius.circular(2),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_BriefcasePainter old) => old.p != p;
}

// ── Megáfono con ondas (CustomPainter) ───────────────────────

class MegaphoneWidget extends StatefulWidget {
  final bool animating;
  const MegaphoneWidget({super.key, required this.animating});

  @override
  State<MegaphoneWidget> createState() => _MegaphoneWidgetState();
}

class _MegaphoneWidgetState extends State<MegaphoneWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _waveT = 0.0;
  double _shakeT = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);
    if (widget.animating) _startWave();
  }

  @override
  void didUpdateWidget(MegaphoneWidget old) {
    super.didUpdateWidget(old);
    if (widget.animating && !old.animating) _startWave();
    if (!widget.animating && old.animating) _stopWave();
  }

  void _startWave() {
    _shakeT = 1.0;
    _ctrl.repeat();
  }

  void _stopWave() {
    _ctrl.stop();
    if (mounted)
      setState(() {
        _waveT = 0;
        _shakeT = 0;
      });
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {
      _waveT += 0.018;
      _shakeT = (_shakeT - 0.02).clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(84, 84),
      painter: _MegaphonePainter(_waveT, _shakeT),
    );
  }
}

class _MegaphonePainter extends CustomPainter {
  final double waveT;
  final double shakeT;
  const _MegaphonePainter(this.waveT, this.shakeT);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const col = Color(0xFF38BDF8);

    final ox = w / 2 - 3 + sin(shakeT * pi * 6) * shakeT * 5;
    final oy = h / 2 + 3;

    canvas.save();
    canvas.translate(ox, oy);
    canvas.rotate(-0.3);

    // Bocina
    final hornPath = Path()
      ..moveTo(3, -10)
      ..lineTo(26, -20)
      ..lineTo(26, 20)
      ..lineTo(3, 10)
      ..close();
    canvas.drawPath(
      hornPath,
      Paint()
        ..color = col
        ..style = PaintingStyle.fill,
    );

    // Cuerpo
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -10, 20, 20),
        const Radius.circular(5),
      ),
      Paint()
        ..color = col
        ..style = PaintingStyle.fill,
    );

    // Mango
    canvas.drawLine(
      const Offset(-8, 10),
      const Offset(-8, 23),
      Paint()
        ..color = col
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Brillo
    final brightPath = Path()
      ..moveTo(5, -8)
      ..lineTo(23, -17)
      ..lineTo(23, -7)
      ..lineTo(5, -2)
      ..close();
    canvas.drawPath(
      brightPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill,
    );

    canvas.restore();

    // Ondas sonoras
    if (waveT > 0) {
      final waveData = [
        (r: 22.0, delay: 0.0),
        (r: 32.0, delay: 0.25),
        (r: 42.0, delay: 0.5),
      ];

      for (final wd in waveData) {
        final phase = ((waveT - wd.delay) % 1.0 + 1.0) % 1.0;
        final alpha = sin(phase * pi) * 0.75;
        if (alpha <= 0.02) continue;

        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(ox + cos(-0.3) * 12, oy + sin(-0.3) * 12),
            radius: wd.r,
          ),
          -0.3 - 0.55,
          1.1,
          false,
          Paint()
            ..color = col.withValues(alpha: alpha)
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MegaphonePainter old) =>
      old.waveT != waveT || old.shakeT != shakeT;
}

// ── Ícono de geolocalización con giro (CustomPainter) ─────────

class GeoLocationIcon extends StatefulWidget {
  final bool active;
  const GeoLocationIcon({super.key, required this.active});

  @override
  State<GeoLocationIcon> createState() => _GeoLocationIconState();
}

class _GeoLocationIconState extends State<GeoLocationIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _angle = 0;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        )..addListener(() {
          if (!mounted) return;
          setState(() => _angle = _ctrl.value * 2 * pi);
        });
  }

  @override
  void didUpdateWidget(GeoLocationIcon old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      // Giro rápido que desacelera
      _ctrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _angle = 0);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(110, 110),
      painter: _GeoPinPainter(_angle, widget.active),
    );
  }
}

class _GeoPinPainter extends CustomPainter {
  final double angle;
  final bool active;
  const _GeoPinPainter(this.angle, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    canvas.translate(-cx, -cy);

    const pinCol = Color(0xFF38BDF8);
    final paint = Paint()
      ..color = pinCol
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = pinCol.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    // Pin más grande — escala ~2.5x respecto al original
    final path = Path()
      ..moveTo(cx, cy - 34)
      ..cubicTo(cx - 20, cy - 34, cx - 20, cy - 16, cx - 20, cy - 10)
      ..cubicTo(cx - 20, cy + 5, cx, cy + 34, cx, cy + 34)
      ..cubicTo(cx, cy + 34, cx + 20, cy + 5, cx + 20, cy - 10)
      ..cubicTo(cx + 20, cy - 16, cx + 20, cy - 34, cx, cy - 34)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    // Círculo interior
    canvas.drawCircle(Offset(cx, cy - 12), 9, paint);

    canvas.restore();

    // Punto verde de señal (fijo)
    canvas.drawCircle(
      Offset(cx + 28, cy - 28),
      8,
      Paint()
        ..color = const Color(0xFF34D399)
        ..style = PaintingStyle.fill,
    );
    final checkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx + 24, cy - 28),
      Offset(cx + 27, cy - 25),
      checkPaint,
    );
    canvas.drawLine(
      Offset(cx + 27, cy - 25),
      Offset(cx + 33, cy - 31),
      checkPaint,
    );
  }

  @override
  bool shouldRepaint(_GeoPinPainter old) =>
      old.angle != angle || old.active != active;
}
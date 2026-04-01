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
  final ScrollController _scrollController = ScrollController();

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
    _countrySearchController.dispose();
    _countryFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();
    final username = value.trim();

    setState(() {
      usernameAvailable = false;
      usernameError = "";
      checkingUsername = username.length >= 3;
    });

    if (username.length < 3) return;

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

    final location = _locationData ?? LocationData();
    final scoreResult = TrustScoreService.calculate(
      location: location,
      user: user,
    );

    await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
      "username": usernameController.text.trim(),
      "country": selectedCountry,
      "countryCode": countryCode,
      "location": location.toMap(),
      "trustScore": {...scoreResult.toMap(), "pendingCloudValidation": true},
    }, SetOptions(merge: true));

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      await functions.httpsCallable('validateTrustScore').call({
        'uid': user.uid,
        'locationData': location.toMap(),
        'clientScore': scoreResult.score,
      });
    } catch (_) {}

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
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
        return _locationPermission != null;
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
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "¿Podemos ver tu ubicación?",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.8,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "Nomad usa tu ubicación para conectarte con compatriotas cercanos. Nunca compartimos tu posición exacta con otros usuarios.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.45),
                  height: 1.55,
                ),
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF0D9488),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Impacto en tu Score de Confianza",
                            style: TextStyle(
                              color: Color(0xFF0D9488),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Tu score valida tu identidad frente a otros Nomads. Compartir ubicación es uno de los factores que más sube tu score — sin él, tu perfil tendrá menor visibilidad y credibilidad en la comunidad.",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Stack(
                clipBehavior: Clip.none,
                children: [
                  _permissionOption(
                    icon: Icons.my_location_rounded,
                    iconColor: const Color(0xFF0D9488),
                    iconBg: const Color(0xFF0D9488).withValues(alpha: 0.15),
                    title: "Permitir solo al usar",
                    subtitle: "+Score · Solo cuando Nomad está abierta",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _locationPermission = 'inUse');
                      getLocation();
                    },
                  ),
                  Positioned(
                    top: -10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Recomendado",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _permissionOption(
                icon: Icons.location_on_rounded,
                iconColor: const Color(0xFF38BDF8),
                iconBg: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                title: "Permitir siempre",
                subtitle: "+Score máximo · Acceso completo en todo momento",
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _locationPermission = 'always');
                  getLocation();
                },
              ),

              const SizedBox(height: 12),

              _permissionOption(
                icon: Icons.location_off_rounded,
                iconColor: const Color(0xFFEF4444),
                iconBg: const Color(0xFFEF4444).withValues(alpha: 0.1),
                title: "No permitir ahora",
                subtitle: "−Score · Podrás activarlo más tarde desde tu perfil",
                titleColor: const Color(0xFFEF4444),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _locationPermission = 'denied');
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
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
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Fondo huella digital animado (solo step 0) ──────────
          if (step == 0) const Positioned.fill(child: _FingerprintBgWidget()),

          // ── Fondo banderas (solo step 1) ──────────────────────────
          if (step == 1) const Positioned.fill(child: _FlagsBgWidget()),

          // ── Fondo red de nodos (solo step 3) ─────────────────────
          if (step == 3) const Positioned.fill(child: _NetworkBgWidget()),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Hero(
                                tag: "logo",
                                child: Material(
                                  color: Colors.transparent,
                                  child: const Align(
                                    alignment: Alignment.center,
                                    child: Text(
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
                              ),
                            ),
                          ),

                          if (step > 0)
                            Positioned(
                              left: 0,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() {
                                  step--;
                                  _showCountryList = false;
                                  _countrySearch = '';
                                  _countrySearchController.clear();
                                  _countryFocusNode.unfocus();
                                }),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white.withValues(alpha: 0.75),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
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

                    _progressIndicator(),

                    const SizedBox(height: 36),

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
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const ClampingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight:
                                    MediaQuery.of(context).size.height * 0.55,
                              ),
                              child: IntrinsicHeight(child: buildStep()),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _canContinue() ? nextStep : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
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
                        child: const Text(
                          "Continuar",
                          style: TextStyle(
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
                ? const Color(0xFF0D9488)
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
                        color: Color(0xFF0D9488),
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
                    : const Color(0xFF0D9488),
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

  final TextEditingController _countrySearchController =
      TextEditingController();
  final FocusNode _countryFocusNode = FocusNode();

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

        TextField(
          controller: _countrySearchController,
          focusNode: _countryFocusNode,
          readOnly: !_showCountryList,
          enableInteractiveSelection: false,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: _showCountryList
                ? 'Buscar país...'
                : (selectedCountry ?? 'Seleccionar país'),
            hintStyle: TextStyle(
              color: _showCountryList
                  ? Colors.white.withValues(alpha: 0.35)
                  : selectedCountry != null
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.3),
              fontSize: 15,
            ),
            prefixIcon: _showCountryList
                ? Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 20,
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        Icons.public,
                        color: Colors.white.withValues(alpha: 0.4),
                        size: 20,
                      ),
                      if (countryCode != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          Country.parse(countryCode!).flagEmoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                      const SizedBox(width: 8),
                    ],
                  ),
            suffixIcon: AnimatedRotation(
              turns: _showCountryList ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 20,
              ),
            ),
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
                color: _showCountryList
                    ? const Color(0xFF0D9488)
                    : countryCode != null
                    ? const Color(0xFF0D9488).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF0D9488),
                width: 1.5,
              ),
            ),
          ),
          onTap: () {
            setState(() {
              _showCountryList = true;
              _countrySearch = '';
              _countrySearchController.clear();
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                );
              }
            });
            Future.microtask(() => _countryFocusNode.requestFocus());
          },
          onChanged: (v) => setState(() => _countrySearch = v),
        ),

        if (_showCountryList) ...[
          const SizedBox(height: 6),

          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'Sin resultados',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: filtered.map((c) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            _countryFocusNode.unfocus();
                            setState(() {
                              selectedCountry = c.name;
                              countryCode = c.countryCode;
                              _showCountryList = false;
                              _countrySearch = '';
                              _countrySearchController.clear();
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  c.flagEmoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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
    final denied = _locationPermission == 'denied';

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

        const SizedBox(height: 8),

        Text(
          "Acercate a tus compatriotas",
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),

        const SizedBox(height: 20),

        // ── Mapa de ciudad nocturna ───────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fondo: foto de ciudad nocturna con cruce peatonal
                Image.network(
                  'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=800&q=80',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: const Color(0xFF0A1F1C),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) =>
                      CustomPaint(painter: _NightCityMapPainter()),
                ),

                // Tinte oscuro-verde para integrar con la paleta
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1F1C).withValues(alpha: 0.45),
                  ),
                ),

                // Overlay degradado inferior
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0F0F14).withValues(alpha: 0.85),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),

                // (pins eliminados)

                // Chip de ciudad detectada
                if (hasGPS)
                  Positioned(
                    bottom: 14,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFF0D9488,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.gps_fixed_rounded,
                              color: Color(0xFF34D399),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${loc!.city ?? 'Ciudad desconocida'}, ${loc.country ?? ''}',
                              style: const TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ── Botón geolocalizar ────────────────────────────────────
        GestureDetector(
          onTap: _loadingLocation ? null : _showLocationPermissionDialog,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: denied
                  ? const Color(0xFF3A1E1E)
                  : loc != null
                  ? const Color(0xFF0D9488).withValues(alpha: 0.25)
                  : const Color(0xFF0D9488),
              border: Border.all(
                color: denied
                    ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                    : loc != null
                    ? const Color(0xFF0D9488).withValues(alpha: 0.6)
                    : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: denied || loc != null
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_loadingLocation)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    denied
                        ? Icons.location_off_rounded
                        : loc != null
                        ? Icons.gps_fixed_rounded
                        : Icons.my_location_rounded,
                    color: denied ? const Color(0xFFEF4444) : Colors.white,
                    size: 22,
                  ),
                const SizedBox(width: 10),
                Text(
                  _loadingLocation
                      ? 'Detectando...'
                      : denied
                      ? 'Permiso denegado'
                      : loc != null
                      ? 'Actualizar ubicación'
                      : 'GEOLOCALIZAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: denied ? const Color(0xFFEF4444) : Colors.white,
                  ),
                ),
              ],
            ),
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
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1.0,
            height: 1.1,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          "Podés elegir más de una opción",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.40),
            letterSpacing: 0.2,
          ),
        ),

        const SizedBox(height: 32),

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
            const SizedBox(width: 12),
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

        const SizedBox(height: 16),

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
            const SizedBox(width: 12),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlowCircle(selected: selected, size: 140, child: icon),
            const SizedBox(height: 10),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: selected ? 19 : 17,
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF34D399) : Colors.white,
                letterSpacing: -0.3,
              ),
              child: Text(label, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: selected ? 0.60 : 0.35),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Círculo con borde brillante animado ───────────────────────

class _GlowCircle extends StatefulWidget {
  final bool selected;
  final double size;
  final Widget child;

  const _GlowCircle({
    required this.selected,
    required this.size,
    required this.child,
  });

  @override
  State<_GlowCircle> createState() => _GlowCircleState();
}

class _GlowCircleState extends State<_GlowCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Borde brillante giratorio
            CustomPaint(
              size: Size(s + 8, s + 8),
              painter: _GlowBorderPainter(
                progress: _ctrl.value,
                selected: widget.selected,
              ),
            ),
            // Círculo interior con fondo animado
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.selected
                    ? const Color(0xFF0D4A3A)
                    : const Color(0xFF0D2E2A),
                boxShadow: widget.selected
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF0D9488,
                          ).withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: Center(child: widget.child),
            ),
            // Tick de selección
            Positioned(
              top: 6,
              right: 6,
              child: AnimatedScale(
                scale: widget.selected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topRight,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D9488),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GlowBorderPainter extends CustomPainter {
  final double progress;
  final bool selected;

  const _GlowBorderPainter({required this.progress, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width / 2) - 2;

    // Anillo base tenue
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = const Color(0xFF0D9488).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Arco giratorio — color sólido, sin SweepGradient
    final sweepAngle = selected ? 2 * pi : pi * 0.70;
    final startAngle = progress * 2 * pi - pi / 2;
    final arcColor = selected
        ? const Color(0xFF34D399)
        : const Color(0xFF0D9488).withValues(alpha: 0.85);

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3.5 : 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Punto brillante en la punta
    final tipX = cx + radius * cos(startAngle + sweepAngle);
    final tipY = cy + radius * sin(startAngle + sweepAngle);
    canvas.drawCircle(
      Offset(tipX, tipY),
      selected ? 4.5 : 3.0,
      Paint()
        ..color = const Color(0xFF34D399)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_GlowBorderPainter old) =>
      old.progress != progress || old.selected != selected;
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
      builder: (_, __) => CustomPaint(
        size: const Size(120, 120),
        painter: _HugPainter(_anim.value),
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
    final scaleF = size.width / 84.0;
    canvas.save();
    canvas.scale(scaleF, scaleF);
    final w = 84.0;
    final h = 84.0;
    final cxc = w / 2;
    final groundY = h / 2 + 13.0;
    final lx = _lerp(cxc - 14, cxc, e);
    final rx = _lerp(cxc + 14, cxc, e);
    final headY = groundY - 26;
    const headR = 7.0;

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
      size: const Size(116, 116),
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
    final s = 18.0 * (size.width / 84.0);

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

    if (p > 0) {
      final docW = bw * 0.6;
      final docH = h * 0.32;
      final dx = bx + (bw - docW) / 2;
      final docStartY = by + 4;
      final docEndY = by - docH + 6;
      final dy = docStartY + (docEndY - docStartY) * p;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(dx - 2, 0, docW + 4, by + bh));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(dx, dy, docW, docH),
          const Radius.circular(3),
        ),
        Paint()
          ..color = const Color(0xFFE0E7FF)
          ..style = PaintingStyle.fill,
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

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw, bh),
        const Radius.circular(br),
      ),
      Paint()
        ..color = col
        ..style = PaintingStyle.fill,
    );

    canvas.drawLine(
      Offset(bx, by + bh / 2),
      Offset(bx + bw, by + bh / 2),
      Paint()
        ..color = const Color(0xFF4F46E5)
        ..strokeWidth = 1.5,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx + bw / 2 - 5, by + bh / 2 - 4, 10, 8),
        const Radius.circular(2),
      ),
      Paint()
        ..color = const Color(0xFF4F46E5)
        ..style = PaintingStyle.fill,
    );

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

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -10, 20, 20),
        const Radius.circular(5),
      ),
      Paint()
        ..color = col
        ..style = PaintingStyle.fill,
    );

    canvas.drawLine(
      const Offset(-8, 10),
      const Offset(-8, 23),
      Paint()
        ..color = col
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

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

// ── Mapa nocturno CustomPainter ───────────────────────────────

class _NightCityMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fondo base oscuro con tinte verde
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF0A1F1C),
    );

    // Grilla de calles principales
    final streetPaint = Paint()
      ..color = const Color(0xFF1A3A35)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final minorStreetPaint = Paint()
      ..color = const Color(0xFF152E2A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Calles horizontales principales
    for (final y in [0.20, 0.42, 0.65, 0.85]) {
      canvas.drawLine(Offset(0, h * y), Offset(w, h * y), streetPaint);
    }
    // Calles verticales principales
    for (final x in [0.15, 0.38, 0.60, 0.82]) {
      canvas.drawLine(Offset(w * x, 0), Offset(w * x, h), streetPaint);
    }
    // Calles menores horizontales
    for (final y in [0.31, 0.53, 0.75]) {
      canvas.drawLine(Offset(0, h * y), Offset(w, h * y), minorStreetPaint);
    }
    // Calles menores verticales
    for (final x in [0.27, 0.49, 0.71]) {
      canvas.drawLine(Offset(w * x, 0), Offset(w * x, h), minorStreetPaint);
    }

    // Manzanas / bloques (rellenos tenue)
    final blockPaint = Paint()
      ..color = const Color(0xFF0D2926)
      ..style = PaintingStyle.fill;

    final blocks = [
      Rect.fromLTWH(w * 0.16, h * 0.01, w * 0.21, h * 0.18),
      Rect.fromLTWH(w * 0.39, h * 0.01, w * 0.20, h * 0.18),
      Rect.fromLTWH(w * 0.61, h * 0.01, w * 0.20, h * 0.18),
      Rect.fromLTWH(w * 0.01, h * 0.22, w * 0.13, h * 0.18),
      Rect.fromLTWH(w * 0.16, h * 0.22, w * 0.21, h * 0.18),
      Rect.fromLTWH(w * 0.39, h * 0.22, w * 0.20, h * 0.18),
      Rect.fromLTWH(w * 0.61, h * 0.22, w * 0.20, h * 0.18),
      Rect.fromLTWH(w * 0.83, h * 0.22, w * 0.16, h * 0.18),
      Rect.fromLTWH(w * 0.01, h * 0.44, w * 0.13, h * 0.19),
      Rect.fromLTWH(w * 0.16, h * 0.44, w * 0.21, h * 0.19),
      Rect.fromLTWH(w * 0.39, h * 0.44, w * 0.20, h * 0.19),
      Rect.fromLTWH(w * 0.61, h * 0.44, w * 0.20, h * 0.19),
      Rect.fromLTWH(w * 0.83, h * 0.44, w * 0.16, h * 0.19),
      Rect.fromLTWH(w * 0.01, h * 0.67, w * 0.13, h * 0.16),
      Rect.fromLTWH(w * 0.16, h * 0.67, w * 0.21, h * 0.16),
      Rect.fromLTWH(w * 0.39, h * 0.67, w * 0.20, h * 0.16),
      Rect.fromLTWH(w * 0.61, h * 0.67, w * 0.20, h * 0.16),
      Rect.fromLTWH(w * 0.83, h * 0.67, w * 0.16, h * 0.16),
    ];

    for (final b in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(b, const Radius.circular(3)),
        blockPaint,
      );
    }

    // Luces de ventanas (puntitos amarillos/cyan dispersos)
    final lightPaint = Paint()..style = PaintingStyle.fill;
    final lightPositions = [
      (0.20, 0.05, 0xFFFFD166),
      (0.25, 0.08, 0xFF0D9488),
      (0.42, 0.04, 0xFFFFD166),
      (0.48, 0.10, 0xFF34D399),
      (0.64, 0.06, 0xFFFFD166),
      (0.70, 0.03, 0xFF0D9488),
      (0.18, 0.26, 0xFF34D399),
      (0.22, 0.30, 0xFFFFD166),
      (0.40, 0.25, 0xFFFFD166),
      (0.45, 0.28, 0xFF0D9488),
      (0.63, 0.27, 0xFF34D399),
      (0.68, 0.24, 0xFFFFD166),
      (0.85, 0.26, 0xFFFFD166),
      (0.88, 0.30, 0xFF0D9488),
      (0.20, 0.48, 0xFFFFD166),
      (0.24, 0.52, 0xFF34D399),
      (0.41, 0.46, 0xFF0D9488),
      (0.44, 0.50, 0xFFFFD166),
      (0.62, 0.47, 0xFFFFD166),
      (0.67, 0.51, 0xFF34D399),
      (0.84, 0.48, 0xFF0D9488),
      (0.87, 0.52, 0xFFFFD166),
      (0.19, 0.70, 0xFF34D399),
      (0.23, 0.74, 0xFFFFD166),
      (0.40, 0.69, 0xFFFFD166),
      (0.46, 0.72, 0xFF0D9488),
      (0.63, 0.71, 0xFF34D399),
      (0.69, 0.68, 0xFFFFD166),
      (0.85, 0.70, 0xFFFFD166),
      (0.89, 0.73, 0xFF0D9488),
    ];

    for (final (lx, ly, color) in lightPositions) {
      lightPaint.color = Color(color).withValues(alpha: 0.7);
      canvas.drawCircle(Offset(w * lx, h * ly), 2.0, lightPaint);
    }

    // Halo verde central (zona de búsqueda)
    final haloPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF0D9488).withValues(alpha: 0.18),
              const Color(0xFF0D9488).withValues(alpha: 0.06),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(w / 2, h / 2), radius: w * 0.45),
          )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.45, haloPaint);

    // Anillo punteado de radio
    final ringPaint = Paint()
      ..color = const Color(0xFF0D9488).withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.30, ringPaint);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44, ringPaint);
  }

  @override
  bool shouldRepaint(_NightCityMapPainter _) => false;
}

// ── Pin de usuario en el mapa ─────────────────────────────────

class _MapPin extends StatefulWidget {
  final double left; // fracción 0..1 del ancho
  final double top; // fracción 0..1 del alto
  final String label;
  final int delay; // ms de delay para la animación de entrada

  const _MapPin({
    required this.left,
    required this.top,
    required this.label,
    required this.delay,
  });

  @override
  State<_MapPin> createState() => _MapPinState();
}

class _MapPinState extends State<_MapPin> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final px = constraints.maxWidth * widget.left;
        final py = constraints.maxHeight * widget.top;
        return Positioned(
          left: px - 36,
          top: py - 36,
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D2926).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D9488),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Pin central animado (tu ubicación) ────────────────────────

class _CenterLocationPin extends StatefulWidget {
  final bool loading;
  final bool detected;
  final bool denied;

  const _CenterLocationPin({
    required this.loading,
    required this.detected,
    required this.denied,
  });

  @override
  State<_CenterLocationPin> createState() => _CenterLocationPinState();
}

class _CenterLocationPinState extends State<_CenterLocationPin>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final pulse = 1.0 + _ctrl.value * 0.15;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Onda exterior
            if (!widget.denied)
              Container(
                width: 72 * pulse,
                height: 72 * pulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(
                    0xFF0D9488,
                  ).withValues(alpha: 0.12 * (1 - _ctrl.value)),
                ),
              ),
            // Círculo base
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.denied
                    ? const Color(0xFF3A1E1E)
                    : const Color(0xFF0D9488).withValues(alpha: 0.25),
                border: Border.all(
                  color: widget.denied
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF0D9488),
                  width: 2,
                ),
              ),
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF0D9488),
                        ),
                      )
                    : Icon(
                        widget.denied
                            ? Icons.location_off_rounded
                            : widget.detected
                            ? Icons.my_location_rounded
                            : Icons.location_on_rounded,
                        color: widget.denied
                            ? const Color(0xFFEF4444)
                            : Colors.white,
                        size: 26,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

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

    final path = Path()
      ..moveTo(cx, cy - 34)
      ..cubicTo(cx - 20, cy - 34, cx - 20, cy - 16, cx - 20, cy - 10)
      ..cubicTo(cx - 20, cy + 5, cx, cy + 34, cx, cy + 34)
      ..cubicTo(cx, cy + 34, cx + 20, cy + 5, cx + 20, cy - 10)
      ..cubicTo(cx + 20, cy - 16, cx + 20, cy - 34, cx, cy - 34)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(cx, cy - 12), 9, paint);
    canvas.restore();

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

// ── Fondo huella digital animado ─────────────────────────────

class _FingerprintBgWidget extends StatefulWidget {
  const _FingerprintBgWidget();

  @override
  State<_FingerprintBgWidget> createState() => _FingerprintBgWidgetState();
}

class _FingerprintBgWidgetState extends State<_FingerprintBgWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Imagen de fondo con opacidad ──────────────────────
        Opacity(
          opacity: 0.72,
          child: Image.asset(
            'assets/images/fingerprint_bg.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // ── Overlay oscuro para legibilidad ───────────────────
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0F0F14).withValues(alpha: 0.55),
                const Color(0xFF0F0F14).withValues(alpha: 0.20),
                const Color(0xFF0F0F14).withValues(alpha: 0.55),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // ── Degradado superior — protege título y campo ──────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LayoutBuilder(
            builder: (ctx, constraints) => SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0F0F14),
                      const Color(0xFF0F0F14).withValues(alpha: 0.80),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.50, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Degradado inferior — protege botón ────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: LayoutBuilder(
            builder: (ctx, constraints) => SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.14,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xFF0F0F14), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Fondo banderas animado ────────────────────────────────────

// ── Fondo banderas ────────────────────────────────────────────

class _FlagsBgWidget extends StatefulWidget {
  const _FlagsBgWidget();

  @override
  State<_FlagsBgWidget> createState() => _FlagsBgWidgetState();
}

class _FlagsBgWidgetState extends State<_FlagsBgWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Imagen de fondo
        Image.asset(
          'assets/images/flags_bg.png',
          fit: BoxFit.cover,
          width: w,
          height: h,
          opacity: const AlwaysStoppedAnimation(0.55),
        ),

        // 2. Tinte verde oscuro uniforme
        Container(color: const Color(0xFF071510).withValues(alpha: 0.50)),

        // 3. Degradado solo en la zona del header (top 40%)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: h * 0.42,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0F0F14),
                  const Color(0xFF0F0F14).withValues(alpha: 0.75),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // 4. Degradado solo en la zona del botón (bottom 15%)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: h * 0.15,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [const Color(0xFF0F0F14), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Fondo red de nodos animada (step 3) ──────────────────────

class _NetworkBgWidget extends StatefulWidget {
  const _NetworkBgWidget();

  @override
  State<_NetworkBgWidget> createState() => _NetworkBgWidgetState();
}

class _NetworkBgWidgetState extends State<_NetworkBgWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Red animada
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) =>
              CustomPaint(painter: _NetworkPainter(_ctrl.value)),
        ),

        // Degradado superior — protege header
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.28,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F0F14), Colors.transparent],
                ),
              ),
            ),
          ),
        ),

        // Degradado inferior — protege botón
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.14,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFF0F0F14), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NetworkPainter extends CustomPainter {
  final double t;
  const _NetworkPainter(this.t);

  // Nodos fijos con movimiento suave
  static const _baseNodes = [
    (x: 0.08, y: 0.12),
    (x: 0.28, y: 0.08),
    (x: 0.55, y: 0.15),
    (x: 0.80, y: 0.10),
    (x: 0.92, y: 0.22),
    (x: 0.15, y: 0.30),
    (x: 0.42, y: 0.28),
    (x: 0.70, y: 0.32),
    (x: 0.88, y: 0.45),
    (x: 0.05, y: 0.50),
    (x: 0.30, y: 0.52),
    (x: 0.58, y: 0.48),
    (x: 0.78, y: 0.60),
    (x: 0.95, y: 0.65),
    (x: 0.18, y: 0.70),
    (x: 0.45, y: 0.72),
    (x: 0.65, y: 0.80),
    (x: 0.85, y: 0.82),
    (x: 0.10, y: 0.88),
    (x: 0.38, y: 0.90),
    (x: 0.62, y: 0.92),
  ];

  // Conexiones entre índices de nodos
  static const _edges = [
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (0, 5),
    (1, 6),
    (2, 6),
    (3, 7),
    (4, 8),
    (5, 6),
    (6, 7),
    (7, 8),
    (5, 10),
    (6, 10),
    (6, 11),
    (7, 11),
    (7, 12),
    (8, 13),
    (9, 10),
    (10, 11),
    (11, 12),
    (12, 13),
    (9, 14),
    (10, 15),
    (11, 15),
    (12, 16),
    (13, 17),
    (14, 15),
    (15, 16),
    (16, 17),
    (14, 18),
    (15, 19),
    (16, 20),
    (18, 19),
    (19, 20),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Calcular posiciones animadas (flotan suavemente)
    final nodes = _baseNodes.asMap().entries.map((e) {
      final i = e.key;
      final n = e.value;
      final dx = sin(t * 2 * pi + i * 0.7) * 0.018;
      final dy = cos(t * 2 * pi + i * 1.1) * 0.018;
      return Offset(w * (n.x + dx), h * (n.y + dy));
    }).toList();

    // Dibujar conexiones
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (final (a, b) in _edges) {
      final pa = nodes[a];
      final pb = nodes[b];
      final dist = (pa - pb).distance;
      final maxDist = w * 0.55;
      if (dist > maxDist) continue;
      final alpha = (1 - dist / maxDist) * 0.18;
      linePaint.color = const Color(0xFF0D9488).withValues(alpha: alpha);
      canvas.drawLine(pa, pb, linePaint);
    }

    // Dibujar nodos
    for (int i = 0; i < nodes.length; i++) {
      final pos = nodes[i];
      final pulse = sin(t * 2 * pi * 1.2 + i * 0.8) * 0.5 + 0.5;
      final alpha = 0.12 + pulse * 0.18;
      final r = 3.0 + pulse * 1.5;

      // Halo
      canvas.drawCircle(
        pos,
        r * 2.5,
        Paint()
          ..color = const Color(0xFF0D9488).withValues(alpha: alpha * 0.35)
          ..style = PaintingStyle.fill,
      );
      // Núcleo
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = const Color(0xFF34D399).withValues(alpha: alpha * 0.9)
          ..style = PaintingStyle.fill,
      );
    }

    // Pulso viajando por las conexiones
    final pulseProgress = t % 1.0;
    final edgeIdx = (pulseProgress * _edges.length).floor() % _edges.length;
    final edgeT = (pulseProgress * _edges.length) % 1.0;
    final (ea, eb) = _edges[edgeIdx];
    if (ea < nodes.length && eb < nodes.length) {
      final pa = nodes[ea];
      final pb = nodes[eb];
      final pulsePos = Offset.lerp(pa, pb, edgeT)!;
      canvas.drawCircle(
        pulsePos,
        4,
        Paint()
          ..color = const Color(0xFF34D399).withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_NetworkPainter old) => old.t != t;
}

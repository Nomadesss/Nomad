import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';

import '../../services/biometric_service.dart';
import '../auth/terms_acceptance_screen.dart';
import '../../l10n/app_localizations.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  bool _isLoading = false;
  List<BiometricType> _tipos = [];

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1, curve: Curves.easeIn),
      ),
    );
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();
    _cargarTipos();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _cargarTipos() async {
    final tipos = await BiometricService.availableTypes();
    if (mounted) setState(() => _tipos = tipos);
  }

  // ── Determinar ícono y texto según biometría disponible ───────

  String get _biometricIcon {
    if (_tipos.contains(BiometricType.face)) return '🪪';
    if (_tipos.contains(BiometricType.fingerprint)) return '👆';
    return '🔐';
  }

  String get _biometricNombre {
    if (_tipos.contains(BiometricType.face)) return 'Face ID';
    if (_tipos.contains(BiometricType.fingerprint)) return 'huella dactilar';
    return 'biometría';
  }

  // ── Activar biometría ─────────────────────────────────────────

  Future<void> _activar() async {
    final canCheck = await LocalAuthentication().canCheckBiometrics;
    final isSupported = await LocalAuthentication().isDeviceSupported();
    final tipos = await LocalAuthentication().getAvailableBiometrics();
    debugPrint('🔐 canCheck: $canCheck');
    debugPrint('🔐 isSupported: $isSupported');
    debugPrint('🔐 tipos: $tipos');
    setState(() => _isLoading = true);

    // Pedir autenticación para confirmar que funciona
    final ok = await BiometricService.authenticate(
      reason: 'Registrá tu $_biometricNombre para futuros accesos',
    );

    if (!mounted) return;

    if (ok) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await BiometricService.setEnabled(uid, true);
      _irSiguiente();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo verificar la biometría. Podés activarla más tarde en configuración.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Saltar (no activar) ───────────────────────────────────────

  Future<void> _saltar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await BiometricService.setEnabled(uid, false);
    _irSiguiente();
  }

  void _irSiguiente() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TermsAcceptanceScreen()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Stack(
        children: [
          // Fondo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F0F1A),
                  Color(0xFF14101F),
                  Color(0xFF0F1A14),
                ],
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      // Logo
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Hero(
                          tag: "logo",
                          child: Material(
                            color: Colors.transparent,
                            child: const Text(
                              "Nomad",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Ícono grande
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF5C6EF5,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(
                              0xFF5C6EF5,
                            ).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _biometricIcon,
                            style: const TextStyle(fontSize: 46),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      Text(
                        l10n.biometricSetupTitle(_biometricNombre),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        l10n.biometricSetupDescription(_biometricNombre),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.55),
                          height: 1.55,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Beneficios
                      _beneficioItem(
                        '⚡',
                        l10n.biometricSetupBenefit1Title,
                        l10n.biometricSetupBenefit1Desc,
                      ),
                      const SizedBox(height: 12),
                      _beneficioItem(
                        '🔒',
                        l10n.biometricSetupBenefit2Title,
                        l10n.biometricSetupBenefit2Desc,
                      ),
                      const SizedBox(height: 12),
                      _beneficioItem(
                        '📴',
                        l10n.biometricSetupBenefit3Title,
                        l10n.biometricSetupBenefit3Desc,
                      ),

                      const Spacer(),

                      // Botón activar
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF5C6EF5),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5C6EF5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _activar,
                                child: Text(
                                  l10n.biometricSetupActivate(_biometricNombre),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(height: 14),

                      // Saltar
                      GestureDetector(
                        onTap: _isLoading ? null : _saltar,
                        child: Text(
                          l10n.biometricSetupSkip,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.45),
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withValues(
                              alpha: 0.3,
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
          ),
        ],
      ),
    );
  }

  Widget _beneficioItem(String emoji, String titulo, String subtitulo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitulo,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

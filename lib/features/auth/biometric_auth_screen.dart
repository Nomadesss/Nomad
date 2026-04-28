import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';

import '../../services/biometric_service.dart';
import '../auth/login_screen.dart';
import '../../l10n/app_localizations.dart';

/// Pantalla que se muestra en logins siguientes cuando el usuario
/// ya tiene biometría activada. Destino final se pasa como parámetro.
class BiometricAuthScreen extends StatefulWidget {
  final Widget destination;

  const BiometricAuthScreen({super.key, required this.destination});

  @override
  State<BiometricAuthScreen> createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<double> _pulse;

  bool _isLoading = false;
  bool _failed = false;
  int _intentos = 0;
  List<BiometricType> _tipos = [];

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0, 0.4, curve: Curves.easeIn),
      ),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _cargarTipos();
    // Lanzar automáticamente al entrar
    WidgetsBinding.instance.addPostFrameCallback((_) => _autenticar());
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

  // ── Autenticar ────────────────────────────────────────────────

  Future<void> _autenticar() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _failed = false;
    });

    final ok = await BiometricService.authenticate(
      reason:
          'Confirmá tu identidad con $_biometricNombre para ingresar a Nomad',
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.destination),
      );
    } else {
      _intentos++;
      setState(() {
        _isLoading = false;
        _failed = true;
      });
    }
  }

  // ── Cerrar sesión y volver al login ───────────────────────────

  Future<void> _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    // Logo
                    const Hero(
                      tag: "logo",
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
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

                    const Spacer(),

                    // Ícono con pulso
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Transform.scale(
                        scale: _isLoading ? _pulse.value : 1.0,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: _failed
                                ? Colors.redAccent.withValues(alpha: 0.12)
                                : const Color(
                                    0xFF5C6EF5,
                                  ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: _failed
                                  ? Colors.redAccent.withValues(alpha: 0.4)
                                  : const Color(
                                      0xFF5C6EF5,
                                    ).withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _failed ? '✗' : _biometricIcon,
                              style: TextStyle(
                                fontSize: _failed ? 42 : 48,
                                color: _failed ? Colors.redAccent : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      _failed ? l10n.biometricAuthErrorTitle : l10n.biometricAuthWelcome,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      _failed
                          ? l10n.biometricAuthErrorMessage
                          : l10n.biometricAuthInstruction(_biometricNombre),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Botón principal
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
                                backgroundColor: _failed
                                    ? Colors.redAccent
                                    : const Color(0xFF5C6EF5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              onPressed: _autenticar,
                              child: Text(
                                _failed
                                    ? l10n.biometricAuthRetry
                                    : l10n.biometricAuthUse(_biometricNombre),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Cerrar sesión
                    GestureDetector(
                      onTap: _cerrarSesion,
                      child: Text(
                        l10n.biometricAuthOtherAccount,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.4),
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),

                    const Spacer(),
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
}

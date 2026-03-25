import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../auth/terms_acceptance_screen.dart';
import '../auth/phone_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _backgroundZoom;
  late Animation<double> _logoFade;
  late Animation<double> _buttonsFade;
  late Animation<Offset> _buttonsSlide;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _backgroundZoom = Tween<double>(
      begin: 1.1,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.6, curve: Curves.easeIn),
      ),
    );

    _buttonsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1, curve: Curves.easeIn),
      ),
    );

    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Login con Google ──────────────────────────────────────────

  Future<void> _loginGoogle() async {
    setState(() => _isLoading = true);

    try {
      final result = await AuthService().signInWithGoogle();

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Error explícito devuelto por el servicio
      if (result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error!),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // El usuario canceló el selector de cuentas
      if (result.user == null) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TermsAcceptanceScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo iniciar sesión. Intentá de nuevo.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Login con teléfono ────────────────────────────────────────

  void _loginTelefono() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // ← Fix principal
      body: Stack(
        children: [
          /// BACKGROUND
          AnimatedBuilder(
            animation: _backgroundZoom,
            builder: (context, child) {
              return Transform.scale(
                scale: _backgroundZoom.value,
                alignment: Alignment.center, // ← Evita que el zoom se desplace
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        "assets/images/login_background.jpg",
                        fit: BoxFit.cover,
                      ),
                    ),
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          /// GRADIENT
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          /// LOGO — posición fija, no depende del viewport
          Positioned(
            top: 80,
            left: 30,
            right: 30,
            child: FadeTransition(
              opacity: _logoFade,
              child: Column(
                children: [
                  Hero(
                    tag: "logo",
                    child: Text(
                      "Nomad",
                      style: GoogleFonts.pacifico(
                        fontSize: 64,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Siéntete más cerca de tu casa",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.pacifico(
                      fontSize: 20,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// BOTONES — anclados al fondo, posición fija
          Positioned(
            bottom: 40,
            left: 30,
            right: 30,
            child: FadeTransition(
              opacity: _buttonsFade,
              child: SlideTransition(
                position: _buttonsSlide,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Column(
                        children: [
                          _socialButton(
                            "assets/icons/google.png",
                            "Continuar con Google",
                            _loginGoogle,
                          ),
                          const SizedBox(height: 12),
                          _socialButton(
                            "assets/icons/apple.png",
                            "Continuar con Apple",
                            () {},
                          ),
                          const SizedBox(height: 12),
                          _socialButton(
                            "assets/icons/phone.png",
                            "Iniciar sesión con número de celular",
                            _loginTelefono,
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, '/registro'),
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(fontSize: 14),
                                children: [
                                  TextSpan(
                                    text: '¿No tenés cuenta? ',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                  TextSpan(
                                    text: 'Registrate aquí',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white,
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
          ),
        ],
      ),
    );
  }

  Widget _socialButton(String iconPath, String text, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 55,
          decoration: BoxDecoration(
            color: const Color(0xFF0D9488).withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFF34D399).withValues(alpha: 0.5),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(iconPath, height: 22),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
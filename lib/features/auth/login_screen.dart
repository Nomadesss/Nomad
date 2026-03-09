import 'dart:ui';
import 'package:flutter/material.dart';
import '../feed/feed_screen.dart';
import '../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    /// ZOOM DEL FONDO
    _backgroundZoom = Tween<double>(
      begin: 1.1,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    /// FADE LOGO
    _logoFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.6, curve: Curves.easeIn),
      ),
    );

    /// FADE BOTONES
    _buttonsFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1, curve: Curves.easeIn),
      ),
    );

    /// SLIDE BOTONES
    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// LOGIN GOOGLE SIMULADO
  Future<void> _loginGoogle() async {

    setState(() {
      _isLoading = true;
    });

    User? user = await AuthService().signInWithGoogle();

    setState(() {
      _isLoading = false;
    });

    if (user == null || !mounted) return;

    /// No navegamos manualmente
    /// AuthGate decidirá a dónde ir

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Stack(
        children: [

          /// BACKGROUND CON ZOOM
          AnimatedBuilder(
            animation: _backgroundZoom,
            builder: (context, child) {
              return Transform.scale(
                scale: _backgroundZoom.value,
                child: Stack(
                  children: [

                    Positioned.fill(
                      child: Image.asset(
                        "assets/images/login_background.jpg",
                        fit: BoxFit.cover,
                      ),
                    ),

                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 4,
                        sigmaY: 4,
                      ),
                      child: Container(
                        color: Colors.black.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          /// GRADIENT INFERIOR
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  const SizedBox(),

                  /// LOGO
                  FadeTransition(
                    opacity: _logoFade,
                    child: const Column(
                      children: [

                        Hero(
                          tag: "logo",
                          child: Text(
                            "Nomad",
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        SizedBox(height: 10),

                        Text(
                          "Siéntete más cerca de tu casa",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        )
                      ],
                    ),
                  ),

                  /// BOTONES
                  FadeTransition(
                    opacity: _buttonsFade,
                    child: SlideTransition(
                      position: _buttonsSlide,
                      child: Column(
                        children: [

                          if (_isLoading)
                            const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          else
                            Column(
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
                                  () {},
                                ),
                              ],
                            ),

                          const SizedBox(height: 20),

                          /// BOTON PRINCIPAL
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3F6293),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pushNamed(
                                    context, '/registro');
                              },
                              child: const Text(
                                "Entrar en tu cuenta",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [

                              const Text(
                                "¿No tienes cuenta?",
                                style:
                                    TextStyle(color: Colors.white70),
                              ),

                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                      context, '/registro');
                                },
                                child: const Text(
                                  "Regístrate",
                                  style: TextStyle(
                                      color: Colors.white),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            "English (US) · Español · Français",
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
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
  }

  /// BOTONES SOCIALES GLASSMORPHISM
  Widget _socialButton(
      String iconPath, String text, VoidCallback onTap) {

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),
        child: Container(
          height: 55,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
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
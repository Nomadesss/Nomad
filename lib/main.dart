import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_theme.dart';

//import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/registration_screen.dart';
import 'features/auth/terms_acceptance_screen.dart';
import 'features/auth/biometric_setup_screen.dart';
import 'features/auth/biometric_auth_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/profile/perfil_screen.dart';
import 'features/profile/profile_setup_screen.dart';
import 'services/biometric_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NomadApp());
}

class NomadApp extends StatelessWidget {
  const NomadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nomad',
      debugShowCheckedModeBanner: false,
      theme: NomadTheme.light,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es', 'AR')],
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/terms': (context) => const TermsAcceptanceScreen(),
        '/perfil': (context) => const PantallaPerfil(),
        '/feed': (context) => const FeedScreen(),
        '/registro': (context) => const RegistrationScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _resolveScreen(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();

    // ── 1. No aceptó términos ─────────────────────────────────
    if (!doc.exists || data?['acceptedTerms'] != true) {
      // Antes de ir a términos, ver si hay que ofrecer biometría
      final biometricAvailable = await BiometricService.isAvailable();
      final isFirstTime = await BiometricService.isFirstTimeForUser(user.uid);

      if (biometricAvailable && isFirstTime) {
        return const BiometricSetupScreen();
      }

      return const TermsAcceptanceScreen();
    }

    // ── 2. Onboarding incompleto ──────────────────────────────
    if (data?['username'] == null ||
        data?['country'] == null ||
        data?['photo'] == null) {
      return const ProfileSetupScreen();
    }

    // ── 3. Usuario completo ───────────────────────────────────
    // Verificar si tiene biometría activa en este dispositivo
    final biometricEnabled = await BiometricService.isEnabledForUser(user.uid);

    if (biometricEnabled) {
      return BiometricAuthScreen(destination: const FeedScreen());
    }

    // Si nunca se le ofreció biometría (ej. usuario viejo), ofrecerla ahora
    final biometricAvailable = await BiometricService.isAvailable();
    final isFirstTime = await BiometricService.isFirstTimeForUser(user.uid);

    if (biometricAvailable && isFirstTime) {
      return const BiometricSetupScreen();
    }

    return const FeedScreen();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Cargando
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0F14),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF5C6EF5)),
            ),
          );
        }

        // No logueado
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // Logueado — resolver pantalla
        return FutureBuilder<Widget>(
          future: _resolveScreen(snapshot.data!),
          builder: (context, screen) {
            if (!screen.hasData) {
              return const Scaffold(
                backgroundColor: Color(0xFF0F0F14),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF5C6EF5)),
                ),
              );
            }
            return screen.data!;
          },
        );
      },
    );
  }
}

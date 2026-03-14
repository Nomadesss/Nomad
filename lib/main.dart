import 'package:cerca_de_casa/features/auth/registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/registration_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/terms_acceptance_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/profile/perfil_screen.dart';
import 'features/profile/profile_setup_screen.dart';

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
      theme: AppTheme.lightTheme,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es', 'AR')],

      home: const AuthGate(),

      routes: {
        "/login": (context) => const LoginScreen(),
        "/terms": (context) => const TermsAcceptanceScreen(),
        "/perfil": (context) => const PantallaPerfil(),
        "/feed": (context) => const FeedScreen(),
        '/registro': (context) => const RegistrationScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _handleUser(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    /// Usuario nuevo
    if (!doc.exists) {
      return const TermsAcceptanceScreen();
    }

    final data = doc.data();

    /// No aceptó términos
    if (data?["acceptedTerms"] != true) {
      return const TermsAcceptanceScreen();
    }

    /// Onboarding incompleto
    if (data?["username"] == null ||
        data?["country"] == null ||
        data?["photo"] == null) {
      return const ProfileSetupScreen();
    }

    /// Usuario completo
    return const FeedScreen();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        /// Usuario NO logueado
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        /// Usuario logueado
        final user = snapshot.data!;

        return FutureBuilder(
          future: _handleUser(user),

          builder: (context, AsyncSnapshot<Widget> screen) {
            if (!screen.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return screen.data!;
          },
        );
      },
    );
  }
}

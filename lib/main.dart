import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/theme/app_theme.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/terms_acceptance_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/profile/perfil_screen.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

      home: const AuthGate(),

      routes: {

        "/login": (context) => const LoginScreen(),
        "/terms": (context) => const TermsAcceptanceScreen(),
        "/perfil": (context) => const PantallaPerfil(),
        "/feed": (context) => const FeedScreen(),

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

    /// Si el usuario existe en Firestore
    if (doc.exists) {

      return const FeedScreen();

    }

    /// Usuario nuevo → aceptar términos
    return const TermsAcceptanceScreen();
  }

  @override
  Widget build(BuildContext context) {

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {

          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
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
                body: Center(
                  child: CircularProgressIndicator(),
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
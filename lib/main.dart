import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'package:flutter/services.dart';
import 'core/locale_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/registration_screen.dart';
import 'features/auth/terms_acceptance_screen.dart';
import 'features/auth/biometric_setup_screen.dart';
import 'features/auth/biometric_auth_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/profile/perfil_screen.dart';
import 'features/profile/profile_setup_screen.dart';
import 'services/biometric_service.dart';
import 'features/map/map_screen.dart';
import 'features/search/search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final localeProvider = await LocaleProvider.create();
  runApp(NomadApp(localeProvider: localeProvider));
}

class NomadApp extends StatelessWidget {
  final LocaleProvider localeProvider;
  const NomadApp({super.key, required this.localeProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: localeProvider,
      child: Consumer<LocaleProvider>(
        builder: (context, locale, _) => MaterialApp(
          title: 'Nomad',
          debugShowCheckedModeBanner: false,
          theme: NomadTheme.light,
          locale: locale.locale,
          supportedLocales: const [
            Locale('es'),
            Locale('en'),
            Locale('pt'),
            Locale('fr'),
            Locale('de'),
            Locale('it'),
            Locale('tr'),
            Locale('ru'),
            Locale('hi'),
          ],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AuthGate(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/terms': (context) => const TermsAcceptanceScreen(),
            '/profile': (context) => const PerfilPropio(),
            '/feed': (context) => const FeedScreen(),
            '/registro': (context) => const RegistrationScreen(),
            '/map': (context) => const MapScreen(),
            '/search': (context) => const SearchScreen(),
          },
        ),
      ),
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
    if (!doc.exists || data?['terminosAceptados'] != true) {
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
    final biometricEnabled = await BiometricService.isEnabledForUser(user.uid);

    if (biometricEnabled) {
      return BiometricAuthScreen(destination: const FeedScreen());
    }

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0F14),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF5C6EF5)),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

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

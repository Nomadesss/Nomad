import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Importa tus otros archivos (asegúrate de que los nombres coincidan)
import 'registro_email.dart';
import 'perfil.dart';
import 'pantalladebienvenida.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDhK4paBW76TTvg-9tfQUt1ol4jFBIzzF4",
      authDomain: "cerca-de-casa-52756.firebaseapp.com",
      projectId: "cerca-de-casa-52756",
      storageBucket: "cerca-de-casa-52756.firebasestorage.app",
      messagingSenderId: "828586691109",
      appId: "1:828586691109:web:bea2c0bdd20a44bf2b0dcc",
      measurementId: "G-PDESX2B2BF",
    ),
  );

  runApp(const CercaDeCasaApp());
}

class CercaDeCasaApp extends StatelessWidget {
  const CercaDeCasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cerca de Casa',
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/registro': (context) => const RegistroEmailScreen(),
        '/bienvenida': (context) => const PantallaBienvenida(),
        '/perfil': (context) => const PantallaPerfil(),
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  // Cambiado a StatefulWidget para manejar estados de carga
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.public, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              "Cerca de Casa",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "Tu comunidad global, estés donde estés.",
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),

            if (_isLoading)
              const CircularProgressIndicator(color: Colors.white)
            else ...[
              _loginButton(
                text: "Continuar con Google",
                icon: Icons.login,
                onPressed: () async {
                  setState(() => _isLoading = true);
                  User? usuario = await AuthService().signInWithGoogle();
                  setState(() => _isLoading = false);

                  if (usuario != null) {
                    if (mounted) Navigator.pushNamed(context, '/bienvenida');
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Error al iniciar sesión con Google"),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 15),
              _loginButton(
                text: "Continuar con Apple",
                icon: Icons.apple,
                onPressed: () => print("Login con Apple"),
              ),
            ],

            const SizedBox(height: 30),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/registro'),
              child: const Text(
                "Registrarse con email o celular",
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loginButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      icon: Icon(icon, color: Colors.black87),
      label: Text(
        text,
        style: const TextStyle(color: Colors.black87, fontSize: 16),
      ),
      onPressed: onPressed,
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        "828586691109-8ealek8q0hgb70l0f03sa1kpq6ei0ka8.apps.googleusercontent.com",
    scopes: ['email', 'profile'],
  );

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Usamos los tokens para crear la credencial de Firebase
      // Agregamos el chequeo de nulidad para evitar errores de compilación
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      return userCredential.user;
    } catch (e) {
      debugPrint("Error detallado en el proceso: $e");
      return null;
    }
  }
}

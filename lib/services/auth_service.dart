import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Google Sign In ────────────────────────────────────────────

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    return {"user": userCredential.user, "credential": userCredential};
  }

  // ── Chequear si el email ya existe en Firestore ───────────────

  Future<bool> emailYaRegistrado(String email) async {
    final query = await _firestore
        .collection('usuarios')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // ── Registro con email y contraseña ──────────────────────────

  /// Retorna null si todo salió bien.
  /// Retorna un String con el mensaje de error si algo falló.
  Future<String?> registrarConEmail({
    required String nombres,
    required String apellidos,
    required DateTime fechaNacimiento,
    required String email,
    required String password,
  }) async {
    try {
      // 1. Verificar si el email ya existe en Firestore
      final existe = await emailYaRegistrado(email);
      if (existe) {
        return 'Este email ya está registrado. Iniciá sesión.';
      }

      // 2. Crear el usuario en Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return 'No se pudo crear el usuario. Intentá de nuevo.';

      // 3. Actualizar displayName en Firebase Auth
      await user.updateDisplayName('$nombres $apellidos');

      // 4. Guardar datos completos en Firestore
      await _firestore.collection('usuarios').doc(user.uid).set({
        'uid': user.uid,
        'nombres': nombres.trim(),
        'apellidos': apellidos.trim(),
        'nombreCompleto': '${nombres.trim()} ${apellidos.trim()}',
        'email': email.trim().toLowerCase(),
        'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
        'fotoUrl': null,
        'nacionalidad': null,
        'ubicacionActual': null,
        'bio': null,
        'terminosAceptados': false,
        'creadoEn': FieldValue.serverTimestamp(),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      return null; // éxito
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Este email ya está en uso. Iniciá sesión.';
        case 'weak-password':
          return 'La contraseña es demasiado débil.';
        case 'invalid-email':
          return 'El formato del email no es válido.';
        case 'network-request-failed':
          return 'Sin conexión. Verificá tu internet.';
        default:
          return 'Error al registrarse: ${e.message}';
      }
    } catch (e) {
      return 'Error inesperado. Intentá de nuevo.';
    }
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthService — autenticación y creación de perfil en Nomad
//
// Colección Firestore: 'users'
//
// Convención de retorno:
//   Todos los métodos devuelven ({T? data, String? error}).
//   Si error == null → operación exitosa.
//   Si error != null → mostrar el mensaje al usuario.
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _usersCollection = 'users';

  // Web Client ID (tipo 3) del google-services.json.
  // Es un identificador público — no es una clave secreta.
  // Necesario para que Google Sign-In valide la app correctamente.
  static const _webClientId =
      '647251551994-h4obeqh8dmuna7qgpho70bah5r8e8ro4.apps.googleusercontent.com';

  // Instancia única de GoogleSignIn con el serverClientId configurado.
  // Al ser una instancia de clase (no de método), evitamos crear múltiples
  // instancias y garantizamos que siempre use el clientId correcto.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
  );

  // ── Stream de estado de sesión ─────────────────────────────────────────────

  Stream<User?> get streamAuthState => _auth.authStateChanges();

  // ── Usuario actual ─────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;

  bool get isLoggedIn => _auth.currentUser != null;

  // ── Google Sign In ─────────────────────────────────────────────────────────
  //
  // Flujo:
  //   1. disconnect() → fuerza el selector de cuentas en cada intento.
  //   2. Google Sign In → obtiene credencial.
  //   3. Firebase Auth → autentica con la credencial.
  //   4. Firestore → crea el documento si es nuevo, o devuelve el existente.

  Future<({UserModel? user, String? error})> signInWithGoogle() async {
    try {
      // Desconectar sesión previa de Google para forzar el selector de cuentas.
      // catchError evita crashes si no había sesión activa.
      await _googleSignIn.disconnect().catchError((_) {});

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // El usuario canceló el selector de cuentas — no es un error.
        return (user: null, error: null);
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        return (user: null, error: 'No se pudo autenticar. Intentá de nuevo.');
      }

      final docRef = _db.collection(_usersCollection).doc(firebaseUser.uid);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        // Primera vez con Google → crear documento base.
        final newUser = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          nombreCompleto: firebaseUser.displayName,
          fotoUrl: firebaseUser.photoURL,
          terminosAceptados: false,
          gdprAceptadoEn: null,
        );
        await docRef.set(newUser.toMap());
        return (user: newUser, error: null);
      } else {
        // Usuario existente → leer y devolver su modelo actual.
        final existingUser = UserModel.fromDoc(docSnap);
        return (user: existingUser, error: null);
      }
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _mapAuthError(e));
    } catch (e) {
      return (user: null, error: 'Error inesperado. Intentá de nuevo.');
    }
  }

  // ── Registro con email y contraseña ───────────────────────────────────────

  Future<({UserModel? user, String? error})> registrarConEmail({
    required String nombres,
    required String apellidos,
    required DateTime fechaNacimiento,
    required String email,
    required String password,
    required DateTime gdprAceptadoEn,
    String gdprVersion = '1.0',
    String? nacionalidad,
    String? nacionalidadCode,
    String? countryFlag,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return (user: null, error: 'No se pudo crear el usuario. Intentá de nuevo.');
      }

      final nombreCompleto = '${nombres.trim()} ${apellidos.trim()}';
      await firebaseUser.updateDisplayName(nombreCompleto);

      final newUser = UserModel(
        uid: firebaseUser.uid,
        email: email.trim().toLowerCase(),
        nombres: nombres.trim(),
        apellidos: apellidos.trim(),
        nombreCompleto: nombreCompleto,
        fechaNacimiento: fechaNacimiento,
        nacionalidad: nacionalidad,
        nacionalidadCode: nacionalidadCode,
        countryFlag: countryFlag,
        terminosAceptados: true,
        gdprAceptadoEn: gdprAceptadoEn,
        gdprVersion: gdprVersion,
        followersCount: 0,
        followingCount: 0,
      );

      await _db
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .set(newUser.toMap());

      firebaseUser.sendEmailVerification().ignore();

      return (user: newUser, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _mapAuthError(e));
    } catch (e) {
      return (user: null, error: 'Error inesperado. Intentá de nuevo.');
    }
  }

  // ── Login con email y contraseña ───────────────────────────────────────────

  Future<({UserModel? user, String? error})> loginConEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return (user: null, error: 'No se pudo iniciar sesión. Intentá de nuevo.');
      }

      final docSnap = await _db
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .get();

      if (!docSnap.exists) {
        final minimalUser = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? email,
          nombreCompleto: firebaseUser.displayName,
          fotoUrl: firebaseUser.photoURL,
        );
        await _db
            .collection(_usersCollection)
            .doc(firebaseUser.uid)
            .set(minimalUser.toMap());
        return (user: minimalUser, error: null);
      }

      return (user: UserModel.fromDoc(docSnap), error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _mapAuthError(e));
    } catch (e) {
      return (user: null, error: 'Error inesperado. Intentá de nuevo.');
    }
  }

  // ── Cerrar sesión ──────────────────────────────────────────────────────────

  Future<void> cerrarSesion() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // ── Reset de contraseña ────────────────────────────────────────────────────

  Future<String?> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'Error inesperado. Intentá de nuevo.';
    }
  }

  // ── Aceptar términos (post Google Sign In) ─────────────────────────────────

  Future<String?> aceptarTerminos({
    required String uid,
    String gdprVersion = '1.0',
  }) async {
    try {
      await _db.collection(_usersCollection).doc(uid).update({
        'terminosAceptados': true,
        'gdprAceptadoEn': FieldValue.serverTimestamp(),
        'gdprVersion': gdprVersion,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'No se pudo guardar la aceptación. Intentá de nuevo.';
    }
  }

  // ── Reenviar email de verificación ────────────────────────────────────────

  Future<String?> reenviarVerificacion() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return null;
    } catch (e) {
      return 'No se pudo enviar el email. Intentá en unos minutos.';
    }
  }

  // ── Mapeo de errores de Firebase Auth → mensajes en español ───────────────

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este email ya está en uso. Iniciá sesión.';
      case 'user-not-found':
        return 'No encontramos una cuenta con ese email.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'invalid-credential':
        return 'Email o contraseña incorrectos.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'El formato del email no es válido.';
      case 'user-disabled':
        return 'Esta cuenta fue suspendida. Contactá a soporte.';
      case 'too-many-requests':
        return 'Demasiados intentos. Esperá unos minutos e intentá de nuevo.';
      case 'network-request-failed':
        return 'Sin conexión. Verificá tu internet.';
      case 'operation-not-allowed':
        return 'Este método de acceso no está habilitado.';
      case 'account-exists-with-different-credential':
        return 'Ya existe una cuenta con ese email. Intentá con otro método de acceso.';
      default:
        return 'Error al iniciar sesión: ${e.message}';
    }
  }
}
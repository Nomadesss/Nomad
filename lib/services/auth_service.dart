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
//
// ── Convención de nombres de campos (ÚNICA fuente de verdad) ─────────────────
//
//   Campo             Tipo          Notas
//   ────────────────  ────────────  ─────────────────────────────────────────
//   uid               String
//   email             String
//   nombres           String?       Solo registro con email
//   apellidos         String?       Solo registro con email
//   nombreCompleto    String?       Siempre presente si hay nombre
//   fotoUrl           String?       URL de foto de perfil
//   fechaNacimiento   Timestamp?
//   nacionalidad      String?
//   nacionalidadCode  String?
//   countryFlag       String?
//   terminosAceptados bool          Fuente de verdad GDPR (booleano)
//   gdprAceptadoEn    Timestamp?    Fuente de verdad GDPR (timestamp)
//   gdprVersion       String?
//   followersCount    int
//   followingCount    int
//   creadoEn          Timestamp     Server timestamp de creación
//   actualizadoEn     Timestamp     Server timestamp de última modificación
//   dataDeletionRequestedAt Timestamp? GDPR Art.17
//
//   ELIMINADOS (eran duplicados con nombres en inglés):
//     name        → usar nombreCompleto
//     photo       → usar fotoUrl
//     acceptedTerms → usar terminosAceptados
//     acceptedAt  → usar gdprAceptadoEn
//     createdAt   → usar creadoEn
//
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _usersCollection = 'users';

  // ── Stream de estado de sesión ─────────────────────────────────────────────
  //
  // Usalo en el router raíz de la app para redirigir automáticamente:
  //
  //   StreamBuilder<User?>(
  //     stream: authService.streamAuthState,
  //     builder: (context, snap) {
  //       if (snap.data != null) return const HomeScreen();
  //       return const LoginScreen();
  //     },
  //   );

  Stream<User?> get streamAuthState => _auth.authStateChanges();

  // ── Usuario actual ─────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;

  bool get isLoggedIn => _auth.currentUser != null;

  // ── Google Sign In ─────────────────────────────────────────────────────────
  //
  // Flujo:
  //   1. Google Sign In → obtiene credencial.
  //   2. Firebase Auth → autentica con la credencial.
  //   3. Firestore → crea el documento si es nuevo, o lo actualiza si ya existe.
  //      Usa set + merge:true para NO pisar datos del onboarding si ya los tenía.
  //
  // El documento inicial NO incluye terminosAceptados:true porque el flujo
  // de Google no mostró la pantalla de términos. El router debe detectar
  // gdprCompliant == false y llevar al usuario a la pantalla de términos
  // antes de entrar al feed. Desde ahí se llama aceptarTerminos().

  Future<({UserModel? user, String? error})> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
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
          uid:              firebaseUser.uid,
          email:            firebaseUser.email ?? '',
          nombreCompleto:   firebaseUser.displayName,
          fotoUrl:          firebaseUser.photoURL,
          terminosAceptados: false,
          gdprAceptadoEn:   null,
          followersCount:   0,
          followingCount:   0,
        );

        // IMPORTANTE: usamos toMap() que ya incluye creadoEn y actualizadoEn
        // con FieldValue.serverTimestamp(). No se agregan campos extra acá.
        await docRef.set(newUser.toMap());
        return (user: newUser, error: null);
      } else {
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
    // GDPR: timestamp exacto en que el usuario tocó "Acepto los términos".
    // El caller (la pantalla de registro) debe pasar DateTime.now() en ese momento.
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
        uid:              firebaseUser.uid,
        email:            email.trim().toLowerCase(),
        nombres:          nombres.trim(),
        apellidos:        apellidos.trim(),
        nombreCompleto:   nombreCompleto,
        fechaNacimiento:  fechaNacimiento,
        nacionalidad:     nacionalidad,
        nacionalidadCode: nacionalidadCode,
        countryFlag:      countryFlag,
        terminosAceptados: true,
        gdprAceptadoEn:   gdprAceptadoEn,
        gdprVersion:      gdprVersion,
        followersCount:   0,
        followingCount:   0,
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
        // Caso edge: usuario existe en Auth pero no en Firestore.
        // Creamos un documento mínimo para no dejarlo sin perfil.
        final minimalUser = UserModel(
          uid:            firebaseUser.uid,
          email:          firebaseUser.email ?? email,
          nombreCompleto: firebaseUser.displayName,
          fotoUrl:        firebaseUser.photoURL,
          terminosAceptados: false,
          followersCount: 0,
          followingCount: 0,
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
      await GoogleSignIn().signOut(); // no-op si entró con email
    } catch (_) {
      // Google Sign In puede no estar inicializado si entró con email.
    }
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
  //
  // Llamar desde la pantalla de términos que aparece después del primer
  // Google Sign In, cuando terminosAceptados == false.
  //
  // IMPORTANTE: solo escribe los campos de la convención en español.
  // No agrega acceptedTerms, acceptedAt ni createdAt.

  Future<String?> aceptarTerminos({
    required String uid,
    String gdprVersion = '1.0',
  }) async {
    try {
      await _db.collection(_usersCollection).doc(uid).update({
        'terminosAceptados': true,
        'gdprAceptadoEn':    FieldValue.serverTimestamp(),
        'gdprVersion':       gdprVersion,
        'actualizadoEn':     FieldValue.serverTimestamp(),
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
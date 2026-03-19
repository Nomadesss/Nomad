import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthService — autenticación y creación de perfil en Nomad
//
// Colección Firestore: 'users'  ← unificado. Era 'usuarios', estaba roto.
//
// Convención de retorno:
//   Todos los métodos devuelven ({T? data, String? error}).
//   Si error == null → operación exitosa.
//   Si error != null → mostrar el mensaje al usuario.
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Nombre de la colección en un solo lugar.
  // Si alguna vez cambia, se cambia acá y listo.
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
  // CORRECCIÓN: en el original este método no tocaba Firestore.
  // El usuario entraba pero no tenía documento → todo lo demás fallaba.

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

      // Verificar si el documento ya existe en Firestore.
      final docRef = _db.collection(_usersCollection).doc(firebaseUser.uid);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        // Primera vez con Google → crear documento base.
        // NO pedimos términos acá porque el flujo de Google no los mostró.
        // El router debe detectar gdprCompliant == false y llevar al usuario
        // a la pantalla de términos antes de entrar al feed.
        final newUser = UserModel(
          uid:           firebaseUser.uid,
          email:         firebaseUser.email ?? '',
          nombreCompleto: firebaseUser.displayName,
          fotoUrl:       firebaseUser.photoURL,
          // gdprAceptadoEn se completa en el paso de términos post-Google
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
  //
  // CAMBIOS respecto al original:
  //   - Eliminada la query manual de email duplicado. Firebase Auth ya lo
  //     detecta atómicamente con 'email-already-in-use'. La query extra era
  //     redundante y tenía una race condition (dos usuarios registrándose
  //     con el mismo email al mismo tiempo podían pasar los dos la query).
  //   - 'usuarios' → 'users'.
  //   - terminosAceptados ya no es hardcodeado false.
  //   - Recibe gdprAceptadoEn como parámetro — obligatorio por GDPR.
  //   - Devuelve UserModel en lugar de solo null/error.

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
    // Campos opcionales del perfil migratorio.
    // Si el registro tiene pantalla de origen, pasarlos acá.
    // Si no, se completan después desde el perfil.
    String? nacionalidad,
    String? nacionalidadCode,
    String? countryFlag,
  }) async {
    try {
      // 1. Crear usuario en Firebase Auth.
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return (user: null, error: 'No se pudo crear el usuario. Intentá de nuevo.');
      }

      // 2. Actualizar displayName en Firebase Auth.
      //    Esto hace que firebaseUser.displayName funcione en otros servicios.
      final nombreCompleto = '${nombres.trim()} ${apellidos.trim()}';
      await firebaseUser.updateDisplayName(nombreCompleto);

      // 3. Construir el modelo tipado.
      final newUser = UserModel(
        uid:            firebaseUser.uid,
        email:          email.trim().toLowerCase(),
        nombres:        nombres.trim(),
        apellidos:      apellidos.trim(),
        nombreCompleto: nombreCompleto,
        fechaNacimiento: fechaNacimiento,
        nacionalidad:     nacionalidad,
        nacionalidadCode: nacionalidadCode,
        countryFlag:      countryFlag,
        // GDPR: guardamos el timestamp real de aceptación.
        terminosAceptados: true,
        gdprAceptadoEn:    gdprAceptadoEn,
        gdprVersion:       gdprVersion,
        // Contadores iniciales.
        followersCount: 0,
        followingCount: 0,
      );

      // 4. Guardar documento en Firestore.
      await _db
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .set(newUser.toMap());

      // 5. Enviar email de verificación (no bloqueante — si falla, no importa).
      firebaseUser.sendEmailVerification().ignore();

      return (user: newUser, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _mapAuthError(e));
    } catch (e) {
      return (user: null, error: 'Error inesperado. Intentá de nuevo.');
    }
  }

  // ── Login con email y contraseña ───────────────────────────────────────────
  //
  // NUEVO. Faltaba en el servicio original.
  //
  // Devuelve el UserModel leído de Firestore, no el User de Firebase Auth,
  // para que el caller tenga el perfil completo listo desde el primer momento.

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

      // Leer el documento de Firestore para devolver el modelo completo.
      final docSnap = await _db
          .collection(_usersCollection)
          .doc(firebaseUser.uid)
          .get();

      if (!docSnap.exists) {
        // Caso edge: el usuario existe en Auth pero no en Firestore
        // (ej: se creó antes de que existiera este servicio).
        // Creamos un documento mínimo para no dejarlo sin perfil.
        final minimalUser = UserModel(
          uid:   firebaseUser.uid,
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
  //
  // NUEVO. Faltaba en el servicio original.
  //
  // Cierra sesión tanto en Firebase Auth como en Google Sign In.
  // Si el usuario entró con Google, hay que desconectarlo de ambos
  // para que la próxima vez muestre el selector de cuentas.

  Future<void> cerrarSesion() async {
    try {
      await GoogleSignIn().signOut(); // no-op si entró con email
    } catch (_) {
      // Google Sign In puede no estar inicializado si entró con email.
      // Ignoramos el error y continuamos con Firebase Auth.
    }
    await _auth.signOut();
  }

  // ── Reset de contraseña ────────────────────────────────────────────────────
  //
  // NUEVO. Faltaba en el servicio original.
  //
  // Firebase envía un email con link de reset.
  // El método retorna null si tuvo éxito, o un mensaje de error si falló.

  Future<String?> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
      return null; // éxito
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    } catch (e) {
      return 'Error inesperado. Intentá de nuevo.';
    }
  }

  // ── Aceptar términos (post Google Sign In) ─────────────────────────────────
  //
  // Llamar desde la pantalla de términos que aparece después del primer
  // Google Sign In, cuando gdprCompliant == false.

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
  //
  // Centralizado acá para no tener switches duplicados en auth y login.

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este email ya está en uso. Iniciá sesión.';
      case 'user-not-found':
        return 'No encontramos una cuenta con ese email.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'invalid-credential':
        // Firebase v10+ unifica user-not-found + wrong-password en este código.
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
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // ── Disponibilidad ────────────────────────────────────────────

  /// Retorna true si el dispositivo soporta biometría Y tiene alguna registrada
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Lista de biometrías disponibles en el dispositivo
  static Future<List<BiometricType>> availableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  // ── Preferencia del usuario ───────────────────────────────────

  static const _keyEnabled = 'biometric_enabled';
  static const _keyUid = 'biometric_uid';

  /// Guarda que este usuario habilitó biometría
  static Future<void> setEnabled(String uid, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
    await prefs.setString(_keyUid, uid);
  }

  /// Retorna true si este usuario específico habilitó biometría
  static Future<bool> isEnabledForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    final savedUid = prefs.getString(_keyUid) ?? '';
    return enabled && savedUid == uid;
  }

  /// Retorna true si es la primera vez que este usuario inicia sesión
  /// en este dispositivo (no tiene preferencia guardada)
  static Future<bool> isFirstTimeForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final savedUid = prefs.getString(_keyUid) ?? '';
    return savedUid != uid;
  }

  // ── Autenticación ─────────────────────────────────────────────

  /// Solicita autenticación biométrica.
  /// Retorna true si fue exitosa, false si falló o canceló.
  static Future<bool> authenticate({
    String reason = 'Confirmá tu identidad para continuar',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // permite PIN como fallback
          stickyAuth: true, // no cancela si el usuario cambia de app
          sensitiveTransaction: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

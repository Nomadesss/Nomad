import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UserModel — modelo de usuario para Nomad
//
// Espejo exacto de la colección 'users' en Firestore.
// Todos los campos opcionales reflejan los distintos momentos en que se
// completa el perfil: registro con email, Google Sign In, onboarding, etc.
// ─────────────────────────────────────────────────────────────────────────────

class UserModel {
  final String uid;
  final String email;

  // Nombre completo precalculado. Se guarda en Firestore para poder hacer
  // queries sin tener que concatenar nombres + apellidos en el cliente.
  final String? nombreCompleto;

  // Nombre y apellido por separado — sólo disponibles en registro con email.
  final String? nombres;
  final String? apellidos;

  final DateTime? fechaNacimiento;

  // Foto de perfil. Viene de Google Sign In o se sube manualmente.
  final String? fotoUrl;

  // ── Datos migratorios ──────────────────────────────────────────────────────
  final String? nacionalidad;      // ej: "Argentina"
  final String? nacionalidadCode;  // ej: "AR"
  final String? countryFlag;       // ej: "🇦🇷"

  // ── GDPR / Términos ────────────────────────────────────────────────────────
  // Si terminosAceptados == false, el router debe llevar al usuario
  // a la pantalla de términos antes de dejar entrar al feed.
  final bool terminosAceptados;
  final DateTime? gdprAceptadoEn;
  final String? gdprVersion;

  // ── Social ─────────────────────────────────────────────────────────────────
  final int followersCount;
  final int followingCount;

  // ── Timestamps ────────────────────────────────────────────────────────────
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  const UserModel({
    required this.uid,
    required this.email,
    this.nombreCompleto,
    this.nombres,
    this.apellidos,
    this.fechaNacimiento,
    this.fotoUrl,
    this.nacionalidad,
    this.nacionalidadCode,
    this.countryFlag,
    this.terminosAceptados = false,
    this.gdprAceptadoEn,
    this.gdprVersion,
    this.followersCount = 0,
    this.followingCount = 0,
    this.creadoEn,
    this.actualizadoEn,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// true si el usuario completó el paso de términos / GDPR.
  bool get gdprCompliant => terminosAceptados && gdprAceptadoEn != null;

  /// Nombre para mostrar en la UI: nombreCompleto, o la parte antes del @.
  String get displayName =>
      nombreCompleto?.isNotEmpty == true
          ? nombreCompleto!
          : email.split('@').first;

  // ── Serialización ──────────────────────────────────────────────────────────

  /// Convierte el modelo a un Map listo para escribir en Firestore.
  /// Los campos nulos se omiten para no pisar datos preexistentes con set+merge.
  Map<String, dynamic> toMap() {
    return {
      'uid':   uid,
      'email': email,
      if (nombreCompleto != null) 'nombreCompleto': nombreCompleto,
      if (nombres != null)        'nombres':        nombres,
      if (apellidos != null)      'apellidos':      apellidos,
      if (fechaNacimiento != null)
        'fechaNacimiento': Timestamp.fromDate(fechaNacimiento!),
      if (fotoUrl != null)          'fotoUrl':          fotoUrl,
      if (nacionalidad != null)     'nacionalidad':     nacionalidad,
      if (nacionalidadCode != null) 'nacionalidadCode': nacionalidadCode,
      if (countryFlag != null)      'countryFlag':      countryFlag,
      'terminosAceptados': terminosAceptados,
      if (gdprAceptadoEn != null)
        'gdprAceptadoEn': Timestamp.fromDate(gdprAceptadoEn!),
      if (gdprVersion != null) 'gdprVersion': gdprVersion,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'creadoEn':      FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
  }

  /// Construye un UserModel desde un DocumentSnapshot de Firestore.
  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data);
  }

  /// Construye un UserModel desde un Map plano (útil para tests).
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid:            data['uid']   as String? ?? '',
      email:          data['email'] as String? ?? '',
      nombreCompleto: data['nombreCompleto'] as String?,
      nombres:        data['nombres']        as String?,
      apellidos:      data['apellidos']      as String?,
      fechaNacimiento: _toDateTime(data['fechaNacimiento']),
      fotoUrl:          data['fotoUrl']          as String?,
      nacionalidad:     data['nacionalidad']     as String?,
      nacionalidadCode: data['nacionalidadCode'] as String?,
      countryFlag:      data['countryFlag']      as String?,
      terminosAceptados: data['terminosAceptados'] as bool? ?? false,
      gdprAceptadoEn:    _toDateTime(data['gdprAceptadoEn']),
      gdprVersion:       data['gdprVersion'] as String?,
      followersCount: data['followersCount'] as int? ?? 0,
      followingCount: data['followingCount'] as int? ?? 0,
      creadoEn:      _toDateTime(data['creadoEn']),
      actualizadoEn: _toDateTime(data['actualizadoEn']),
    );
  }

  /// copyWith para actualizar campos puntuales sin mutar el objeto.
  UserModel copyWith({
    String? uid,
    String? email,
    String? nombreCompleto,
    String? nombres,
    String? apellidos,
    DateTime? fechaNacimiento,
    String? fotoUrl,
    String? nacionalidad,
    String? nacionalidadCode,
    String? countryFlag,
    bool? terminosAceptados,
    DateTime? gdprAceptadoEn,
    String? gdprVersion,
    int? followersCount,
    int? followingCount,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return UserModel(
      uid:            uid            ?? this.uid,
      email:          email          ?? this.email,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      nombres:        nombres        ?? this.nombres,
      apellidos:      apellidos      ?? this.apellidos,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      fotoUrl:          fotoUrl          ?? this.fotoUrl,
      nacionalidad:     nacionalidad     ?? this.nacionalidad,
      nacionalidadCode: nacionalidadCode ?? this.nacionalidadCode,
      countryFlag:      countryFlag      ?? this.countryFlag,
      terminosAceptados: terminosAceptados ?? this.terminosAceptados,
      gdprAceptadoEn:    gdprAceptadoEn    ?? this.gdprAceptadoEn,
      gdprVersion:       gdprVersion       ?? this.gdprVersion,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      creadoEn:      creadoEn      ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }

  @override
  String toString() => 'UserModel(uid: $uid, email: $email, gdprCompliant: $gdprCompliant)';

  // ── Utilidad privada ───────────────────────────────────────────────────────

  /// Convierte un campo Firestore (Timestamp o DateTime) a DateTime?.
  /// Firestore devuelve Timestamp; los tests pueden pasar DateTime directamente.
  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MigrationStatus — estado actual del usuario en su proceso migratorio
//
// planning   → todavía en su país de origen, planificando la mudanza
// in_transit → en proceso de mudanza / tramitando documentos
// arrived    → llegó al país destino, fase de instalación
// established → ya establecido, documentos en orden
// ─────────────────────────────────────────────────────────────────────────────

enum MigrationStatus {
  planning,
  inTransit,
  arrived,
  established;

  /// Convierte el string de Firestore al enum.
  /// Devuelve [planning] si el valor no es reconocido.
  static MigrationStatus fromString(String? value) {
    switch (value) {
      case 'planning':
        return MigrationStatus.planning;
      case 'in_transit':
        return MigrationStatus.inTransit;
      case 'arrived':
        return MigrationStatus.arrived;
      case 'established':
        return MigrationStatus.established;
      default:
        return MigrationStatus.planning;
    }
  }

  /// Convierte el enum al string que se guarda en Firestore.
  String toFirestoreString() {
    switch (this) {
      case MigrationStatus.planning:
        return 'planning';
      case MigrationStatus.inTransit:
        return 'in_transit';
      case MigrationStatus.arrived:
        return 'arrived';
      case MigrationStatus.established:
        return 'established';
    }
  }

  /// Etiqueta legible para mostrar en la UI.
  String get label {
    switch (this) {
      case MigrationStatus.planning:
        return 'Planificando';
      case MigrationStatus.inTransit:
        return 'En tránsito';
      case MigrationStatus.arrived:
        return 'Recién llegado';
      case MigrationStatus.established:
        return 'Establecido';
    }
  }

  String get emoji {
    switch (this) {
      case MigrationStatus.planning:
        return '🗺️';
      case MigrationStatus.inTransit:
        return '✈️';
      case MigrationStatus.arrived:
        return '📦';
      case MigrationStatus.established:
        return '🏠';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UserModel — representa un documento de la colección 'users' en Firestore
//
// Colección: users/{uid}
//
// Regla general: todos los campos son nullable excepto uid y email,
// que siempre existen si el documento fue creado correctamente.
// ─────────────────────────────────────────────────────────────────────────────

class UserModel {
  // ── Identidad ──────────────────────────────────────────────────────────────
  final String uid;
  final String email;
  final String? nombres;
  final String? apellidos;
  final String? nombreCompleto;
  final String? username;
  final String? fotoUrl;
  final String? bio;
  final DateTime? fechaNacimiento;

  // ── Ubicación y origen ─────────────────────────────────────────────────────
  final String? nacionalidad;         // país de origen (ej: 'Uruguay')
  final String? nacionalidadCode;     // código ISO (ej: 'UY')
  final String? countryFlag;          // emoji bandera (ej: '🇺🇾')
  final Map<String, dynamic>? ubicacionActual; // snapshot de LocationData

  // ── Perfil migratorio ──────────────────────────────────────────────────────
  // Estos campos son el núcleo del Community Hub.
  // Se completan en el onboarding extendido o desde el perfil.
  final String? destinationCountry;   // país al que quiere/fue a migrar (ej: 'España')
  final String? destinationCountryCode; // código ISO destino (ej: 'ES')
  final MigrationStatus migrationStatus;
  final String? visaType;             // tipo de visa actual (ej: 'Trabajo cuenta ajena')
  final bool hasChildren;             // afecta checklist y contenido mostrado
  final String? profession;           // para matching laboral
  final DateTime? arrivedAt;          // cuándo llegó al país destino

  // ── Social ─────────────────────────────────────────────────────────────────
  final int followersCount;
  final int followingCount;

  // ── Trust score ────────────────────────────────────────────────────────────
  final Map<String, dynamic>? trustScore; // snapshot de TrustScoreResult.toMap()

  // ── GDPR / Legal ───────────────────────────────────────────────────────────
  // CRÍTICO: terminosAceptados no puede ser hardcodeado false.
  // gdprAceptadoEn null significa que el usuario NO aceptó los términos.
  final bool terminosAceptados;
  final DateTime? gdprAceptadoEn;           // timestamp de aceptación explícita
  final String? gdprVersion;                // versión de términos aceptados (ej: '1.0')
  final DateTime? dataDeletionRequestedAt;  // derecho al olvido — Art. 17 GDPR

  // ── Discover ───────────────────────────────────────────────────────────────
  final String? genero;               // 'masculino' | 'femenino' | 'no_binario'
  final List<String>? discoverPhotos; // carrusel de fotos (hasta 6 URLs)

  // ── Metadata ───────────────────────────────────────────────────────────────
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  const UserModel({
    required this.uid,
    required this.email,
    this.nombres,
    this.apellidos,
    this.nombreCompleto,
    this.username,
    this.fotoUrl,
    this.bio,
    this.fechaNacimiento,
    this.nacionalidad,
    this.nacionalidadCode,
    this.countryFlag,
    this.ubicacionActual,
    this.destinationCountry,
    this.destinationCountryCode,
    this.migrationStatus = MigrationStatus.planning,
    this.visaType,
    this.hasChildren = false,
    this.profession,
    this.arrivedAt,
    this.followersCount = 0,
    this.followingCount = 0,
    this.trustScore,
    this.terminosAceptados = false,
    this.gdprAceptadoEn,
    this.gdprVersion,
    this.dataDeletionRequestedAt,
    this.genero,
    this.discoverPhotos,
    this.creadoEn,
    this.actualizadoEn,
  });

  // ── fromMap ────────────────────────────────────────────────────────────────
  // Construye un UserModel desde un documento de Firestore.
  // Usa casteos seguros — nunca lanza si un campo está ausente o es null.

  factory UserModel.fromMap(Map<String, dynamic> map, {String? uid}) {
    return UserModel(
      uid:              uid ?? map['uid'] as String? ?? '',
      email:            map['email'] as String? ?? '',
      nombres:          map['nombres'] as String?,
      apellidos:        map['apellidos'] as String?,
      nombreCompleto:   map['nombreCompleto'] as String?,
      username:         map['username'] as String?,
      fotoUrl:          map['fotoUrl'] as String?,
      bio:              map['bio'] as String?,
      fechaNacimiento:  _tsToDateTime(map['fechaNacimiento']),
      nacionalidad:         map['nacionalidad'] as String?,
      nacionalidadCode:     map['nacionalidadCode'] as String?,
      countryFlag:          map['countryFlag'] as String?,
      ubicacionActual:      map['ubicacionActual'] as Map<String, dynamic>?,
      destinationCountry:      map['destinationCountry'] as String?,
      destinationCountryCode:  map['destinationCountryCode'] as String?,
      migrationStatus:  MigrationStatus.fromString(map['migrationStatus'] as String?),
      visaType:         map['visaType'] as String?,
      hasChildren:      map['hasChildren'] as bool? ?? false,
      profession:       map['profession'] as String?,
      arrivedAt:        _tsToDateTime(map['arrivedAt']),
      followersCount:   (map['followersCount'] as num?)?.toInt() ?? 0,
      followingCount:   (map['followingCount'] as num?)?.toInt() ?? 0,
      trustScore:       map['trustScore'] as Map<String, dynamic>?,
      genero:           map['genero'] as String?,
      discoverPhotos:   (map['discoverPhotos'] as List?)
                            ?.map((e) => e as String)
                            .toList(),
      terminosAceptados:    map['terminosAceptados'] as bool? ?? false,
      gdprAceptadoEn:       _tsToDateTime(map['gdprAceptadoEn']),
      gdprVersion:          map['gdprVersion'] as String?,
      dataDeletionRequestedAt: _tsToDateTime(map['dataDeletionRequestedAt']),
      creadoEn:         _tsToDateTime(map['creadoEn']),
      actualizadoEn:    _tsToDateTime(map['actualizadoEn']),
    );
  }

  // ── fromDoc ────────────────────────────────────────────────────────────────
  // Atajo para construir desde un DocumentSnapshot de Firestore.

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    return UserModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      uid: doc.id,
    );
  }

  // ── toMap ──────────────────────────────────────────────────────────────────
  // Convierte el modelo al Map que se escribe en Firestore.
  // Los campos null se incluyen explícitamente para que Firestore
  // sobreescriba cualquier valor previo al hacer un set() con merge.

  Map<String, dynamic> toMap() {
    return {
      'uid':            uid,
      'email':          email,
      'nombres':        nombres,
      'apellidos':      apellidos,
      'nombreCompleto': nombreCompleto,
      'username':       username,
      'fotoUrl':        fotoUrl,
      'bio':            bio,
      'fechaNacimiento': fechaNacimiento != null
          ? Timestamp.fromDate(fechaNacimiento!)
          : null,
      'nacionalidad':       nacionalidad,
      'nacionalidadCode':   nacionalidadCode,
      'countryFlag':        countryFlag,
      'ubicacionActual':    ubicacionActual,
      'destinationCountry':      destinationCountry,
      'destinationCountryCode':  destinationCountryCode,
      'migrationStatus':    migrationStatus.toFirestoreString(),
      'visaType':           visaType,
      'hasChildren':        hasChildren,
      'profession':         profession,
      'arrivedAt': arrivedAt != null
          ? Timestamp.fromDate(arrivedAt!)
          : null,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'trustScore':     trustScore,
      'genero':         genero,
      'discoverPhotos': discoverPhotos,
      'terminosAceptados':    terminosAceptados,
      'gdprAceptadoEn': gdprAceptadoEn != null
          ? Timestamp.fromDate(gdprAceptadoEn!)
          : null,
      'gdprVersion':            gdprVersion,
      'dataDeletionRequestedAt': dataDeletionRequestedAt != null
          ? Timestamp.fromDate(dataDeletionRequestedAt!)
          : null,
      'creadoEn':     FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
  }

  // ── toUpdateMap ────────────────────────────────────────────────────────────
  // Versión de toMap() para updates parciales (no incluye creadoEn
  // ni campos que no deben sobreescribirse en un update).
  // Usá este map en update(), no en set().

  Map<String, dynamic> toUpdateMap() {
    return {
      if (nombres != null)          'nombres': nombres,
      if (apellidos != null)        'apellidos': apellidos,
      if (nombreCompleto != null)   'nombreCompleto': nombreCompleto,
      if (username != null)         'username': username,
      if (fotoUrl != null)          'fotoUrl': fotoUrl,
      if (bio != null)              'bio': bio,
      if (nacionalidad != null)     'nacionalidad': nacionalidad,
      if (nacionalidadCode != null) 'nacionalidadCode': nacionalidadCode,
      if (countryFlag != null)      'countryFlag': countryFlag,
      if (ubicacionActual != null)  'ubicacionActual': ubicacionActual,
      if (destinationCountry != null)     'destinationCountry': destinationCountry,
      if (destinationCountryCode != null) 'destinationCountryCode': destinationCountryCode,
      'migrationStatus': migrationStatus.toFirestoreString(),
      'hasChildren':     hasChildren,
      if (visaType != null)    'visaType': visaType,
      if (profession != null)  'profession': profession,
      if (arrivedAt != null)   'arrivedAt': Timestamp.fromDate(arrivedAt!),
      if (trustScore != null)  'trustScore': trustScore,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
  }

  // ── copyWith ───────────────────────────────────────────────────────────────
  // Crea una nueva instancia con los campos modificados.
  // Útil en providers/blocs para actualizar el estado sin mutar el objeto.

  UserModel copyWith({
    String? uid,
    String? email,
    String? nombres,
    String? apellidos,
    String? nombreCompleto,
    String? username,
    String? fotoUrl,
    String? bio,
    DateTime? fechaNacimiento,
    String? nacionalidad,
    String? nacionalidadCode,
    String? countryFlag,
    Map<String, dynamic>? ubicacionActual,
    String? destinationCountry,
    String? destinationCountryCode,
    MigrationStatus? migrationStatus,
    String? visaType,
    bool? hasChildren,
    String? profession,
    DateTime? arrivedAt,
    int? followersCount,
    int? followingCount,
    Map<String, dynamic>? trustScore,
    bool? terminosAceptados,
    DateTime? gdprAceptadoEn,
    String? gdprVersion,
    DateTime? dataDeletionRequestedAt,
    String? genero,
    List<String>? discoverPhotos,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return UserModel(
      uid:            uid            ?? this.uid,
      email:          email          ?? this.email,
      nombres:        nombres        ?? this.nombres,
      apellidos:      apellidos      ?? this.apellidos,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      username:       username       ?? this.username,
      fotoUrl:        fotoUrl        ?? this.fotoUrl,
      bio:            bio            ?? this.bio,
      fechaNacimiento:   fechaNacimiento   ?? this.fechaNacimiento,
      nacionalidad:      nacionalidad      ?? this.nacionalidad,
      nacionalidadCode:  nacionalidadCode  ?? this.nacionalidadCode,
      countryFlag:       countryFlag       ?? this.countryFlag,
      ubicacionActual:   ubicacionActual   ?? this.ubicacionActual,
      destinationCountry:      destinationCountry      ?? this.destinationCountry,
      destinationCountryCode:  destinationCountryCode  ?? this.destinationCountryCode,
      migrationStatus:  migrationStatus  ?? this.migrationStatus,
      visaType:         visaType         ?? this.visaType,
      hasChildren:      hasChildren      ?? this.hasChildren,
      profession:       profession       ?? this.profession,
      arrivedAt:        arrivedAt        ?? this.arrivedAt,
      followersCount:   followersCount   ?? this.followersCount,
      followingCount:   followingCount   ?? this.followingCount,
      trustScore:       trustScore       ?? this.trustScore,
      terminosAceptados:    terminosAceptados    ?? this.terminosAceptados,
      gdprAceptadoEn:       gdprAceptadoEn       ?? this.gdprAceptadoEn,
      gdprVersion:          gdprVersion          ?? this.gdprVersion,
      dataDeletionRequestedAt: dataDeletionRequestedAt ?? this.dataDeletionRequestedAt,
      genero:           genero           ?? this.genero,
      discoverPhotos:   discoverPhotos   ?? this.discoverPhotos,
      creadoEn:       creadoEn      ?? this.creadoEn,
      actualizadoEn:  actualizadoEn ?? this.actualizadoEn,
    );
  }

  // ── Helpers de display ─────────────────────────────────────────────────────

  /// Nombre para mostrar en la UI. Prioridad: nombreCompleto → nombres → username → email.
  String get displayName =>
      nombreCompleto?.isNotEmpty == true ? nombreCompleto! :
      nombres?.isNotEmpty == true        ? nombres! :
      username?.isNotEmpty == true       ? username! :
      email;

  /// Iniciales para el avatar cuando no hay foto.
  String get initials {
    final name = nombreCompleto ?? nombres ?? username ?? email;
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// True si el perfil migratorio mínimo está completo.
  bool get hasMigrationProfile =>
      destinationCountry != null && migrationStatus != MigrationStatus.planning;

  /// True si aceptó los términos con timestamp válido (requerido por GDPR).
  bool get gdprCompliant => terminosAceptados && gdprAceptadoEn != null;

  // ── Helper privado: Timestamp → DateTime ───────────────────────────────────
  static DateTime? _tsToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, email: $email, status: ${migrationStatus.label})';
}
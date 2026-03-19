// ─────────────────────────────────────────────────────────────────────────────
// migration_data_model.dart — modelos de datos para el User Journey de Nomad
//
// Ubicación: lib/services/migration_data_model.dart
//
// Fuentes de datos que alimentan estos modelos:
//   OIM GMDAC   → migration.iom.int/api/  (open access, no requiere auth)
//   Numbeo API  → api.numbeo.com/api/      (plan gratuito, 50k req/mes)
//   OIM AVRR    → www.iom.int/avrr         (scraping ético / datos manuales)
//   Missing M.  → missingmigrants.iom.int  (API pública)
// ─────────────────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════════

/// Las 4 fases del User Journey del migrante en Nomad.
enum MigrantPhase {
  discovery,    // Fase 1: Descubrimiento — investiga destinos
  preparation,  // Fase 2: Preparación   — junta documentos
  transition,   // Fase 3: Transición    — viaje y llegada
  integration;  // Fase 4: Integración   — asentamiento

  String get label {
    switch (this) {
      case MigrantPhase.discovery:    return 'Descubrimiento';
      case MigrantPhase.preparation:  return 'Preparación';
      case MigrantPhase.transition:   return 'Transición';
      case MigrantPhase.integration:  return 'Integración';
    }
  }

  String get emoji {
    switch (this) {
      case MigrantPhase.discovery:    return '🔍';
      case MigrantPhase.preparation:  return '📋';
      case MigrantPhase.transition:   return '✈️';
      case MigrantPhase.integration:  return '🏠';
    }
  }

  String get description {
    switch (this) {
      case MigrantPhase.discovery:
        return 'Investigás destinos y evaluás opciones';
      case MigrantPhase.preparation:
        return 'Preparás documentos y tramitás la visa';
      case MigrantPhase.transition:
        return 'Viajás y te instalás en tu nuevo país';
      case MigrantPhase.integration:
        return 'Te establecés, trabajás y construís tu vida';
    }
  }
}

/// Perfil del usuario migrante — determina qué visas y contenido se muestran.
enum MigrantProfileType {
  professional,   // Trabajador calificado / profesional
  student,        // Estudiante
  entrepreneur,   // Emprendedor / inversor
  familyJoin,     // Reagrupación familiar
  nomad,          // Nómada digital / remoto
  refugee,        // Solicitante de asilo / refugiado
  returnee;       // Migrante que quiere volver a su país de origen

  String get label {
    switch (this) {
      case MigrantProfileType.professional:  return 'Trabajador profesional';
      case MigrantProfileType.student:       return 'Estudiante';
      case MigrantProfileType.entrepreneur:  return 'Emprendedor';
      case MigrantProfileType.familyJoin:    return 'Reagrupación familiar';
      case MigrantProfileType.nomad:         return 'Nómada digital';
      case MigrantProfileType.refugee:       return 'Solicitante de asilo';
      case MigrantProfileType.returnee:      return 'Retorno voluntario';
    }
  }

  String get emoji {
    switch (this) {
      case MigrantProfileType.professional:  return '💼';
      case MigrantProfileType.student:       return '🎓';
      case MigrantProfileType.entrepreneur:  return '🚀';
      case MigrantProfileType.familyJoin:    return '👨‍👩‍👧';
      case MigrantProfileType.nomad:         return '💻';
      case MigrantProfileType.refugee:       return '🕊️';
      case MigrantProfileType.returnee:      return '🏡';
    }
  }

  static MigrantProfileType fromString(String? v) {
    switch (v) {
      case 'professional':  return MigrantProfileType.professional;
      case 'student':       return MigrantProfileType.student;
      case 'entrepreneur':  return MigrantProfileType.entrepreneur;
      case 'familyJoin':    return MigrantProfileType.familyJoin;
      case 'nomad':         return MigrantProfileType.nomad;
      case 'refugee':       return MigrantProfileType.refugee;
      case 'returnee':      return MigrantProfileType.returnee;
      default:              return MigrantProfileType.professional;
    }
  }

  String toFirestoreString() => name;
}

/// Nivel de apertura migratoria de un país (basado en índice MIPEX de OIM).
enum PolicyOpenness {
  veryOpen,       // MIPEX score 70-100: muy favorable para migrantes
  open,           // MIPEX score 50-69
  moderate,       // MIPEX score 30-49
  restrictive,    // MIPEX score 10-29
  veryRestrictive;// MIPEX score 0-9

  String get label {
    switch (this) {
      case PolicyOpenness.veryOpen:        return 'Muy abierta';
      case PolicyOpenness.open:            return 'Abierta';
      case PolicyOpenness.moderate:        return 'Moderada';
      case PolicyOpenness.restrictive:     return 'Restrictiva';
      case PolicyOpenness.veryRestrictive: return 'Muy restrictiva';
    }
  }

  static PolicyOpenness fromScore(int score) {
    if (score >= 70) return PolicyOpenness.veryOpen;
    if (score >= 50) return PolicyOpenness.open;
    if (score >= 30) return PolicyOpenness.moderate;
    if (score >= 10) return PolicyOpenness.restrictive;
    return PolicyOpenness.veryRestrictive;
  }
}

/// Nivel de alerta de seguridad para una ruta migratoria.
enum RouteAlertLevel {
  safe,     // Sin alertas activas
  low,      // Precauciones menores
  medium,   // Precauciones importantes
  high,     // Ruta de alto riesgo
  critical; // Ruta humanitaria activa — NO recomendada

  String get label {
    switch (this) {
      case RouteAlertLevel.safe:     return 'Sin alertas';
      case RouteAlertLevel.low:      return 'Bajo riesgo';
      case RouteAlertLevel.medium:   return 'Riesgo moderado';
      case RouteAlertLevel.high:     return 'Alto riesgo';
      case RouteAlertLevel.critical: return 'Ruta crítica';
    }
  }

  String get emoji {
    switch (this) {
      case RouteAlertLevel.safe:     return '🟢';
      case RouteAlertLevel.low:      return '🟡';
      case RouteAlertLevel.medium:   return '🟠';
      case RouteAlertLevel.high:     return '🔴';
      case RouteAlertLevel.critical: return '⚫';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERFIL DE MIGRACIÓN DEL USUARIO
// ═══════════════════════════════════════════════════════════════════════════════

/// Perfil de migración del usuario — combina datos del UserModel con la
/// selección de destino y perfil para alimentar el dashboard.
///
/// Se crea al iniciar el User Journey y se actualiza a medida que el usuario
/// avanza por las fases.
class MigrationProfile {
  final String              userId;
  final String              originCountry;      // ISO 3166 (ej: 'MX')
  final String              originCountryName;  // ej: 'México'
  final String              destinationCountry; // ISO 3166 (ej: 'CA')
  final String              destinationCountryName; // ej: 'Canadá'
  final MigrantProfileType  profileType;
  final MigrantPhase        currentPhase;
  final bool                hasChildren;
  final String?             profession;
  final String?             targetCity;         // ej: 'Calgary'
  final DateTime?           plannedDepartureDate;
  final DateTime            createdAt;
  final DateTime            updatedAt;

  const MigrationProfile({
    required this.userId,
    required this.originCountry,
    required this.originCountryName,
    required this.destinationCountry,
    required this.destinationCountryName,
    required this.profileType,
    required this.currentPhase,
    required this.createdAt,
    required this.updatedAt,
    this.hasChildren         = false,
    this.profession,
    this.targetCity,
    this.plannedDepartureDate,
  });

  factory MigrationProfile.fromMap(Map<String, dynamic> m) {
    return MigrationProfile(
      userId:               m['userId'] as String? ?? '',
      originCountry:        m['originCountry'] as String? ?? '',
      originCountryName:    m['originCountryName'] as String? ?? '',
      destinationCountry:   m['destinationCountry'] as String? ?? '',
      destinationCountryName: m['destinationCountryName'] as String? ?? '',
      profileType:          MigrantProfileType.fromString(m['profileType'] as String?),
      currentPhase:         _phaseFromString(m['currentPhase'] as String?),
      hasChildren:          m['hasChildren'] as bool? ?? false,
      profession:           m['profession'] as String?,
      targetCity:           m['targetCity'] as String?,
      plannedDepartureDate: m['plannedDepartureDate'] != null
          ? DateTime.tryParse(m['plannedDepartureDate'] as String)
          : null,
      createdAt:  DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:  DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId':               userId,
    'originCountry':        originCountry,
    'originCountryName':    originCountryName,
    'destinationCountry':   destinationCountry,
    'destinationCountryName': destinationCountryName,
    'profileType':          profileType.toFirestoreString(),
    'currentPhase':         currentPhase.name,
    'hasChildren':          hasChildren,
    'profession':           profession,
    'targetCity':           targetCity,
    'plannedDepartureDate': plannedDepartureDate?.toIso8601String(),
    'createdAt':            createdAt.toIso8601String(),
    'updatedAt':            DateTime.now().toIso8601String(),
  };

  MigrationProfile copyWith({
    MigrantPhase?        currentPhase,
    String?              targetCity,
    DateTime?            plannedDepartureDate,
    MigrantProfileType?  profileType,
    bool?                hasChildren,
    String?              profession,
  }) {
    return MigrationProfile(
      userId:               userId,
      originCountry:        originCountry,
      originCountryName:    originCountryName,
      destinationCountry:   destinationCountry,
      destinationCountryName: destinationCountryName,
      profileType:          profileType  ?? this.profileType,
      currentPhase:         currentPhase ?? this.currentPhase,
      hasChildren:          hasChildren  ?? this.hasChildren,
      profession:           profession   ?? this.profession,
      targetCity:           targetCity   ?? this.targetCity,
      plannedDepartureDate: plannedDepartureDate ?? this.plannedDepartureDate,
      createdAt:            createdAt,
      updatedAt:            DateTime.now(),
    );
  }

  static MigrantPhase _phaseFromString(String? v) {
    switch (v) {
      case 'discovery':    return MigrantPhase.discovery;
      case 'preparation':  return MigrantPhase.preparation;
      case 'transition':   return MigrantPhase.transition;
      case 'integration':  return MigrantPhase.integration;
      default:             return MigrantPhase.discovery;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULO 1 — POLÍTICAS MIGRATORIAS (OIM MIPEX)
// ═══════════════════════════════════════════════════════════════════════════════

/// Política migratoria de un país destino.
///
/// Fuente: OIM MIPEX (Migrant Integration Policy Index)
/// API:    migration.iom.int/api/data/values?iso3={code}&indicator=MIPEX
class CountryPolicy {
  final String         countryCode;    // ISO 3166-1 alpha-3 (ej: 'CAN')
  final String         countryName;
  final int            mipexScore;     // 0-100
  final PolicyOpenness openness;
  final String         summary;        // Resumen en español para la UI
  final List<String>   strongPoints;   // Áreas donde el país es fuerte
  final List<String>   weakPoints;     // Áreas donde el país es débil
  final List<String>   recommendedVisas; // Visas recomendadas según perfil
  final String?        officialUrl;    // URL oficial de inmigración
  final DateTime       lastUpdated;

  const CountryPolicy({
    required this.countryCode,
    required this.countryName,
    required this.mipexScore,
    required this.openness,
    required this.summary,
    required this.strongPoints,
    required this.weakPoints,
    required this.recommendedVisas,
    required this.lastUpdated,
    this.officialUrl,
  });

  factory CountryPolicy.fromMap(Map<String, dynamic> m) {
    final score = (m['mipexScore'] as num?)?.toInt() ?? 0;
    return CountryPolicy(
      countryCode:       m['countryCode'] as String? ?? '',
      countryName:       m['countryName'] as String? ?? '',
      mipexScore:        score,
      openness:          PolicyOpenness.fromScore(score),
      summary:           m['summary'] as String? ?? '',
      strongPoints:      List<String>.from(m['strongPoints'] ?? []),
      weakPoints:        List<String>.from(m['weakPoints'] ?? []),
      recommendedVisas:  List<String>.from(m['recommendedVisas'] ?? []),
      officialUrl:       m['officialUrl'] as String?,
      lastUpdated:       DateTime.tryParse(m['lastUpdated'] as String? ?? '')
                         ?? DateTime.now(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULO 2 — REMESAS (OIM + Banco Mundial)
// ═══════════════════════════════════════════════════════════════════════════════

/// Corredor de remesas entre dos países.
///
/// Fuente: OIM + World Bank Remittance Prices Worldwide
/// API:    remittanceprices.worldbank.org/api/
class RemittanceCorridor {
  final String originCountry;       // ISO (ej: 'MX')
  final String destinationCountry;  // ISO (ej: 'CA')
  final double avgCostPct;          // Costo promedio como % del monto enviado
  final double avgCostUsd;          // Costo promedio en USD para envío de $200
  final String cheapestProvider;    // Proveedor más barato actualmente
  final double cheapestCostPct;
  final List<RemittanceProvider> providers;
  final String recommendation;      // Texto de recomendación para la UI
  final DateTime lastUpdated;

  const RemittanceCorridor({
    required this.originCountry,
    required this.destinationCountry,
    required this.avgCostPct,
    required this.avgCostUsd,
    required this.cheapestProvider,
    required this.cheapestCostPct,
    required this.providers,
    required this.recommendation,
    required this.lastUpdated,
  });

  factory RemittanceCorridor.fromMap(Map<String, dynamic> m) {
    return RemittanceCorridor(
      originCountry:      m['originCountry'] as String? ?? '',
      destinationCountry: m['destinationCountry'] as String? ?? '',
      avgCostPct:         (m['avgCostPct'] as num?)?.toDouble() ?? 0,
      avgCostUsd:         (m['avgCostUsd'] as num?)?.toDouble() ?? 0,
      cheapestProvider:   m['cheapestProvider'] as String? ?? '',
      cheapestCostPct:    (m['cheapestCostPct'] as num?)?.toDouble() ?? 0,
      providers:          (m['providers'] as List<dynamic>? ?? [])
          .map((p) => RemittanceProvider.fromMap(p as Map<String, dynamic>))
          .toList(),
      recommendation:     m['recommendation'] as String? ?? '',
      lastUpdated:        DateTime.tryParse(m['lastUpdated'] as String? ?? '')
                          ?? DateTime.now(),
    );
  }

  /// True si el costo promedio está por encima del objetivo ODS
  /// (meta: menos del 3% para 2030).
  bool get isExpensive => avgCostPct > 5;
}

class RemittanceProvider {
  final String name;
  final double costPct;
  final double costUsd;     // Para envío de $200
  final String method;      // 'app', 'banco', 'efectivo', 'cripto'
  final String? promoCode;
  final String? url;

  const RemittanceProvider({
    required this.name,
    required this.costPct,
    required this.costUsd,
    required this.method,
    this.promoCode,
    this.url,
  });

  factory RemittanceProvider.fromMap(Map<String, dynamic> m) {
    return RemittanceProvider(
      name:       m['name'] as String? ?? '',
      costPct:    (m['costPct'] as num?)?.toDouble() ?? 0,
      costUsd:    (m['costUsd'] as num?)?.toDouble() ?? 0,
      method:     m['method'] as String? ?? '',
      promoCode:  m['promoCode'] as String?,
      url:        m['url'] as String?,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULO 3 — MISSING MIGRANTS / SEGURIDAD DE RUTAS
// ═══════════════════════════════════════════════════════════════════════════════

/// Alerta de seguridad para una ruta migratoria.
///
/// Fuente: OIM Missing Migrants Project
/// URL:    missingmigrants.iom.int
/// API:    missingmigrants.iom.int/api/incidents/
///
/// IMPORTANTE: Este módulo muestra información humanitaria sensible.
/// La UI debe presentarlo con cuidado y siempre con contexto de apoyo.
class MissingMigrantsAlert {
  final String         routeId;
  final String         routeName;          // ej: 'Mediterráneo Central'
  final String         originRegion;
  final String         destinationRegion;
  final RouteAlertLevel alertLevel;
  final int            incidentsLast12m;   // Incidentes reportados último año
  final String         mainRisks;          // Descripción de riesgos principales
  final List<String>   saferAlternatives;  // Rutas o métodos más seguros
  final String?        emergencyContact;   // Número OIM de emergencia
  final String         humanitarianNote;   // Nota de contexto humanitario
  final DateTime       lastUpdated;

  const MissingMigrantsAlert({
    required this.routeId,
    required this.routeName,
    required this.originRegion,
    required this.destinationRegion,
    required this.alertLevel,
    required this.incidentsLast12m,
    required this.mainRisks,
    required this.saferAlternatives,
    required this.humanitarianNote,
    required this.lastUpdated,
    this.emergencyContact,
  });

  factory MissingMigrantsAlert.fromMap(Map<String, dynamic> m) {
    return MissingMigrantsAlert(
      routeId:             m['routeId'] as String? ?? '',
      routeName:           m['routeName'] as String? ?? '',
      originRegion:        m['originRegion'] as String? ?? '',
      destinationRegion:   m['destinationRegion'] as String? ?? '',
      alertLevel:          _alertFromString(m['alertLevel'] as String?),
      incidentsLast12m:    (m['incidentsLast12m'] as num?)?.toInt() ?? 0,
      mainRisks:           m['mainRisks'] as String? ?? '',
      saferAlternatives:   List<String>.from(m['saferAlternatives'] ?? []),
      humanitarianNote:    m['humanitarianNote'] as String? ?? '',
      emergencyContact:    m['emergencyContact'] as String?,
      lastUpdated:         DateTime.tryParse(m['lastUpdated'] as String? ?? '')
                           ?? DateTime.now(),
    );
  }

  static RouteAlertLevel _alertFromString(String? v) {
    switch (v) {
      case 'safe':     return RouteAlertLevel.safe;
      case 'low':      return RouteAlertLevel.low;
      case 'medium':   return RouteAlertLevel.medium;
      case 'high':     return RouteAlertLevel.high;
      case 'critical': return RouteAlertLevel.critical;
      default:         return RouteAlertLevel.low;
    }
  }

  bool get requiresUrgentAttention =>
      alertLevel == RouteAlertLevel.high ||
      alertLevel == RouteAlertLevel.critical;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MÓDULO 4 — RETORNO VOLUNTARIO (OIM AVRR)
// ═══════════════════════════════════════════════════════════════════════════════

/// Programa de Asistencia para el Retorno Voluntario y la Reintegración.
///
/// Fuente: OIM AVRR (Assisted Voluntary Return and Reintegration)
/// URL:    www.iom.int/assisted-voluntary-return-and-reintegration
///
/// Se muestra como "red de seguridad" cuando el usuario está en Fase 4
/// (integración) o si indica que las cosas no están saliendo bien.
class ReturnProgram {
  final String         programId;
  final String         name;
  final String         countryOfReturn;      // ISO del país al que vuelve
  final String         countryOfReturn_Name;
  final List<String>   eligibleOrigins;      // Países de origen elegibles
  final String         description;
  final List<String>   benefits;             // Qué cubre el programa
  final String         howToApply;
  final String?        contactEmail;
  final String?        contactPhone;
  final String?        contactUrl;
  final bool           includesReintegration; // Si cubre el proceso de reinserción
  final DateTime       lastUpdated;

  const ReturnProgram({
    required this.programId,
    required this.name,
    required this.countryOfReturn,
    required this.countryOfReturn_Name,
    required this.eligibleOrigins,
    required this.description,
    required this.benefits,
    required this.howToApply,
    required this.includesReintegration,
    required this.lastUpdated,
    this.contactEmail,
    this.contactPhone,
    this.contactUrl,
  });

  factory ReturnProgram.fromMap(Map<String, dynamic> m) {
    return ReturnProgram(
      programId:             m['programId'] as String? ?? '',
      name:                  m['name'] as String? ?? '',
      countryOfReturn:       m['countryOfReturn'] as String? ?? '',
      countryOfReturn_Name:  m['countryOfReturn_Name'] as String? ?? '',
      eligibleOrigins:       List<String>.from(m['eligibleOrigins'] ?? []),
      description:           m['description'] as String? ?? '',
      benefits:              List<String>.from(m['benefits'] ?? []),
      howToApply:            m['howToApply'] as String? ?? '',
      includesReintegration: m['includesReintegration'] as bool? ?? false,
      contactEmail:          m['contactEmail'] as String?,
      contactPhone:          m['contactPhone'] as String?,
      contactUrl:            m['contactUrl'] as String?,
      lastUpdated:           DateTime.tryParse(m['lastUpdated'] as String? ?? '')
                             ?? DateTime.now(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COSTO DE VIDA (Numbeo)
// ═══════════════════════════════════════════════════════════════════════════════

/// Snapshot de costo de vida de una ciudad.
///
/// Fuente: Numbeo API (api.numbeo.com/api/city_prices)
/// Actualización: mensual vía data-ingestion service.
class CostOfLivingSnapshot {
  final String countryCode;
  final String countryName;
  final String city;
  final double rentOneBedroomCenter;  // USD/mes
  final double rentOneBedroomSuburb;  // USD/mes
  final double groceriesMonthly;      // USD/mes
  final double transportMonthly;      // USD/mes
  final double mealRestaurant;        // USD (menú económico)
  final double internetMonthly;       // USD/mes
  final double avgSalaryNet;          // USD/mes (salario neto promedio local)
  final double costIndexVsNYC;        // Índice vs NYC (100 = igual que NYC)
  final DateTime lastUpdated;

  const CostOfLivingSnapshot({
    required this.countryCode,
    required this.countryName,
    required this.city,
    required this.rentOneBedroomCenter,
    required this.rentOneBedroomSuburb,
    required this.groceriesMonthly,
    required this.transportMonthly,
    required this.mealRestaurant,
    required this.internetMonthly,
    required this.avgSalaryNet,
    required this.costIndexVsNYC,
    required this.lastUpdated,
  });

  factory CostOfLivingSnapshot.fromMap(Map<String, dynamic> m) {
    return CostOfLivingSnapshot(
      countryCode:            m['countryCode'] as String? ?? '',
      countryName:            m['countryName'] as String? ?? '',
      city:                   m['city'] as String? ?? '',
      rentOneBedroomCenter:   (m['rentOneBedroomCenter'] as num?)?.toDouble() ?? 0,
      rentOneBedroomSuburb:   (m['rentOneBedroomSuburb'] as num?)?.toDouble() ?? 0,
      groceriesMonthly:       (m['groceriesMonthly'] as num?)?.toDouble() ?? 0,
      transportMonthly:       (m['transportMonthly'] as num?)?.toDouble() ?? 0,
      mealRestaurant:         (m['mealRestaurant'] as num?)?.toDouble() ?? 0,
      internetMonthly:        (m['internetMonthly'] as num?)?.toDouble() ?? 0,
      avgSalaryNet:           (m['avgSalaryNet'] as num?)?.toDouble() ?? 0,
      costIndexVsNYC:         (m['costIndexVsNYC'] as num?)?.toDouble() ?? 0,
      lastUpdated:            DateTime.tryParse(m['lastUpdated'] as String? ?? '')
                              ?? DateTime.now(),
    );
  }

  /// Costo mensual estimado total (sin alquiler) para una persona sola.
  double get monthlyBaseCost =>
      groceriesMonthly + transportMonthly + internetMonthly + (mealRestaurant * 8);

  /// Costo mensual total estimado incluyendo alquiler en zona céntrica.
  double get monthlyTotalCenter => rentOneBedroomCenter + monthlyBaseCost;

  /// Costo mensual total estimado incluyendo alquiler en periferia.
  double get monthlyTotalSuburb => rentOneBedroomSuburb + monthlyBaseCost;

  /// Calcula si el salario proyectado del usuario es suficiente.
  /// Devuelve true si el salario cubre el costo mensual con al menos 20% de margen.
  bool isSalaryViable(double projectedSalary) =>
      projectedSalary >= monthlyTotalSuburb * 1.2;

  /// Porcentaje del salario que va a alquiler (regla del 30%).
  double rentToIncomeRatio(double salary) =>
      salary > 0 ? rentOneBedroomSuburb / salary : 1.0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHECKLIST DINÁMICA
// ═══════════════════════════════════════════════════════════════════════════════

/// Un ítem de la checklist del migrante.
class ChecklistItem {
  final String      id;
  final String      title;
  final String      description;
  final MigrantPhase phase;           // En qué fase debe completarse
  final bool        isCompleted;
  final bool        isRequired;       // Requerido vs opcional
  final String?     documentType;     // Si requiere un documento específico
  final String?     linkUrl;          // Link de ayuda o trámite online
  final String?     estimatedDays;    // Tiempo estimado para completar
  final DateTime?   completedAt;

  const ChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.phase,
    required this.isRequired,
    this.isCompleted   = false,
    this.documentType,
    this.linkUrl,
    this.estimatedDays,
    this.completedAt,
  });

  ChecklistItem copyWith({bool? isCompleted, DateTime? completedAt}) {
    return ChecklistItem(
      id:             id,
      title:          title,
      description:    description,
      phase:          phase,
      isRequired:     isRequired,
      isCompleted:    isCompleted   ?? this.isCompleted,
      documentType:   documentType,
      linkUrl:        linkUrl,
      estimatedDays:  estimatedDays,
      completedAt:    completedAt   ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id':             id,
    'isCompleted':    isCompleted,
    'completedAt':    completedAt?.toIso8601String(),
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// PACK DE BIENVENIDA (Fase 3 — Transición)
// ═══════════════════════════════════════════════════════════════════════════════

/// Pack de bienvenida que se muestra/notifica al llegar al país destino.
class WelcomePack {
  final String         countryCode;
  final String         city;
  final List<WelcomeItem> items;       // Acciones inmediatas al llegar
  final List<MapPoint>    mapPoints;  // Puntos clave en el mapa
  final String?           eSIMUrl;    // Link para comprar eSIM local
  final String            emergencyNumber; // Número de emergencias local

  const WelcomePack({
    required this.countryCode,
    required this.city,
    required this.items,
    required this.mapPoints,
    required this.emergencyNumber,
    this.eSIMUrl,
  });
}

class WelcomeItem {
  final String  emoji;
  final String  title;
  final String  description;
  final String? actionUrl;
  final int     priority; // 1 = primero que hacer

  const WelcomeItem({
    required this.emoji,
    required this.title,
    required this.description,
    required this.priority,
    this.actionUrl,
  });
}

class MapPoint {
  final String  name;
  final String  category; // 'immigration', 'bank', 'hospital', 'metro'
  final String  emoji;
  final String? address;
  final String? url;

  const MapPoint({
    required this.name,
    required this.category,
    required this.emoji,
    this.address,
    this.url,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD CONSOLIDADO (alimenta la Fase 1+2)
// ═══════════════════════════════════════════════════════════════════════════════

/// Objeto consolidado que alimenta el DestinationDashboardScreen.
/// Agrupa todos los módulos de datos para un perfil + destino específico.
class DestinationDashboard {
  final MigrationProfile       profile;
  final CountryPolicy          policy;
  final CostOfLivingSnapshot   costOfLiving;
  final RemittanceCorridor?    remittances;    // Null si no hay datos del corredor
  final MissingMigrantsAlert?  safetyAlert;   // Null si la ruta es segura
  final ReturnProgram?         returnProgram; // Siempre disponible como red de seguridad
  final List<ChecklistItem>    checklist;
  final List<String>           newsAlerts;    // Cambios recientes en leyes migratorias
  final DateTime               generatedAt;

  const DestinationDashboard({
    required this.profile,
    required this.policy,
    required this.costOfLiving,
    required this.checklist,
    required this.generatedAt,
    this.remittances,
    this.safetyAlert,
    this.returnProgram,
    this.newsAlerts = const [],
  });

  /// Progreso general del usuario (0.0 a 1.0).
  double get progress {
    if (checklist.isEmpty) return 0;
    final completed = checklist.where((i) => i.isCompleted).length;
    return completed / checklist.length;
  }

  /// Items de la checklist filtrados por fase actual.
  List<ChecklistItem> get currentPhaseItems =>
      checklist.where((i) => i.phase == profile.currentPhase).toList();

  /// True si hay alguna alerta de seguridad que requiera atención urgente.
  bool get hasUrgentAlert =>
      safetyAlert != null && safetyAlert!.requiresUrgentAttention;
}
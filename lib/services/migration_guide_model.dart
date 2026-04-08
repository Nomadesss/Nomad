// ─────────────────────────────────────────────────────────────────────────────
// migration_guide_model.dart  –  Nomad App
// Ubicación: lib/services/migration_guide_model.dart
//
// Modelo de datos para las guías migratorias extraídas del scraper.
// Refleja exactamente el formato JSON que genera scraper_migraciones_v2.py
// y que se almacena en la colección Firestore /migration_guides/{id}
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

/// Categoría legal del trámite (alineada con inferir_categoria del scraper)
enum GuideCategory {
  estudios,
  trabajo,
  emprender,
  familiar,
  residencia,
  circunstanciasExcepcionales,
  nomadaDigital,
  retorno,
  documento,
  menores,
  otro;

  String get label {
    switch (this) {
      case GuideCategory.estudios:
        return 'Estudios';
      case GuideCategory.trabajo:
        return 'Trabajo';
      case GuideCategory.emprender:
        return 'Emprender';
      case GuideCategory.familiar:
        return 'Familia';
      case GuideCategory.residencia:
        return 'Residencia';
      case GuideCategory.circunstanciasExcepcionales:
        return 'Excepcional';
      case GuideCategory.nomadaDigital:
        return 'Nómada Digital';
      case GuideCategory.retorno:
        return 'Retorno';
      case GuideCategory.documento:
        return 'Documentos';
      case GuideCategory.menores:
        return 'Menores';
      case GuideCategory.otro:
        return 'Otro';
    }
  }

  String get emoji {
    switch (this) {
      case GuideCategory.estudios:
        return '🎓';
      case GuideCategory.trabajo:
        return '💼';
      case GuideCategory.emprender:
        return '🚀';
      case GuideCategory.familiar:
        return '👨‍👩‍👧';
      case GuideCategory.residencia:
        return '🏠';
      case GuideCategory.circunstanciasExcepcionales:
        return '🛡️';
      case GuideCategory.nomadaDigital:
        return '💻';
      case GuideCategory.retorno:
        return '↩️';
      case GuideCategory.documento:
        return '📄';
      case GuideCategory.menores:
        return '👦';
      case GuideCategory.otro:
        return '📋';
    }
  }

  static GuideCategory fromString(String? s) {
    switch (s) {
      case 'estudios':
        return GuideCategory.estudios;
      case 'trabajo':
        return GuideCategory.trabajo;
      case 'emprender':
        return GuideCategory.emprender;
      case 'familiar':
        return GuideCategory.familiar;
      case 'residencia':
        return GuideCategory.residencia;
      case 'circunstancias_excepcionales':
        return GuideCategory.circunstanciasExcepcionales;
      case 'nomada_digital':
        return GuideCategory.nomadaDigital;
      case 'retorno':
        return GuideCategory.retorno;
      case 'documento':
        return GuideCategory.documento;
      case 'menores':
        return GuideCategory.menores;
      default:
        return GuideCategory.otro;
    }
  }
}

/// Objetivo del migrante (se obtiene del onboarding o del perfil)
enum MigracionObjetivo {
  trabajar,
  estudiar,
  emprender,
  familia,
  residir,
  nomada;

  String get label {
    switch (this) {
      case MigracionObjetivo.trabajar:
        return 'Trabajar';
      case MigracionObjetivo.estudiar:
        return 'Estudiar';
      case MigracionObjetivo.emprender:
        return 'Emprender';
      case MigracionObjetivo.familia:
        return 'Reunirme con familia';
      case MigracionObjetivo.residir:
        return 'Vivir / Residir';
      case MigracionObjetivo.nomada:
        return 'Nómada digital';
    }
  }

  String get emoji {
    switch (this) {
      case MigracionObjetivo.trabajar:
        return '💼';
      case MigracionObjetivo.estudiar:
        return '🎓';
      case MigracionObjetivo.emprender:
        return '🚀';
      case MigracionObjetivo.familia:
        return '👨‍👩‍👧';
      case MigracionObjetivo.residir:
        return '🏠';
      case MigracionObjetivo.nomada:
        return '💻';
    }
  }

  static MigracionObjetivo fromString(String? s) {
    switch (s) {
      case 'trabajar':
        return MigracionObjetivo.trabajar;
      case 'estudiar':
        return MigracionObjetivo.estudiar;
      case 'emprender':
        return MigracionObjetivo.emprender;
      case 'familia':
        return MigracionObjetivo.familia;
      case 'residir':
        return MigracionObjetivo.residir;
      case 'nomada':
        return MigracionObjetivo.nomada;
      default:
        return MigracionObjetivo.residir;
    }
  }
}

// ── Modelo principal ──────────────────────────────────────────────────────────

class MigrationGuide {
  final String id;
  final String paisIso;
  final String paisNombre;
  final String paisFlag;
  final bool paisRegimenUe;
  final String fuenteOficial;
  final String url;
  final String titulo;
  final GuideCategory categoria;
  final List<String>
  objetivos; // valores: trabajar|estudiar|emprender|familia|residir|nomada
  final bool soloPasaporteUe; // true = solo aplica con pasaporte UE
  final String? duracion;
  final bool? renovable;
  final String? tipoAutorizacion;
  final String? normativa;
  final List<String> requisitos;
  final List<String> documentacionExigible;
  final List<String> procedimiento;
  final List<String> familiares;
  final List<String> prorroga;
  final String? tasas;
  final String? plazoResolucion;
  final List<String> notas;
  final String scrapedAt;
  final String hash;

  const MigrationGuide({
    required this.id,
    required this.paisIso,
    required this.paisNombre,
    required this.paisFlag,
    required this.paisRegimenUe,
    required this.fuenteOficial,
    required this.url,
    required this.titulo,
    required this.categoria,
    required this.objetivos,
    required this.soloPasaporteUe,
    this.duracion,
    this.renovable,
    this.tipoAutorizacion,
    this.normativa,
    required this.requisitos,
    required this.documentacionExigible,
    required this.procedimiento,
    required this.familiares,
    required this.prorroga,
    this.tasas,
    this.plazoResolucion,
    required this.notas,
    required this.scrapedAt,
    required this.hash,
  });

  // Convierte un campo que puede ser String o List<dynamic> en String?.
  // Necesario porque el scraper de Uruguay guarda algunos campos como lista.
  static String? _toStringField(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isNotEmpty ? v : null;
    if (v is List) {
      final joined = v.map((e) => e.toString()).join(' · ');
      return joined.isNotEmpty ? joined : null;
    }
    return v.toString();
  }

  factory MigrationGuide.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MigrationGuide(
      id: doc.id,
      paisIso: d['paisIso'] as String? ?? '',
      paisNombre: d['paisNombre'] as String? ?? '',
      paisFlag: d['paisFlag'] as String? ?? '🌍',
      paisRegimenUe: d['paisRegimenUe'] as bool? ?? false,
      fuenteOficial: d['fuenteOficial'] as String? ?? '',
      url: d['url'] as String? ?? '',
      titulo: d['titulo'] as String? ?? '',
      categoria: GuideCategory.fromString(d['categoria'] as String?),
      objetivos: List<String>.from(d['objetivos'] as List? ?? []),
      soloPasaporteUe: d['soloPasaporteUe'] as bool? ?? false,
      duracion: _toStringField(d['duracion']),
      renovable: d['renovable'] as bool?,
      tipoAutorizacion: _toStringField(d['tipoAutorizacion']),
      normativa: _toStringField(d['normativa']),
      requisitos: List<String>.from(d['requisitos'] as List? ?? []),
      documentacionExigible: List<String>.from(
        d['documentacionExigible'] as List? ?? [],
      ),
      procedimiento: List<String>.from(d['procedimiento'] as List? ?? []),
      familiares: List<String>.from(d['familiares'] as List? ?? []),
      prorroga: List<String>.from(d['prorroga'] as List? ?? []),
      tasas: _toStringField(d['tasas']),
      plazoResolucion: _toStringField(d['plazoResolucion']),
      notas: List<String>.from(d['notas'] as List? ?? []),
      scrapedAt: d['scrapedAt'] as String? ?? '',
      hash: d['hash'] as String? ?? '',
    );
  }

  factory MigrationGuide.fromJson(Map<String, dynamic> d) {
    return MigrationGuide(
      id: d['id'] as String? ?? '',
      paisIso: d['paisIso'] as String? ?? '',
      paisNombre: d['paisNombre'] as String? ?? '',
      paisFlag: d['paisFlag'] as String? ?? '🌍',
      paisRegimenUe: d['paisRegimenUe'] as bool? ?? false,
      fuenteOficial: d['fuenteOficial'] as String? ?? '',
      url: d['url'] as String? ?? '',
      titulo: d['titulo'] as String? ?? '',
      categoria: GuideCategory.fromString(d['categoria'] as String?),
      objetivos: List<String>.from(d['objetivos'] as List? ?? []),
      soloPasaporteUe: d['soloPasaporteUe'] as bool? ?? false,
      duracion: _toStringField(d['duracion']),
      renovable: d['renovable'] as bool?,
      tipoAutorizacion: _toStringField(d['tipoAutorizacion']),
      normativa: _toStringField(d['normativa']),
      requisitos: List<String>.from(d['requisitos'] as List? ?? []),
      documentacionExigible: List<String>.from(
        d['documentacionExigible'] as List? ?? [],
      ),
      procedimiento: List<String>.from(d['procedimiento'] as List? ?? []),
      familiares: List<String>.from(d['familiares'] as List? ?? []),
      prorroga: List<String>.from(d['prorroga'] as List? ?? []),
      tasas: _toStringField(d['tasas']),
      plazoResolucion: _toStringField(d['plazoResolucion']),
      notas: List<String>.from(d['notas'] as List? ?? []),
      scrapedAt: d['scrapedAt'] as String? ?? '',
      hash: d['hash'] as String? ?? '',
    );
  }

  /// Determina si esta guía aplica al perfil del usuario
  bool aplicaA({
    required String? objetivoUsuario,
    required bool tienePasaporteUe,
  }) {
    // Si el trámite es exclusivo de UE y el usuario no tiene pasaporte UE → no aplica
    if (soloPasaporteUe && !tienePasaporteUe) return false;
    // Si no hay objetivo, mostrar todo
    if (objetivoUsuario == null) return true;
    return objetivos.contains(objetivoUsuario);
  }
}

// ── Perfil de filtro del usuario ──────────────────────────────────────────────
// Se construye desde Firestore (datos del usuario) o desde el onboarding.

class UserMigrationFilter {
  final String paisDestinoIso;
  final String? objetivo; // trabajar|estudiar|emprender|familia|residir|nomada
  final bool tienePasaporteUe;

  const UserMigrationFilter({
    required this.paisDestinoIso,
    this.objetivo,
    this.tienePasaporteUe = false,
  });

  /// Construye el filtro desde el documento del usuario en Firestore
  factory UserMigrationFilter.fromFirestoreData(Map<String, dynamic> data) {
    return UserMigrationFilter(
      paisDestinoIso:
          (data['destinationCountry'] as String?)?.toUpperCase() ?? 'ES',
      objetivo: data['migracionObjetivo'] as String?,
      tienePasaporteUe: data['tienePasaporteUe'] as bool? ?? false,
    );
  }
}

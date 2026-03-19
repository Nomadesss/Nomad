import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'migration_data_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IomService — construye el DestinationDashboard para el User Journey de Nomad
//
// Ubicación: lib/services/iom_service.dart
//
// Fuentes de datos:
//   OIM Migration Data Portal  → migration.iom.int/api/
//   OIM Missing Migrants       → missingmigrants.iom.int/api/incidents/
//   World Bank Remittances     → remittanceprices.worldbank.org/api/
//   Numbeo                     → api.numbeo.com/api/city_prices
//
// Estado del MVP:
//   Los métodos _fetch*() usan mocks con estructura idéntica a la API real.
//   Para conectar la API real, reemplazá el cuerpo de cada _fetch*() por
//   la llamada HTTP correspondiente — la interfaz pública no cambia.
//
// Cache:
//   Los dashboards se cachean en memoria por _cacheTtl (24h por defecto).
//   La key es '{originISO}_{destinationISO}_{profileType}'.
// ─────────────────────────────────────────────────────────────────────────────

class IomService {

  // ── Cache en memoria ───────────────────────────────────────────────────────
  static final Map<String, _CacheEntry<DestinationDashboard>> _cache = {};
  static const _cacheTtl = Duration(hours: 24);

  // ── Endpoint base de la API real (para cuando se conecte) ─────────────────
  static const _iomApiBase    = 'https://www.migrationdataportal.org/api';
  static const _numbeoApiBase = 'https://api.numbeo.com/api';
  // static const _numbeoApiKey = String.fromEnvironment('NUMBEO_API_KEY');

  // ══════════════════════════════════════════════════════════════════════════
  // MÉTODO PRINCIPAL — build()
  //
  // El screen llama a este único método. Maneja cache, coordina las llamadas
  // a los módulos y devuelve el DestinationDashboard consolidado.
  // ══════════════════════════════════════════════════════════════════════════

  /// Construye el DestinationDashboard completo para el perfil dado.
  ///
  /// Ejemplo — el User Journey de Luis:
  ///   final dashboard = await IomService.build(
  ///     MigrationProfile(
  ///       userId:               'uid123',
  ///       originCountry:        'MX',
  ///       originCountryName:    'México',
  ///       destinationCountry:   'CA',
  ///       destinationCountryName: 'Canadá',
  ///       profileType:          MigrantProfileType.professional,
  ///       currentPhase:         MigrantPhase.discovery,
  ///       createdAt:            DateTime.now(),
  ///       updatedAt:            DateTime.now(),
  ///     ),
  ///   );
  static Future<DestinationDashboard> build(MigrationProfile profile) async {
    final cacheKey = '${profile.originCountry}_'
        '${profile.destinationCountry}_'
        '${profile.profileType.name}';

    // Devolver desde cache si es válido.
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('[IomService] Cache hit: $cacheKey');
      return cached.value;
    }

    debugPrint('[IomService] Building dashboard for $cacheKey...');

    // Cargar todos los módulos en paralelo.
    final results = await Future.wait([
      _fetchCountryPolicy(profile.destinationCountry),
      _fetchCostOfLiving(profile.destinationCountry, profile.targetCity),
      _fetchRemittances(profile.originCountry, profile.destinationCountry),
      _fetchSafetyAlert(profile.originCountry, profile.destinationCountry),
      _fetchReturnProgram(profile.destinationCountry, profile.originCountry),
      _fetchNewsAlerts(profile.destinationCountry),
    ]);

    final policy       = results[0] as CountryPolicy;
    final costOfLiving = results[1] as CostOfLivingSnapshot;
    final remittances  = results[2] as RemittanceCorridor?;
    final safetyAlert  = results[3] as MissingMigrantsAlert?;
    final returnProg   = results[4] as ReturnProgram?;
    final news         = results[5] as List<String>;

    // Generar checklist dinámica según el perfil.
    final checklist = _buildChecklist(profile);

    final dashboard = DestinationDashboard(
      profile:       profile,
      policy:        policy,
      costOfLiving:  costOfLiving,
      remittances:   remittances,
      safetyAlert:   safetyAlert,
      returnProgram: returnProg,
      checklist:     checklist,
      newsAlerts:    news,
      generatedAt:   DateTime.now(),
    );

    // Guardar en cache.
    _cache[cacheKey] = _CacheEntry(dashboard, _cacheTtl);
    return dashboard;
  }

  /// Invalida el cache para un perfil específico.
  /// Llamar cuando el usuario cambia su país destino o tipo de perfil.
  static void invalidateCache(MigrationProfile profile) {
    final key = '${profile.originCountry}_'
        '${profile.destinationCountry}_'
        '${profile.profileType.name}';
    _cache.remove(key);
  }

  /// Invalida todo el cache (útil en logout).
  static void clearCache() => _cache.clear();

  // ══════════════════════════════════════════════════════════════════════════
  // MÓDULO 1 — POLÍTICAS MIGRATORIAS
  //
  // API real: GET migration.iom.int/api/data/values
  //           ?iso3={countryCode}&indicator=MIPEX&year=latest
  //
  // Respuesta real (estructura):
  //   { "data": [{ "iso3": "CAN", "value": 72, "year": 2023 }] }
  // ══════════════════════════════════════════════════════════════════════════

  static Future<CountryPolicy> _fetchCountryPolicy(String countryCode) async {
    // TODO: reemplazar con llamada real cuando se integre la API de OIM:
    //
    // final uri = Uri.parse('$_iomApiBase/data/values'
    //     '?iso3=${_toAlpha3(countryCode)}&indicator=MIPEX&year=latest');
    // final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    // if (resp.statusCode == 200) {
    //   final json = jsonDecode(resp.body);
    //   final score = json['data'][0]['value'] as int;
    //   return _buildPolicyFromScore(countryCode, score);
    // }

    return _mockPolicies[countryCode] ??
        _mockPolicies['DEFAULT']!;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MÓDULO 2 — COSTO DE VIDA (Numbeo)
  //
  // API real: GET api.numbeo.com/api/city_prices
  //           ?api_key={key}&city={city}&country={country}&currency=USD
  //
  // Respuesta real (estructura):
  //   { "city": "Calgary", "country": "Canada",
  //     "prices": [{ "item_id": 1, "average_price": 1800.0 }] }
  //
  // Item IDs relevantes de Numbeo:
  //   1 = Apartment 1BR city center (rent/month)
  //   2 = Apartment 1BR outside center
  //  27 = Monthly Pass transport
  //  30 = Internet (60 Mbps)
  //  101 = Meal inexpensive restaurant
  //  110 = Average net salary
  // ══════════════════════════════════════════════════════════════════════════

  static Future<CostOfLivingSnapshot> _fetchCostOfLiving(
    String countryCode,
    String? targetCity,
  ) async {
    final city = (targetCity ?? _defaultCities[countryCode] ?? 'Capital')
        .toLowerCase();

    // TODO: reemplazar con llamada real:
    //
    // final uri = Uri.parse('$_numbeoApiBase/city_prices'
    //     '?api_key=$_numbeoApiKey&city=${Uri.encodeComponent(city)}'
    //     '&country=${_countryName(countryCode)}&currency=USD');
    // ...

    final key = '${countryCode}_$city';
    return _mockCostOfLiving[key] ??
        _mockCostOfLiving[countryCode] ??
        _mockCostOfLiving['DEFAULT']!;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MÓDULO 3 — REMESAS (World Bank Remittance Prices)
  //
  // API real: GET remittanceprices.worldbank.org/api/
  //           ?sending_country_code={iso}&payout_country_code={iso}&format=json
  //
  // Respuesta real (estructura):
  //   { "remittanceprices": [{ "name": "Wise", "total_cost": 2.1 }] }
  // ══════════════════════════════════════════════════════════════════════════

  static Future<RemittanceCorridor?> _fetchRemittances(
    String originCode,
    String destinationCode,
  ) async {
    // TODO: reemplazar con llamada real al World Bank API.

    final key = '${originCode}_$destinationCode';
    return _mockRemittances[key]; // null si no hay datos del corredor
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MÓDULO 4 — MISSING MIGRANTS / SEGURIDAD
  //
  // API real: GET missingmigrants.iom.int/api/incidents/
  //           ?region={region}&year=latest&format=json
  //
  // Respuesta real (estructura):
  //   { "results": [{ "region": "Mediterranean", "total_dead": 1205 }] }
  // ══════════════════════════════════════════════════════════════════════════

  static Future<MissingMigrantsAlert?> _fetchSafetyAlert(
    String originCode,
    String destinationCode,
  ) async {
    // TODO: reemplazar con llamada real a missingmigrants.iom.int/api/

    final key = '${originCode}_$destinationCode';
    return _mockSafetyAlerts[key]; // null = ruta sin alertas activas
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MÓDULO 5 — RETORNO VOLUNTARIO (OIM AVRR)
  //
  // No tiene API pública estructurada — datos manuales actualizados
  // trimestralmente por el equipo de Nomad desde iom.int/avrr.
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ReturnProgram?> _fetchReturnProgram(
    String destinationCode,
    String originCode,
  ) async {
    // Mostrar siempre que exista un programa para el corredor.
    return _mockReturnPrograms[destinationCode];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MÓDULO 6 — ALERTAS DE NOTICIAS MIGRATORIAS
  //
  // En v2.0: scraping ético de portales oficiales + RSS feeds.
  // En MVP: alertas manuales curadas por el equipo de Nomad.
  // ══════════════════════════════════════════════════════════════════════════

  static Future<List<String>> _fetchNewsAlerts(String countryCode) async {
    return _mockNewsAlerts[countryCode] ?? [];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHECKLIST DINÁMICA
  //
  // Genera la lista de tareas personalizada según:
  //   - originCountry      → qué documentos apostillar y dónde
  //   - destinationCountry → qué trámites hacer al llegar
  //   - profileType        → qué visas y pasos aplican
  //   - hasChildren        → agrega items de escolarización
  //
  // Cada combinación produce una lista diferente.
  // Luis (MX → CA, profesional) ≠ María (UY → ES, familiar con hijos).
  // ══════════════════════════════════════════════════════════════════════════

  static List<ChecklistItem> _buildChecklist(MigrationProfile profile) {
    final items = <ChecklistItem>[];
    int id = 0;
    String nextId() => 'ck_${id++}';

    // ── Fase 1: Descubrimiento — siempre ────────────────────────────────────
    items.addAll([
      ChecklistItem(
        id:            nextId(),
        title:         'Definí tu ciudad destino',
        description:   'Comparar el costo de vida entre ciudades antes de comprometerte.',
        phase:         MigrantPhase.discovery,
        isRequired:    true,
        estimatedDays: '1–3 días',
      ),
      ChecklistItem(
        id:            nextId(),
        title:         'Verificá el tipo de visa que necesitás',
        description:   'Según tu perfil (${profile.profileType.label}) en ${profile.destinationCountryName}.',
        phase:         MigrantPhase.discovery,
        isRequired:    true,
        linkUrl:       _officialImmigrationUrl[profile.destinationCountry],
        estimatedDays: '1 día',
      ),
      ChecklistItem(
        id:            nextId(),
        title:         'Calculá tu presupuesto de instalación',
        description:   'Primer mes de alquiler + depósito + vuelo + colchón de emergencia.',
        phase:         MigrantPhase.discovery,
        isRequired:    true,
        estimatedDays: '1–2 días',
      ),
    ]);

    // ── Fase 2: Preparación — base ───────────────────────────────────────────
    items.addAll([
      ChecklistItem(
        id:            nextId(),
        title:         'Verificá vigencia del pasaporte',
        description:   'Debe tener al menos 6 meses de validez al llegar a ${profile.destinationCountryName}.',
        phase:         MigrantPhase.preparation,
        isRequired:    true,
        documentType:  'Pasaporte',
        estimatedDays: '2–4 semanas si hay que renovar',
      ),
      ChecklistItem(
        id:            nextId(),
        title:         'Apostillá los antecedentes penales',
        description:   _apostilleInstructions(profile.originCountry),
        phase:         MigrantPhase.preparation,
        isRequired:    true,
        documentType:  'Antecedentes penales',
        linkUrl:       _apostilleUrls[profile.originCountry],
        estimatedDays: '3–7 días hábiles',
      ),
      ChecklistItem(
        id:            nextId(),
        title:         'Apostillá la partida de nacimiento',
        description:   'Original + apostille + traducción certificada si aplica.',
        phase:         MigrantPhase.preparation,
        isRequired:    true,
        documentType:  'Partida de nacimiento',
        linkUrl:       _apostilleUrls[profile.originCountry],
        estimatedDays: '3–7 días hábiles',
      ),
      ChecklistItem(
        id:            nextId(),
        title:         'Conseguí seguro médico internacional',
        description:   'Requisito para la visa y cobertura hasta estar en el sistema público.',
        phase:         MigrantPhase.preparation,
        isRequired:    true,
        estimatedDays: '1–3 días (online)',
      ),
    ]);

    // ── Preparación — específicos por perfil ─────────────────────────────────
    switch (profile.profileType) {
      case MigrantProfileType.professional:
        items.addAll([
          ChecklistItem(
            id:            nextId(),
            title:         'Evaluación de credenciales (ECA/WES)',
            description:   _credentialEvaluationInstructions(profile.destinationCountry),
            phase:         MigrantPhase.preparation,
            isRequired:    true,
            documentType:  'Título universitario',
            linkUrl:       _credentialEvalUrls[profile.destinationCountry],
            estimatedDays: '4–8 semanas',
          ),
          ChecklistItem(
            id:            nextId(),
            title:         _languageTestName(profile.destinationCountry),
            description:   'Puntaje mínimo requerido para la visa de trabajo.',
            phase:         MigrantPhase.preparation,
            isRequired:    true,
            estimatedDays: '1–3 meses de preparación',
          ),
        ]);
      case MigrantProfileType.student:
        items.addAll([
          ChecklistItem(
            id:            nextId(),
            title:         'Carta de aceptación de la institución educativa',
            description:   'Documento oficial de admisión — requisito para la visa de estudios.',
            phase:         MigrantPhase.preparation,
            isRequired:    true,
            documentType:  'Carta de admisión',
            estimatedDays: 'Variable según institución',
          ),
          ChecklistItem(
            id:            nextId(),
            title:         'Prueba de solvencia económica',
            description:   'Extractos bancarios de los últimos 3 meses.',
            phase:         MigrantPhase.preparation,
            isRequired:    true,
            estimatedDays: '1–3 días',
          ),
        ]);
      case MigrantProfileType.nomad:
        items.addAll([
          ChecklistItem(
            id:            nextId(),
            title:         'Comprobante de ingresos remotos',
            description:   'Contrato con empresa extranjera o extractos de plataformas freelance (3 meses).',
            phase:         MigrantPhase.preparation,
            isRequired:    true,
            estimatedDays: '1–3 días',
          ),
        ]);
      case MigrantProfileType.familyJoin:
        items.addAll([
          ChecklistItem(
            id:            nextId(),
            title:         'Certificado de matrimonio o unión apostillado',
            description:   'Debe estar apostillado y traducido al idioma del país destino.',
            phase:         MigrantPhase.preparation,
            isRequired:    true,
            documentType:  'Cert. de matrimonio',
            estimatedDays: '3–7 días hábiles',
          ),
        ]);
      default:
        break;
    }

    // ── Preparación — con hijos ───────────────────────────────────────────────
    if (profile.hasChildren) {
      items.addAll([
        ChecklistItem(
          id:            nextId(),
          title:         'Apostillá las partidas de nacimiento de los hijos',
          description:   'Una por cada hijo menor de edad.',
          phase:         MigrantPhase.preparation,
          isRequired:    true,
          documentType:  'Partidas de nacimiento (hijos)',
          linkUrl:       _apostilleUrls[profile.originCountry],
          estimatedDays: '3–7 días hábiles por documento',
        ),
        ChecklistItem(
          id:            nextId(),
          title:         'Investigar sistema escolar en ${profile.destinationCountryName}',
          description:   'Requisitos de inscripción, calendario escolar y documentos necesarios.',
          phase:         MigrantPhase.preparation,
          isRequired:    false,
          estimatedDays: '1–2 días',
        ),
      ]);
    }

    // ── Fase 3: Transición ───────────────────────────────────────────────────
    items.addAll([
      ChecklistItem(
        id:            nextId(),
        title:         'Conseguir SIM/eSIM local al llegar',
        description:   'Necesario para activar apps de transporte, banco y comunicación.',
        phase:         MigrantPhase.transition,
        isRequired:    true,
        estimatedDays: 'Día 1',
      ),
      ChecklistItem(
        id:            nextId(),
        title:         _idDocumentName(profile.destinationCountry),
        description:   _idDocumentInstructions(profile.destinationCountry),
        phase:         MigrantPhase.transition,
        isRequired:    true,
        linkUrl:       _officialImmigrationUrl[profile.destinationCountry],
        estimatedDays: _idDocumentTime(profile.destinationCountry),
      ),
      ChecklistItem(
        id:            nextId(),
        title:         'Abrir cuenta bancaria local',
        description:   _bankAccountInstructions(profile.destinationCountry),
        phase:         MigrantPhase.transition,
        isRequired:    true,
        estimatedDays: '1–7 días',
      ),
      ChecklistItem(
        id:            nextId(),
        title:         'Empadronarte / registrarte en el municipio',
        description:   'Necesario para acceder a servicios públicos en la mayoría de países europeos.',
        phase:         MigrantPhase.transition,
        isRequired:    _requiresEmpadronamiento(profile.destinationCountry),
        estimatedDays: '1 día',
      ),
    ]);

    // ── Fase 4: Integración ───────────────────────────────────────────────────
    items.addAll([
      ChecklistItem(
        id:            nextId(),
        title:         'Tramitar seguro médico público',
        description:   'Registrarte en el sistema de salud del país.',
        phase:         MigrantPhase.integration,
        isRequired:    true,
        estimatedDays: '1–4 semanas',
      ),
      ChecklistItem(
        id:            nextId(),
        title:         'Unirte a grupos de la comunidad en Nomad',
        description:   'Conectate con otros migrantes en tu ciudad.',
        phase:         MigrantPhase.integration,
        isRequired:    false,
        estimatedDays: 'Cuando quieras',
      ),
      if (profile.profileType == MigrantProfileType.professional ||
          profile.profileType == MigrantProfileType.nomad)
        ChecklistItem(
          id:            nextId(),
          title:         'Buscar empleo con ofertas para migrantes',
          description:   'Filtrá por "acepta migrantes" en el módulo Empleo de Nomad.',
          phase:         MigrantPhase.integration,
          isRequired:    false,
          estimatedDays: 'Variable',
        ),
    ]);

    return items;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WELCOME PACK — construye el pack de bienvenida al llegar
  // ══════════════════════════════════════════════════════════════════════════

  static WelcomePack buildWelcomePack({
    required String countryCode,
    required String city,
    required MigrantProfileType profileType,
  }) {
    return _mockWelcomePacks[countryCode] ??
        _buildDefaultWelcomePack(countryCode, city);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DATOS MOCK — estructura idéntica a la API real de OIM
  //
  // Estos mocks sirven dos propósitos:
  //   1. Permitir desarrollar y testear la UI sin depender de la API.
  //   2. Documentar exactamente qué estructura esperamos de la API real.
  //
  // Fuentes de los valores:
  //   - MIPEX scores: mipex.eu (2020, última edición disponible)
  //   - Costo de vida: Numbeo Q1 2025
  //   - Remesas: World Bank Remittance Prices Q4 2024
  // ══════════════════════════════════════════════════════════════════════════

  static final Map<String, CountryPolicy> _mockPolicies = {
    'CA': CountryPolicy(
      countryCode:      'CA',
      countryName:      'Canadá',
      mipexScore:       80,
      openness:         PolicyOpenness.veryOpen,
      summary:          'Canadá tiene una de las políticas migratorias más abiertas del mundo. El sistema de puntos Express Entry es transparente y predecible.',
      strongPoints:     ['Reunificación familiar prioritaria', 'Acceso laboral amplio para residentes', 'Ciudadanía a los 3 años'],
      weakPoints:       ['Proceso puede tomar 6–18 meses', 'Reconocimiento de títulos extranjeros complejo'],
      recommendedVisas: ['Express Entry — Federal Skilled Worker', 'Provincial Nominee Program', 'Working Holiday (18–35 años)'],
      officialUrl:      'https://ircc.canada.ca',
      lastUpdated:      DateTime(2025, 1, 15),
    ),
    'ES': CountryPolicy(
      countryCode:      'ES',
      countryName:      'España',
      mipexScore:       61,
      openness:         PolicyOpenness.open,
      summary:          'España es especialmente favorable para iberoamericanos. El idioma compartido y los convenios de doble nacionalidad son ventajas únicas.',
      strongPoints:     ['Convenio de doble nacionalidad con Uruguay, México y otros', 'Ciudadanía a los 2 años para iberoamericanos', 'Visa Nómada Digital vigente'],
      weakPoints:       ['Burocracia lenta en oficinas de extranjería', 'Alto desempleo en ciertas regiones'],
      recommendedVisas: ['Visa de trabajo por cuenta ajena', 'Visa Nómada Digital', 'Reagrupación familiar'],
      officialUrl:      'https://extranjeros.inclusion.gob.es',
      lastUpdated:      DateTime(2025, 1, 10),
    ),
    'PT': CountryPolicy(
      countryCode:      'PT',
      countryName:      'Portugal',
      mipexScore:       81,
      openness:         PolicyOpenness.veryOpen,
      summary:          'Portugal tiene el mejor índice de integración de la UE. La Visa D7 es ideal para trabajadores remotos y rentistas latinoamericanos.',
      strongPoints:     ['Visa D7 accesible para remotos', 'Ciudadanía a los 5 años', 'NHR (régimen fiscal favorable)'],
      weakPoints:       ['Alquileres en Lisboa subieron fuertemente', 'AIMA (antes SEF) con demoras'],
      recommendedVisas: ['Visa D7 (renta pasiva o remota)', 'Visa D2 (emprendedor)', 'Visa D3 (trabajo calificado)'],
      officialUrl:      'https://imigrante.sef.pt',
      lastUpdated:      DateTime(2025, 1, 12),
    ),
    'DE': CountryPolicy(
      countryCode:      'DE',
      countryName:      'Alemania',
      mipexScore:       56,
      openness:         PolicyOpenness.open,
      summary:          'Alemania tiene alta demanda de trabajadores calificados. La Chancenkarte (2024) facilita la búsqueda de empleo desde el exterior.',
      strongPoints:     ['Chancenkarte: buscar trabajo hasta 1 año', 'Alta demanda en IT, salud e ingeniería', 'Excelente sistema de salud'],
      weakPoints:       ['Alemán prácticamente obligatorio para integrarse', 'Reconocimiento de títulos complejo'],
      recommendedVisas: ['Chancenkarte (búsqueda de empleo)', 'EU Blue Card (profesionales calificados)', 'Visa de trabajo'],
      officialUrl:      'https://www.make-it-in-germany.com',
      lastUpdated:      DateTime(2025, 1, 8),
    ),
    'MX': CountryPolicy(
      countryCode:      'MX',
      countryName:      'México',
      mipexScore:       45,
      openness:         PolicyOpenness.moderate,
      summary:          'México es muy accesible para uruguayos (sin visa hasta 180 días). Residencia temporal relativamente fácil de obtener.',
      strongPoints:     ['Sin visa para uruguayos', 'Residencia temporal accesible', 'Costo de vida competitivo'],
      weakPoints:       ['Seguridad varía mucho por zona y estado', 'Sistema de salud público limitado para migrantes'],
      recommendedVisas: ['Estancia turista (sin visa)', 'Residente temporal', 'Residente permanente'],
      officialUrl:      'https://www.inm.gob.mx',
      lastUpdated:      DateTime(2025, 1, 5),
    ),
    'DEFAULT': CountryPolicy(
      countryCode:      'XX',
      countryName:      'País destino',
      mipexScore:       50,
      openness:         PolicyOpenness.moderate,
      summary:          'Información de políticas migratorias no disponible para este país. Consultá el portal oficial de inmigración.',
      strongPoints:     [],
      weakPoints:       [],
      recommendedVisas: [],
      officialUrl:      null,
      lastUpdated:      DateTime.now(),
    ),
  };

  static final Map<String, CostOfLivingSnapshot> _mockCostOfLiving = {
    'CA_calgary': CostOfLivingSnapshot(
      countryCode:           'CA',
      countryName:           'Canadá',
      city:                  'Calgary',
      rentOneBedroomCenter:  1650,
      rentOneBedroomSuburb:  1400,
      groceriesMonthly:      350,
      transportMonthly:      115,
      mealRestaurant:        18,
      internetMonthly:       65,
      avgSalaryNet:          3800,
      costIndexVsNYC:        70,
      lastUpdated:           DateTime(2025, 1, 1),
    ),
    'CA_toronto': CostOfLivingSnapshot(
      countryCode:           'CA',
      countryName:           'Canadá',
      city:                  'Toronto',
      rentOneBedroomCenter:  2400,
      rentOneBedroomSuburb:  1900,
      groceriesMonthly:      380,
      transportMonthly:      156,
      mealRestaurant:        20,
      internetMonthly:       70,
      avgSalaryNet:          4200,
      costIndexVsNYC:        85,
      lastUpdated:           DateTime(2025, 1, 1),
    ),
    'CA': CostOfLivingSnapshot(
      countryCode:           'CA',
      countryName:           'Canadá',
      city:                  'Toronto (referencia)',
      rentOneBedroomCenter:  2400,
      rentOneBedroomSuburb:  1900,
      groceriesMonthly:      380,
      transportMonthly:      156,
      mealRestaurant:        20,
      internetMonthly:       70,
      avgSalaryNet:          4200,
      costIndexVsNYC:        85,
      lastUpdated:           DateTime(2025, 1, 1),
    ),
    'ES': CostOfLivingSnapshot(
      countryCode:           'ES',
      countryName:           'España',
      city:                  'Madrid',
      rentOneBedroomCenter:  1200,
      rentOneBedroomSuburb:  900,
      groceriesMonthly:      280,
      transportMonthly:      54,
      mealRestaurant:        12,
      internetMonthly:       35,
      avgSalaryNet:          1800,
      costIndexVsNYC:        55,
      lastUpdated:           DateTime(2025, 1, 1),
    ),
    'PT': CostOfLivingSnapshot(
      countryCode:           'PT',
      countryName:           'Portugal',
      city:                  'Lisboa',
      rentOneBedroomCenter:  1100,
      rentOneBedroomSuburb:  800,
      groceriesMonthly:      240,
      transportMonthly:      40,
      mealRestaurant:        10,
      internetMonthly:       30,
      avgSalaryNet:          1400,
      costIndexVsNYC:        48,
      lastUpdated:           DateTime(2025, 1, 1),
    ),
    'DE': CostOfLivingSnapshot(
      countryCode:           'DE',
      countryName:           'Alemania',
      city:                  'Berlín',
      rentOneBedroomCenter:  1300,
      rentOneBedroomSuburb:  950,
      groceriesMonthly:      320,
      transportMonthly:      86,
      mealRestaurant:        14,
      internetMonthly:       40,
      avgSalaryNet:          2800,
      costIndexVsNYC:        65,
      lastUpdated:           DateTime(2025, 1, 1),
    ),
    'MX': CostOfLivingSnapshot(
      countryCode:           'MX',
      countryName:           'México',
      city:                  'Ciudad de México',
      rentOneBedroomCenter:  650,
      rentOneBedroomSuburb:  450,
      groceriesMonthly:      180,
      transportMonthly:      30,
      mealRestaurant:        6,
      internetMonthly:       22,
      avgSalaryNet:          900,
      costIndexVsNYC:        38,
      lastUpdated:           DateTime(2025, 1, 1),
    ),
    'DEFAULT': CostOfLivingSnapshot(
      countryCode:           'XX',
      countryName:           'País destino',
      city:                  'Ciudad principal',
      rentOneBedroomCenter:  1000,
      rentOneBedroomSuburb:  750,
      groceriesMonthly:      300,
      transportMonthly:      80,
      mealRestaurant:        12,
      internetMonthly:       40,
      avgSalaryNet:          2000,
      costIndexVsNYC:        55,
      lastUpdated:           DateTime.now(),
    ),
  };

  static final Map<String, RemittanceCorridor> _mockRemittances = {
    'UY_ES': RemittanceCorridor(
      originCountry:      'UY',
      destinationCountry: 'ES',
      avgCostPct:         4.2,
      avgCostUsd:         8.40,
      cheapestProvider:   'Wise',
      cheapestCostPct:    0.8,
      recommendation:     'Wise es la opción más barata para este corredor. Evitá los bancos tradicionales que cobran hasta 6%.',
      providers: [
        RemittanceProvider(name: 'Wise',     costPct: 0.8,  costUsd: 1.60, method: 'app', url: 'wise.com'),
        RemittanceProvider(name: 'Remitly',  costPct: 1.5,  costUsd: 3.00, method: 'app', url: 'remitly.com'),
        RemittanceProvider(name: 'Western Union', costPct: 4.9, costUsd: 9.80, method: 'efectivo'),
        RemittanceProvider(name: 'Banco UY', costPct: 6.1,  costUsd: 12.20, method: 'banco'),
      ],
      lastUpdated: DateTime(2025, 1, 15),
    ),
    'MX_CA': RemittanceCorridor(
      originCountry:      'MX',
      destinationCountry: 'CA',
      avgCostPct:         3.8,
      avgCostUsd:         7.60,
      cheapestProvider:   'Wise',
      cheapestCostPct:    0.6,
      recommendation:     'El corredor México-Canadá tiene opciones muy competitivas. Wise y Remitly son las mejores opciones por app.',
      providers: [
        RemittanceProvider(name: 'Wise',    costPct: 0.6,  costUsd: 1.20,  method: 'app', url: 'wise.com'),
        RemittanceProvider(name: 'Remitly', costPct: 1.2,  costUsd: 2.40,  method: 'app', url: 'remitly.com'),
        RemittanceProvider(name: 'Xoom',    costPct: 2.8,  costUsd: 5.60,  method: 'app'),
        RemittanceProvider(name: 'Western Union', costPct: 4.5, costUsd: 9.00, method: 'efectivo'),
      ],
      lastUpdated: DateTime(2025, 1, 15),
    ),
    'UY_PT': RemittanceCorridor(
      originCountry:      'UY',
      destinationCountry: 'PT',
      avgCostPct:         3.5,
      avgCostUsd:         7.00,
      cheapestProvider:   'Wise',
      cheapestCostPct:    0.7,
      recommendation:     'Wise domina este corredor. Para montos mayores a €1.000, Currencyfair puede ser más barato.',
      providers: [
        RemittanceProvider(name: 'Wise',         costPct: 0.7, costUsd: 1.40, method: 'app',  url: 'wise.com'),
        RemittanceProvider(name: 'Remitly',       costPct: 1.4, costUsd: 2.80, method: 'app',  url: 'remitly.com'),
        RemittanceProvider(name: 'Currencyfair',  costPct: 0.9, costUsd: 1.80, method: 'banco', url: 'currencyfair.com'),
      ],
      lastUpdated: DateTime(2025, 1, 15),
    ),
  };

  static final Map<String, MissingMigrantsAlert> _mockSafetyAlerts = {
    // Solo se carga si existe la ruta en este mapa.
    // Rutas seguras (vuelos directos, pasos legales) no tienen entrada.
    'MA_ES': MissingMigrantsAlert(
      routeId:           'med_west',
      routeName:         'Mediterráneo Occidental',
      originRegion:      'África del Norte',
      destinationRegion: 'Europa del Sur',
      alertLevel:        RouteAlertLevel.high,
      incidentsLast12m:  312,
      mainRisks:         'Cruce en embarcaciones no aptas. Corrientes peligrosas en el Estrecho de Gibraltar.',
      saferAlternatives: ['Solicitud de visa en consulado español', 'Programa AVRR de la OIM si se encuentra en tránsito'],
      humanitarianNote:  'Si estás en una situación de emergencia o en tránsito, contactá a la OIM al +34 91 445 7116.',
      emergencyContact:  '+34 91 445 7116',
      lastUpdated:       DateTime(2025, 1, 10),
    ),
  };

  static final Map<String, ReturnProgram> _mockReturnPrograms = {
    'ES': ReturnProgram(
      programId:            'avrr_es',
      name:                 'Programa de Retorno Voluntario — España',
      countryOfReturn:      'ES',
      countryOfReturn_Name: 'España (hacia país de origen)',
      eligibleOrigins:      ['UY', 'AR', 'MX', 'CO', 'PE', 'BO', 'EC', 'PY'],
      description:          'Si las cosas no salieron como esperabas, la OIM y el gobierno español tienen programas gratuitos para volver a casa dignamente.',
      benefits:             ['Pasaje de avión costeado total o parcialmente', 'Asesoría pre-retorno', 'Apoyo para reintegración en el país de origen', 'Documentación de viaje si es necesario'],
      howToApply:           'Contactá la oficina de la OIM en España (Madrid) o el consulado de tu país. El proceso demora entre 2 y 6 semanas.',
      contactEmail:         'iomspain@iom.int',
      contactPhone:         '+34 91 445 7116',
      contactUrl:           'https://spain.iom.int/voluntary-return',
      includesReintegration: true,
      lastUpdated:          DateTime(2025, 1, 1),
    ),
    'CA': ReturnProgram(
      programId:            'avrr_ca',
      name:                 'Assisted Voluntary Return — Canadá',
      countryOfReturn:      'CA',
      countryOfReturn_Name: 'Canadá (hacia país de origen)',
      eligibleOrigins:      ['MX', 'UY', 'AR', 'CO', 'PE'],
      description:          'Si tu proceso migratorio en Canadá no prosperó, existen programas de retorno asistido desde IRCC y la OIM.',
      benefits:             ['Asistencia con documentación', 'Orientación pre-retorno', 'Conexión con programas de reintegración en país de origen'],
      howToApply:           'Contactá a la OIM en Canadá (Ottawa) o al IRCC. El proceso puede tomar 4–8 semanas.',
      contactEmail:         'iomcanada@iom.int',
      contactPhone:         '+1 613 232 9011',
      contactUrl:           'https://canada.iom.int/voluntary-return',
      includesReintegration: true,
      lastUpdated:          DateTime(2025, 1, 1),
    ),
  };

  static final Map<String, List<String>> _mockNewsAlerts = {
    'CA': [
      '🇨🇦 Express Entry: último draw requirió 488 puntos CRS (ene. 2025)',
      '📋 Nuevos requisitos de inglés para PR a partir de marzo 2025',
    ],
    'ES': [
      '🇪🇸 Ley de Nietos: plazo extendido hasta dic. 2025',
      '⚖️ Nueva circular sobre visas de nómada digital en vigor',
    ],
    'PT': [
      '🇵🇹 AIMA: tiempos de espera reducidos a 4–6 meses en Lisboa',
      '💼 Visa D7: requisito de ingresos actualizado a €820/mes',
    ],
    'DE': [
      '🇩🇪 Chancenkarte: ampliación del programa hasta 2026',
      '📚 Reconocimiento de títulos: nuevos centros de evaluación abiertos',
    ],
  };

  static final Map<String, WelcomePack> _mockWelcomePacks = {
    'CA': WelcomePack(
      countryCode:     'CA',
      city:            'Calgary',
      emergencyNumber: '911',
      eSIMUrl:         'https://roamless.com',
      items: [
        WelcomeItem(emoji: '📱', title: 'Conseguí una SIM local', description: 'Koodo, Fido o Lucky Mobile son las más económicas. Disponibles en Walmart y Costco.', priority: 1),
        WelcomeItem(emoji: '🪪', title: 'Tramitá tu SIN (Social Insurance Number)', description: 'Necesario para trabajar. Se tramita gratis en Service Canada — llevá tu pasaporte y permiso de trabajo.', priority: 2, actionUrl: 'https://www.canada.ca/en/employment-social-development/services/sin.html'),
        WelcomeItem(emoji: '🏦', title: 'Abrí una cuenta bancaria', description: 'TD Bank y RBC tienen programas especiales para recién llegados sin historial crediticio.', priority: 3),
        WelcomeItem(emoji: '🏥', title: 'Registrate en Alberta Health Services', description: 'El seguro médico provincial es gratuito pero tiene 3 meses de carencia. Confirmá tu cobertura de seguro privado.', priority: 4, actionUrl: 'https://www.alberta.ca/ahcip'),
        WelcomeItem(emoji: '🚌', title: 'Descargá la app de transporte', description: 'Calgary Transit app para rutas de bus y CTrain. Un pase mensual cuesta CAD \$115.', priority: 5),
      ],
      mapPoints: [
        MapPoint(name: 'Service Canada — Centro', category: 'immigration', emoji: '🏛️', address: '220 4 Ave SE, Calgary'),
        MapPoint(name: 'Alberta Health Services', category: 'hospital',    emoji: '🏥', address: '10101 Southport Rd SW'),
        MapPoint(name: 'TD Bank Chinatown',       category: 'bank',        emoji: '🏦', address: '111 3 Ave SE, Calgary'),
        MapPoint(name: 'CTrain City Hall Station', category: 'metro',      emoji: '🚇', address: '3 Ave SW & 1 St SW'),
      ],
    ),
    'ES': WelcomePack(
      countryCode:     'ES',
      city:            'Madrid',
      emergencyNumber: '112',
      eSIMUrl:         'https://airalo.com',
      items: [
        WelcomeItem(emoji: '📱', title: 'Conseguí una SIM española', description: 'Simyo, Digi o Pepephone son las más baratas. Solo necesitás el pasaporte.', priority: 1),
        WelcomeItem(emoji: '🪪', title: 'Pedí cita para el NIE/TIE', description: 'Número de Identidad de Extranjero — imprescindible para cualquier trámite. Pedí cita en extranjeros.inclusion.gob.es.', priority: 2, actionUrl: 'https://icp.administracionelectronica.gob.es'),
        WelcomeItem(emoji: '🏙️', title: 'Empadronarte en el Ayuntamiento', description: 'Lleva contrato de alquiler y pasaporte. Necesario para acceder a la sanidad pública.', priority: 3),
        WelcomeItem(emoji: '🏦', title: 'Abrí una cuenta bancaria', description: 'N26 y Revolut no requieren NIE. Después podés abrir en BBVA o CaixaBank con el NIE.', priority: 4),
        WelcomeItem(emoji: '🏥', title: 'Registrate en el centro de salud', description: 'Con el padrón y el TIE, asignate un médico de cabecera en el centro de salud más cercano.', priority: 5),
      ],
      mapPoints: [
        MapPoint(name: 'Oficina Extranjería Madrid', category: 'immigration', emoji: '🏛️', address: 'C/ Miguel Ángel, 5, Madrid'),
        MapPoint(name: 'Hospital La Paz',           category: 'hospital',    emoji: '🏥', address: 'Paseo de la Castellana, 261'),
        MapPoint(name: 'BBVA Gran Vía',             category: 'bank',        emoji: '🏦', address: 'Gran Vía, 1, Madrid'),
        MapPoint(name: 'Metro Sol',                 category: 'metro',       emoji: '🚇', address: 'Puerta del Sol, Madrid'),
      ],
    ),
  };

  // ── Helpers de contenido ───────────────────────────────────────────────────

  static String _apostilleInstructions(String originCode) {
    switch (originCode) {
      case 'UY': return 'En Uruguay: Ministerio de RREE (Torre Ejecutiva). Costo: \$500–1.500 UYU. Tiempo: 2–5 días hábiles.';
      case 'MX': return 'En México: Secretaría de Gobernación (SEGOB) o notario público con fe pública federal. Tiempo: 1–5 días.';
      case 'AR': return 'En Argentina: Cancillería (Palermo) o colegios de escribanos provinciales. Tiempo: 1–10 días según provincia.';
      default:   return 'Consultá el organismo oficial de apostille en tu país de origen.';
    }
  }

  static String _credentialEvaluationInstructions(String destCode) {
    switch (destCode) {
      case 'CA': return 'En Canadá: WES (World Education Services) es la más reconocida para Express Entry. Costo: ~CAD \$220. Tiempo: 7–10 semanas.';
      case 'DE': return 'En Alemania: anabin.kmk.org para verificar reconocimiento previo. Si no está listado, tramitá en la Zentralstelle für ausländisches Bildungswesen (ZAB).';
      case 'ES': return 'En España: ANECA para títulos universitarios. Proceso: solicitud online en educacion.gob.es. Tiempo: 3–12 meses.';
      default:   return 'Consultá el organismo de reconocimiento de títulos del país destino.';
    }
  }

  static String _languageTestName(String destCode) {
    switch (destCode) {
      case 'CA': return 'Rendir IELTS o CELPIP (inglés)';
      case 'DE': return 'Certificado de alemán (mínimo B1)';
      case 'PT': return 'Certificado de portugués (A2 para ciudadanía)';
      default:   return 'Certificado de idioma del país destino';
    }
  }

  static String _idDocumentName(String destCode) {
    switch (destCode) {
      case 'CA': return 'Tramitar SIN (Social Insurance Number)';
      case 'ES': return 'Tramitar NIE / TIE';
      case 'PT': return 'Tramitar NIF y Autorización de Residencia';
      case 'DE': return 'Registro de residencia (Anmeldung)';
      case 'MX': return 'Tramitar CURP y tarjeta de residente';
      default:   return 'Tramitar documento de identidad local';
    }
  }

  static String _idDocumentInstructions(String destCode) {
    switch (destCode) {
      case 'CA': return 'Gratis en Service Canada. Llevá pasaporte y permiso de trabajo. Se obtiene en el día.';
      case 'ES': return 'Cita en extranjeros.inclusion.gob.es. Llevá pasaporte + foto + tasa (€15) + documentos de la visa.';
      case 'PT': return 'Cita en AIMA (Agência para a Integração, Migrações e Asilo). Llevá pasaporte + comprobante de alojamiento.';
      case 'DE': return 'Anmeldung en el Bürgeramt de tu barrio. Gratis. Llevá pasaporte + contrato de alquiler.';
      default:   return 'Consultá el organismo de inmigración local para instrucciones específicas.';
    }
  }

  static String _idDocumentTime(String destCode) {
    switch (destCode) {
      case 'CA': return 'Día 1 (mismo día)';
      case 'ES': return '2–4 semanas (cita + resolución)';
      case 'PT': return '4–8 semanas';
      case 'DE': return 'Día 1 (necesitás cita previa)';
      default:   return '1–4 semanas';
    }
  }

  static String _bankAccountInstructions(String destCode) {
    switch (destCode) {
      case 'CA': return 'TD Bank y RBC tienen paquetes para recién llegados sin historial crediticio. Llevá pasaporte y SIN.';
      case 'ES': return 'N26 y Revolut no requieren NIE. Después podés ir a BBVA o CaixaBank con el TIE.';
      case 'PT': return 'Millennium BCP y Caixa Geral atienden a residentes extranjeros. Necesitás NIF + comprobante de dirección.';
      case 'DE': return 'N26 (100% online, sin requisitos) es la opción más fácil para recién llegados. Deutsche Bank requiere Anmeldung.';
      default:   return 'Consultá los bancos locales sobre requisitos para no residentes.';
    }
  }

  static bool _requiresEmpadronamiento(String destCode) {
    // El empadronamiento es obligatorio en España y Portugal, opcional en otros.
    return destCode == 'ES' || destCode == 'PT';
  }

  static WelcomePack _buildDefaultWelcomePack(String countryCode, String city) {
    return WelcomePack(
      countryCode:     countryCode,
      city:            city,
      emergencyNumber: '112',
      items: [
        WelcomeItem(emoji: '📱', title: 'Conseguí una SIM local', description: 'Necesaria para activar apps de transporte, banco y mapas.', priority: 1),
        WelcomeItem(emoji: '🪪', title: 'Tramitá tu documento de identidad local', description: 'Consultá el organismo de inmigración local para instrucciones.', priority: 2),
        WelcomeItem(emoji: '🏦', title: 'Abrí una cuenta bancaria', description: 'N26 y Revolut funcionan en muchos países sin documentación local.', priority: 3),
        WelcomeItem(emoji: '🏥', title: 'Verificá cobertura médica', description: 'Confirmá que tu seguro privado está activo hasta estar en el sistema público.', priority: 4),
      ],
      mapPoints: [],
    );
  }

  // ── Mapas de referencia ────────────────────────────────────────────────────

  static const Map<String, String> _defaultCities = {
    'CA': 'toronto',
    'ES': 'madrid',
    'PT': 'lisboa',
    'DE': 'berlin',
    'MX': 'ciudad de méxico',
    'AU': 'sydney',
    'GB': 'london',
  };

  static const Map<String, String> _officialImmigrationUrl = {
    'CA': 'https://ircc.canada.ca',
    'ES': 'https://extranjeros.inclusion.gob.es',
    'PT': 'https://imigrante.sef.pt',
    'DE': 'https://www.make-it-in-germany.com',
    'MX': 'https://www.inm.gob.mx',
    'AU': 'https://immi.homeaffairs.gov.au',
    'GB': 'https://www.gov.uk/browse/visas-immigration',
  };

  static const Map<String, String> _apostilleUrls = {
    'UY': 'https://www.gub.uy/ministerio-relaciones-exteriores/apostilla',
    'MX': 'https://www.gob.mx/tramites/ficha/apostilla',
    'AR': 'https://cancilleria.gob.ar/es/servicios/apostilla',
    'CO': 'https://www.cancilleria.gov.co/tramites_servicios/apostilla',
    'CL': 'https://www.minjusticia.gob.cl/apostilla/',
  };

  static const Map<String, String> _credentialEvalUrls = {
    'CA': 'https://www.wes.org',
    'ES': 'https://www.aneca.es/homologacion',
    'DE': 'https://anabin.kmk.org',
    'AU': 'https://www.aecc.net.au',
    'GB': 'https://www.enic.org.uk',
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper interno — entrada del cache con TTL
// ═══════════════════════════════════════════════════════════════════════════════

class _CacheEntry<T> {
  final T        value;
  final DateTime expiresAt;

  _CacheEntry(this.value, Duration ttl)
      : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
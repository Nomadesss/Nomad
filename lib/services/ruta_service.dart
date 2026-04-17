// lib/services/ruta_service.dart
//
// Genera la "Ruta Inteligente" personalizada a partir del MigrationProfile.
// No requiere API externa — toda la lógica es local y determinística.

import 'migration_data_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS DE RUTA
// ─────────────────────────────────────────────────────────────────────────────

class RutaMes {
  final int    mesNumero;   // 1, 2, 3…
  final String titulo;
  final String emoji;
  final MigrantPhase fase;
  final List<RutaTarea> tareas;

  const RutaMes({
    required this.mesNumero,
    required this.titulo,
    required this.emoji,
    required this.fase,
    required this.tareas,
  });
}

class RutaTarea {
  final String titulo;
  final String detalle;
  final bool   esRequerida;
  final String? costoEstimado; // ej: 'USD 120–200'
  final String? duracionEstimada;

  const RutaTarea({
    required this.titulo,
    required this.detalle,
    required this.esRequerida,
    this.costoEstimado,
    this.duracionEstimada,
  });
}

class RutaPresupuesto {
  final double visa;
  final double documentos;
  final double vuelo;
  final double primerMesAlquiler;
  final double deposito;
  final double colchon; // reserva recomendada
  final double total;
  final String moneda;

  const RutaPresupuesto({
    required this.visa,
    required this.documentos,
    required this.vuelo,
    required this.primerMesAlquiler,
    required this.deposito,
    required this.colchon,
    required this.total,
    this.moneda = 'USD',
  });

  double get porcentajeVisa      => total > 0 ? visa / total          : 0;
  double get porcentajeDocumentos => total > 0 ? documentos / total    : 0;
  double get porcentajeVuelo     => total > 0 ? vuelo / total          : 0;
  double get porcentajeInstalacion =>
      total > 0 ? (primerMesAlquiler + deposito) / total : 0;
  double get porcentajeColchon   => total > 0 ? colchon / total        : 0;
}

class CasoSimilar {
  final String nombre;
  final String origen;
  final String destino;
  final String profesion;
  final String resumenHistoria;
  final int    mesesQueLesTardo;
  final String consejoPrincipal;

  const CasoSimilar({
    required this.nombre,
    required this.origen,
    required this.destino,
    required this.profesion,
    required this.resumenHistoria,
    required this.mesesQueLesTardo,
    required this.consejoPrincipal,
  });
}

class RutaInteligente {
  final MigrationProfile   perfil;
  final List<RutaMes>      timeline;
  final RutaPresupuesto    presupuesto;
  final List<String>       proximosPasos;  // "Ahora necesitas esto"
  final List<CasoSimilar>  casosSimilares;
  final String             resumenEjecutivo;
  final DateTime           generadaEn;

  const RutaInteligente({
    required this.perfil,
    required this.timeline,
    required this.presupuesto,
    required this.proximosPasos,
    required this.casosSimilares,
    required this.resumenEjecutivo,
    required this.generadaEn,
  });

  int get totalMeses => timeline.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// GENERADOR
// ─────────────────────────────────────────────────────────────────────────────

class RutaService {
  RutaService._();

  static RutaInteligente generate(MigrationProfile perfil) {
    final urgencia = perfil.urgencyLevel ?? UrgencyLevel.moderate;
    final budget   = perfil.budgetRange  ?? BudgetRange.medium;
    final tipo     = perfil.profileType;
    final destino  = perfil.destinationCountry;

    final meses    = _buildTimeline(perfil, urgencia, tipo);
    final presup   = _buildPresupuesto(destino, tipo, budget, urgencia);
    final proximos = _buildProximosPasos(perfil);
    final casos    = _buildCasosSimilares(perfil);
    final resumen  = _buildResumen(perfil, urgencia, presup);

    return RutaInteligente(
      perfil:           perfil,
      timeline:         meses,
      presupuesto:      presup,
      proximosPasos:    proximos,
      casosSimilares:   casos,
      resumenEjecutivo: resumen,
      generadaEn:       DateTime.now(),
    );
  }

  // ── Timeline ───────────────────────────────────────────────────────────────

  static List<RutaMes> _buildTimeline(
    MigrationProfile perfil,
    UrgencyLevel urgencia,
    MigrantProfileType tipo,
  ) {
    final meses = <RutaMes>[];
    final total = urgencia.totalMonths;

    if (total <= 3) {
      // Ruta urgente — comprimida
      meses.add(_mesDescubrimiento(1, perfil, comprimido: true));
      meses.add(_mesPreparacion(2,  perfil, comprimido: true));
      meses.add(_mesViaje(3, perfil));
    } else if (total <= 5) {
      // Ruta moderada
      meses.add(_mesDescubrimiento(1, perfil, comprimido: false));
      meses.add(_mesPreparacion(2,  perfil, comprimido: false));
      meses.add(_mesPreparacion(3,  perfil, comprimido: false, parte2: true));
      meses.add(_mesViaje(4, perfil));
      meses.add(_mesIntegracion(5, perfil, inicial: true));
    } else {
      // Ruta tranquila — 9 meses
      meses.add(_mesDescubrimiento(1, perfil, comprimido: false));
      meses.add(_mesDescubrimiento(2, perfil, comprimido: false, parte2: true));
      meses.add(_mesPreparacion(3,  perfil, comprimido: false));
      meses.add(_mesPreparacion(4,  perfil, comprimido: false, parte2: true));
      meses.add(_mesPreparacion(5,  perfil, comprimido: false, documentos: true));
      meses.add(_mesViaje(6, perfil));
      meses.add(_mesIntegracion(7, perfil, inicial: true));
      meses.add(_mesIntegracion(8, perfil, inicial: false));
      meses.add(_mesIntegracion(9, perfil, inicial: false));
    }

    return meses;
  }

  static RutaMes _mesDescubrimiento(int n, MigrationProfile p, {
    required bool comprimido, bool parte2 = false,
  }) {
    final dest = p.destinationCountryName;
    final tipo = p.profileType;

    if (parte2) {
      return RutaMes(
        mesNumero: n,
        titulo:   'Investigación profunda',
        emoji:    '🔬',
        fase:     MigrantPhase.discovery,
        tareas: [
          RutaTarea(
            titulo: 'Elegir ciudad destino',
            detalle: 'Comparar costo de vida, mercado laboral y comunidad latinoamericana en $dest.',
            esRequerida: true,
            duracionEstimada: '1–2 semanas',
          ),
          RutaTarea(
            titulo: 'Validar reconocimiento de título / profesión',
            detalle: _tituloTexto(tipo, dest),
            esRequerida: tipo == MigrantProfileType.professional || tipo == MigrantProfileType.student,
            duracionEstimada: '1 semana',
          ),
          RutaTarea(
            titulo: 'Calcular presupuesto real',
            detalle: 'Sumar: visa + documentos + vuelo + primer mes + depósito + colchón de 3 meses.',
            esRequerida: true,
            duracionEstimada: '2–3 días',
          ),
          RutaTarea(
            titulo: 'Conectar con la comunidad en $dest',
            detalle: 'Unirte a grupos de Nomad de gente que ya hizo tu ruta y preguntarles directo.',
            esRequerida: false,
            duracionEstimada: '1 semana',
          ),
        ],
      );
    }

    return RutaMes(
      mesNumero: n,
      titulo:   comprimido ? 'Investigación y decisión' : 'Investigación inicial',
      emoji:    '🔍',
      fase:     MigrantPhase.discovery,
      tareas: [
        RutaTarea(
          titulo: 'Definir país y ciudad destino',
          detalle: 'Confirmá $dest como destino. Investigá el índice MIPEX, visas disponibles para tu perfil y costo de vida.',
          esRequerida: true,
          duracionEstimada: comprimido ? '3–5 días' : '1–2 semanas',
        ),
        RutaTarea(
          titulo: 'Identificar la visa correcta',
          detalle: _visaTexto(p.profileType, dest),
          esRequerida: true,
          duracionEstimada: '3–5 días',
        ),
        RutaTarea(
          titulo: 'Abrir cuenta bancaria sin comisiones internacionales',
          detalle: 'Abrí Wise, Revolut o similar antes de moverte. Vas a necesitar recibir y enviar dinero internacionalmente.',
          esRequerida: true,
          duracionEstimada: '1–2 días',
          costoEstimado: 'Gratis–USD 10',
        ),
        if (comprimido)
          RutaTarea(
            titulo: 'Listar documentos necesarios para la visa',
            detalle: 'Usá el checklist de Nomad para tu perfil + destino. Empezá a juntar lo que ya tenés.',
            esRequerida: true,
            duracionEstimada: '2–3 días',
          ),
      ],
    );
  }

  static RutaMes _mesPreparacion(int n, MigrationProfile p, {
    required bool comprimido, bool parte2 = false, bool documentos = false,
  }) {
    final dest = p.destinationCountryName;
    final tipo = p.profileType;

    if (documentos) {
      return RutaMes(
        mesNumero: n,
        titulo:   'Documentos y apostillas',
        emoji:    '📋',
        fase:     MigrantPhase.preparation,
        tareas: [
          RutaTarea(
            titulo: 'Apostillar documentos en tu país de origen',
            detalle: 'Título universitario, partida de nacimiento, antecedentes penales. La apostilla puede tardar 2–4 semanas.',
            esRequerida: true,
            duracionEstimada: '2–4 semanas',
            costoEstimado: 'USD 50–200',
          ),
          RutaTarea(
            titulo: 'Traducción jurada (si aplica)',
            detalle: p.originCountry != 'ES' && dest != 'ES'
                ? 'Traducí al idioma del destino los documentos que lo requieran.'
                : 'No necesitás traducción para documentos en español.',
            esRequerida: p.originCountry != 'ES',
            duracionEstimada: '1–2 semanas',
            costoEstimado: 'USD 30–150 por documento',
          ),
          RutaTarea(
            titulo: 'Presentar solicitud de visa',
            detalle: 'Completá el formulario oficial, juntá todos los documentos y presentá en el consulado o portal online.',
            esRequerida: true,
            duracionEstimada: '1 semana de trámite',
            costoEstimado: _costVisa(tipo, dest),
          ),
        ],
      );
    }

    if (parte2) {
      return RutaMes(
        mesNumero: n,
        titulo:   'Financiero y logística',
        emoji:    '💼',
        fase:     MigrantPhase.preparation,
        tareas: [
          RutaTarea(
            titulo: 'Ahorrar y convertir moneda',
            detalle: 'Convertí tus ahorros a USD o EUR con Wise para minimizar el spread. Evitá hacerlo todo junto el día antes.',
            esRequerida: true,
          ),
          RutaTarea(
            titulo: 'Seguro de salud internacional',
            detalle: 'Contratá cobertura antes de viajar. Opciones: SafetyWing (~USD 42/mes), Cigna Global, o cobertura del empleador.',
            esRequerida: true,
            duracionEstimada: '2–3 días para comparar',
            costoEstimado: 'USD 40–150/mes',
          ),
          RutaTarea(
            titulo: 'Reservar alojamiento temporal',
            detalle: 'Airbnb o booking para las primeras 2–4 semanas. No firmes contrato de larga duración antes de conocer el barrio.',
            esRequerida: true,
            costoEstimado: 'USD 600–1.500 primeras semanas',
          ),
          if (tipo == MigrantProfileType.professional || tipo == MigrantProfileType.nomad)
            RutaTarea(
              titulo: 'Actualizar perfil LinkedIn + portfolio',
              detalle: 'Poné "$dest" como ubicación deseada y activá la opción "open to work". Conectá con reclutadores locales.',
              esRequerida: false,
              duracionEstimada: '1–2 días',
            ),
        ],
      );
    }

    return RutaMes(
      mesNumero: n,
      titulo:   comprimido ? 'Documentos y visa express' : 'Preparación documental',
      emoji:    '📄',
      fase:     MigrantPhase.preparation,
      tareas: [
        RutaTarea(
          titulo: 'Renovar pasaporte (si vence en menos de 1 año)',
          detalle: 'Verificá vigencia. Muchos países exigen 6 meses mínimo de vigencia al ingresar.',
          esRequerida: true,
          duracionEstimada: comprimido ? '2–3 días urgente' : '1–3 semanas',
          costoEstimado: 'USD 30–80',
        ),
        RutaTarea(
          titulo: 'Juntar documentos para la visa',
          detalle: _documentosTexto(tipo),
          esRequerida: true,
          duracionEstimada: '1–2 semanas',
        ),
        RutaTarea(
          titulo: 'Antecedentes penales legalizados',
          detalle: 'Solicitá el certificado en tu país. Puede tardar hasta 15 días hábiles.',
          esRequerida: true,
          duracionEstimada: '1–3 semanas',
          costoEstimado: 'USD 10–30',
        ),
        if (!comprimido)
          RutaTarea(
            titulo: 'Sacar turno en el consulado / embajada',
            detalle: 'Los turnos pueden demorar semanas. Sacá turno incluso antes de tener todos los documentos.',
            esRequerida: true,
          ),
      ],
    );
  }

  static RutaMes _mesViaje(int n, MigrationProfile p) {
    return RutaMes(
      mesNumero: n,
      titulo:   'Viaje y llegada',
      emoji:    '✈️',
      fase:     MigrantPhase.transition,
      tareas: [
        RutaTarea(
          titulo: 'Comprar pasaje de avión',
          detalle: 'Comprá con 30–45 días de anticipación. Usá Google Flights y activá alertas de precio.',
          esRequerida: true,
          costoEstimado: _costVuelo(p.originCountry, p.destinationCountry),
        ),
        RutaTarea(
          titulo: 'Llegar y conseguir SIM local',
          detalle: 'Lo primero al salir del aeropuerto: conseguí una SIM local o activá una eSIM. Internet es crítico para moverte.',
          esRequerida: true,
          costoEstimado: 'USD 10–30',
        ),
        RutaTarea(
          titulo: 'Registrarse ante las autoridades migratorias',
          detalle: _registroMigratoriTexto(p.destinationCountry),
          esRequerida: true,
          duracionEstimada: 'Primeros 30 días',
        ),
        RutaTarea(
          titulo: 'Abrir cuenta bancaria local',
          detalle: _cuentaBancariaTexto(p.destinationCountry),
          esRequerida: true,
          duracionEstimada: '1–2 semanas',
        ),
        RutaTarea(
          titulo: 'Recorrer el barrio y elegir zona definitiva',
          detalle: 'No firmes contrato largo el primer mes. Explorá, hablá con locales, encontrá tu zona.',
          esRequerida: false,
          duracionEstimada: '2–3 semanas',
        ),
      ],
    );
  }

  static RutaMes _mesIntegracion(int n, MigrationProfile p, {required bool inicial}) {
    if (inicial) {
      return RutaMes(
        mesNumero: n,
        titulo:   'Instalación y primeros pasos',
        emoji:    '🏠',
        fase:     MigrantPhase.integration,
        tareas: [
          RutaTarea(
            titulo: 'Firmar contrato de alquiler definitivo',
            detalle: 'Buscá con 2–3 semanas de anticipación. Tené listo pasaporte, visa y último extracto bancario.',
            esRequerida: true,
            costoEstimado: '1–2 meses de depósito',
          ),
          RutaTarea(
            titulo: 'Número de identificación fiscal / social',
            detalle: _idFiscalTexto(p.destinationCountry),
            esRequerida: true,
            duracionEstimada: '1–4 semanas',
          ),
          if (p.profileType == MigrantProfileType.professional ||
              p.profileType == MigrantProfileType.nomad)
            RutaTarea(
              titulo: 'Buscar trabajo o primer contrato',
              detalle: 'Actualizá LinkedIn con dirección local. Postulate a posiciones en empresas que contratan migrantes.',
              esRequerida: true,
              duracionEstimada: '2–8 semanas',
            ),
          if (p.profileType == MigrantProfileType.student)
            RutaTarea(
              titulo: 'Inscripción universitaria y orientación',
              detalle: 'Asistí a la semana de orientación, registrate en los servicios de la universidad y conseguí tu credencial.',
              esRequerida: true,
            ),
          RutaTarea(
            titulo: 'Conectar con la comunidad local',
            detalle: 'Buscá en Nomad personas con tu misma ruta. Los primeros amigos suelen ser el diferencial entre quedarse o irse.',
            esRequerida: false,
          ),
        ],
      );
    }

    return RutaMes(
      mesNumero: n,
      titulo:   n <= 8 ? 'Estabilización' : 'Consolidación',
      emoji:    n <= 8 ? '🌱' : '🌳',
      fase:     MigrantPhase.integration,
      tareas: [
        RutaTarea(
          titulo: 'Regularizar situación migratoria (si aplica)',
          detalle: 'Verificá plazos de renovación de visa o permiso de residencia. Agendá trámites con anticipación.',
          esRequerida: true,
        ),
        RutaTarea(
          titulo: 'Establecer rutina financiera',
          detalle: 'Abrí cuenta de ahorro local, dominiciliá pagos fijos y empezá a rastrear gastos vs. presupuesto.',
          esRequerida: false,
        ),
        if (n > 8)
          RutaTarea(
            titulo: 'Evaluar camino hacia residencia permanente',
            detalle: 'Investigá los requisitos y plazos para residencia permanente o ciudadanía según tu perfil.',
            esRequerida: false,
            duracionEstimada: 'Proceso de 1–5 años',
          ),
      ],
    );
  }

  // ── Presupuesto ────────────────────────────────────────────────────────────

  static RutaPresupuesto _buildPresupuesto(
    String destino,
    MigrantProfileType tipo,
    BudgetRange budget,
    UrgencyLevel urgencia,
  ) {
    final visa        = _visaCost(tipo, destino);
    final documentos  = _documentosCost(urgencia);
    final vuelo       = _vueloCost(destino);
    final alquiler    = _alquilerMes(destino);
    final deposito    = alquiler * 1.5;
    final colchon     = alquiler * 3;

    final total = visa + documentos + vuelo + alquiler + deposito + colchon;

    return RutaPresupuesto(
      visa:               visa,
      documentos:         documentos,
      vuelo:              vuelo,
      primerMesAlquiler:  alquiler,
      deposito:           deposito,
      colchon:            colchon,
      total:              total,
    );
  }

  // ── Próximos pasos ─────────────────────────────────────────────────────────

  static List<String> _buildProximosPasos(MigrationProfile p) {
    final steps = <String>[];
    final fase  = p.currentPhase;

    if (fase == MigrantPhase.discovery) {
      if (p.urgencyLevel == UrgencyLevel.urgent) {
        steps.add('Sacá turno en el consulado de ${p.destinationCountryName} esta semana');
        steps.add('Verificá vigencia del pasaporte HOY');
        steps.add('Abrí una cuenta Wise para mover ahorros sin comisiones');
      } else {
        steps.add('Investigá las visas disponibles para tu perfil en ${p.destinationCountryName}');
        steps.add('Calculá cuánto necesitás ahorrar con el presupuesto de abajo');
        steps.add('Conectá con alguien en Nomad que ya hizo tu ruta');
      }
    } else if (fase == MigrantPhase.preparation) {
      steps.add('Verificá que tenés todos los documentos del checklist');
      steps.add('Apostillá lo que falta — puede tardar 2–4 semanas');
      steps.add('Reservá alojamiento temporal para las primeras semanas');
    } else if (fase == MigrantPhase.transition) {
      steps.add('Registrarte en el consulado de tu país en ${p.destinationCountryName}');
      steps.add('Tramitar el número de identificación fiscal / social');
      steps.add('Abrir cuenta bancaria local');
    } else {
      steps.add('Regularizar tu situación migratoria antes de que venza el plazo');
      steps.add('Buscar un asesor legal local para el camino hacia la residencia');
      steps.add('Conectar con comunidad latinoamericana en tu ciudad');
    }

    return steps;
  }

  // ── Casos similares ────────────────────────────────────────────────────────

  static List<CasoSimilar> _buildCasosSimilares(MigrationProfile p) {
    final tipo   = p.profileType;
    final destino = p.destinationCountryName;

    // Casos curados por perfil + destino. En v2.0: datos reales de Firestore.
    if (tipo == MigrantProfileType.professional) {
      return [
        CasoSimilar(
          nombre:         'Valentina R.',
          origen:         'Buenos Aires, Argentina',
          destino:        destino,
          profesion:      'Diseñadora UX',
          resumenHistoria: 'Migré a $destino con una oferta de trabajo previa. El proceso de visa me llevó 3 meses en total.',
          mesesQueLesTardo: 4,
          consejoPrincipal: 'Conseguí la oferta laboral antes de moverte — cambia todo el proceso migratorio.',
        ),
        CasoSimilar(
          nombre:         'Martín C.',
          origen:         'Bogotá, Colombia',
          destino:        destino,
          profesion:      'Desarrollador backend',
          resumenHistoria: 'Llegué con visa de turista y conseguí trabajo en el primer mes. Después tramité el permiso de trabajo.',
          mesesQueLesTardo: 6,
          consejoPrincipal: 'La comunidad local de tech me abrió más puertas que LinkedIn.',
        ),
      ];
    }

    if (tipo == MigrantProfileType.student) {
      return [
        CasoSimilar(
          nombre:         'Camila F.',
          origen:         'Santiago, Chile',
          destino:        destino,
          profesion:      'Estudiante de Ingeniería',
          resumenHistoria: 'Apliqué a 3 universidades en $destino. Me aceptaron en dos. La visa de estudiante me llevó 2 meses.',
          mesesQueLesTardo: 5,
          consejoPrincipal: 'Aplicá con 8 meses de anticipación al ciclo lectivo. Los plazos son estrictos.',
        ),
      ];
    }

    if (tipo == MigrantProfileType.nomad) {
      return [
        CasoSimilar(
          nombre:         'Diego M.',
          origen:         'Montevideo, Uruguay',
          destino:        destino,
          profesion:      'Freelancer (marketing)',
          resumenHistoria: 'Tramité la visa de nómada digital. Ahora trabajo desde cafés y coworkings en $destino.',
          mesesQueLesTardo: 3,
          consejoPrincipal: 'La visa de nómada digital vale la pena si ya tenés clientes que te pagan en USD/EUR.',
        ),
      ];
    }

    return [
      CasoSimilar(
        nombre:         'Ana P.',
        origen:         'Lima, Perú',
        destino:        destino,
        profesion:      'Migrante general',
        resumenHistoria: 'Me tomó 6 meses en total desde que decidí migrar hasta que me instalé en $destino.',
        mesesQueLesTardo: 6,
        consejoPrincipal: 'Ahorrar más de lo que calculás al principio. Siempre hay gastos imprevistos.',
      ),
    ];
  }

  // ── Resumen ejecutivo ──────────────────────────────────────────────────────

  static String _buildResumen(
    MigrationProfile p,
    UrgencyLevel urgencia,
    RutaPresupuesto presup,
  ) {
    final dest    = p.destinationCountryName;
    final meses   = urgencia.totalMonths;
    final budget  = presup.total.toStringAsFixed(0);

    return 'Tu ruta personalizada a $dest en $meses meses con un presupuesto estimado de USD $budget. '
        'Basada en tu perfil como ${p.profileType.label.toLowerCase()}.';
  }

  // ── Helpers de textos ──────────────────────────────────────────────────────

  static String _visaTexto(MigrantProfileType tipo, String destino) {
    switch (tipo) {
      case MigrantProfileType.professional:
        return 'Para profesionales en $destino las opciones principales son: visa de trabajo con oferta, visa de búsqueda de empleo (algunos países) y visa de habilidades globales.';
      case MigrantProfileType.student:
        return 'Necesitás carta de aceptación de una institución reconocida en $destino para solicitar la visa de estudiante.';
      case MigrantProfileType.nomad:
        return 'Investigá si $destino tiene visa de nómada digital. Requisito típico: ingresos mensuales comprobables de USD 2.000–3.500.';
      case MigrantProfileType.entrepreneur:
        return 'Visa de inversión o emprendedor. Requiere plan de negocios y capital mínimo demostrable.';
      case MigrantProfileType.familyJoin:
        return 'Visa de reagrupación familiar. Tu familiar en $destino debe ser ciudadano o residente permanente.';
      default:
        return 'Revisá las opciones de visa disponibles para tu perfil en el portal oficial de inmigración de $destino.';
    }
  }

  static String _tituloTexto(MigrantProfileType tipo, String destino) {
    if (tipo == MigrantProfileType.professional) {
      return 'Investigá si tu profesión está regulada en $destino y qué organismo reconoce títulos extranjeros.';
    }
    if (tipo == MigrantProfileType.student) {
      return 'Si querés homologar tu título anterior, iniciá el proceso en paralelo con la inscripción universitaria.';
    }
    return 'Verificá si tu formación es reconocida directamente o si necesita convalidación.';
  }

  static String _documentosTexto(MigrantProfileType tipo) {
    final base = 'Pasaporte vigente, partida de nacimiento, antecedentes penales, fotos carnet.';
    switch (tipo) {
      case MigrantProfileType.professional:
        return '$base Además: título universitario, CV actualizado, carta de oferta laboral (si aplicás con trabajo).';
      case MigrantProfileType.student:
        return '$base Además: carta de aceptación de la institución, historial académico, prueba de fondos suficientes.';
      case MigrantProfileType.nomad:
        return '$base Además: prueba de ingresos (3–6 últimos estados de cuenta), contrato o facturas de clientes.';
      case MigrantProfileType.familyJoin:
        return '$base Además: partida de matrimonio/unión o documentación del familiar que te patrocina.';
      default:
        return base;
    }
  }

  static String _registroMigratoriTexto(String destino) {
    switch (destino) {
      case 'ES':
        return 'Registrate en el Padrón Municipal del ayuntamiento de tu ciudad. Necesitás domicilio y pasaporte.';
      case 'PT':
        return 'Registrate en el SEF (Serviço de Estrangeiros e Fronteiras) dentro de los primeros 90 días.';
      case 'DE':
        return 'Anmeldung (empadronamiento) en la Einwohnermeldeamt local. Es obligatorio dentro de los primeros 14 días.';
      case 'CA':
        return 'Si llegaste con visa de trabajo o estudio, ya estás registrado. Obtené tu SIN (Social Insurance Number) en Service Canada.';
      default:
        return 'Registrate ante las autoridades migratorias locales dentro de los primeros 30 días de llegada.';
    }
  }

  static String _cuentaBancariaTexto(String destino) {
    switch (destino) {
      case 'ES':
        return 'Con pasaporte + NIE podés abrir cuenta en BBVA, Santander o N26. Sin NIE: Wise o Revolut como puente.';
      case 'PT':
        return 'Con pasaporte y NIF (que tramitás en Finanças) podés abrir en Millennium BCP o Montepio.';
      case 'DE':
        return 'Deutsche Bank y N26 aceptan pasaporte + Anmeldung (comprobante de domicilio).';
      case 'CA':
        return 'Con pasaporte y SIN podés abrir en TD, RBC o Scotiabank. El primer día lo podés hacer online.';
      default:
        return 'Primero usá Wise como cuenta puente. Luego abrí cuenta bancaria local con tu documentación de residencia.';
    }
  }

  static String _idFiscalTexto(String destino) {
    switch (destino) {
      case 'ES':
        return 'NIE (Número de Identidad de Extranjero) — solicitalo en la Oficina de Extranjería o comisaría de policía.';
      case 'PT':
        return 'NIF (Número de Identificação Fiscal) — sacalo en cualquier oficina de Finanças con el pasaporte.';
      case 'DE':
        return 'Steueridentifikationsnummer — te llega por correo automáticamente después del Anmeldung.';
      case 'CA':
        return 'SIN (Social Insurance Number) — tramitalo en Service Canada. Lo necesitás para trabajar y pagar impuestos.';
      default:
        return 'Tramitá el número de identificación fiscal local. Es necesario para trabajar, alquilar y abrir cuentas.';
    }
  }

  // ── Costos estimados ───────────────────────────────────────────────────────

  static String _costVisa(MigrantProfileType tipo, String destino) {
    final costos = {
      'CA': {'professional': 'CAD 155–1.050', 'student': 'CAD 150', 'nomad': 'N/A'},
      'ES': {'professional': 'EUR 70–200',    'student': 'EUR 80',  'nomad': 'EUR 70'},
      'PT': {'professional': 'EUR 90–200',    'student': 'EUR 90',  'nomad': 'EUR 75'},
      'DE': {'professional': 'EUR 75–200',    'student': 'EUR 75',  'nomad': 'N/A'},
    };
    return costos[destino]?[tipo.name] ?? 'USD 80–300';
  }

  static double _visaCost(MigrantProfileType tipo, String destino) {
    if (destino == 'CA') return 300;
    if (destino == 'ES') return 120;
    if (destino == 'PT') return 100;
    if (destino == 'DE') return 110;
    if (destino == 'AU') return 350;
    return 150;
  }

  static double _documentosCost(UrgencyLevel urgencia) {
    // Urgente = apostillas exprés = más caro
    switch (urgencia) {
      case UrgencyLevel.urgent:   return 400;
      case UrgencyLevel.moderate: return 250;
      case UrgencyLevel.relaxed:  return 150;
    }
  }

  static double _vueloCost(String destino) {
    // Promedio desde Latinoamérica
    switch (destino) {
      case 'CA': return 900;
      case 'ES': return 650;
      case 'PT': return 700;
      case 'DE': return 800;
      case 'AU': return 1200;
      case 'GB': return 750;
      default:   return 700;
    }
  }

  static double _alquilerMes(String destino) {
    switch (destino) {
      case 'CA': return 1400;
      case 'ES': return 900;
      case 'PT': return 750;
      case 'DE': return 1000;
      case 'AU': return 1300;
      case 'GB': return 1500;
      default:   return 900;
    }
  }

  static String _costVuelo(String origen, String destino) {
    final costo = _vueloCost(destino);
    return 'Aprox. USD ${costo.toInt()} (promedio desde Latinoamérica)';
  }
}

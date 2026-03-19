import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../../../services/social_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmpleoScreen — listado de ofertas laborales del Community Hub
//
// Ubicación: lib/features/community/empleo/empleo_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

// Datos de ejemplo — reemplazar con JobService cuando esté implementado.
final _mockJobs = [
  _JobData(
    id:             'j1',
    title:          'Desarrollador Full Stack',
    company:        'Nexo Fintech',
    location:       'Madrid, España',
    type:           'Remoto',
    salary:         '€3.500–€4.800/mes',
    sector:         'IT',
    tags:           ['React', 'Node.js'],
    acceptsMigrants: true,
    visaSponsored:  false,
    emoji:          '🏢',
    postedAgo:      'Hace 2 días',
    description:    'Buscamos un Full Stack con experiencia en React y Node.js para trabajar en nuestra plataforma de pagos para el mercado latinoamericano en España.',
    requirements:   ['Mínimo 2 años con React y Node.js', 'Experiencia con PostgreSQL', 'Inglés técnico B2+'],
    benefits:       ['100% remoto', 'Equipo multicultural', 'Acepta trabajadores migrantes'],
  ),
  _JobData(
    id:             'j2',
    title:          'Enfermera/o Clínico',
    company:        'Hospital Sant Pau',
    location:       'Barcelona, España',
    type:           'Presencial',
    salary:         '€2.200–€2.800/mes',
    sector:         'Salud',
    tags:           ['Medicina', 'Turno rotativo'],
    acceptsMigrants: true,
    visaSponsored:  true,
    emoji:          '🏥',
    postedAgo:      'Hace 5 días',
    description:    'El Hospital Sant Pau busca enfermeras/os para su servicio de medicina interna. Se acepta título en proceso de homologación.',
    requirements:   ['Título de Enfermería (homologado o en proceso)', 'Español fluido', 'Disponibilidad turno rotativo'],
    benefits:       ['Visa patrocinada', 'Ayuda con homologación', 'Formación continua'],
  ),
  _JobData(
    id:             'j3',
    title:          'Diseñador UX/UI',
    company:        'Pixel Agency',
    location:       'Lisboa, Portugal',
    type:           'Híbrido',
    salary:         '€2.000–€2.600/mes',
    sector:         'Diseño',
    tags:           ['Figma', 'Producto'],
    acceptsMigrants: true,
    visaSponsored:  false,
    emoji:          '🎨',
    postedAgo:      'Hace 1 semana',
    description:    'Agencia digital portuguesa busca diseñador UX/UI para proyectos de e-commerce y apps móviles.',
    requirements:   ['Dominio de Figma', 'Portfolio con proyectos reales', 'Portugués o inglés B1+'],
    benefits:       ['Modelo híbrido 3d/semana', 'Ambiente joven', 'Presupuesto para cursos'],
  ),
  _JobData(
    id:             'j4',
    title:          'Analista de Datos',
    company:        'Consulting Group',
    location:       'Berlín, Alemania',
    type:           'Remoto',
    salary:         '€4.000–€5.500/mes',
    sector:         'IT',
    tags:           ['Python', 'SQL'],
    acceptsMigrants: true,
    visaSponsored:  false,
    emoji:          '📊',
    postedAgo:      'Hace 3 días',
    description:    'Posición remota para analista de datos con foco en reportes de negocio y dashboards para clientes europeos.',
    requirements:   ['Python + SQL avanzado', 'Experiencia con Power BI o Tableau', 'Alemán básico (deseable)'],
    benefits:       ['100% remoto', 'Flexibilidad horaria', 'Bono anual'],
  ),
];

class EmpleoScreen extends StatefulWidget {
  const EmpleoScreen({super.key});

  @override
  State<EmpleoScreen> createState() => _EmpleoScreenState();
}

class _EmpleoScreenState extends State<EmpleoScreen> {
  String _activeFilter = 'Todos';
  final _filters = ['Todos', 'Remoto', 'Presencial', 'IT', 'Salud'];

  List<_JobData> get _filtered => _activeFilter == 'Todos'
      ? _mockJobs
      : _mockJobs.where((j) =>
          j.type   == _activeFilter ||
          j.sector == _activeFilter,
        ).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: CustomScrollView(
        slivers: [

          // ── App bar ─────────────────────────────────────────────────────
          SliverAppBar(
            floating:        true,
            snap:            true,
            elevation:       0,
            backgroundColor: NomadColors.feedHeaderBg,
            leading: IconButton(
              icon:  const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: NomadColors.feedIconColor,
              onPressed: () => Navigator.of(context).pop(),
            ),
            centerTitle: true,
            title: const Text(
              'Nomad',
              style: TextStyle(
                fontFamily:  'Georgia',
                fontSize:    22,
                fontWeight:  FontWeight.w700,
                color:       NomadColors.primary,
                letterSpacing: -0.3,
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Empleo',
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w600,
                      color:      NomadColors.primary,
                      letterSpacing: .12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tu próximo trabajo',
                    style: TextStyle(
                      fontFamily:  'Georgia',
                      fontSize:    26,
                      fontWeight:  FontWeight.w700,
                      color:       NomadColors.feedIconColor,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Buscador
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical:   11,
                    ),
                    decoration: BoxDecoration(
                      color:        Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: Colors.grey.shade400,
                          size:  18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cargo, empresa o ciudad…',
                          style: TextStyle(
                            fontSize: 14,
                            color:    Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // ── Filtros ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount:     _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f      = _filters[i];
                  final active = f == _activeFilter;
                  return GestureDetector(
                    onTap: () => setState(() => _activeFilter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical:    6,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? NomadColors.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: active
                              ? NomadColors.primary
                              : Colors.black.withValues(alpha: 0.1),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w500,
                          color: active ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Botón publicar ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width:  double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon:  const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Publicar una oferta laboral'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NomadColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'OFERTAS RECIENTES',
                style: TextStyle(
                  fontSize:      11,
                  fontWeight:    FontWeight.w600,
                  color:         Colors.grey.shade500,
                  letterSpacing: .08,
                ),
              ),
            ),
          ),

          // ── Lista de ofertas ─────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _JobCard(
                    job: _filtered[i],
                    onTap: () => _showJobDetail(context, _filtered[i]),
                  ),
                ),
                childCount: _filtered.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showJobDetail(BuildContext context, _JobData job) {
    showModalBottomSheet(
      context:       context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JobDetailSheet(job: job),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _JobCard
// ─────────────────────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final _JobData     job;
  final VoidCallback onTap;

  const _JobCard({required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Título + logo
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w600,
                          color:      NomadColors.feedIconColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${job.company} · ${job.location}',
                        style: TextStyle(
                          fontSize: 12,
                          color:    Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width:  42,
                  height: 42,
                  decoration: BoxDecoration(
                    color:        NomadColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      job.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tags
            Wrap(
              spacing:    6,
              runSpacing: 4,
              children: [
                _Tag(text: job.type,    style: _TagStyle.teal),
                for (final t in job.tags) _Tag(text: t, style: _TagStyle.gray),
                if (job.acceptsMigrants)
                  _Tag(text: '✓ Acepta migrantes', style: _TagStyle.green),
                if (job.visaSponsored)
                  _Tag(text: 'Visa patrocinada', style: _TagStyle.green),
              ],
            ),
            const SizedBox(height: 10),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  job.salary,
                  style: const TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      NomadColors.primaryDark,
                  ),
                ),
                Text(
                  job.postedAgo,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _JobDetailSheet — bottom sheet con el detalle completo de la oferta
// ─────────────────────────────────────────────────────────────────────────────

class _JobDetailSheet extends StatefulWidget {
  final _JobData job;
  const _JobDetailSheet({required this.job});

  @override
  State<_JobDetailSheet> createState() => _JobDetailSheetState();
}

class _JobDetailSheetState extends State<_JobDetailSheet> {
  bool _saved    = false;
  bool _applied  = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize:     0.95,
      minChildSize:     0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [

            // Handle
            Center(
              child: Container(
                margin:       const EdgeInsets.only(top: 10, bottom: 8),
                width:        36,
                height:       4,
                decoration:   BoxDecoration(
                  color:        Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),

            // Contenido scrollable
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                children: [

                  // Logo + título
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width:  58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: NomadColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            job.emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.title,
                              style: const TextStyle(
                                fontFamily:  'Georgia',
                                fontSize:    20,
                                fontWeight:  FontWeight.w700,
                                color:       NomadColors.feedIconColor,
                                height:      1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${job.company} · ${job.location}',
                              style: TextStyle(
                                fontSize: 13,
                                color:    Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Badges
                  Wrap(
                    spacing:    6,
                    runSpacing: 6,
                    children: [
                      _Tag(text: job.type, style: _TagStyle.teal),
                      _Tag(text: job.sector, style: _TagStyle.gray),
                      if (job.acceptsMigrants)
                        _Tag(text: '✓ Acepta migrantes', style: _TagStyle.green),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Meta grid
                  Row(
                    children: [
                      _MetaChip(label: 'Salario',   value: job.salary,    color: NomadColors.primaryDark),
                      const SizedBox(width: 8),
                      _MetaChip(label: 'Publicado', value: job.postedAgo, color: NomadColors.feedIconColor),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Descripción
                  const Text(
                    'Sobre el puesto',
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color:      NomadColors.feedIconColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    job.description,
                    style: TextStyle(
                      fontSize:   13,
                      color:      Colors.grey.shade600,
                      height:     1.7,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Requisitos
                  const Text(
                    'Requisitos',
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color:      NomadColors.feedIconColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...job.requirements.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: NomadColors.primary, fontSize: 13)),
                        Expanded(
                          child: Text(
                            r,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),

                  // Beneficios
                  const Text(
                    'Beneficios para migrantes',
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color:      NomadColors.feedIconColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...job.benefits.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✓ ', style: TextStyle(color: NomadColors.primary, fontSize: 13)),
                        Expanded(
                          child: Text(
                            b,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),

            // ── Barra de acción fija ───────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade100,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applied ? null : () => setState(() => _applied = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _applied
                            ? NomadColors.success
                            : NomadColors.primary,
                        foregroundColor:  Colors.white,
                        disabledBackgroundColor: NomadColors.success,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _applied ? '✓ Postulación enviada' : 'Postularme ahora',
                        style: const TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Guardar
                  GestureDetector(
                    onTap: () => setState(() => _saved = !_saved),
                    child: Container(
                      width:  46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _saved
                              ? NomadColors.primary
                              : Colors.grey.shade200,
                          width: _saved ? 1.5 : 1,
                        ),
                      ),
                      child: Icon(
                        _saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: _saved
                            ? NomadColors.primary
                            : Colors.grey.shade400,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets helpers compartidos en este archivo
// ─────────────────────────────────────────────────────────────────────────────

enum _TagStyle { teal, gray, green, amber }

class _Tag extends StatelessWidget {
  final String    text;
  final _TagStyle style;

  const _Tag({required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;

    switch (style) {
      case _TagStyle.teal:
        bg = NomadColors.primary.withValues(alpha: 0.1);
        fg = NomadColors.primaryDark;
      case _TagStyle.gray:
        bg = Colors.grey.withValues(alpha: 0.1);
        fg = Colors.grey.shade600;
      case _TagStyle.green:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
      case _TagStyle.amber:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.w600,
          color:      fg,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;

  const _MetaChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:        NomadColors.feedBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize:      9,
                letterSpacing: .06,
                color:         Colors.grey.shade400,
                fontWeight:    FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de datos local — reemplazar con el model real cuando esté listo
// ─────────────────────────────────────────────────────────────────────────────

class _JobData {
  final String       id;
  final String       title;
  final String       company;
  final String       location;
  final String       type;
  final String       salary;
  final String       sector;
  final List<String> tags;
  final bool         acceptsMigrants;
  final bool         visaSponsored;
  final String       emoji;
  final String       postedAgo;
  final String       description;
  final List<String> requirements;
  final List<String> benefits;

  const _JobData({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.type,
    required this.salary,
    required this.sector,
    required this.tags,
    required this.acceptsMigrants,
    required this.visaSponsored,
    required this.emoji,
    required this.postedAgo,
    required this.description,
    required this.requirements,
    required this.benefits,
  });
}
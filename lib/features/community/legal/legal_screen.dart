import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app_theme.dart';
import '../../../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LegalScreen — listado de temas + ficha detalle + chat IA
//
// Ubicación: lib/features/community/legal/legal_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

// ── Datos de los temas legales ────────────────────────────────────────────────

final _topics = [
  _TopicData(
    key:        'visa',
    icon:       '🛂',
    title:      'Tipos de visa',
    subtitle:   'Trabajo, residencia, nómada digital',
    color:      Color(0xFFCCFBF1),
    steps: [
      _Step(num: 1, title: 'Identificá tu situación',
        body: '¿Vas con oferta de trabajo? ¿Tenés ingresos propios? ¿Vas a estudiar? El tipo de visa depende de tu objetivo.',
        docs: []),
      _Step(num: 2, title: 'Opciones por país destino',
        body: 'España: Trabajo, Nómada Digital.\nPortugal: D7 (renta pasiva), D2 (emprendedor).\nAlemania: Chancenkarte, Blue Card.\nCanadá: Express Entry, Work Permit.',
        docs: []),
      _Step(num: 3, title: 'Documentos base',
        body: 'Independientemente del destino necesitás:',
        docs: ['Pasaporte vigente (+6 meses)', 'Antecedentes penales', 'Seguro médico', 'Solvencia económica']),
      _Step(num: 4, title: 'Tramitá en el consulado',
        body: 'La mayoría de las visas se inician en el consulado del país destino. Pedí turno con anticipación.',
        docs: []),
    ],
    tip: '💡 Uruguay firmó el Convenio de La Haya. Apostillando en el Ministerio de RREE, tus documentos son válidos en más de 120 países.',
    sources: ['extranjeros.interior.gob.es', 'imigrante.sef.pt', 'ircc.canada.ca'],
  ),
  _TopicData(
    key:        'residencia',
    icon:       '🏠',
    title:      'Residencia',
    subtitle:   'Empadronamiento y trámites',
    color:      Color(0xFFDBEAFE),
    steps: [
      _Step(num: 1, title: 'Visa de entrada válida',
        body: 'Necesitás haber ingresado con la visa correcta. La mayoría de los países no permite cambiar de categoría una vez dentro con visa de turista.',
        docs: []),
      _Step(num: 2, title: 'Empadronamiento',
        body: 'Al llegar, registrate en el municipio. El padrón municipal da acceso a servicios públicos, salud y educación.',
        docs: ['Contrato de alquiler', 'Pasaporte', 'Formulario municipal']),
      _Step(num: 3, title: 'Tarjeta de residencia',
        body: 'Con el padrón, solicitás la tarjeta (TIE en España, AR en Portugal) en la oficina de extranjería local.',
        docs: []),
      _Step(num: 4, title: 'Hacia residencia permanente',
        body: 'A los 5 años de residencia legal continua. Para iberoamericanos en España, ciudadanía a los 2 años.',
        docs: []),
    ],
    tip: '⚠️ Guardá todos los sellos de entrada y documentos. La continuidad de residencia debe poder demostrarse.',
    sources: ['sede.sepe.es', 'sef.pt'],
  ),
  _TopicData(
    key:        'trabajo',
    icon:       '💼',
    title:      'Derechos laborales',
    subtitle:   'Contrato, IRPF, seguro social',
    color:      Color(0xFFD1FAE5),
    steps: [
      _Step(num: 1, title: 'Contrato obligatorio',
        body: 'Nunca trabajes sin contrato. Te deja sin derechos ante despidos, accidentes o impagos.',
        docs: []),
      _Step(num: 2, title: 'Número fiscal',
        body: 'Necesitás NIE/NIF para trabajar formalmente. Sin él no pueden darte de alta en seguridad social.',
        docs: ['Pasaporte', 'Formulario de solicitud', 'Domicilio comprobado']),
      _Step(num: 3, title: 'Alta en seguridad social',
        body: 'El empleador debe darte de alta desde el primer día. Esto da acceso a salud, bajas y desempleo.',
        docs: []),
      _Step(num: 4, title: 'Ante un problema',
        body: 'Acudí a la Inspección de Trabajo (gratuita). Para impagos, reclamá en el juzgado laboral.',
        docs: []),
    ],
    tip: '💡 El salario mínimo aplica igual a migrantes que a locales. Es ilegal pagarte menos por ser extranjero.',
    sources: ['mitramiss.gob.es', 'act.gov.pt'],
  ),
  _TopicData(
    key:        'documentos',
    icon:       '📄',
    title:      'Documentos y apostille',
    subtitle:   'Legalización y traducción',
    color:      Color(0xFFFEF3C7),
    steps: [
      _Step(num: 1, title: '¿Qué es el apostille?',
        body: 'Sello que certifica que un documento público es auténtico. Uruguay firmó el Convenio de La Haya.',
        docs: []),
      _Step(num: 2, title: 'Dónde apostillar en Uruguay',
        body: 'Ministerio de Relaciones Exteriores (Torre Ejecutiva, Montevideo). Costo: \$500–1.500 UYU. Tiempo: 2–5 días hábiles.',
        docs: ['Documento original', 'Formulario de solicitud', 'Comprobante de pago']),
      _Step(num: 3, title: 'Traducción certificada',
        body: 'Traducción por Traductor Público habilitado, tramitada en la Suprema Corte de Justicia.',
        docs: []),
      _Step(num: 4, title: 'Documentos más solicitados',
        body: 'Los más pedidos son:',
        docs: ['Partida de nacimiento', 'Antecedentes penales', 'Título universitario', 'Cert. de matrimonio/soltería']),
    ],
    tip: '📌 Pedí más copias de las que pensás necesitar. Sacar duplicados desde el exterior es costoso y lento.',
    sources: ['mrree.gub.uy', 'apostille.hcch.net'],
  ),
  _TopicData(
    key:        'salud',
    icon:       '🏥',
    title:      'Salud y seguro médico',
    subtitle:   'Acceso al sistema público y privado',
    color:      Color(0xFFFCE7F3),
    steps: [
      _Step(num: 1, title: 'Seguro para la visa',
        body: 'La mayoría de las visas exigen seguro médico privado vigente con cobertura mínima de €30.000 en Europa.',
        docs: []),
      _Step(num: 2, title: 'Sistema público',
        body: 'Con residencia legal y trabajo formal accedés automáticamente. España (SNS) y Portugal (SNS) son universales.',
        docs: []),
      _Step(num: 3, title: 'Médico de cabecera',
        body: 'Al estar dado de alta en seguridad social, pedí asignación en el centro de salud más cercano.',
        docs: ['Tarjeta de residencia', 'Tarjeta sanitaria']),
      _Step(num: 4, title: 'Emergencias',
        body: 'Europa: 112. Canadá/EEUU: 911. No pueden negarte atención de emergencia.',
        docs: []),
    ],
    tip: '💡 Guardá recetas y facturas médicas. Con seguro privado podés reclamar reintegro de gastos.',
    sources: ['sanidad.gob.es', 'sns24.gov.pt'],
  ),
  _TopicData(
    key:        'familia',
    icon:       '👨‍👩‍👧',
    title:      'Reagrupación familiar',
    subtitle:   'Traer a tu familia al exterior',
    color:      Color(0xFFEDE9FE),
    steps: [
      _Step(num: 1, title: 'Requisitos previos',
        body: 'Residencia legal mínima de 1 año, vivienda adecuada y medios económicos suficientes.',
        docs: []),
      _Step(num: 2, title: 'Quiénes pueden venir',
        body: 'Cónyuge o pareja de hecho, hijos menores de 18 años, y en algunos casos padres a cargo.',
        docs: []),
      _Step(num: 3, title: 'Documentación',
        body: 'Los documentos principales son:',
        docs: ['Pasaportes de todos', 'Partidas de nacimiento apostilladas', 'Cert. de matrimonio', 'Docs de tu residencia']),
      _Step(num: 4, title: 'Tiempo estimado',
        body: 'Entre 3 y 12 meses según el país. España: 4–8 meses actualmente.',
        docs: []),
    ],
    tip: '💡 Si tenés hijos menores, priorizá incluirlos en el primer reagrupamiento — se complica cuando superan los 18.',
    sources: ['extranjeros.interior.gob.es', 'sef.pt'],
  ),
  _TopicData(
    key:        'ciudadania',
    icon:       '🌍',
    title:      'Ciudadanía',
    subtitle:   'Plazos y naturalización',
    color:      Color(0xFFFEE2E2),
    steps: [
      _Step(num: 1, title: 'Residencia previa',
        body: 'España: 2 años (iberoamericanos). Portugal: 5 años. Alemania: 5–8 años. Canadá: 3 de los últimos 5.',
        docs: []),
      _Step(num: 2, title: 'Idioma y cultura',
        body: 'Casi todos exigen nivel A2-B1 del idioma local y nociones de historia.',
        docs: []),
      _Step(num: 3, title: 'Antecedentes limpios',
        body: 'Sin condenas penales en Uruguay ni en el país de residencia.',
        docs: ['Antecedentes UY (apostillado)', 'Antecedentes país de residencia']),
      _Step(num: 4, title: 'Doble nacionalidad',
        body: 'Uruguay tiene convenio con España y Portugal — no necesitás renunciar a la ciudadanía uruguaya.',
        docs: []),
    ],
    tip: '🇺🇾 Uruguay tiene convenio de doble nacionalidad con varios países iberoamericanos. Verificá antes de iniciar.',
    sources: ['mjusticia.gob.es', 'sef.pt'],
  ),
];

// ── LegalScreen ───────────────────────────────────────────────────────────────

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: CustomScrollView(
        slivers: [

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
            actions: [
              IconButton(
                icon:  const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                color: NomadColors.feedIconColor,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LegalChatScreen()),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Asesoría Legal',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: NomadColors.primary, letterSpacing: .12)),
                  const SizedBox(height: 4),
                  const Text('Trámites sin sorpresas',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 26,
                      fontWeight: FontWeight.w700, color: NomadColors.feedIconColor,
                      letterSpacing: -0.4)),
                  const SizedBox(height: 14),

                  // Banner chat IA
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LegalChatScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [NomadColors.primary, NomadColors.primaryDark],
                          begin: Alignment.topLeft,
                          end:   Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width:  40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:        Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.white,
                              size:  20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Consultá con la IA legal',
                                  style: TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                                SizedBox(height: 2),
                                Text('Respuestas al instante sobre tu situación',
                                  style: TextStyle(fontSize: 12,
                                    color: Colors.white70)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                            color: Colors.white60, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lista de temas
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.07),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: _topics.asMap().entries.map((entry) {
                    final i     = entry.key;
                    final topic = entry.value;
                    return Column(
                      children: [
                        _TopicRow(
                          topic: topic,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LegalTopicScreen(topic: topic),
                            ),
                          ),
                        ),
                        if (i < _topics.length - 1)
                          Divider(height: 1, color: Colors.grey.shade100),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final _TopicData   topic;
  final VoidCallback onTap;

  const _TopicRow({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        topic.color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(topic.icon, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                      color: NomadColors.feedIconColor)),
                  const SizedBox(height: 2),
                  Text(topic.subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
              color: Colors.grey.shade300, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── LegalTopicScreen — ficha detalle de un tema ───────────────────────────────

class LegalTopicScreen extends StatelessWidget {
  final _TopicData topic;
  const LegalTopicScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: CustomScrollView(
        slivers: [
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
            title: const Text('Nomad',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 22,
                fontWeight: FontWeight.w700, color: NomadColors.primary,
                letterSpacing: -0.3)),
            actions: [
              IconButton(
                icon:  const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                color: NomadColors.feedIconColor,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LegalChatScreen()),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.icon, style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text(topic.title,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 22,
                      fontWeight: FontWeight.w700, color: NomadColors.feedIconColor)),
                  const SizedBox(height: 4),
                  Text(topic.subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
                  const SizedBox(height: 16),
                  Text('PASO A PASO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400, letterSpacing: .08)),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Pasos
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _StepCard(step: topic.steps[i]),
                childCount: topic.steps.length,
              ),
            ),
          ),

          // Tip
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: Text(
                  topic.tip,
                  style: const TextStyle(fontSize: 12,
                    color: NomadColors.feedIconColor, height: 1.6),
                ),
              ),
            ),
          ),

          // Fuentes
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text('FUENTES OFICIALES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400, letterSpacing: .08)),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
            sliver: SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.07),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: topic.sources.asMap().entries.map((e) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new_rounded,
                              size: 14, color: NomadColors.primary),
                            const SizedBox(width: 8),
                            Text(e.value,
                              style: const TextStyle(fontSize: 12,
                                color: NomadColors.primaryDark)),
                          ],
                        ),
                      ),
                      if (e.key < topic.sources.length - 1)
                        Divider(height: 1, color: Colors.grey.shade100),
                    ],
                  )).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final _Step step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width:  28,
                  height: 28,
                  decoration: BoxDecoration(
                    color:        NomadColors.primary.withValues(alpha: 0.1),
                    shape:        BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${step.num}',
                      style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w600, color: NomadColors.primaryDark)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(step.title,
                    style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w500, color: NomadColors.feedIconColor)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.body,
                  style: TextStyle(fontSize: 13,
                    color: Colors.grey.shade600, height: 1.6)),
                if (step.docs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: step.docs.map((d) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color:        NomadColors.feedBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_outlined,
                            size: 12, color: NomadColors.primary),
                          const SizedBox(width: 5),
                          Text(d,
                            style: const TextStyle(fontSize: 11,
                              color: NomadColors.feedIconColor)),
                        ],
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── LegalChatScreen — chat con IA legal ───────────────────────────────────────

class LegalChatScreen extends StatefulWidget {
  const LegalChatScreen({super.key});

  @override
  State<LegalChatScreen> createState() => _LegalChatScreenState();
}

class _LegalChatScreenState extends State<LegalChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<_ChatMsg> _messages = [];
  bool _isSending = false;

  final _quickQs = [
    '¿Qué visa necesito para España?',
    '¿Cómo apostillo en Uruguay?',
    '¿Cuánto tarda la residencia en Portugal?',
    '¿Qué derechos laborales tengo?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMsg(
      text:  '¡Hola! Soy el asistente legal de Nomad. Podés preguntarme sobre visas, residencia, derechos laborales y cualquier trámite migratorio. ¿En qué te ayudo?',
      isMe:  false,
    ));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _isSending) return;

    _inputCtrl.clear();
    setState(() {
      _messages.add(_ChatMsg(text: q, isMe: true));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      // Llamada real a la API de Anthropic a través de AuthService pattern.
      // Por ahora usamos una respuesta simulada con delay realista.
      // En v2.0 reemplazar por la llamada real al ai-service.
      await Future.delayed(const Duration(milliseconds: 1200));

      final reply = _mockReply(q);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(text: reply, isMe: false));
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg(
            text: 'Hubo un error de conexión. Intentá de nuevo.',
            isMe: false,
          ));
          _isSending = false;
        });
      }
    }
  }

  String _mockReply(String q) {
    final lower = q.toLowerCase();
    if (lower.contains('visa') && lower.contains('españa')) {
      return 'Para vivir en España como uruguayo necesitás una visa de larga estancia. Las más comunes son:\n\n• Visa de trabajo por cuenta ajena (con oferta laboral)\n• Visa nómada digital (si trabajás remoto)\n• Visa D7 equivalente (renta pasiva)\n\n¿Tenés oferta de trabajo o trabajás de forma remota? Así te digo cuál te conviene más.';
    }
    if (lower.contains('apostille') || lower.contains('apostillar')) {
      return 'En Uruguay apostillás en el Ministerio de Relaciones Exteriores (Torre Ejecutiva, Montevideo).\n\n• Costo: \$500–1.500 UYU por documento\n• Tiempo: 2–5 días hábiles\n• También podés hacerlo por correo\n\n¿Qué documentos necesitás apostillar?';
    }
    if (lower.contains('portugal') || lower.contains('residencia')) {
      return 'La residencia en Portugal para latinoamericanos generalmente tarda:\n\n• Visa inicial: 2–3 meses en el consulado\n• Autorización de residencia (AIMA): 2–4 meses más\n\nEn total, contá con 4–7 meses desde que iniciás el trámite. ¿Qué tipo de visa estás evaluando?';
    }
    if (lower.contains('derecho') || lower.contains('laboral')) {
      return 'Como trabajador migrante tenés los mismos derechos que los locales:\n\n• Salario mínimo garantizado\n• Contrato escrito obligatorio\n• Alta en seguridad social desde el día 1\n• Derecho a baja por enfermedad y desempleo\n\nSi tenés un problema con tu empleador, podés ir a la Inspección de Trabajo (es gratuito). ¿Hay alguna situación específica que querés consultar?';
    }
    return 'Entiendo tu consulta. Te recomiendo verificar la información actualizada en las fuentes oficiales del país destino, ya que los requisitos pueden cambiar. ¿Podés darme más detalles sobre tu situación para darte una respuesta más precisa?';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      appBar: AppBar(
        backgroundColor:  NomadColors.feedHeaderBg,
        elevation:        0,
        leading: IconButton(
          icon:  const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: NomadColors.feedIconColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Column(
          children: [
            const Text('Nomad',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 18,
                fontWeight: FontWeight.w700, color: NomadColors.primary,
                letterSpacing: -0.3)),
            Text('ASISTENTE LEGAL',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                color: NomadColors.primary, letterSpacing: .06)),
          ],
        ),
      ),
      body: Column(
        children: [

          // Quick questions
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount:     _quickQs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _send(_quickQs[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: NomadColors.primary.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    _quickQs[i],
                    style: const TextStyle(fontSize: 12,
                      color: NomadColors.primaryDark),
                  ),
                ),
              ),
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller:  _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              itemCount:   _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length && _isSending) {
                  return _TypingBubble();
                }
                return _BubbleWidget(msg: _messages[i]);
              },
            ),
          ),

          // Input
          Container(
            padding: EdgeInsets.fromLTRB(
              16, 10, 16,
              10 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade100),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:      _inputCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted:     _send,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText:    'Escribí tu consulta legal…',
                      hintStyle:   TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      filled:      true,
                      fillColor:   NomadColors.feedBg,
                      border:      OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:   BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(_inputCtrl.text),
                  child: Container(
                    width:  38,
                    height: 38,
                    decoration: BoxDecoration(
                      color:        NomadColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size:  17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleWidget extends StatelessWidget {
  final _ChatMsg msg;
  const _BubbleWidget({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isMe ? NomadColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(msg.isMe ? 16 : 4),
            bottomRight: Radius.circular(msg.isMe ? 4 : 16),
          ),
          border: msg.isMe ? null : Border.all(
            color: Colors.black.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 13,
            height:   1.55,
            color:    msg.isMe ? Colors.white : NomadColors.feedIconColor,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(16),
            topRight:    Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft:  Radius.circular(4),
          ),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _Dot(delay: i * 200)),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width:  7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3 + _anim.value * 0.5),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelos locales
// ─────────────────────────────────────────────────────────────────────────────

class _TopicData {
  final String       key;
  final String       icon;
  final String       title;
  final String       subtitle;
  final Color        color;
  final List<_Step>  steps;
  final String       tip;
  final List<String> sources;

  const _TopicData({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.steps,
    required this.tip,
    required this.sources,
  });
}

class _Step {
  final int          num;
  final String       title;
  final String       body;
  final List<String> docs;

  const _Step({
    required this.num,
    required this.title,
    required this.body,
    required this.docs,
  });
}

class _ChatMsg {
  final String text;
  final bool   isMe;
  const _ChatMsg({required this.text, required this.isMe});
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app_theme.dart';
import '../../../services/migration_data_model.dart';
import '../../../services/iom_service.dart';
import '../../../services/user_service.dart';
import 'welcome_pack_screen.dart';
import 'ruta_quiz_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DestinationDashboardScreen — Fases 1 y 2 del User Journey del migrante
//
// Ubicación: lib/features/community/journey/destination_dashboard_screen.dart
//
// Flujo:
//   1. El usuario elige país destino + tipo de perfil (onboarding o desde perfil)
//   2. IomService.build() construye el DestinationDashboard consolidado
//   3. La pantalla muestra: política migratoria, costo de vida, calculadora,
//      alertas de seguridad, remesas, checklist dinámica y red de seguridad (AVRR)
//   4. El usuario navega a WelcomePackScreen cuando está listo para Fase 3
// ─────────────────────────────────────────────────────────────────────────────

class DestinationDashboardScreen extends StatefulWidget {
  /// Si se pasa un profile existente, se usa directamente.
  /// Si no, se muestra el selector de destino + perfil primero.
  final MigrationProfile? initialProfile;

  const DestinationDashboardScreen({super.key, this.initialProfile});

  @override
  State<DestinationDashboardScreen> createState() =>
      _DestinationDashboardScreenState();
}

class _DestinationDashboardScreenState
    extends State<DestinationDashboardScreen>
    with SingleTickerProviderStateMixin {

  // ── Estado ─────────────────────────────────────────────────────────────────
  MigrationProfile?    _profile;
  DestinationDashboard? _dashboard;
  bool   _isLoading     = false;
  bool   _showSelector  = true; // false cuando ya hay perfil
  String? _error;

  // Tab controller para las secciones del dashboard
  late TabController _tabCtrl;
  static const _tabs = ['Resumen', 'Costo', 'Checklist', 'Seguridad'];

  // Calculadora
  final _salaryCtrl = TextEditingController();
  double? _projectedSalary;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);

    if (widget.initialProfile != null) {
      _profile      = widget.initialProfile;
      _showSelector = false;
      _loadDashboard();
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  // ── Carga del dashboard ────────────────────────────────────────────────────

  Future<void> _loadDashboard() async {
    if (_profile == null) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final dashboard = await IomService.build(_profile!);
      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error     = 'No se pudieron cargar los datos. Verificá tu conexión.';
          _isLoading = false;
        });
      }
    }
  }

  // ── Selector de perfil ─────────────────────────────────────────────────────

  void _onProfileSelected(MigrationProfile profile) {
    setState(() {
      _profile      = profile;
      _showSelector = false;
    });
    _loadDashboard();

    // Guardar en Firestore para persistir el destino del usuario.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      UserService().updateMigrationStatus(
        destinationCountry:      profile.destinationCountry,
        destinationCountryCode:  profile.destinationCountry,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSelector) return _buildSelector();
    if (_isLoading)    return _buildLoading();
    if (_error != null) return _buildError();
    if (_dashboard == null) return _buildLoading();
    return _buildDashboard(_dashboard!);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PANTALLA 1 — SELECTOR DE DESTINO + PERFIL
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSelector() {
    return _ProfileSelectorScreen(onSelected: _onProfileSelected);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PANTALLA 2 — DASHBOARD CONSOLIDADO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboard(DestinationDashboard d) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [

          // ── App bar ────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            floating:       false,
            pinned:         true,
            elevation:      0,
            backgroundColor: NomadColors.feedHeaderBg,
            leading: IconButton(
              icon:  const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: NomadColors.feedIconColor,
              onPressed: () => setState(() => _showSelector = true),
            ),
            actions: [
              IconButton(
                icon:  const Icon(Icons.refresh_rounded, size: 20),
                color: NomadColors.feedIconColor,
                onPressed: () {
                  IomService.invalidateCache(d.profile);
                  _loadDashboard();
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _DashboardHero(dashboard: d),
            ),
          ),

          // ── Alerta urgente (si aplica) ────────────────────────────────────
          if (d.hasUrgentAlert)
            SliverToBoxAdapter(child: _UrgentAlertBanner(alert: d.safetyAlert!)),

          // ── Noticias recientes ────────────────────────────────────────────
          if (d.newsAlerts.isNotEmpty)
            SliverToBoxAdapter(child: _NewsTicker(alerts: d.newsAlerts)),

          // ── Tabs ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: NomadColors.feedHeaderBg,
              child: TabBar(
                controller: _tabCtrl,
                tabs:       _tabs.map((t) => Tab(text: t)).toList(),
                labelColor:        NomadColors.primary,
                unselectedLabelColor: Colors.grey.shade400,
                indicatorColor:    NomadColors.primary,
                indicatorWeight:   2,
                labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],

        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _TabResumen(dashboard: d),
            _TabCosto(dashboard: d, salaryCtrl: _salaryCtrl,
              onSalaryChanged: (v) => setState(() =>
                _projectedSalary = double.tryParse(v))),
            _TabChecklist(dashboard: d, onItemToggle: _onChecklistToggle),
            _TabSeguridad(dashboard: d),
          ],
        ),
      ),

      // ── FAB — avanzar a Fase 3 ─────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WelcomePackScreen(
              pack: IomService.buildWelcomePack(
                countryCode: d.profile.destinationCountry,
                city:        d.profile.targetCity ?? d.costOfLiving.city,
                profileType: d.profile.profileType,
              ),
              profile: d.profile,
            ),
          ),
        ),
        backgroundColor: NomadColors.primary,
        icon:  const Icon(Icons.flight_takeoff_rounded, color: Colors.white),
        label: const Text('Pack de bienvenida ✈️',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _onChecklistToggle(ChecklistItem item) {
    if (_dashboard == null) return;
    final updated = _dashboard!.checklist.map((i) =>
      i.id == item.id
          ? i.copyWith(isCompleted: !i.isCompleted,
                       completedAt: !i.isCompleted ? DateTime.now() : null)
          : i,
    ).toList();

    setState(() {
      _dashboard = DestinationDashboard(
        profile:       _dashboard!.profile,
        policy:        _dashboard!.policy,
        costOfLiving:  _dashboard!.costOfLiving,
        remittances:   _dashboard!.remittances,
        safetyAlert:   _dashboard!.safetyAlert,
        returnProgram: _dashboard!.returnProgram,
        checklist:     updated,
        newsAlerts:    _dashboard!.newsAlerts,
        generatedAt:   _dashboard!.generatedAt,
      );
    });

    // Persistir en Firestore (async, sin bloquear UI).
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // En v2.0: guardar estado de checklist en users/{uid}/checklists/
      // Por ahora solo actualizamos en memoria.
    }
  }

  // ── Estados de carga / error ───────────────────────────────────────────────

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      appBar: AppBar(
        backgroundColor: NomadColors.feedHeaderBg,
        leading: IconButton(
          icon:  const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: NomadColors.feedIconColor,
          onPressed: () => setState(() => _showSelector = true),
        ),
        elevation: 0,
        title: const Text('Nomad',
          style: TextStyle(fontFamily: 'Georgia', fontSize: 22,
            fontWeight: FontWeight.w700, color: NomadColors.primary)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: NomadColors.primary),
            const SizedBox(height: 20),
            Text(
              'Cargando datos de ${_profile?.destinationCountryName ?? "destino"}…',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text('OIM · Numbeo · World Bank',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😕', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadDashboard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NomadColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SELECTOR DE DESTINO + PERFIL
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileSelectorScreen extends StatefulWidget {
  final ValueChanged<MigrationProfile> onSelected;
  const _ProfileSelectorScreen({required this.onSelected});

  @override
  State<_ProfileSelectorScreen> createState() => _ProfileSelectorScreenState();
}

class _ProfileSelectorScreenState extends State<_ProfileSelectorScreen> {
  String?             _selectedDest;
  String?             _selectedDestName;
  MigrantProfileType? _selectedProfile;
  String?             _selectedCity;

  static const _destinations = [
    ('CA', 'Canadá',   '🇨🇦'),
    ('ES', 'España',   '🇪🇸'),
    ('PT', 'Portugal', '🇵🇹'),
    ('DE', 'Alemania', '🇩🇪'),
    ('MX', 'México',   '🇲🇽'),
    ('AU', 'Australia','🇦🇺'),
    ('GB', 'Reino Unido','🇬🇧'),
  ];

  static const _cities = {
    'CA': ['Toronto', 'Calgary', 'Vancouver', 'Montreal', 'Ottawa'],
    'ES': ['Madrid', 'Barcelona', 'Valencia', 'Sevilla', 'Bilbao'],
    'PT': ['Lisboa', 'Porto', 'Braga', 'Faro', 'Coimbra'],
    'DE': ['Berlín', 'Múnich', 'Hamburgo', 'Frankfurt', 'Colonia'],
    'MX': ['Ciudad de México', 'Guadalajara', 'Monterrey', 'Mérida'],
    'AU': ['Sídney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaide'],
    'GB': ['Londres', 'Manchester', 'Edimburgo', 'Birmingham'],
  };

  bool get _canContinue =>
      _selectedDest != null && _selectedProfile != null;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      appBar: AppBar(
        backgroundColor: NomadColors.feedHeaderBg,
        elevation:       0,
        leading: IconButton(
          icon:  const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: NomadColors.feedIconColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text('Nomad',
          style: TextStyle(fontFamily: 'Georgia', fontSize: 22,
            fontWeight: FontWeight.w700, color: NomadColors.primary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Header
            const Text('🗺️', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            const Text('¿A dónde querés\nmigrar?',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 28,
                fontWeight: FontWeight.w700, color: NomadColors.feedIconColor,
                height: 1.15, letterSpacing: -0.4)),
            const SizedBox(height: 6),
            Text('Elegí tu destino y te armamos un plan personalizado',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500,
                fontWeight: FontWeight.w300)),
            const SizedBox(height: 28),

            // ── País destino ─────────────────────────────────────────────────
            _SectionLabel(label: 'País destino'),
            const SizedBox(height: 10),
            Wrap(
              spacing:    10,
              runSpacing: 10,
              children: _destinations.map((d) {
                final selected = _selectedDest == d.$1;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedDest     = d.$1;
                    _selectedDestName = d.$2;
                    _selectedCity     = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? NomadColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? NomadColors.primary
                            : Colors.black.withValues(alpha: 0.1),
                        width: selected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(d.$3, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(d.$2,
                          style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : NomadColors.feedIconColor)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Ciudad destino (opcional) ─────────────────────────────────────
            if (_selectedDest != null &&
                (_cities[_selectedDest] ?? []).isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionLabel(label: 'Ciudad destino (opcional)'),
              const SizedBox(height: 10),
              Wrap(
                spacing:    8,
                runSpacing: 8,
                children: (_cities[_selectedDest] ?? []).map((city) {
                  final sel = _selectedCity == city;
                  return GestureDetector(
                    onTap: () => setState(() =>
                        _selectedCity = sel ? null : city),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? NomadColors.primary.withValues(alpha: 0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: sel
                              ? NomadColors.primary
                              : Colors.black.withValues(alpha: 0.1),
                          width: sel ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(city,
                        style: TextStyle(fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel
                              ? NomadColors.primaryDark
                              : Colors.grey.shade600)),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 28),

            // ── Tipo de perfil ─────────────────────────────────────────────────
            _SectionLabel(label: 'Tu perfil migratorio'),
            const SizedBox(height: 10),
            ...MigrantProfileType.values.map((p) {
              final sel = _selectedProfile == p;
              return GestureDetector(
                onTap: () => setState(() => _selectedProfile = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: sel
                        ? NomadColors.primary.withValues(alpha: 0.06)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel
                          ? NomadColors.primary
                          : Colors.black.withValues(alpha: 0.08),
                      width: sel ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(p.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(p.label,
                          style: TextStyle(fontSize: 14,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                            color: sel
                                ? NomadColors.primaryDark
                                : NomadColors.feedIconColor)),
                      ),
                      if (sel)
                        const Icon(Icons.check_circle_rounded,
                          color: NomadColors.primary, size: 18),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 32),

            // ── Botón continuar ───────────────────────────────────────────────
            SizedBox(
              width:  double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canContinue ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NomadColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      NomadColors.primary.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  _canContinue
                      ? 'Ver mi plan para ${_selectedDestName ?? "destino"}'
                      : 'Elegí destino y perfil para continuar',
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onContinue() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final profile = MigrationProfile(
      userId:                uid,
      originCountry:         'UY', // Se actualiza con el UserModel real
      originCountryName:     'Uruguay',
      destinationCountry:    _selectedDest!,
      destinationCountryName: _selectedDestName!,
      profileType:           _selectedProfile!,
      currentPhase:          MigrantPhase.discovery,
      targetCity:            _selectedCity,
      createdAt:             DateTime.now(),
      updatedAt:             DateTime.now(),
    );
    widget.onSelected(profile);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TABS DEL DASHBOARD
// ══════════════════════════════════════════════════════════════════════════════

// ── Tab 1: Resumen ─────────────────────────────────────────────────────────

class _TabResumen extends StatelessWidget {
  final DestinationDashboard dashboard;
  const _TabResumen({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [

        // Ruta Inteligente — CTA principal
        _RutaInteligenteCard(dashboard: d),
        const SizedBox(height: 20),

        // Política migratoria
        _SectionTitle(title: '🏛️  Política migratoria'),
        const SizedBox(height: 10),
        _PolicyCard(policy: d.policy),
        const SizedBox(height: 16),

        // Visas recomendadas
        _SectionTitle(title: '🛂  Visas recomendadas para tu perfil'),
        const SizedBox(height: 10),
        ...d.policy.recommendedVisas.map((v) => _VisaRow(visa: v)),
        const SizedBox(height: 16),

        // Remesas (si hay datos del corredor)
        if (d.remittances != null) ...[
          _SectionTitle(title: '💸  Enviar dinero a casa'),
          const SizedBox(height: 10),
          _RemittanceCard(corridor: d.remittances!),
          const SizedBox(height: 16),
        ],

        // Red de seguridad — AVRR
        if (d.returnProgram != null) ...[
          _SectionTitle(title: '🛡️  Red de seguridad'),
          const SizedBox(height: 10),
          _ReturnProgramCard(program: d.returnProgram!),
        ],
      ],
    );
  }
}

// ── Tab 2: Costo de vida ────────────────────────────────────────────────────

class _TabCosto extends StatelessWidget {
  final DestinationDashboard     dashboard;
  final TextEditingController    salaryCtrl;
  final ValueChanged<String>     onSalaryChanged;

  const _TabCosto({
    required this.dashboard,
    required this.salaryCtrl,
    required this.onSalaryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final col = dashboard.costOfLiving;
    final salary = double.tryParse(salaryCtrl.text);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [

        // Ciudad + actualización
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('📍 ${col.city}, ${col.countryName}',
              style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w600, color: NomadColors.feedIconColor)),
            Text('Actualizado: ${_formatDate(col.lastUpdated)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ],
        ),
        const SizedBox(height: 14),

        // Grid de costos
        _CostGrid(cost: col),
        const SizedBox(height: 20),

        // ── Calculadora ─────────────────────────────────────────────────────
        _SectionTitle(title: '🧮  Calculadora de viabilidad'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.07), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tu salario proyectado (USD/mes)',
                style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextField(
                controller:   salaryCtrl,
                onChanged:    onSalaryChanged,
                keyboardType: TextInputType.number,
                style:        const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText:   'Ej: 3500',
                  hintStyle:  TextStyle(color: Colors.grey.shade400),
                  prefixText: 'USD ',
                  filled:     true,
                  fillColor:  NomadColors.feedBg,
                  border:     OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:   BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                ),
              ),
              if (salary != null) ...[
                const SizedBox(height: 16),
                _SalaryResult(cost: col, salary: salary),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Comparativa de ciudades del mismo país
        _SectionTitle(title: '🏙️  ¿Toronto vs Calgary?'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NomadColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: NomadColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                color: NomadColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Usá el selector de ciudad en la pantalla anterior para comparar costos entre ciudades del mismo país.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600,
                    height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ── Tab 3: Checklist ────────────────────────────────────────────────────────

class _TabChecklist extends StatelessWidget {
  final DestinationDashboard        dashboard;
  final ValueChanged<ChecklistItem> onItemToggle;

  const _TabChecklist({required this.dashboard, required this.onItemToggle});

  @override
  Widget build(BuildContext context) {
    final checklist = dashboard.checklist;
    final total     = checklist.length;
    final done      = checklist.where((i) => i.isCompleted).length;
    final progress  = total > 0 ? done / total : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [

        // Progreso general
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.07), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tu progreso',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: NomadColors.feedIconColor)),
                  Text('$done / $total completados',
                    style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w500, color: NomadColors.primary)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value:            progress,
                  backgroundColor:  NomadColors.feedBg,
                  valueColor: const AlwaysStoppedAnimation(NomadColors.primary),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _progressMessage(progress),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Items agrupados por fase
        ...MigrantPhase.values.map((phase) {
          final items = checklist.where((i) => i.phase == phase).toList();
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PhaseHeader(phase: phase),
              const SizedBox(height: 8),
              ...items.map((item) => _ChecklistItemCard(
                item:     item,
                onToggle: () => onItemToggle(item),
              )),
              const SizedBox(height: 16),
            ],
          );
        }),
      ],
    );
  }

  String _progressMessage(double p) {
    if (p == 0)   return '¡Empezá por el paso 1!';
    if (p < 0.25) return 'Buen comienzo, seguí así 💪';
    if (p < 0.5)  return 'Ya vas por el camino correcto';
    if (p < 0.75) return '¡Más de la mitad! Casi llegás';
    if (p < 1)    return '¡Casi listo para partir! ✈️';
    return '¡Todo listo! Buen viaje 🎉';
  }
}

// ── Tab 4: Seguridad ─────────────────────────────────────────────────────────

class _TabSeguridad extends StatelessWidget {
  final DestinationDashboard dashboard;
  const _TabSeguridad({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final alert = dashboard.safetyAlert;
    final ret   = dashboard.returnProgram;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [

        if (alert == null) ...[
          // Sin alertas activas
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:        const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              children: [
                const Text('🟢', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                const Text('Ruta sin alertas activas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: Color(0xFF166534))),
                const SizedBox(height: 6),
                Text(
                  'No hay alertas de seguridad activas para la ruta '
                  '${dashboard.profile.originCountryName} → '
                  '${dashboard.profile.destinationCountryName}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600,
                    height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          _SafetyAlertCard(alert: alert),
          const SizedBox(height: 16),
        ],

        // Siempre mostrar recursos de emergencia
        _SectionTitle(title: '🚨  Números de emergencia'),
        const SizedBox(height: 10),
        _EmergencyNumbers(countryCode: dashboard.profile.destinationCountry),
        const SizedBox(height: 20),

        // OIM Missing Migrants — contexto
        _SectionTitle(title: 'ℹ️  Proyecto Missing Migrants (OIM)'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.07), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'La OIM monitorea incidentes en rutas migratorias a nivel global. Los datos de seguridad en Nomad provienen de este proyecto.',
                style: TextStyle(fontSize: 13, color: NomadColors.feedIconColor,
                  height: 1.6)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.open_in_new_rounded,
                    size: 13, color: NomadColors.primary),
                  const SizedBox(width: 6),
                  Text('missingmigrants.iom.int',
                    style: const TextStyle(fontSize: 12,
                      color: NomadColors.primaryDark)),
                ],
              ),
            ],
          ),
        ),

        // Red de seguridad AVRR
        if (ret != null) ...[
          const SizedBox(height: 20),
          _SectionTitle(title: '🏡  ¿Las cosas no salieron bien?'),
          const SizedBox(height: 10),
          _ReturnProgramCard(program: ret, expanded: true),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HERO DEL DASHBOARD
// ══════════════════════════════════════════════════════════════════════════════

class _DashboardHero extends StatelessWidget {
  final DestinationDashboard dashboard;
  const _DashboardHero({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NomadColors.primary,
            NomadColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 70, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(d.profile.profileType.emoji,
                style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(d.profile.profileType.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12,
                    color: Colors.white70, fontWeight: FontWeight.w400)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color:        Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99)),
                child: Text(
                  d.policy.openness.label,
                  style: const TextStyle(fontSize: 11,
                    color: Colors.white, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${d.profile.originCountryName} → ${d.profile.destinationCountryName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 20,
              fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
          ),
          if (d.profile.targetCity != null)
            Text(d.profile.targetCity!,
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            children: [
              _HeroStat(
                label: 'MIPEX',
                value: '${d.policy.mipexScore}/100',
              ),
              const SizedBox(width: 16),
              _HeroStat(
                label: 'Costo/mes',
                value: 'USD ${d.costOfLiving.monthlyTotalSuburb.toStringAsFixed(0)}',
              ),
              const SizedBox(width: 16),
              _HeroStat(
                label: 'Progreso',
                value: '${(d.progress * 100).toInt()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: const TextStyle(fontSize: 9, color: Colors.white60,
            letterSpacing: .06, fontWeight: FontWeight.w600)),
        Text(value,
          style: const TextStyle(fontSize: 14, color: Colors.white,
            fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COMPONENTES DE CONTENIDO
// ══════════════════════════════════════════════════════════════════════════════

class _PolicyCard extends StatelessWidget {
  final CountryPolicy policy;
  const _PolicyCard({required this.policy});

  @override
  Widget build(BuildContext context) {
    final color = _opennessColor(policy.openness);
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(policy.countryName,
                        style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: NomadColors.feedIconColor)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99)),
                      child: Text(policy.openness.label,
                        style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600, color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Barra MIPEX
                Row(
                  children: [
                    Text('MIPEX ${policy.mipexScore}/100',
                      style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w500, color: color)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value:           policy.mipexScore / 100,
                          backgroundColor: NomadColors.feedBg,
                          valueColor:      AlwaysStoppedAnimation(color),
                          minHeight:       6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(policy.summary,
                  style: TextStyle(fontSize: 13,
                    color: Colors.grey.shade600, height: 1.6)),
              ],
            ),
          ),
          if (policy.strongPoints.isNotEmpty) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Puntos fuertes',
                    style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600, color: NomadColors.feedIconColor)),
                  const SizedBox(height: 6),
                  ...policy.strongPoints.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✓ ', style: TextStyle(
                          color: NomadColors.primary, fontSize: 13)),
                        Expanded(child: Text(p,
                          style: TextStyle(fontSize: 13,
                            color: Colors.grey.shade600, height: 1.4))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _opennessColor(PolicyOpenness o) {
    switch (o) {
      case PolicyOpenness.veryOpen:        return const Color(0xFF10B981);
      case PolicyOpenness.open:            return NomadColors.primary;
      case PolicyOpenness.moderate:        return const Color(0xFFF59E0B);
      case PolicyOpenness.restrictive:     return const Color(0xFFEF4444);
      case PolicyOpenness.veryRestrictive: return const Color(0xFF991B1B);
    }
  }
}

class _VisaRow extends StatelessWidget {
  final String visa;
  const _VisaRow({required this.visa});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
            color: NomadColors.primary, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(visa,
            style: const TextStyle(fontSize: 13,
              color: NomadColors.feedIconColor))),
        ],
      ),
    );
  }
}

class _CostGrid extends StatelessWidget {
  final CostOfLivingSnapshot cost;
  const _CostGrid({required this.cost});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('🏠', 'Alquiler (zona)',   'USD ${cost.rentOneBedroomSuburb.toStringAsFixed(0)}/mes'),
      ('🏙️', 'Alquiler (centro)', 'USD ${cost.rentOneBedroomCenter.toStringAsFixed(0)}/mes'),
      ('🛒', 'Supermercado',      'USD ${cost.groceriesMonthly.toStringAsFixed(0)}/mes'),
      ('🚌', 'Transporte',        'USD ${cost.transportMonthly.toStringAsFixed(0)}/mes'),
      ('🍽️', 'Menú económico',   'USD ${cost.mealRestaurant.toStringAsFixed(0)}'),
      ('💻', 'Internet',          'USD ${cost.internetMonthly.toStringAsFixed(0)}/mes'),
      ('💰', 'Salario neto prom.','USD ${cost.avgSalaryNet.toStringAsFixed(0)}/mes'),
      ('📊', 'Costo total est.',  'USD ${cost.monthlyTotalSuburb.toStringAsFixed(0)}/mes'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics:    const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   2,
        mainAxisSpacing:  8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final isTotal = i == 7;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isTotal
                ? NomadColors.primary.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isTotal
                  ? NomadColors.primary.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.07),
              width: isTotal ? 1 : 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:  MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(item.$2,
                      style: TextStyle(fontSize: 10,
                        color: Colors.grey.shade500,
                        overflow: TextOverflow.ellipsis)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(item.$3,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: isTotal ? NomadColors.primaryDark : NomadColors.feedIconColor)),
            ],
          ),
        );
      },
    );
  }
}

class _SalaryResult extends StatelessWidget {
  final CostOfLivingSnapshot cost;
  final double               salary;

  const _SalaryResult({required this.cost, required this.salary});

  @override
  Widget build(BuildContext context) {
    final viable  = cost.isSalaryViable(salary);
    final balance = salary - cost.monthlyTotalSuburb;
    final rentRatio = (cost.rentToIncomeRatio(salary) * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: viable
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: viable
                  ? const Color(0xFFBBF7D0)
                  : const Color(0xFFFECACA)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(viable ? '✅' : '⚠️',
                    style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      viable
                          ? 'Tu salario es viable en ${cost.city}'
                          : 'Tu salario podría ser ajustado para ${cost.city}',
                      style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w600,
                        color: viable
                            ? const Color(0xFF166534)
                            : const Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ResultRow(
                label: 'Salario proyectado',
                value: 'USD ${salary.toStringAsFixed(0)}/mes',
                bold:  false,
              ),
              _ResultRow(
                label: 'Costo mensual estimado',
                value: 'USD ${cost.monthlyTotalSuburb.toStringAsFixed(0)}/mes',
                bold:  false,
              ),
              _ResultRow(
                label: 'Balance mensual',
                value: '${balance >= 0 ? "+" : ""}USD ${balance.toStringAsFixed(0)}',
                bold:  true,
                color: balance >= 0 ? const Color(0xFF166534) : const Color(0xFF991B1B),
              ),
              _ResultRow(
                label: 'Alquiler sobre ingreso',
                value: '$rentRatio% ${rentRatio > 30 ? "⚠️" : "✓"}',
                bold:  false,
              ),
            ],
          ),
        ),
        if (!viable) ...[
          const SizedBox(height: 8),
          Text(
            '💡 Considerá ciudades más económicas como ${_cheaperCity(cost.countryCode)}.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  String _cheaperCity(String code) {
    switch (code) {
      case 'CA': return 'Calgary o Halifax';
      case 'ES': return 'Valencia o Zaragoza';
      case 'PT': return 'Porto o Braga';
      case 'DE': return 'Leipzig o Hannover';
      default:   return 'ciudades medianas del interior';
    }
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   bold;
  final Color? color;

  const _ResultRow({
    required this.label,
    required this.value,
    required this.bold,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value,
            style: TextStyle(fontSize: 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
              color: color ?? NomadColors.feedIconColor)),
        ],
      ),
    );
  }
}

class _RemittanceCard extends StatelessWidget {
  final RemittanceCorridor corridor;
  const _RemittanceCard({required this.corridor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enviar USD 200 de ${corridor.originCountry} a ${corridor.destinationCountry}',
                  style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: NomadColors.feedIconColor)),
                const SizedBox(height: 10),
                Text(corridor.recommendation,
                  style: TextStyle(fontSize: 13,
                    color: Colors.grey.shade600, height: 1.5)),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          ...corridor.providers.map((p) => _ProviderRow(provider: p,
            isCheapest: p.name == corridor.cheapestProvider)),
        ],
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  final RemittanceProvider provider;
  final bool               isCheapest;

  const _ProviderRow({required this.provider, required this.isCheapest});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(provider.name,
                  style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: NomadColors.feedIconColor)),
                if (isCheapest) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color:        NomadColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99)),
                    child: const Text('Más barato',
                      style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: NomadColors.primaryDark)),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${provider.costPct}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: isCheapest ? NomadColors.primary : NomadColors.feedIconColor)),
              Text('USD ${provider.costUsd.toStringAsFixed(2)} por USD 200',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReturnProgramCard extends StatelessWidget {
  final ReturnProgram program;
  final bool          expanded;

  const _ReturnProgramCard({required this.program, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🛡️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(program.name,
                  style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NomadColors.feedIconColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(program.description,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600,
              height: 1.6)),
          if (expanded) ...[
            const SizedBox(height: 10),
            const Text('Qué incluye:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: NomadColors.feedIconColor)),
            const SizedBox(height: 6),
            ...program.benefits.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Text('✓ ', style: TextStyle(
                  color: NomadColors.primary, fontSize: 13)),
                Expanded(child: Text(b,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
              ]),
            )),
            if (program.contactPhone != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.phone_outlined,
                  color: NomadColors.primary, size: 14),
                const SizedBox(width: 6),
                Text(program.contactPhone!,
                  style: const TextStyle(fontSize: 13,
                    color: NomadColors.primaryDark,
                    fontWeight: FontWeight.w500)),
              ]),
            ],
          ],
          const SizedBox(height: 8),
          Text('Fuente: OIM AVRR',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

class _SafetyAlertCard extends StatelessWidget {
  final MissingMigrantsAlert alert;
  const _SafetyAlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color bgColor;

    switch (alert.alertLevel) {
      case RouteAlertLevel.critical:
      case RouteAlertLevel.high:
        borderColor = const Color(0xFFFECACA);
        bgColor     = const Color(0xFFFEF2F2);
      case RouteAlertLevel.medium:
        borderColor = const Color(0xFFFED7AA);
        bgColor     = const Color(0xFFFFF7ED);
      default:
        borderColor = const Color(0xFFFEF08A);
        bgColor     = const Color(0xFFFEFCE8);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(alert.alertLevel.emoji,
                style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${alert.alertLevel.label} — ${alert.routeName}',
                  style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NomadColors.feedIconColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(alert.mainRisks,
            style: TextStyle(fontSize: 13,
              color: Colors.grey.shade700, height: 1.6)),
          const SizedBox(height: 10),
          Text(alert.humanitarianNote,
            style: TextStyle(fontSize: 12,
              color: Colors.grey.shade500, height: 1.5,
              fontStyle: FontStyle.italic)),
          if (alert.emergencyContact != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.phone_outlined, color: Colors.red, size: 14),
              const SizedBox(width: 6),
              Text('Emergencias OIM: ${alert.emergencyContact}',
                style: const TextStyle(fontSize: 13,
                  color: Colors.red, fontWeight: FontWeight.w500)),
            ]),
          ],
          const SizedBox(height: 8),
          Text('Fuente: OIM Missing Migrants Project',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

class _EmergencyNumbers extends StatelessWidget {
  final String countryCode;
  const _EmergencyNumbers({required this.countryCode});

  static const _numbers = {
    'CA': [('911', 'Emergencias'), ('811', 'Salud (no urgente)')],
    'ES': [('112', 'Emergencias'), ('091', 'Policía'), ('061', 'Salud')],
    'PT': [('112', 'Emergencias'), ('117', 'Policía')],
    'DE': [('112', 'Emergencias / Bomberos'), ('110', 'Policía')],
    'MX': [('911', 'Emergencias'), ('800 266 8435', 'OIM México')],
    'AU': [('000', 'Emergencias'), ('131 444', 'Policía (no urgente)')],
    'GB': [('999', 'Emergencias'), ('101', 'Policía (no urgente)')],
  };

  @override
  Widget build(BuildContext context) {
    final nums = _numbers[countryCode] ?? [('112', 'Emergencias')];
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Column(
        children: nums.asMap().entries.map((e) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.phone_rounded,
                    color: NomadColors.primary, size: 16),
                  const SizedBox(width: 10),
                  Text(e.value.$1,
                    style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w700, color: NomadColors.feedIconColor)),
                  const SizedBox(width: 8),
                  Text(e.value.$2,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ),
            if (e.key < nums.length - 1)
              Divider(height: 1, color: Colors.grey.shade100),
          ],
        )).toList(),
      ),
    );
  }
}

class _ChecklistItemCard extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback  onToggle;

  const _ChecklistItemCard({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isCompleted
              ? NomadColors.primary.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isCompleted
                ? NomadColors.primary.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.07),
            width: item.isCompleted ? 1 : 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: item.isCompleted ? NomadColors.primary : Colors.grey.shade300,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                      color: item.isCompleted
                          ? NomadColors.primary.withValues(alpha: 0.7)
                          : NomadColors.feedIconColor,
                      decoration: item.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none)),
                  const SizedBox(height: 3),
                  Text(item.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500,
                      height: 1.4)),
                  if (item.estimatedDays != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.access_time_rounded,
                        size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(item.estimatedDays!,
                        style: TextStyle(fontSize: 11,
                          color: Colors.grey.shade400)),
                    ]),
                  ],
                ],
              ),
            ),
            if (item.isRequired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:        NomadColors.feedBg,
                  borderRadius: BorderRadius.circular(4)),
                child: Text('REQ.',
                  style: TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  final MigrantPhase phase;
  const _PhaseHeader({required this.phase});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(phase.emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text('Fase ${phase.index + 1}: ${phase.label}'.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: Colors.grey.shade500, letterSpacing: .08)),
      ],
    );
  }
}

// ── Banners y tickers ─────────────────────────────────────────────────────────

class _UrgentAlertBanner extends StatelessWidget {
  final MissingMigrantsAlert alert;
  const _UrgentAlertBanner({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFEF2F2),
      child: Row(
        children: [
          const Text('🔴', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Alerta: ${alert.alertLevel.label} en ${alert.routeName}. Ver pestaña Seguridad.',
              style: const TextStyle(fontSize: 12,
                color: Color(0xFF991B1B), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _NewsTicker extends StatelessWidget {
  final List<String> alerts;
  const _NewsTicker({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: NomadColors.primary.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: alerts.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(a,
            style: const TextStyle(fontSize: 12, color: NomadColors.feedIconColor)),
        )).toList(),
      ),
    );
  }
}

// ── Widgets helper simples ────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
        color: NomadColors.feedIconColor));
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: Colors.grey.shade500,
        letterSpacing: .04));
  }
}

// ── Tarjeta de acceso a Ruta Inteligente ─────────────────────────────────────

class _RutaInteligenteCard extends StatelessWidget {
  final DestinationDashboard dashboard;
  const _RutaInteligenteCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final tieneRutaCompleta =
        dashboard.profile.budgetRange != null &&
        dashboard.profile.urgencyLevel != null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RutaQuizScreen(perfilBase: dashboard.profile),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [NomadColors.primary, NomadColors.primaryDark],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      NomadColors.primary.withValues(alpha: 0.25),
              blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🧭', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Text('Ruta Inteligente',
                        style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700, color: Colors.white)),
                      if (tieneRutaCompleta) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:        Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text('Lista',
                            style: TextStyle(fontSize: 9,
                              color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tieneRutaCompleta
                        ? 'Tu plan personalizado está listo. Tocá para verlo.'
                        : 'Tu ruta personalizada a ${dashboard.profile.destinationCountryName} con timeline, presupuesto y próximos pasos.',
                    style: const TextStyle(fontSize: 12,
                      color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
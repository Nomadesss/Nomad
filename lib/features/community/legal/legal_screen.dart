import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_theme.dart';
import '../../../services/migration_guide_model.dart';
import '../../../services/migration_guide_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// legal_screen_v2.dart  –  Nomad App
// Ubicación: lib/features/community/legal/legal_screen.dart  (reemplaza v1)
//
// Flujo completo:
//   1. Carga el perfil del usuario desde Firestore
//   2. Si falta objetivo o país destino → muestra el wizard de onboarding
//   3. Filtra las guías automáticamente por país destino + objetivo + pasaporte UE
//   4. Permite cambiar filtros sin salir de la pantalla
//   5. Tap en una guía → ficha detalle con pasos, requisitos y docs
//   6. Botón de chat IA legal (existente)
// ─────────────────────────────────────────────────────────────────────────────

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  // ── Estado ──────────────────────────────────────────────────────────────────
  UserMigrationFilter? _filter;
  List<MigrationGuide> _guides = [];
  List<MigrationGuide> _filtered = [];
  bool _loading = true;
  bool _showWizard = false;
  String? _error;

  // Filtros de la UI (categoría activa)
  GuideCategory? _activeCategory;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Carga ───────────────────────────────────────────────────────────────────

  Future<void> _load({bool forceWizard = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final filter = await MigrationGuideService.loadUserFilter();

      // Siempre mostrar el wizard al entrar, a menos que se llame
      // explícitamente con forceWizard:false (después de completarlo).
      if (forceWizard) {
        setState(() {
          _filter = filter;
          _showWizard = true;
          _loading = false;
        });
        return;
      }

      final guides = await MigrationGuideService.getGuidesForUser(
        filter: filter,
      );

      if (mounted) {
        setState(() {
          _filter = filter;
          _guides = guides;
          _loading = false;
          _showWizard = false;
          _activeCategory = _mapObjetivoToCategory(filter.objetivo);
        });
        _applyFilters();
        if (_filtered.isEmpty) {
          setState(() {
            _activeCategory = null; // null = chip "Todas"
          });
          _applyFilters();
        }
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Error cargando guías: $e';
          _loading = false;
        });
    }
  }

  void _applyFilters() {
    var result = _guides;

    // Filtro por categoría
    if (_activeCategory != null) {
      result = result.where((g) {
        // si el usuario eligió Familia, incluir menores
        if (_activeCategory == GuideCategory.familiar) {
          return g.categoria == GuideCategory.familiar ||
              g.categoria == GuideCategory.menores;
        }

        return g.categoria == _activeCategory;
      }).toList();
    }

    // Filtro por búsqueda
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (g) =>
                g.titulo.toLowerCase().contains(q) ||
                g.categoria.label.toLowerCase().contains(q) ||
                (g.tipoAutorizacion?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }

    setState(() => _filtered = result);
  }

  // ── Guardar objetivo desde el wizard ────────────────────────────────────────

  Future<void> _saveFilter({
    required String objetivo,
    required bool tienePasaporteUe,
    required String paisIso,
  }) async {
    await MigrationGuideService.saveUserObjective(
      objetivo: objetivo,
      tienePasaporteUe: tienePasaporteUe,
    );
    // También actualizar país destino si cambió
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'destinationCountry': paisIso,
      });
    }
    // forceWizard:false para ir directo a los resultados después de completar el wizard
    await _load(forceWizard: false);
  }

  GuideCategory? _mapObjetivoToCategory(String? objetivo) {
    switch (objetivo) {
      case "familia":
        return GuideCategory.familiar;

      case "trabajar":
        return GuideCategory.trabajo;

      case "estudiar":
        return GuideCategory.estudios;

      case "residir":
        return GuideCategory.residencia;

      case "emprender":
        return GuideCategory.emprender;

      case "nomada":
        return GuideCategory.nomadaDigital;

      default:
        return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();
    if (_showWizard) return _LegalWizard(onComplete: _saveFilter);
    return _buildMain();
  }

  // ── Estados intermedios ───────────────────────────────────────────────────

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: const Center(
        child: CircularProgressIndicator(color: NomadColors.primary),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: NomadColors.feedIconColor),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NomadColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pantalla principal ────────────────────────────────────────────────────

  Widget _buildMain() {
    final f = _filter!;
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ────────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: NomadColors.feedHeaderBg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: NomadColors.feedIconColor,
              onPressed: () => Navigator.of(context).pop(),
            ),
            centerTitle: true,
            title: const Text(
              'Nomad',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: NomadColors.primary,
                letterSpacing: -0.3,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 20),
                color: NomadColors.feedIconColor,
                onPressed: () => _showFilterSheet(),
                tooltip: 'Cambiar filtros',
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                color: NomadColors.feedIconColor,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LegalChatScreen()),
                ),
              ),
            ],
          ),

          // ── Header con contexto del usuario ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Breadcrumb: país destino + objetivo
                  _UserContextBanner(
                    filter: f,
                    onChangeTap: () => setState(() => _showWizard = true),
                  ),
                  const SizedBox(height: 16),

                  // Buscador
                  _buildSearchBar(),
                  const SizedBox(height: 14),

                  // Banner de chat IA
                  _AIChatBanner(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalChatScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Chips de categoría
                  _CategoryChips(
                    activeCategory: _activeCategory,
                    onSelect: (cat) {
                      setState(() => _activeCategory = cat);
                      _applyFilters();
                      HapticFeedback.selectionClick();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Conteo de resultados
                  Text(
                    _activeCategory != null
                        ? '${_filtered.length} guías · ${_activeCategory!.label}'
                        : '${_filtered.length} guías para ${f.paisDestinoIso}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Lista de guías ────────────────────────────────────────────────
          _filtered.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyState())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _GuideCard(
                        guide: _filtered[i],
                        filter: f,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LegalGuideDetailScreen(
                              guide: _filtered[i],
                              filter: f,
                            ),
                          ),
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

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) {
        setState(() => _searchQuery = v.trim());
        _applyFilters();
      },
      style: const TextStyle(fontSize: 14, color: NomadColors.feedIconColor),
      decoration: InputDecoration(
        hintText: 'Buscar visa, permiso, trámite…',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 18,
          color: NomadColors.primary,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                  _applyFilters();
                },
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NomadColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.find_in_page_outlined,
            size: 52,
            color: NomadColors.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No encontramos guías con esos filtros',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: NomadColors.feedIconColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Probá eliminando algunos filtros o cambiando tu objetivo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _activeCategory = null;
                _searchQuery = '';
                _searchCtrl.clear();
              });
              _applyFilters();
            },
            icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
            label: const Text('Limpiar filtros'),
            style: TextButton.styleFrom(foregroundColor: NomadColors.primary),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        currentFilter: _filter!,
        onApply: (objetivo, tienePasaporteUe, paisIso) async {
          Navigator.pop(context);
          await _saveFilter(
            objetivo: objetivo,
            tienePasaporteUe: tienePasaporteUe,
            paisIso: paisIso,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wizard de onboarding legal (cuando falta objetivo o país destino)
// ─────────────────────────────────────────────────────────────────────────────

class _LegalWizard extends StatefulWidget {
  final Future<void> Function({
    required String objetivo,
    required bool tienePasaporteUe,
    required String paisIso,
  })
  onComplete;

  const _LegalWizard({required this.onComplete});

  @override
  State<_LegalWizard> createState() => _LegalWizardState();
}

class _LegalWizardState extends State<_LegalWizard> {
  int _step = 0;
  String? _objetivo;
  bool _pasaporteUe = false;
  String _paisDestino = 'ES';

  static const _paises = [
    {'iso': 'AR', 'nombre': 'Argentina', 'flag': '🇦🇷'},
    {'iso': 'ES', 'nombre': 'España', 'flag': '🇪🇸'},
    {'iso': 'UY', 'nombre': 'Uruguay', 'flag': '🇺🇾'},
    // Escalable: agregar más países aquí cuando estén scrapeados
  ];

  static const _objetivos = [
    {'key': 'trabajar', 'label': 'Trabajar', 'emoji': '💼'},
    {'key': 'estudiar', 'label': 'Estudiar', 'emoji': '🎓'},
    {'key': 'emprender', 'label': 'Emprender / Invertir', 'emoji': '🚀'},
    {'key': 'familia', 'label': 'Reunirme con mi familia', 'emoji': '👨‍👩‍👧'},
    {'key': 'residir', 'label': 'Vivir / Residir', 'emoji': '🏠'},
    {'key': 'nomada', 'label': 'Nómada digital', 'emoji': '💻'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      appBar: AppBar(
        backgroundColor: NomadColors.feedHeaderBg,
        elevation: 0,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                color: NomadColors.feedIconColor,
                onPressed: () => setState(() => _step--),
              )
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                color: NomadColors.feedIconColor,
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          'Nomad',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: NomadColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de progreso
              _WizardProgress(step: _step, total: 3),
              const SizedBox(height: 28),

              if (_step == 0) _buildStep0(),
              if (_step == 1) _buildStep1(),
              if (_step == 2) _buildStep2(),
            ],
          ),
        ),
      ),
    );
  }

  // Paso 0: País destino
  Widget _buildStep0() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿A dónde vas a migrar?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: NomadColors.feedIconColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mostramos información legal oficial del país destino.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: ListView(
              children: _paises.map((p) {
                final selected = _paisDestino == p['iso'];
                return _WizardOption(
                  emoji: p['flag']!,
                  label: p['nombre']!,
                  selected: selected,
                  onTap: () => setState(() => _paisDestino = p['iso']!),
                );
              }).toList(),
            ),
          ),
          _WizardNextButton(
            label: 'Continuar',
            enabled: _paisDestino.isNotEmpty,
            onTap: () => setState(() => _step = 1),
          ),
        ],
      ),
    );
  }

  // Paso 1: Objetivo principal
  Widget _buildStep1() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Cuál es tu objetivo principal?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: NomadColors.feedIconColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Filtramos la información para no abrumarte con lo que no necesitás.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: ListView(
              children: _objetivos.map((o) {
                final selected = _objetivo == o['key'];
                return _WizardOption(
                  emoji: o['emoji']!,
                  label: o['label']!,
                  selected: selected,
                  onTap: () => setState(() => _objetivo = o['key']!),
                );
              }).toList(),
            ),
          ),
          _WizardNextButton(
            label: 'Continuar',
            enabled: _objetivo != null,
            onTap: () => setState(() => _step = 2),
          ),
        ],
      ),
    );
  }

  // Paso 2: Pasaporte UE
  Widget _buildStep2() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Tenés pasaporte europeo?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: NomadColors.feedIconColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los ciudadanos de la UE tienen acceso al régimen comunitario: '
            'menores requisitos, sin cuotas y trámites más simples.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          _WizardOption(
            emoji: '🇪🇺',
            label: 'Sí, tengo pasaporte de un país de la UE',
            selected: _pasaporteUe,
            onTap: () => setState(() => _pasaporteUe = true),
          ),
          const SizedBox(height: 10),
          _WizardOption(
            emoji: '🌎',
            label: 'No, tengo pasaporte latinoamericano',
            selected: !_pasaporteUe,
            onTap: () => setState(() => _pasaporteUe = false),
          ),
          // Info sobre régimen comunitario
          if (_pasaporteUe) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: const Text(
                '🇪🇺 Con pasaporte UE accedés al régimen de libre circulación. '
                'Podés trabajar, estudiar y residir sin visa ni cuotas en España '
                'y los 26 países del Espacio Schengen.',
                style: TextStyle(
                  fontSize: 12,
                  color: NomadColors.feedIconColor,
                  height: 1.6,
                ),
              ),
            ),
          ],
          const Spacer(),
          _WizardNextButton(
            label: 'Ver mis guías legales',
            enabled: true,
            onTap: () => widget.onComplete(
              objetivo: _objetivo!,
              tienePasaporteUe: _pasaporteUe,
              paisIso: _paisDestino,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GuideCard — tarjeta de cada guía en la lista
// ─────────────────────────────────────────────────────────────────────────────

class _GuideCard extends StatelessWidget {
  final MigrationGuide guide;
  final UserMigrationFilter filter;
  final VoidCallback onTap;

  const _GuideCard({
    required this.guide,
    required this.filter,
    required this.onTap,
  });

  Color get _catColor {
    switch (guide.categoria) {
      case GuideCategory.estudios:
        return const Color(0xFF7C3AED);
      case GuideCategory.trabajo:
        return const Color(0xFF0D9488);
      case GuideCategory.emprender:
        return const Color(0xFFD97706);
      case GuideCategory.familiar:
        return const Color(0xFFDB2777);
      case GuideCategory.residencia:
        return const Color(0xFF1D4ED8);
      case GuideCategory.nomadaDigital:
        return const Color(0xFF059669);
      default:
        return Colors.grey.shade600;
    }
  }

  String _iconForGuide(MigrationGuide g) {
    final text = (g.subtitulo + " " + g.titulo).toLowerCase();

    if (text.contains("tutela")) return "🛡️";
    if (text.contains("viaja")) return "✈️";
    if (text.contains("carta poder")) return "✍️";
    if (text.contains("fallecido")) return "⚖️";
    if (text.contains("exterior")) return "🌍";
    if (text.contains("mercosur")) return "🧭";
    if (text.contains("permanente")) return "🏠";

    return g.categoria.emoji;
  }

  String get _cleanTitle {
    var t = guide.titulo;
    for (final p in ['Hoja 1 - ', 'Hoja 2 - ', 'Hoja 3 - ', 'Hoja 4 - ']) {
      if (t.startsWith(p)) t = t.substring(p.length);
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    // Si el doc tiene subtitulo diferente al titulo, el subtitulo es el texto
    // principal (más descriptivo) y el titulo se muestra como aclaración.
    bool _isGenericTitle(String t) {
      final x = t.toLowerCase();

      return x.contains("permiso para menor") ||
          x == "residencia legal" ||
          x == "residencia" ||
          x == "visado";
    }

    final subtitle = guide.subtitulo.trim();
    final title = _cleanTitle.trim();

    final useSubtitleAsMain = subtitle.isNotEmpty && !_isGenericTitle(subtitle);

    final mainText = useSubtitleAsMain ? subtitle : title;

    final secondText = useSubtitleAsMain ? title : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.06), width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ícono de categoría
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _catColor.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    _iconForGuide(guide),
                    style: const TextStyle(fontSize: 21),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Bloque de texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InlineBadge(
                      label: guide.categoria.label,
                      color: _catColor,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      mainText,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: NomadColors.feedIconColor,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (secondText != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        secondText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge de una línea: punto de color + label
class _InlineBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _InlineBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class LegalGuideDetailScreen extends StatelessWidget {
  final MigrationGuide guide;
  final UserMigrationFilter filter;

  const LegalGuideDetailScreen({
    super.key,
    required this.guide,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: NomadColors.feedHeaderBg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: NomadColors.feedIconColor,
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: Text(guide.paisFlag, style: const TextStyle(fontSize: 22)),
            actions: [
              IconButton(
                icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                color: NomadColors.feedIconColor,
                onPressed: () => _openUrl(guide.url),
                tooltip: 'Ver fuente oficial',
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
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
                  // Encabezado
                  Row(
                    children: [
                      Text(
                        guide.categoria.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guide.paisNombre,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade400,
                                letterSpacing: .5,
                              ),
                            ),
                            Text(
                              guide.categoria.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: NomadColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _cleanTitle(guide.titulo),
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: NomadColors.feedIconColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Metadata pills
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (guide.duracion != null)
                        _MetaPill(
                          icon: Icons.schedule_rounded,
                          label: guide.duracion!,
                        ),
                      if (guide.renovable == true)
                        const _MetaPill(
                          icon: Icons.refresh_rounded,
                          label: 'Renovable',
                        ),
                      if (guide.soloPasaporteUe)
                        const _MetaPill(
                          icon: Icons.flag_rounded,
                          label: 'Régimen UE',
                          color: Color(0xFF1D4ED8),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Tipo de autorización
          if (guide.tipoAutorizacion != null)
            _DetailSection(
              icon: Icons.info_outline_rounded,
              title: '¿Qué es?',
              child: Text(
                guide.tipoAutorizacion!,
                style: const TextStyle(
                  fontSize: 13,
                  color: NomadColors.feedIconColor,
                  height: 1.6,
                ),
              ),
            ),

          // Requisitos
          if (guide.requisitos.isNotEmpty)
            _DetailSection(
              icon: Icons.checklist_rounded,
              title: 'Requisitos (${guide.requisitos.length})',
              child: _BulletList(
                items: guide.requisitos,
                color: const Color(0xFF7C3AED),
              ),
            ),

          // Documentación
          if (guide.documentacionExigible.isNotEmpty)
            _DetailSection(
              icon: Icons.folder_outlined,
              title:
                  'Documentación exigible (${guide.documentacionExigible.length})',
              child: _BulletList(
                items: guide.documentacionExigible,
                color: const Color(0xFFD97706),
              ),
            ),

          // Procedimiento
          if (guide.procedimiento.isNotEmpty)
            _DetailSection(
              icon: Icons.account_tree_outlined,
              title: 'Procedimiento',
              child: _NumberedList(items: guide.procedimiento),
            ),

          // Familiares
          if (guide.familiares.isNotEmpty)
            _DetailSection(
              icon: Icons.people_outline_rounded,
              title: 'Familiares',
              child: _BulletList(
                items: guide.familiares,
                color: const Color(0xFFDB2777),
              ),
            ),

          // Prórroga
          if (guide.prorroga.isNotEmpty)
            _DetailSection(
              icon: Icons.refresh_rounded,
              title: 'Prórroga / Renovación',
              child: _BulletList(
                items: guide.prorroga,
                color: const Color(0xFF059669),
              ),
            ),

          // Tasas
          if (guide.tasas != null)
            _DetailSection(
              icon: Icons.euro_rounded,
              title: 'Tasas',
              child: Text(
                guide.tasas!,
                style: const TextStyle(
                  fontSize: 13,
                  color: NomadColors.feedIconColor,
                  height: 1.6,
                ),
              ),
            ),

          // Fuente oficial
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
              child: GestureDetector(
                onTap: () => _openUrl(guide.url),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.open_in_browser_rounded,
                        size: 18,
                        color: NomadColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fuente oficial',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: NomadColors.primary,
                                letterSpacing: .5,
                              ),
                            ),
                            Text(
                              guide.fuenteOficial,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Colors.grey.shade300,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanTitle(String t) {
    final prefixes = ['Hoja 1 - ', 'Hoja 2 - ', 'Hoja 3 - '];
    for (final p in prefixes) {
      if (t.startsWith(p)) return t.substring(p.length);
    }
    return t;
  }

  void _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet de filtros
// ─────────────────────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final UserMigrationFilter currentFilter;
  final Future<void> Function(
    String objetivo,
    bool tienePasaporteUe,
    String paisIso,
  )
  onApply;

  const _FilterSheet({required this.currentFilter, required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _objetivo;
  late bool _pasaporteUe;
  late String _paisIso;

  static const _objetivos = [
    {'key': 'trabajar', 'label': 'Trabajar', 'emoji': '💼'},
    {'key': 'estudiar', 'label': 'Estudiar', 'emoji': '🎓'},
    {'key': 'emprender', 'label': 'Emprender / Invertir', 'emoji': '🚀'},
    {'key': 'familia', 'label': 'Reunirme con mi familia', 'emoji': '👨‍👩‍👧'},
    {'key': 'residir', 'label': 'Vivir / Residir', 'emoji': '🏠'},
    {'key': 'nomada', 'label': 'Nómada digital', 'emoji': '💻'},
  ];

  @override
  void initState() {
    super.initState();
    _objetivo = widget.currentFilter.objetivo ?? 'residir';
    _pasaporteUe = widget.currentFilter.tienePasaporteUe;
    _paisIso = widget.currentFilter.paisDestinoIso;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Ajustar filtros',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: NomadColors.feedIconColor,
            ),
          ),
          const SizedBox(height: 18),

          // Objetivo
          const Text(
            'Mi objetivo principal',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: NomadColors.primary,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _objetivos.map((o) {
              final sel = _objetivo == o['key'];
              return GestureDetector(
                onTap: () => setState(() => _objetivo = o['key']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? NomadColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? NomadColors.primary : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    '${o['emoji']} ${o['label']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : NomadColors.feedIconColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Pasaporte UE
          const Text(
            'Pasaporte europeo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: NomadColors.primary,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ToggleChip(
                label: '🇪🇺 Sí tengo',
                selected: _pasaporteUe,
                onTap: () => setState(() => _pasaporteUe = true),
              ),
              const SizedBox(width: 8),
              _ToggleChip(
                label: '🌎 No tengo',
                selected: !_pasaporteUe,
                onTap: () => setState(() => _pasaporteUe = false),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Aplicar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  widget.onApply(_objetivo, _pasaporteUe, _paisIso),
              style: ElevatedButton.styleFrom(
                backgroundColor: NomadColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Aplicar filtros',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets reutilizables
// ─────────────────────────────────────────────────────────────────────────────

/// Selector de país destino. Solo muestra el país y un botón "Cambiar"
/// que abre el wizard para actualizar todos los filtros.
class _UserContextBanner extends StatelessWidget {
  final UserMigrationFilter filter;
  final VoidCallback onChangeTap;

  const _UserContextBanner({required this.filter, required this.onChangeTap});

  static const _paisInfo = {
    'ES': ('🇪🇸', 'España'),
    'UY': ('🇺🇾', 'Uruguay'),
    'AR': ('🇦🇷', 'Argentina'),
    'PT': ('🇵🇹', 'Portugal'),
    'MX': ('🇲🇽', 'México'),
    'CO': ('🇨🇴', 'Colombia'),
    'CL': ('🇨🇱', 'Chile'),
    'DE': ('🇩🇪', 'Alemania'),
    'CA': ('🇨🇦', 'Canadá'),
  };

  @override
  Widget build(BuildContext context) {
    final iso = filter.paisDestinoIso.toUpperCase();
    final info = _paisInfo[iso];
    final flag = info?.$1 ?? '🌍';
    final name = info?.$2 ?? iso;

    return GestureDetector(
      onTap: onChangeTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'País de destino',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade400,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: NomadColors.feedIconColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: NomadColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Cambiar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: NomadColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AIChatBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AIChatBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [NomadColors.primary, NomadColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consultá con la IA legal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Respuestas al instante sobre tu situación',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white60,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final GuideCategory? activeCategory;
  final ValueChanged<GuideCategory?> onSelect;

  const _CategoryChips({required this.activeCategory, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cats = [
      null, // "Todas"
      GuideCategory.estudios,
      GuideCategory.trabajo,
      GuideCategory.emprender,
      GuideCategory.familiar,
      GuideCategory.residencia,
      GuideCategory.nomadaDigital,
    ];

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: cats.map((cat) {
          final sel = activeCategory == cat;
          final label = cat == null ? 'Todas' : cat.label;
          final emoji = cat == null ? '📋' : cat.emoji;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? NomadColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? NomadColors.primary : Colors.grey.shade300,
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: NomadColors.primary.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '$emoji $label',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: NomadColors.primary),
                const SizedBox(width: 6),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade400,
                    letterSpacing: .08,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  final Color color;

  const _BulletList({required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 5),
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: NomadColors.feedIconColor,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _NumberedList extends StatelessWidget {
  final List<String> items;
  const _NumberedList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: NomadColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${e.key + 1}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: NomadColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: NomadColors.feedIconColor,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaPill({
    required this.icon,
    required this.label,
    this.color = NomadColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardProgress extends StatelessWidget {
  final int step;
  final int total;
  const _WizardProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        total,
        (i) => Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: i <= step ? NomadColors.primary : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _WizardOption extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WizardOption({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? NomadColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? NomadColors.primary : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : NomadColors.feedIconColor,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _WizardNextButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _WizardNextButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: NomadColors.primary,
          disabledBackgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? NomadColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? NomadColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : NomadColors.feedIconColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder para LegalChatScreen (ya existe en tu código)
// Este import está acá solo para que el archivo compile.
// En producción se usa el LegalChatScreen de la v1.
// ─────────────────────────────────────────────────────────────────────────────

class LegalChatScreen extends StatelessWidget {
  const LegalChatScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Chat IA Legal')));
}

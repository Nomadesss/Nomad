import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../app_theme.dart';
import '../../../services/migration_data_model.dart';
import '../../../services/location_service.dart';
import 'integration_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WelcomePackScreen — Fase 3: Transición / Llegada
//
// Ubicación: lib/features/community/journey/welcome_pack_screen.dart
//
// Se activa cuando:
//   a) El usuario toca "Pack de bienvenida ✈️" en el Dashboard (manual)
//   b) WelcomePackService detecta que la ubicación GPS coincide con el
//      país destino del perfil (automático, Fase 3 del Journey)
//
// Persistencia del estado de la checklist:
//   SharedPreferences con key 'welcome_pack_{countryCode}'
//   No requiere Firestore ni conexión — funciona offline el primer día.
// ─────────────────────────────────────────────────────────────────────────────

class WelcomePackScreen extends StatefulWidget {
  final WelcomePack       pack;
  final MigrationProfile  profile;

  const WelcomePackScreen({
    super.key,
    required this.pack,
    required this.profile,
  });

  @override
  State<WelcomePackScreen> createState() => _WelcomePackScreenState();
}

class _WelcomePackScreenState extends State<WelcomePackScreen>
    with SingleTickerProviderStateMixin {

  // ── Estado ─────────────────────────────────────────────────────────────────
  late List<bool>       _done;         // Estado de cada item del pack
  late AnimationController _animCtrl;
  late Animation<double>   _fadeIn;

  // ── Persistencia ───────────────────────────────────────────────────────────
  String get _prefsKey => 'welcome_pack_${widget.pack.countryCode}';

  @override
  void initState() {
    super.initState();
    _done = List.filled(widget.pack.items.length, false);

    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    _loadState();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs  = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored != null) {
      final list = List<bool>.from(jsonDecode(stored) as List);
      if (list.length == _done.length && mounted) {
        setState(() => _done = list);
      }
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_done));
  }

  void _toggle(int index) {
    setState(() => _done[index] = !_done[index]);
    _saveState();
  }

  int get _completedCount => _done.where((d) => d).length;
  double get _progress =>
      widget.pack.items.isEmpty ? 0 : _completedCount / widget.pack.items.length;
  bool get _allDone => _completedCount == widget.pack.items.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          slivers: [

            // ── App bar expandible con hero ──────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned:         true,
              elevation:      0,
              backgroundColor: NomadColors.primary,
              leading: IconButton(
                icon:  const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _WelcomeHero(
                  pack:    widget.pack,
                  profile: widget.profile,
                ),
              ),
            ),

            // ── Barra de progreso ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _ProgressBar(
                progress:  _progress,
                completed: _completedCount,
                total:     widget.pack.items.length,
              ),
            ),

            // ── Banner "todo listo" ───────────────────────────────────────────
            if (_allDone)
              SliverToBoxAdapter(
                child: _AllDoneBanner(
                  profile: widget.profile,
                  onContinue: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IntegrationScreen(
                        profile: widget.profile,
                      ),
                    ),
                  ),
                ),
              ),

            // ── Acciones del primer día ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'TU PRIMER DÍA EN ${widget.pack.city.toUpperCase()}',
                  style: TextStyle(
                    fontSize:      11,
                    fontWeight:    FontWeight.w600,
                    color:         Colors.grey.shade500,
                    letterSpacing: .08,
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = widget.pack.items[i];
                    return _PackItemCard(
                      item:      item,
                      isDone:    _done[i],
                      onToggle:  () => _toggle(i),
                      animDelay: Duration(milliseconds: 100 + i * 80),
                    );
                  },
                  childCount: widget.pack.items.length,
                ),
              ),
            ),

            // ── eSIM ──────────────────────────────────────────────────────────
            if (widget.pack.eSIMUrl != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _ESIMCard(url: widget.pack.eSIMUrl!),
                ),
              ),

            // ── Mapa de puntos clave ──────────────────────────────────────────
            if (widget.pack.mapPoints.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    'PUNTOS CLAVE CERCA TUYO',
                    style: TextStyle(
                      fontSize:      11,
                      fontWeight:    FontWeight.w600,
                      color:         Colors.grey.shade500,
                      letterSpacing: .08,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _MapPointCard(
                      point: widget.pack.mapPoints[i],
                    ),
                    childCount: widget.pack.mapPoints.length,
                  ),
                ),
              ),
            ],

            // ── Emergencias ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _EmergencyCard(
                  number: widget.pack.emergencyNumber,
                  country: widget.profile.destinationCountryName,
                ),
              ),
            ),

            // ── Botón Fase 4 ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 60),
                child: SizedBox(
                  width:  double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IntegrationScreen(
                          profile: widget.profile,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.home_rounded,
                      color: Colors.white, size: 18),
                    label: const Text(
                      'Continuar a Fase 4: Integración',
                      style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w600,
                        color:      Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NomadColors.primaryDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WELCOME PACK SERVICE — lógica de detección de llegada
//
// Separado de la UI para que sea testeable y reutilizable.
// ═══════════════════════════════════════════════════════════════════════════════

class WelcomePackService {

  // Key de SharedPreferences para saber si ya se mostró el pack.
  static String _shownKey(String countryCode) =>
      'welcome_pack_shown_$countryCode';

  /// Verifica si el usuario llegó al país destino comparando su ubicación
  /// actual con el país destino del perfil.
  ///
  /// Devuelve true si:
  ///   - La ubicación GPS o IP coincide con el país destino
  ///   - El pack NO fue mostrado previamente (evitar repetición)
  static Future<bool> shouldShowWelcomePack({
    required MigrationProfile profile,
    required LocationData     location,
  }) async {
    final destCode     = profile.destinationCountry.toUpperCase();
    final currentCode  = (location.countryCodeEffective ?? '').toUpperCase();

    if (currentCode != destCode) return false;

    // Verificar si ya se mostró antes.
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(_shownKey(destCode)) ?? false;

    return !shown;
  }

  /// Marca el pack como mostrado — no se vuelve a mostrar automáticamente.
  static Future<void> markAsShown(String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shownKey(countryCode.toUpperCase()), true);
  }

  /// Resetea el estado — útil si el usuario quiere volver a ver el pack.
  static Future<void> reset(String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shownKey(countryCode.toUpperCase()));
  }

  /// Llama a este método en el initState del FeedScreen o AuthGate
  /// para detectar si hay que mostrar el pack de bienvenida.
  ///
  /// Ejemplo de uso en FeedScreen._loadFeed():
  ///
  ///   final location = await LocationService.collect();
  ///   final profile  = await UserService().getPerfil();
  ///   if (profile?.hasMigrationProfile == true) {
  ///     final migProfile = MigrationProfile(... from profile ...);
  ///     final show = await WelcomePackService.shouldShowWelcomePack(
  ///       profile:  migProfile,
  ///       location: location,
  ///     );
  ///     if (show && mounted) {
  ///       await WelcomePackService.markAsShown(migProfile.destinationCountry);
  ///       Navigator.push(context, MaterialPageRoute(
  ///         builder: (_) => WelcomePackScreen(
  ///           pack:    IomService.buildWelcomePack(...),
  ///           profile: migProfile,
  ///         ),
  ///       ));
  ///     }
  ///   }
  static Future<bool> checkAndTrigger({
    required MigrationProfile profile,
    required LocationData     location,
  }) async {
    return shouldShowWelcomePack(profile: profile, location: location);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COMPONENTES DE LA PANTALLA
// ══════════════════════════════════════════════════════════════════════════════

// ── Hero ────────────────────────────────────────────────────────────────────

class _WelcomeHero extends StatelessWidget {
  final WelcomePack      pack;
  final MigrationProfile profile;

  const _WelcomeHero({required this.pack, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [NomadColors.primary, NomadColors.primaryDark],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✈️', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          Text(
            '¡Bienvenido/a\na ${pack.city}!',
            style: const TextStyle(
              fontFamily:    'Georgia',
              fontSize:      26,
              fontWeight:    FontWeight.w700,
              color:         Colors.white,
              height:        1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Aquí está todo lo que necesitás hacer hoy.',
            style: const TextStyle(
              fontSize: 14,
              color:    Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Barra de progreso ────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double progress;
  final int    completed;
  final int    total;

  const _ProgressBar({
    required this.progress,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color:   Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _progressLabel(progress),
                style: const TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                  color:      NomadColors.feedIconColor,
                ),
              ),
              Text(
                '$completed de $total completados',
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w500,
                  color:      NomadColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween:    Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve:    Curves.easeOut,
              builder: (_, value, __) => LinearProgressIndicator(
                value:           value,
                backgroundColor: NomadColors.feedBg,
                valueColor: const AlwaysStoppedAnimation(NomadColors.primary),
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _progressLabel(double p) {
    if (p == 0)   return '¿Por dónde empezás?';
    if (p < 0.5)  return 'Buen comienzo 💪';
    if (p < 1.0)  return '¡Casi listo!';
    return '¡Todo listo para tu primer día! 🎉';
  }
}

// ── Banner "todo listo" ───────────────────────────────────────────────────────

class _AllDoneBanner extends StatelessWidget {
  final MigrationProfile profile;
  final VoidCallback     onContinue;

  const _AllDoneBanner({required this.profile, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          Text(
            '¡Completaste tu primer día\nen ${profile.destinationCountryName}!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily:  'Georgia',
              fontSize:    18,
              fontWeight:  FontWeight.w700,
              color:       Color(0xFF166534),
              height:      1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ya estás listo para la Fase 4: integrarte a la comunidad, '
            'encontrar trabajo y construir tu vida acá.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color:    Colors.grey.shade600,
              height:   1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width:  double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Ir a Fase 4: Integración →',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item del pack ─────────────────────────────────────────────────────────────

class _PackItemCard extends StatelessWidget {
  final WelcomeItem  item;
  final bool         isDone;
  final VoidCallback onToggle;
  final Duration     animDelay;

  const _PackItemCard({
    required this.item,
    required this.isDone,
    required this.onToggle,
    required this.animDelay,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween:    Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve:    Curves.easeOut,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDone
                ? NomadColors.primary.withValues(alpha: 0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDone
                  ? NomadColors.primary.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.07),
              width: isDone ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Número de prioridad o check
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width:  32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone
                      ? NomadColors.primary
                      : NomadColors.feedBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone
                        ? NomadColors.primary
                        : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : Text(
                          '${item.priority}',
                          style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            color:      Colors.grey.shade500,
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.emoji,
                          style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize:   14,
                              fontWeight: FontWeight.w600,
                              color: isDone
                                  ? NomadColors.primary.withValues(alpha: 0.6)
                                  : NomadColors.feedIconColor,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 13,
                        color:    Colors.grey.shade500,
                        height:   1.5,
                      ),
                    ),

                    // Botón de acción (si tiene URL)
                    if (item.actionUrl != null && !isDone) ...[
                      const SizedBox(height: 8),
                      _ActionButton(url: item.actionUrl!, label: 'Ir al trámite'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── eSIM Card ─────────────────────────────────────────────────────────────────

class _ESIMCard extends StatelessWidget {
  final String url;
  const _ESIMCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Row(
        children: [
          Container(
            width:  44,
            height: 44,
            decoration: BoxDecoration(
              color:        NomadColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('📱', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conectate al instante con eSIM',
                  style: TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w600,
                    color:      NomadColors.feedIconColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Sin SIM física ni trámites. Activá datos locales en minutos.',
                  style: TextStyle(
                    fontSize: 12,
                    color:    Colors.grey.shade600,
                    height:   1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ActionButton(url: url, label: 'Ver planes'),
        ],
      ),
    );
  }
}

// ── Mapa de puntos ────────────────────────────────────────────────────────────

class _MapPointCard extends StatelessWidget {
  final MapPoint point;
  const _MapPointCard({required this.point});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width:  40,
            height: 40,
            decoration: BoxDecoration(
              color:        _categoryColor(point.category)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(point.emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.name,
                  style: const TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w500,
                    color:      NomadColors.feedIconColor,
                  ),
                ),
                if (point.address != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    point.address!,
                    style: TextStyle(
                      fontSize: 12,
                      color:    Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Botón "Cómo llegar" — abre Google Maps
          if (point.address != null)
            GestureDetector(
              onTap: () => _openMaps(point.address!),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:        NomadColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Cómo llegar',
                  style: TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    color:      NomadColors.primaryDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Abre Google Maps con la dirección.
  // En producción usar url_launcher: launchUrl(Uri.parse(url))
  void _openMaps(String address) {
    final encoded = Uri.encodeComponent(address);
    final url     = 'https://www.google.com/maps/search/?api=1&query=$encoded';
    // launchUrl(Uri.parse(url)); // descomentar con url_launcher importado
    debugPrint('[WelcomePack] Abriendo Maps: $url');
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'immigration': return NomadColors.primary;
      case 'hospital':    return const Color(0xFF10B981);
      case 'bank':        return const Color(0xFFF59E0B);
      case 'metro':       return const Color(0xFF6366F1);
      default:            return Colors.grey;
    }
  }
}

// ── Emergencias ───────────────────────────────────────────────────────────────

class _EmergencyCard extends StatelessWidget {
  final String number;
  final String country;

  const _EmergencyCard({required this.number, required this.country});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Container(
            width:  48,
            height: 48,
            decoration: BoxDecoration(
              color:        const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🚨', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergencias en $country',
                  style: const TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w600,
                    color:      NomadColors.feedIconColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Policía, bomberos, ambulancia',
                  style: TextStyle(
                    fontSize: 12,
                    color:    Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              // launchUrl(Uri.parse('tel:$number')); // con url_launcher
              debugPrint('[WelcomePack] Llamando a $number');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:        const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.w800,
                  color:      Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón de acción ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String url;
  final String label;

  const _ActionButton({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // launchUrl(Uri.parse(url)); // descomentar con url_launcher importado
        debugPrint('[WelcomePack] Abriendo URL: $url');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:        NomadColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new_rounded,
              size: 12, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
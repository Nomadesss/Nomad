import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app_theme.dart';
import '../../../services/migration_data_model.dart';
import '../../../services/user_model.dart';
import '../../../services/user_service.dart';
import '../../../services/social_service.dart';
import '../empleo/empleo_screen.dart';
import '../legal/legal_screen.dart';
import '../social/social_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IntegrationScreen — Fase 4: Integración / Asentamiento
//
// Ubicación: lib/features/community/journey/integration_screen.dart
//
// Es el "home" del migrante ya establecido. Consolida:
//   - Estado migratorio (visa, residencia, documentos)
//   - Progreso hacia residencia permanente
//   - Accesos a Empleo / Legal / Social con contexto del perfil
//   - Grupos de la comunidad en su ciudad actual
//   - Alertas de vencimiento de documentos
//   - Acceso a la red de seguridad (AVRR) si las cosas no salen bien
// ─────────────────────────────────────────────────────────────────────────────

class IntegrationScreen extends StatefulWidget {
  final MigrationProfile profile;
  const IntegrationScreen({super.key, required this.profile});

  @override
  State<IntegrationScreen> createState() => _IntegrationScreenState();
}

class _IntegrationScreenState extends State<IntegrationScreen> {

  UserModel? _user;
  bool       _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await UserService().getPerfil();
    if (mounted) setState(() { _user = user; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: CustomScrollView(
        slivers: [

          // ── App bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned:         true,
            elevation:      0,
            backgroundColor: NomadColors.primaryDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _IntegrationHero(
                profile: widget.profile,
                user:    _user,
              ),
            ),
          ),

          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(
                  color: NomadColors.primary)),
              ),
            )
          else ...[

            // ── Estado migratorio ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _MigrationStatusCard(
                profile: widget.profile,
                user:    _user,
              ),
            ),

            // ── Alertas de documentos ────────────────────────────────────────
            if (_user != null)
              SliverToBoxAdapter(
                child: _DocumentAlertsSection(user: _user!),
              ),

            // ── Accesos rápidos ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _QuickAccessSection(profile: widget.profile),
            ),

            // ── Comunidad local ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _LocalCommunitySection(profile: widget.profile),
            ),

            // ── Próximos pasos ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _NextStepsSection(profile: widget.profile),
            ),

            // ── Red de seguridad ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SafetyNetSection(profile: widget.profile),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HERO
// ══════════════════════════════════════════════════════════════════════════════

class _IntegrationHero extends StatelessWidget {
  final MigrationProfile profile;
  final UserModel?       user;

  const _IntegrationHero({required this.profile, required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? 'Nomad';
    final city        = profile.targetCity ?? profile.destinationCountryName;
    // arrivedAt vive en UserModel, no en MigrationProfile.
    final daysInCountry = user?.arrivedAt != null
        ? DateTime.now().difference(user!.arrivedAt!).inDays
        : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [NomadColors.primaryDark, Color(0xFF065F46)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 75, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [

          // Avatar
          Container(
            width:  52,
            height: 52,
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: 0.15),
              shape:        BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                user?.initials ?? '?',
                style: const TextStyle(
                  fontSize:   18,
                  fontWeight: FontWeight.w700,
                  color:      Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:  MainAxisAlignment.end,
              children: [
                Text(
                  '👋 Hola, $displayName',
                  style: const TextStyle(
                    fontSize: 14,
                    color:    Colors.white70,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Establecido en $city',
                  style: const TextStyle(
                    fontFamily:  'Georgia',
                    fontSize:    20,
                    fontWeight:  FontWeight.w700,
                    color:       Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                if (daysInCountry != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$daysInCountry días en ${profile.destinationCountryName} 🏠',
                    style: const TextStyle(
                      fontSize: 12,
                      color:    Colors.white60,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Fase badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '${MigrantPhase.integration.emoji} Fase 4',
              style: const TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color:      Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ESTADO MIGRATORIO
// ══════════════════════════════════════════════════════════════════════════════

class _MigrationStatusCard extends StatelessWidget {
  final MigrationProfile profile;
  final UserModel?       user;

  const _MigrationStatusCard({required this.profile, required this.user});

  @override
  Widget build(BuildContext context) {
    // Calcular progreso hacia residencia permanente.
    // Canadá: 3 años. España: 5 años (2 para ciudadanía). Portugal: 5 años.
    // arrivedAt vive en UserModel — se pasa desde _IntegrationScreenState
    // que ya cargó el UserModel completo.
    final yearsRequired = _yearsToPermRes(profile.destinationCountry);
    final daysInCountry = user?.arrivedAt != null
        ? DateTime.now().difference(user!.arrivedAt!).inDays
        : 0;
    final yearsInCountry = daysInCountry / 365;
    final permResProgress = (yearsInCountry / yearsRequired).clamp(0.0, 1.0);
    final yearsLeft = (yearsRequired - yearsInCountry).clamp(0.0, yearsRequired);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Text('🛂', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Text(
                  'Tu situación migratoria',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: NomadColors.feedIconColor),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        NomadColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    profile.currentPhase.label,
                    style: const TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600, color: NomadColors.primaryDark),
                  ),
                ),
              ],
            ),
          ),

          // Datos
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _StatusRow(
                  label: 'País de residencia',
                  value: '${_countryFlag(profile.destinationCountry)} ${profile.destinationCountryName}',
                ),
                _StatusRow(
                  label: 'Perfil',
                  value: '${profile.profileType.emoji} ${profile.profileType.label}',
                ),
                if (user?.visaType != null)
                  _StatusRow(
                    label: 'Tipo de visa',
                    value: user!.visaType!,
                  ),
                if (user?.migrationStatus != null)
                  _StatusRow(
                    label: 'Estado',
                    value: user!.migrationStatus.label,
                  ),
              ],
            ),
          ),

          // Barra hacia residencia permanente
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hacia residencia permanente',
                      style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                    ),
                    Text(
                      permResProgress >= 1
                          ? '¡Elegible!'
                          : '${yearsLeft.toStringAsFixed(1)} años más',
                      style: TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                        color: permResProgress >= 1
                            ? NomadColors.success
                            : NomadColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween:    Tween(begin: 0, end: permResProgress),
                    duration: const Duration(milliseconds: 800),
                    curve:    Curves.easeOut,
                    builder: (_, value, __) => LinearProgressIndicator(
                      value:           value,
                      backgroundColor: NomadColors.feedBg,
                      valueColor: AlwaysStoppedAnimation(
                        permResProgress >= 1
                            ? NomadColors.success
                            : NomadColors.primary,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _permResMessage(profile.destinationCountry, yearsRequired),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _yearsToPermRes(String code) {
    switch (code) {
      case 'CA': return 3;
      case 'ES': return 2; // ciudadanía para iberoamericanos
      case 'PT': return 5;
      case 'DE': return 5;
      case 'MX': return 5;
      case 'AU': return 4;
      default:   return 5;
    }
  }

  String _permResMessage(String code, int years) {
    switch (code) {
      case 'ES': return 'España: ciudadanía a los $years años para iberoamericanos';
      case 'CA': return 'Canadá: Residencia Permanente a los $years años (de los últimos 5)';
      default:   return 'Residencia permanente: $years años de residencia legal continua';
    }
  }

  String _countryFlag(String code) {
    switch (code) {
      case 'CA': return '🇨🇦';
      case 'ES': return '🇪🇸';
      case 'PT': return '🇵🇹';
      case 'DE': return '🇩🇪';
      case 'MX': return '🇲🇽';
      case 'AU': return '🇦🇺';
      default:   return '🌍';
    }
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: NomadColors.feedIconColor)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ALERTAS DE DOCUMENTOS
// ══════════════════════════════════════════════════════════════════════════════

class _DocumentAlertsSection extends StatelessWidget {
  final UserModel user;
  const _DocumentAlertsSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final alerts = _buildAlerts(user);
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          emoji: '⚠️',
          title: 'Documentos a renovar',
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        ),
        ...alerts.map((a) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: _DocumentAlertCard(alert: a),
        )),
      ],
    );
  }

  List<_DocAlert> _buildAlerts(UserModel user) {
    final alerts  = <_DocAlert>[];
    final now     = DateTime.now();
    final in60    = now.add(const Duration(days: 60));

    // Vencimiento de visa
    if (user.migrationStatus == MigrationStatus.arrived) {
      // Si está en estado "arrived", verificar aproximación de vencimientos
      // En v2.0 esto viene del campo visaExpiry del migration_profile
      alerts.add(_DocAlert(
        title:      'Verificar vencimiento de visa',
        subtitle:   'Confirmá la fecha de vencimiento de tu visa actual.',
        level:      _AlertLevel.info,
        actionText: 'Ver trámites legales',
      ));
    }

    return alerts;
  }
}

class _DocumentAlertCard extends StatelessWidget {
  final _DocAlert alert;
  const _DocumentAlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color textColor;

    switch (alert.level) {
      case _AlertLevel.urgent:
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFECACA);
        textColor = const Color(0xFF991B1B);
      case _AlertLevel.warning:
        bg = const Color(0xFFFFF7ED);
        border = const Color(0xFFFED7AA);
        textColor = const Color(0xFF92400E);
      case _AlertLevel.info:
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
        textColor = const Color(0xFF1E40AF);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(alert.level == _AlertLevel.urgent ? '🔴'
               : alert.level == _AlertLevel.warning ? '🟡' : 'ℹ️',
            style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: textColor)),
                Text(alert.subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600,
                    height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ACCESOS RÁPIDOS
// ══════════════════════════════════════════════════════════════════════════════

class _QuickAccessSection extends StatelessWidget {
  final MigrationProfile profile;
  const _QuickAccessSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          emoji: '⚡',
          title: 'Acceso rápido',
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _QuickCard(
                  emoji:    '💼',
                  title:    'Empleos',
                  subtitle: 'Para tu perfil y visa',
                  gradient: [const Color(0xFFCCFBF1), const Color(0xFF99F6E4)],
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const EmpleoScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickCard(
                  emoji:    '⚖️',
                  title:    'Legal',
                  subtitle: 'Visas y trámites',
                  gradient: [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LegalScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickCard(
                  emoji:    '🤝',
                  title:    'Social',
                  subtitle: 'Grupos en ${profile.targetCity ?? "tu ciudad"}',
                  gradient: [const Color(0xFFFDF4FF), const Color(0xFFF0ABFC)],
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SocialScreen())),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String       emoji;
  final String       title;
  final String       subtitle;
  final List<Color>  gradient;
  final VoidCallback onTap;

  const _QuickCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient:     LinearGradient(
            colors: gradient,
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: NomadColors.feedIconColor)),
            const SizedBox(height: 2),
            Text(subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600,
                height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COMUNIDAD LOCAL
// ══════════════════════════════════════════════════════════════════════════════

class _LocalCommunitySection extends StatelessWidget {
  final MigrationProfile profile;
  const _LocalCommunitySection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final city = (profile.targetCity ?? '').toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          emoji: '🤝',
          title: 'Tu comunidad en ${profile.targetCity ?? profile.destinationCountryName}',
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          action: GestureDetector(
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SocialScreen())),
            child: Text('Ver todos',
              style: const TextStyle(fontSize: 13,
                color: NomadColors.primary, fontWeight: FontWeight.w500)),
          ),
        ),
        if (city.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _EmptyState(
              emoji:    '📍',
              message:  'Actualizá tu ciudad en el perfil para ver grupos cercanos.',
            ),
          )
        else
          StreamBuilder<List<GroupModel>>(
            stream: SocialService.streamGroups(city: city, limit: 3),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator(
                    color: NomadColors.primary, strokeWidth: 2)),
                );
              }

              final groups = snap.data ?? [];
              if (groups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _EmptyState(
                    emoji:   '🌱',
                    message: 'Todavía no hay grupos en ${profile.targetCity}. ¡Sé el primero en crear uno!',
                    action: ElevatedButton(
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SocialScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NomadColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Crear un grupo',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              }

              return Column(
                children: groups.map((g) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _CompactGroupCard(group: g, context: context),
                )).toList(),
              );
            },
          ),
      ],
    );
  }
}

class _CompactGroupCard extends StatelessWidget {
  final GroupModel group;
  final BuildContext context;

  const _CompactGroupCard({required this.group, required this.context});

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Row(
        children: [
          Text(group.coverEmoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: NomadColors.feedIconColor),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${group.category.label} · ${group.memberCount} miembros',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          StreamBuilder<bool>(
            stream: SocialService.isMemberStream(group.docId),
            builder: (_, snap) {
              final isMember = snap.data ?? false;
              return GestureDetector(
                onTap: () => isMember
                    ? SocialService.leaveGroup(group.docId)
                    : SocialService.joinGroup(group.docId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMember ? NomadColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: NomadColors.primary),
                  ),
                  child: Text(
                    isMember ? 'Unido ✓' : 'Unirse',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: isMember ? Colors.white : NomadColors.primary),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRÓXIMOS PASOS
// ══════════════════════════════════════════════════════════════════════════════

class _NextStepsSection extends StatelessWidget {
  final MigrationProfile profile;
  const _NextStepsSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps(profile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          emoji: '🎯',
          title: 'Próximos pasos',
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.07), width: 0.5),
            ),
            child: Column(
              children: steps.asMap().entries.map((e) {
                final step = e.value;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width:  32,
                            height: 32,
                            decoration: BoxDecoration(
                              color:        NomadColors.primary.withValues(alpha: 0.1),
                              shape:        BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(step.emoji,
                                style: const TextStyle(fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(step.title,
                                  style: const TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: NomadColors.feedIconColor)),
                                Text(step.subtitle,
                                  style: TextStyle(fontSize: 12,
                                    color: Colors.grey.shade500, height: 1.4)),
                              ],
                            ),
                          ),
                          if (step.onTap != null)
                            GestureDetector(
                              onTap: () => step.onTap!(context),
                              child: const Icon(Icons.chevron_right_rounded,
                                color: NomadColors.primary, size: 20),
                            ),
                        ],
                      ),
                    ),
                    if (e.key < steps.length - 1)
                      Divider(height: 1, color: Colors.grey.shade100),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  List<_NextStep> _buildSteps(MigrationProfile p) {
    final dest   = p.destinationCountry;
    final steps  = <_NextStep>[];

    steps.add(_NextStep(
      emoji:    '🏥',
      title:    'Registrarte en el sistema de salud',
      subtitle: _healthcareInstructions(dest),
      onTap:    (ctx) => Navigator.push(ctx,
          MaterialPageRoute(builder: (_) => const LegalScreen())),
    ));

    if (p.profileType == MigrantProfileType.professional ||
        p.profileType == MigrantProfileType.nomad) {
      steps.add(_NextStep(
        emoji:    '💼',
        title:    'Buscar empleo con ofertas para migrantes',
        subtitle: 'Filtrá por "acepta migrantes" y por tu tipo de visa.',
        onTap:    (ctx) => Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const EmpleoScreen())),
      ));
    }

    steps.add(_NextStep(
      emoji:    '🤝',
      title:    'Conectarte con la comunidad local',
      subtitle: 'Grupos de compatriotas y actividades en tu ciudad.',
      onTap:    (ctx) => Navigator.push(ctx,
          MaterialPageRoute(builder: (_) => const SocialScreen())),
    ));

    steps.add(_NextStep(
      emoji:    '📋',
      title:    'Validar tu título universitario',
      subtitle: _credentialInstructions(dest),
      onTap:    (ctx) => Navigator.push(ctx,
          MaterialPageRoute(builder: (_) => const LegalScreen())),
    ));

    steps.add(_NextStep(
      emoji:    '💰',
      title:    'Configurar envío de remesas',
      subtitle: 'Wise y Remitly son las opciones más económicas para tu corredor.',
    ));

    return steps;
  }

  String _healthcareInstructions(String code) {
    switch (code) {
      case 'CA': return 'Registrate en Alberta Health Services (3 meses de carencia).';
      case 'ES': return 'Con el TIE y padrón, pedí cita en el centro de salud más cercano.';
      case 'PT': return 'Con la AR, registrate en el Centro de Saúde de tu barrio.';
      case 'DE': return 'Alta automática al firmar contrato laboral (Krankenversicherung).';
      default:   return 'Consultá el organismo de salud local para registrarte.';
    }
  }

  String _credentialInstructions(String code) {
    switch (code) {
      case 'CA': return 'WES (World Education Services) — proceso online, 7–10 semanas.';
      case 'ES': return 'ANECA para títulos universitarios — proceso: educacion.gob.es.';
      case 'DE': return 'Verificá en anabin.kmk.org si tu título está reconocido.';
      default:   return 'Consultá el organismo de reconocimiento de títulos local.';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RED DE SEGURIDAD
// ══════════════════════════════════════════════════════════════════════════════

class _SafetyNetSection extends StatelessWidget {
  final MigrationProfile profile;
  const _SafetyNetSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        const Color(0xFFF0FDFA),
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: const Color(0xFF99F6E4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🛡️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Text(
                  '¿Las cosas no salen como esperabas?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: NomadColors.feedIconColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Si necesitás apoyo o considerás volver a casa, '
              'existen programas gratuitos de la OIM para ayudarte. '
              'No estás solo.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600,
                height: 1.6),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SafetyNetButton(
                    emoji:    '📞',
                    label:    'Contactar OIM',
                    subtitle: 'Asesoría gratuita',
                    onTap:    () {
                      // launchUrl(Uri.parse('tel:${_iomPhone(profile.destinationCountry)}'));
                      debugPrint('[Integration] Contactando OIM');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SafetyNetButton(
                    emoji:    '🏡',
                    label:    'Retorno voluntario',
                    subtitle: 'Programa AVRR',
                    onTap:    () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LegalScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Fuente: OIM — Programa AVRR (Assisted Voluntary Return and Reintegration)',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  String _iomPhone(String code) {
    switch (code) {
      case 'ES': return '+34914457116';
      case 'CA': return '+16132329011';
      case 'PT': return '+351213585500';
      case 'DE': return '+4930278780';
      default:   return '+41227179111'; // OIM Ginebra
    }
  }
}

class _SafetyNetButton extends StatelessWidget {
  final String       emoji;
  final String       label;
  final String       subtitle;
  final VoidCallback onTap;

  const _SafetyNetButton({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: NomadColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: NomadColors.primaryDark)),
                  Text(subtitle,
                    style: TextStyle(fontSize: 10,
                      color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS HELPERS
// ══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String  emoji;
  final String  title;
  final EdgeInsets padding;
  final Widget? action;

  const _SectionHeader({
    required this.emoji,
    required this.title,
    required this.padding,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      Colors.grey.shade500,
                letterSpacing: .04,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String  emoji;
  final String  message;
  final Widget? action;

  const _EmptyState({
    required this.emoji,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500,
              height: 1.5),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

// ── Modelos internos ──────────────────────────────────────────────────────────

class _NextStep {
  final String   emoji;
  final String   title;
  final String   subtitle;
  final void Function(BuildContext)? onTap;

  const _NextStep({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
}

class _DocAlert {
  final String     title;
  final String     subtitle;
  final _AlertLevel level;
  final String?    actionText;

  const _DocAlert({
    required this.title,
    required this.subtitle,
    required this.level,
    this.actionText,
  });
}

enum _AlertLevel { urgent, warning, info }
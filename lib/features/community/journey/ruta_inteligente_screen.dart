// lib/features/community/journey/ruta_inteligente_screen.dart
//
// Pantalla principal de la Ruta Inteligente: timeline, presupuesto,
// próximos pasos y casos similares.

import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../../../services/migration_data_model.dart';
import '../../../services/ruta_service.dart';
import 'ruta_quiz_screen.dart';

class RutaInteligenteScreen extends StatefulWidget {
  final RutaInteligente ruta;

  const RutaInteligenteScreen({super.key, required this.ruta});

  @override
  State<RutaInteligenteScreen> createState() => _RutaInteligenteScreenState();
}

class _RutaInteligenteScreenState extends State<RutaInteligenteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  static const _tabs = ['Ruta', 'Presupuesto', 'Ahora', 'Casos'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ruta;
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [

          SliverAppBar(
            expandedHeight: 200,
            floating:       false,
            pinned:         true,
            elevation:      0,
            backgroundColor: NomadColors.feedHeaderBg,
            leading: IconButton(
              icon:  const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: NomadColors.feedIconColor,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon:  const Icon(Icons.edit_outlined, size: 20),
                color: NomadColors.feedIconColor,
                tooltip: 'Editar quiz',
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RutaQuizScreen(perfilBase: r.perfil),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _RutaHero(ruta: r),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              color: NomadColors.feedHeaderBg,
              child: TabBar(
                controller: _tabCtrl,
                tabs:       _tabs.map((t) => Tab(text: t)).toList(),
                labelColor:            NomadColors.primary,
                unselectedLabelColor:  Colors.grey.shade400,
                indicatorColor:        NomadColors.primary,
                indicatorWeight:       2,
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
            _TabTimeline(ruta: r),
            _TabPresupuesto(ruta: r),
            _TabAhora(ruta: r),
            _TabCasos(ruta: r),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HERO
// ═════════════════════════════════════════════════════════════════════════════

class _RutaHero extends StatelessWidget {
  final RutaInteligente ruta;
  const _RutaHero({required this.ruta});

  @override
  Widget build(BuildContext context) {
    final r = ruta;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [NomadColors.primary, NomadColors.primaryDark],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(r.perfil.profileType.emoji,
                style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(r.perfil.profileType.label,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
              const Spacer(),
              if (r.perfil.urgencyLevel != null)
                _HeroBadge(
                  label: r.perfil.urgencyLevel!.label.split(' ').first,
                  emoji: r.perfil.urgencyLevel!.emoji,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${r.perfil.originCountryName} → ${r.perfil.destinationCountryName}',
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 22,
              fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
          ),
          if (r.perfil.targetCity != null)
            Text(r.perfil.targetCity!,
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeroStat(
                label: 'DURACIÓN',
                value: '${r.totalMeses} meses',
              ),
              const SizedBox(width: 20),
              _HeroStat(
                label: 'PRESUPUESTO',
                value: 'USD ${r.presupuesto.total.toStringAsFixed(0)}',
              ),
              const SizedBox(width: 20),
              _HeroStat(
                label: 'PASOS',
                value: '${r.timeline.fold<int>(0, (s, m) => s + m.tareas.length)}',
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

class _HeroBadge extends StatelessWidget {
  final String emoji;
  final String label;
  const _HeroBadge({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text('$emoji $label',
        style: const TextStyle(fontSize: 11, color: Colors.white,
          fontWeight: FontWeight.w500)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — TIMELINE
// ═════════════════════════════════════════════════════════════════════════════

class _TabTimeline extends StatefulWidget {
  final RutaInteligente ruta;
  const _TabTimeline({required this.ruta});

  @override
  State<_TabTimeline> createState() => _TabTimelineState();
}

class _TabTimelineState extends State<_TabTimeline> {
  int? _expandido;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      itemCount: widget.ruta.timeline.length,
      itemBuilder: (context, i) {
        final mes    = widget.ruta.timeline[i];
        final ultimo = i == widget.ruta.timeline.length - 1;
        return _MesCard(
          mes:        mes,
          index:      i,
          isLast:     ultimo,
          expandido:  _expandido == i,
          onToggle:   () => setState(() =>
            _expandido = _expandido == i ? null : i),
        );
      },
    );
  }
}

class _MesCard extends StatelessWidget {
  final RutaMes  mes;
  final int      index;
  final bool     isLast;
  final bool     expandido;
  final VoidCallback onToggle;

  const _MesCard({
    required this.mes,
    required this.index,
    required this.isLast,
    required this.expandido,
    required this.onToggle,
  });

  static const _faseColors = {
    MigrantPhase.discovery:   Color(0xFF6366F1), // indigo
    MigrantPhase.preparation: Color(0xFFF59E0B), // amber
    MigrantPhase.transition:  Color(0xFF10B981), // emerald
    MigrantPhase.integration: NomadColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final color = _faseColors[mes.fase] ?? NomadColors.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Línea de tiempo
          Column(
            children: [
              Container(
                width:  36, height: 36,
                decoration: BoxDecoration(
                  color:        color,
                  shape:        BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color:       color.withValues(alpha: 0.3),
                    blurRadius:  6, spreadRadius: 1)],
                ),
                child: Center(
                  child: Text('${mes.mesNumero}',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Tarjeta del mes
          Expanded(
            child: GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: expandido
                        ? color.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.07),
                    width: expandido ? 1.2 : 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header del mes
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Text(mes.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mes ${mes.mesNumero}: ${mes.titulo}',
                                  style: const TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: NomadColors.feedIconColor)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:        color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(mes.fase.label,
                                        style: TextStyle(fontSize: 10,
                                          fontWeight: FontWeight.w600, color: color)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('${mes.tareas.length} tareas',
                                      style: TextStyle(fontSize: 11,
                                        color: Colors.grey.shade400)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            expandido
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey.shade400, size: 20,
                          ),
                        ],
                      ),
                    ),

                    // Tareas (expandidas)
                    if (expandido) ...[
                      Divider(height: 1, color: Colors.grey.shade100),
                      ...mes.tareas.asMap().entries.map((e) => _TareaRow(
                        tarea: e.value,
                        isLast: e.key == mes.tareas.length - 1,
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TareaRow extends StatelessWidget {
  final RutaTarea tarea;
  final bool      isLast;

  const _TareaRow({required this.tarea, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                tarea.esRequerida
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: tarea.esRequerida
                    ? NomadColors.primary
                    : Colors.grey.shade300,
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(tarea.titulo,
                            style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: NomadColors.feedIconColor)),
                        ),
                        if (tarea.esRequerida)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color:        NomadColors.feedBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('REQ.',
                              style: TextStyle(fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade400)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(tarea.detalle,
                      style: TextStyle(fontSize: 12,
                        color: Colors.grey.shade500, height: 1.45)),
                    if (tarea.costoEstimado != null ||
                        tarea.duracionEstimada != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (tarea.costoEstimado != null) ...[
                            Icon(Icons.attach_money_rounded,
                              size: 11, color: Colors.grey.shade400),
                            const SizedBox(width: 2),
                            Text(tarea.costoEstimado!,
                              style: TextStyle(fontSize: 11,
                                color: Colors.grey.shade400)),
                            const SizedBox(width: 10),
                          ],
                          if (tarea.duracionEstimada != null) ...[
                            Icon(Icons.access_time_rounded,
                              size: 11, color: Colors.grey.shade400),
                            const SizedBox(width: 2),
                            Text(tarea.duracionEstimada!,
                              style: TextStyle(fontSize: 11,
                                color: Colors.grey.shade400)),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade50),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — PRESUPUESTO
// ═════════════════════════════════════════════════════════════════════════════

class _TabPresupuesto extends StatelessWidget {
  final RutaInteligente ruta;
  const _TabPresupuesto({required this.ruta});

  @override
  Widget build(BuildContext context) {
    final p = ruta.presupuesto;

    final partidas = [
      _Partida('Visa', p.visa, Icons.travel_explore_rounded, const Color(0xFF6366F1)),
      _Partida('Documentos / apostillas', p.documentos, Icons.description_outlined, const Color(0xFFF59E0B)),
      _Partida('Vuelo', p.vuelo, Icons.flight_rounded, const Color(0xFF10B981)),
      _Partida('1er mes alquiler', p.primerMesAlquiler, Icons.home_outlined, NomadColors.primary),
      _Partida('Depósito', p.deposito, Icons.lock_outlined, const Color(0xFFEC4899)),
      _Partida('Colchón (3 meses)', p.colchon, Icons.shield_outlined, const Color(0xFF14B8A6)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [

        // Total destacado
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [NomadColors.primary, NomadColors.primaryDark],
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('Presupuesto total estimado',
                style: TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 6),
              Text('USD ${p.total.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 36,
                  fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Para ${ruta.perfil.destinationCountryName} · ${ruta.totalMeses} meses',
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Gráfico de barras
        _BudgetChart(partidas: partidas, total: p.total),
        const SizedBox(height: 20),

        // Desglose detallado
        const _SectionTitle(title: '📋  Desglose detallado'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.07), width: 0.5),
          ),
          child: Column(
            children: partidas.asMap().entries.map((e) {
              final isLast = e.key == partidas.length - 1;
              final item   = e.value;
              final pct    = (item.monto / p.total * 100).toInt();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color:        item.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.icono, color: item.color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.nombre,
                                style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: NomadColors.feedIconColor)),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value:           item.monto / p.total,
                                  backgroundColor: NomadColors.feedBg,
                                  valueColor: AlwaysStoppedAnimation(item.color),
                                  minHeight: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('USD ${item.monto.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: NomadColors.feedIconColor)),
                            Text('$pct%',
                              style: TextStyle(fontSize: 11,
                                color: Colors.grey.shade400)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Nota sobre el colchón
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El colchón de emergencia es 3 meses de costo de vida. No lo uses a menos que sea absolutamente necesario — es tu red de seguridad.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600,
                    height: 1.5),
                ),
              ),
            ],
          ),
        ),

        // Compatibilidad con su budget declarado
        if (ruta.perfil.budgetRange != null) ...[
          const SizedBox(height: 16),
          _BudgetCompatibilityCard(
            budgetDisponible: ruta.perfil.budgetRange!.midpointUsd,
            budgetNecesario:  ruta.presupuesto.total,
          ),
        ],
      ],
    );
  }
}

class _Partida {
  final String name;
  final String nombre;
  final double monto;
  final IconData icono;
  final Color   color;

  _Partida(this.nombre, this.monto, this.icono, this.color) : name = nombre;
}

class _BudgetChart extends StatelessWidget {
  final List<_Partida> partidas;
  final double         total;

  const _BudgetChart({required this.partidas, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text('Distribución del presupuesto',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: NomadColors.feedIconColor)),
          const SizedBox(height: 16),
          // Barra apilada
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 24,
              child: Row(
                children: partidas.map((p) => Flexible(
                  flex: (p.monto / total * 1000).round(),
                  child: Container(color: p.color),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Leyenda
          Wrap(
            spacing: 12, runSpacing: 6,
            children: partidas.map((p) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: p.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(p.nombre.split(' ').first,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _BudgetCompatibilityCard extends StatelessWidget {
  final double budgetDisponible;
  final double budgetNecesario;

  const _BudgetCompatibilityCard({
    required this.budgetDisponible,
    required this.budgetNecesario,
  });

  @override
  Widget build(BuildContext context) {
    final suficiente = budgetDisponible >= budgetNecesario;
    final diferencia = (budgetDisponible - budgetNecesario).abs();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        suficiente ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: suficiente ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          Text(suficiente ? '✅' : '⚠️',
            style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              suficiente
                  ? 'Tu presupuesto declarado (≈ USD ${budgetDisponible.toInt()}) es compatible con esta ruta.'
                  : 'Tu presupuesto está USD ${diferencia.toInt()} por debajo del estimado. Podés ajustar la urgencia o reducir el colchón inicial.',
              style: TextStyle(fontSize: 12,
                color: suficiente
                    ? const Color(0xFF166534)
                    : const Color(0xFF92400E),
                height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — AHORA (próximos pasos)
// ═════════════════════════════════════════════════════════════════════════════

class _TabAhora extends StatelessWidget {
  final RutaInteligente ruta;
  const _TabAhora({required this.ruta});

  @override
  Widget build(BuildContext context) {
    final pasos = ruta.proximosPasos;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [

        // Callout "Ahora necesitas esto"
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                NomadColors.primary.withValues(alpha: 0.1),
                NomadColors.primary.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: NomadColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  const Text('Ahora necesitás esto',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: NomadColors.feedIconColor)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Basado en tu fase actual (${ruta.perfil.currentPhase.label}) y urgencia.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Lista de próximos pasos
        ...pasos.asMap().entries.map((e) => _PasoCard(
          numero: e.key + 1,
          texto:  e.value,
        )),
        const SizedBox(height: 24),

        // Fase actual + descripción
        _FaseActualCard(fase: ruta.perfil.currentPhase),
        const SizedBox(height: 20),

        // CTA comunidad
        _ComunidadCTA(ruta: ruta),
      ],
    );
  }
}

class _PasoCard extends StatelessWidget {
  final int    numero;
  final String texto;

  const _PasoCard({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color:  NomadColors.primary,
              shape:  BoxShape.circle,
            ),
            child: Center(
              child: Text('$numero',
                style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto,
              style: const TextStyle(fontSize: 14,
                color: NomadColors.feedIconColor, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _FaseActualCard extends StatelessWidget {
  final MigrantPhase fase;
  const _FaseActualCard({required this.fase});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Row(
        children: [
          Text(fase.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estás en: ${fase.label}',
                  style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NomadColors.feedIconColor)),
                const SizedBox(height: 4),
                Text(fase.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500,
                    height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComunidadCTA extends StatelessWidget {
  final RutaInteligente ruta;
  const _ComunidadCTA({required this.ruta});

  @override
  Widget build(BuildContext context) {
    final dest = ruta.perfil.destinationCountryName;
    final tipo = ruta.perfil.profileType.label.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        NomadColors.feedHeaderBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💬  Preguntale a alguien que ya lo hizo',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: NomadColors.feedIconColor)),
          const SizedBox(height: 8),
          Text(
            'En Nomad hay $tipo que ya hicieron exactamente tu ruta a $dest. Podés conectar con ellos en la comunidad.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon:  const Icon(Icons.people_outline_rounded, size: 16),
              label: const Text('Ver comunidad'),
              style: OutlinedButton.styleFrom(
                foregroundColor: NomadColors.primary,
                side: const BorderSide(color: NomadColors.primary, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — CASOS SIMILARES
// ═════════════════════════════════════════════════════════════════════════════

class _TabCasos extends StatelessWidget {
  final RutaInteligente ruta;
  const _TabCasos({required this.ruta});

  @override
  Widget build(BuildContext context) {
    final casos = ruta.casosSimilares;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        NomadColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${casos.length} persona${casos.length != 1 ? "s" : ""} con un perfil similar a vos llegaron a ${ruta.perfil.destinationCountryName}. Así lo hicieron:',
            style: const TextStyle(fontSize: 13, color: NomadColors.feedIconColor,
              height: 1.5),
          ),
        ),
        const SizedBox(height: 16),

        ...casos.map((c) => _CasoCard(caso: c)),
        const SizedBox(height: 20),

        // Disclaimer
        Text(
          '* Los casos son representativos y basados en perfiles reales anonimizados. En futuras versiones se conectarán con miembros reales de la comunidad.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.5,
            fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

class _CasoCard extends StatelessWidget {
  final CasoSimilar caso;
  const _CasoCard({required this.caso});

  static final _colores = [
    const Color(0xFF6366F1),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    NomadColors.primary,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colores[caso.nombre.codeUnitAt(0) % _colores.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color:  color.withValues(alpha: 0.1),
                    shape:  BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(caso.nombre[0],
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                        color: color)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(caso.nombre,
                        style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: NomadColors.feedIconColor)),
                      Text('${caso.profesion} · ${caso.origen}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
                // Badge de tiempo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:        color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${caso.mesesQueLesTardo}m',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: color)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caso.resumenHistoria,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600,
                    height: 1.55)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:        color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                        color: color, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(caso.consejoPrincipal,
                          style: TextStyle(fontSize: 12, color: color,
                            fontWeight: FontWeight.w500, height: 1.4)),
                      ),
                    ],
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

// ═════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: Colors.grey.shade500, letterSpacing: .04));
  }
}

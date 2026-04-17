// lib/features/community/journey/ruta_quiz_screen.dart
//
// Quiz de 5 pasos que recoge el perfil completo para generar la Ruta Inteligente.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app_theme.dart';
import '../../../services/migration_data_model.dart';
import '../../../services/ruta_service.dart';
import 'ruta_inteligente_screen.dart';

class RutaQuizScreen extends StatefulWidget {
  /// Si se pasa un perfil base (del dashboard existente), se pre-rellena.
  final MigrationProfile? perfilBase;

  const RutaQuizScreen({super.key, this.perfilBase});

  @override
  State<RutaQuizScreen> createState() => _RutaQuizScreenState();
}

class _RutaQuizScreenState extends State<RutaQuizScreen> {
  int _paso = 0;
  static const _totalPasos = 5;

  // ── Respuestas del quiz ────────────────────────────────────────────────────
  String?             _destinoCode;
  String?             _destinoNombre;
  String?             _origenCode;
  String?             _origenNombre;
  String?             _ciudad;
  MigrantProfileType? _perfil;
  BudgetRange?        _budget;
  UrgencyLevel?       _urgencia;
  bool                _tieneHijos = false;

  @override
  void initState() {
    super.initState();
    // Pre-rellenar con datos existentes si se pasó un perfil
    final p = widget.perfilBase;
    if (p != null) {
      _destinoCode   = p.destinationCountry;
      _destinoNombre = p.destinationCountryName;
      _origenCode    = p.originCountry;
      _origenNombre  = p.originCountryName;
      _ciudad        = p.targetCity;
      _perfil        = p.profileType;
      _budget        = p.budgetRange;
      _urgencia      = p.urgencyLevel;
      _tieneHijos    = p.hasChildren;
    }
  }

  bool get _puedeAvanzar {
    switch (_paso) {
      case 0: return _destinoCode != null && _origenCode != null;
      case 1: return _perfil != null;
      case 2: return _budget != null;
      case 3: return _urgencia != null;
      case 4: return true; // paso opcional
      default: return false;
    }
  }

  void _avanzar() {
    if (_paso < _totalPasos - 1) {
      setState(() => _paso++);
    } else {
      _generarRuta();
    }
  }

  void _retroceder() {
    if (_paso > 0) setState(() => _paso--);
  }

  void _generarRuta() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final perfil = MigrationProfile(
      userId:                uid,
      originCountry:         _origenCode!,
      originCountryName:     _origenNombre!,
      destinationCountry:    _destinoCode!,
      destinationCountryName: _destinoNombre!,
      profileType:           _perfil!,
      currentPhase:          widget.perfilBase?.currentPhase ?? MigrantPhase.discovery,
      hasChildren:           _tieneHijos,
      targetCity:            _ciudad,
      budgetRange:           _budget,
      urgencyLevel:          _urgencia,
      createdAt:             widget.perfilBase?.createdAt ?? DateTime.now(),
      updatedAt:             DateTime.now(),
    );

    final ruta = RutaService.generate(perfil);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RutaInteligenteScreen(ruta: ruta)),
    );
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      appBar: AppBar(
        backgroundColor: NomadColors.feedHeaderBg,
        elevation:       0,
        leading: IconButton(
          icon:  const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: NomadColors.feedIconColor,
          onPressed: _paso == 0 ? () => Navigator.pop(context) : _retroceder,
        ),
        centerTitle: true,
        title: const Text('Ruta Inteligente',
          style: TextStyle(fontFamily: 'Georgia', fontSize: 20,
            fontWeight: FontWeight.w700, color: NomadColors.primary)),
      ),
      body: Column(
        children: [
          _ProgressBar(paso: _paso, total: _totalPasos),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_paso),
                  child: _buildPaso(),
                ),
              ),
            ),
          ),
          _BottomBar(
            puedeAvanzar: _puedeAvanzar,
            esUltimoPaso: _paso == _totalPasos - 1,
            onAvanzar:    _avanzar,
          ),
        ],
      ),
    );
  }

  Widget _buildPaso() {
    switch (_paso) {
      case 0: return _Paso0OrigenDestino(
        destinoCode:   _destinoCode,
        destinoNombre: _destinoNombre,
        origenCode:    _origenCode,
        origenNombre:  _origenNombre,
        ciudad:        _ciudad,
        onDestinoChanged: (code, nombre) => setState(() {
          _destinoCode   = code;
          _destinoNombre = nombre;
          _ciudad        = null;
        }),
        onOrigenChanged: (code, nombre) => setState(() {
          _origenCode   = code;
          _origenNombre = nombre;
        }),
        onCiudadChanged: (c) => setState(() => _ciudad = c),
      );
      case 1: return _Paso1Perfil(
        selected: _perfil,
        onChanged: (p) => setState(() => _perfil = p),
      );
      case 2: return _Paso2Budget(
        selected:  _budget,
        onChanged: (b) => setState(() => _budget = b),
      );
      case 3: return _Paso3Urgencia(
        selected:  _urgencia,
        onChanged: (u) => setState(() => _urgencia = u),
      );
      case 4: return _Paso4Detalles(
        tieneHijos:       _tieneHijos,
        onHijosChanged:   (v) => setState(() => _tieneHijos = v),
      );
      default: return const SizedBox.shrink();
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PASOS
// ═════════════════════════════════════════════════════════════════════════════

// ── Paso 0: Origen + Destino ─────────────────────────────────────────────────

class _Paso0OrigenDestino extends StatelessWidget {
  final String? destinoCode;
  final String? destinoNombre;
  final String? origenCode;
  final String? origenNombre;
  final String? ciudad;
  final void Function(String code, String nombre) onDestinoChanged;
  final void Function(String code, String nombre) onOrigenChanged;
  final void Function(String ciudad)              onCiudadChanged;

  const _Paso0OrigenDestino({
    required this.destinoCode,
    required this.destinoNombre,
    required this.origenCode,
    required this.origenNombre,
    required this.ciudad,
    required this.onDestinoChanged,
    required this.onOrigenChanged,
    required this.onCiudadChanged,
  });

  static const _destinos = [
    ('CA', 'Canadá',       '🇨🇦'),
    ('ES', 'España',       '🇪🇸'),
    ('PT', 'Portugal',     '🇵🇹'),
    ('DE', 'Alemania',     '🇩🇪'),
    ('MX', 'México',       '🇲🇽'),
    ('AU', 'Australia',    '🇦🇺'),
    ('GB', 'Reino Unido',  '🇬🇧'),
    ('NL', 'Países Bajos', '🇳🇱'),
    ('UY', 'Uruguay',      '🇺🇾'),
    ('CL', 'Chile',        '🇨🇱'),
  ];

  static const _origenes = [
    ('AR', 'Argentina',  '🇦🇷'),
    ('MX', 'México',     '🇲🇽'),
    ('CO', 'Colombia',   '🇨🇴'),
    ('PE', 'Perú',       '🇵🇪'),
    ('VE', 'Venezuela',  '🇻🇪'),
    ('CL', 'Chile',      '🇨🇱'),
    ('BO', 'Bolivia',    '🇧🇴'),
    ('UY', 'Uruguay',    '🇺🇾'),
    ('EC', 'Ecuador',    '🇪🇨'),
    ('PY', 'Paraguay',   '🇵🇾'),
  ];

  static const _ciudades = {
    'CA': ['Toronto', 'Calgary', 'Vancouver', 'Montreal'],
    'ES': ['Madrid', 'Barcelona', 'Valencia', 'Sevilla'],
    'PT': ['Lisboa', 'Porto', 'Braga'],
    'DE': ['Berlín', 'Múnich', 'Hamburgo', 'Frankfurt'],
    'AU': ['Sídney', 'Melbourne', 'Brisbane', 'Perth'],
    'GB': ['Londres', 'Manchester', 'Edimburgo'],
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuizHeader(
          emoji: '🗺️',
          titulo: '¿De dónde venís\ny a dónde vas?',
          subtitulo: 'Esto define qué visas, costos y tiempos aplican a tu ruta.',
        ),
        const SizedBox(height: 28),

        // País origen
        const _SectionLabel(label: 'País de origen'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _origenes.map((o) {
            final sel = origenCode == o.$1;
            return _ChipOption(
              emoji:    o.$3,
              label:    o.$2,
              selected: sel,
              onTap:    () => onOrigenChanged(o.$1, o.$2),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),

        // País destino
        const _SectionLabel(label: 'País destino'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _destinos.map((d) {
            final sel = destinoCode == d.$1;
            return _ChipOption(
              emoji:    d.$3,
              label:    d.$2,
              selected: sel,
              onTap:    () => onDestinoChanged(d.$1, d.$2),
            );
          }).toList(),
        ),

        // Ciudad (opcional)
        if (destinoCode != null &&
            (_ciudades[destinoCode] ?? []).isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel(label: 'Ciudad destino (opcional)'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: (_ciudades[destinoCode] ?? []).map((c) {
              final sel = ciudad == c;
              return _ChipOption(
                label:    c,
                selected: sel,
                onTap:    () => onCiudadChanged(c),
                compact:  true,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Paso 1: Tipo de perfil ────────────────────────────────────────────────────

class _Paso1Perfil extends StatelessWidget {
  final MigrantProfileType? selected;
  final ValueChanged<MigrantProfileType> onChanged;

  const _Paso1Perfil({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuizHeader(
          emoji: '👤',
          titulo: '¿Cuál es tu\nmotivo principal?',
          subtitulo: 'Define qué visas aplican y cómo personalizar tu ruta.',
        ),
        const SizedBox(height: 28),
        ...MigrantProfileType.values.map((p) {
          final sel = selected == p;
          return GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin:  const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: sel
                    ? NomadColors.primary.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: sel
                      ? NomadColors.primary
                      : Colors.black.withValues(alpha: 0.08),
                  width: sel ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Text(p.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
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
                      color: NomadColors.primary, size: 20),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Paso 2: Presupuesto ───────────────────────────────────────────────────────

class _Paso2Budget extends StatelessWidget {
  final BudgetRange? selected;
  final ValueChanged<BudgetRange> onChanged;

  const _Paso2Budget({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuizHeader(
          emoji: '💰',
          titulo: '¿Cuánto tenés\ndisponible para migrar?',
          subtitulo: 'Incluí todo: visa + documentos + vuelo + instalación + colchón de emergencia.',
        ),
        const SizedBox(height: 28),
        ...BudgetRange.values.map((b) {
          final sel = selected == b;
          return GestureDetector(
            onTap: () => onChanged(b),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin:  const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: sel
                    ? NomadColors.primary.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: sel
                      ? NomadColors.primary
                      : Colors.black.withValues(alpha: 0.08),
                  width: sel ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Text(b.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(b.label,
                      style: TextStyle(fontSize: 14,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel
                            ? NomadColors.primaryDark
                            : NomadColors.feedIconColor)),
                  ),
                  if (sel)
                    const Icon(Icons.check_circle_rounded,
                      color: NomadColors.primary, size: 20),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:        NomadColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                color: NomadColors.primary, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El presupuesto afecta la velocidad recomendada y el tipo de ruta. Con menos presupuesto, conviene más tiempo de preparación.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Paso 3: Urgencia / Timeline ───────────────────────────────────────────────

class _Paso3Urgencia extends StatelessWidget {
  final UrgencyLevel? selected;
  final ValueChanged<UrgencyLevel> onChanged;

  const _Paso3Urgencia({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuizHeader(
          emoji: '⏱️',
          titulo: '¿Con qué urgencia\nnecesitás migrar?',
          subtitulo: 'Define el largo y la intensidad de tu ruta personalizada.',
        ),
        const SizedBox(height: 28),
        ...UrgencyLevel.values.map((u) {
          final sel = selected == u;
          return GestureDetector(
            onTap: () => onChanged(u),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin:  const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sel
                    ? NomadColors.primary.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: sel
                      ? NomadColors.primary
                      : Colors.black.withValues(alpha: 0.08),
                  width: sel ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Text(u.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.label,
                          style: TextStyle(fontSize: 14,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                            color: sel
                                ? NomadColors.primaryDark
                                : NomadColors.feedIconColor)),
                        const SizedBox(height: 2),
                        Text('Ruta de ${u.totalMonths} meses',
                          style: TextStyle(fontSize: 12,
                            color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  if (sel)
                    const Icon(Icons.check_circle_rounded,
                      color: NomadColors.primary, size: 20),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Paso 4: Detalles finales ──────────────────────────────────────────────────

class _Paso4Detalles extends StatelessWidget {
  final bool   tieneHijos;
  final ValueChanged<bool> onHijosChanged;

  const _Paso4Detalles({
    required this.tieneHijos,
    required this.onHijosChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuizHeader(
          emoji: '✅',
          titulo: 'Un par de detalles\nmás',
          subtitulo: 'Para afinar tu ruta con lo que más importa.',
        ),
        const SizedBox(height: 28),

        // Hijos
        _ToggleCard(
          emoji:    '👨‍👩‍👧',
          titulo:   '¿Migrás con hijos?',
          subtitulo: 'Agrega requisitos de visas familiares y costos escolares.',
          value:    tieneHijos,
          onChanged: onHijosChanged,
        ),

        const SizedBox(height: 20),

        // Mensaje de cierre
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                NomadColors.primary.withValues(alpha: 0.08),
                NomadColors.primary.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Text('🧭', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Listo. Vamos a generar tu ruta personalizada con timeline, presupuesto y los próximos pasos concretos.',
                  style: TextStyle(fontSize: 13, color: NomadColors.feedIconColor, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS COMPARTIDOS
// ═════════════════════════════════════════════════════════════════════════════

class _ProgressBar extends StatelessWidget {
  final int paso;
  final int total;

  const _ProgressBar({required this.paso, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NomadColors.feedHeaderBg,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Paso ${paso + 1} de $total',
                style: TextStyle(fontSize: 12,
                  color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              Text('${((paso + 1) / total * 100).toInt()}%',
                style: const TextStyle(fontSize: 12,
                  color: NomadColors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value:           (paso + 1) / total,
              backgroundColor: NomadColors.feedBg,
              valueColor: const AlwaysStoppedAnimation(NomadColors.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool puedeAvanzar;
  final bool esUltimoPaso;
  final VoidCallback onAvanzar;

  const _BottomBar({
    required this.puedeAvanzar,
    required this.esUltimoPaso,
    required this.onAvanzar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: NomadColors.feedHeaderBg,
        border: Border(top: BorderSide(
          color: Colors.black.withValues(alpha: 0.06), width: 0.5)),
      ),
      child: SizedBox(
        width:  double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: puedeAvanzar ? onAvanzar : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: NomadColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: NomadColors.primary.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Text(
            esUltimoPaso ? 'Generar mi ruta' : 'Continuar',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _QuizHeader extends StatelessWidget {
  final String emoji;
  final String titulo;
  final String subtitulo;

  const _QuizHeader({
    required this.emoji,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(height: 10),
        Text(titulo,
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 26,
            fontWeight: FontWeight.w700, color: NomadColors.feedIconColor,
            height: 1.2, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text(subtitulo,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500,
            fontWeight: FontWeight.w300, height: 1.4)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
        color: NomadColors.feedIconColor));
  }
}

class _ChipOption extends StatelessWidget {
  final String  label;
  final bool    selected;
  final VoidCallback onTap;
  final String? emoji;
  final bool    compact;

  const _ChipOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical:   compact ? 8  : 10,
        ),
        decoration: BoxDecoration(
          color: selected ? NomadColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(99),
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
            if (emoji != null) ...[
              Text(emoji!, style: TextStyle(fontSize: compact ? 14 : 16)),
              SizedBox(width: compact ? 5 : 7),
            ],
            Text(label,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : NomadColors.feedIconColor,
              )),
          ],
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String  emoji;
  final String  titulo;
  final String  subtitulo;
  final bool    value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.emoji,
    required this.titulo,
    required this.subtitulo,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value
              ? NomadColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value
                ? NomadColors.primary
                : Colors.black.withValues(alpha: 0.08),
            width: value ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                    style: TextStyle(fontSize: 14,
                      fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                      color: NomadColors.feedIconColor)),
                  const SizedBox(height: 2),
                  Text(subtitulo,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500,
                      height: 1.4)),
                ],
              ),
            ),
            Switch(
              value:          value,
              onChanged:      onChanged,
              activeColor:    NomadColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

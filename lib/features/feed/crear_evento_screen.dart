import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';

import '../../../services/event_service.dart';
import '../../../widgets/location_autocomplete_field.dart';
import '../../../services/places_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CrearEventoScreen — crear un evento
// Estética: fondo oscuro #0F0F14, igual que el resto de pantallas de creación.
// ─────────────────────────────────────────────────────────────────────────────

class CrearEventoScreen extends StatefulWidget {
  const CrearEventoScreen({super.key});

  @override
  State<CrearEventoScreen> createState() => _CrearEventoScreenState();
}

class _CrearEventoScreenState extends State<CrearEventoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();

  DateTime? _fecha;
  TimeOfDay? _hora;
  String _tipoEvento = 'Meetup';
  String? _locationPlaceId;
  File? _coverImage;
  bool _guardando = false;

  final _picker = ImagePicker();

  static const _tipos = [
    ('Meetup', '🤝'),
    ('Cultural', '🎭'),
    ('Gastronómico', '🍽️'),
    ('Deportivo', '⚽'),
    ('Otro', '📌'),
  ];

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _lugarCtrl.dispose();
    _capacidadCtrl.dispose();
    super.dispose();
  }

  // ── Foto de portada ────────────────────────────────────────────────────────

  Future<void> _elegirPortada() async {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                PhosphorIcons.images(),
                color: const Color(0xFF34D399),
              ),
              title: Text(
                l10n.gallery,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (picked != null && mounted)
                  setState(() => _coverImage = File(picked.path));
              },
            ),
            ListTile(
              leading: Icon(
                PhosphorIcons.camera(),
                color: const Color(0xFF34D399),
              ),
              title: Text(
                l10n.camera,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (picked != null && mounted)
                  setState(() => _coverImage = File(picked.path));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Date / Time pickers ────────────────────────────────────────────────────

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy.add(const Duration(days: 1)),
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF0D9488),
            onPrimary: Colors.white,
            surface: Color(0xFF1A1A24),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _elegirHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF0D9488),
            onPrimary: Colors.white,
            surface: Color(0xFF1A1A24),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _hora = picked);
  }

  // ── Guardar ────────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fecha == null || _hora == null) {
      _snack(AppLocalizations.of(context).eventErrorDateTime);
      return;
    }

    setState(() => _guardando = true);

    final fechaCompleta = DateTime(
      _fecha!.year,
      _fecha!.month,
      _fecha!.day,
      _hora!.hour,
      _hora!.minute,
    );

    final result = await EventService.createEvent(
      title: _tituloCtrl.text,
      description: _descripcionCtrl.text,
      location: _lugarCtrl.text,
      locationPlaceId: _locationPlaceId,
      fecha: fechaCompleta,
      tipo: _tipoEvento,
      capacidad: int.tryParse(_capacidadCtrl.text),
      coverImage: _coverImage,
    );

    if (!mounted) return;
    setState(() => _guardando = false);

    if (result.error != null) {
      _snack(result.error!);
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).eventSuccess),
        backgroundColor: const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );

  String _fechaFormateada(AppLocalizations l10n) => _fecha == null
      ? l10n.eventPickDate
      : DateFormat("EEE d MMM", 'es').format(_fecha!);

  String _horaFormateada(AppLocalizations l10n) {
    if (_hora == null) return l10n.eventPickTime;
    final h = _hora!.hour.toString().padLeft(2, '0');
    final m = _hora!.minute.toString().padLeft(2, '0');
    return '$h:$m hs';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.eventAppBarTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Foto de portada ──────────────────────────────────────────
              _DarkLabel(
                icono: PhosphorIcons.image(),
                texto: l10n.eventCoverLabel,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _elegirPortada,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                    ),
                    image: _coverImage != null
                        ? DecorationImage(
                            image: FileImage(_coverImage!),
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          )
                        : null,
                  ),
                  child: _coverImage != null
                      ? Stack(
                          children: [
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _coverImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [
                            Container(
                              width: 54,
                              height: 54,

                              decoration: BoxDecoration(
                                shape: BoxShape.circle,

                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF0D9488),
                                    Color(0xFF34D399),
                                  ],
                                ),
                              ),

                              child: Icon(
                                PhosphorIcons.image(),
                                color: Colors.white,
                              ),
                            ),

                            SizedBox(height: 12),

                            Text(
                              l10n.eventCoverPlaceholder,

                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              l10n.eventCoverPlaceholderSub,

                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Tipo de evento ───────────────────────────────────────────
              _DarkLabel(icono: PhosphorIcons.tag(), texto: l10n.eventTypeLabel),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _tipos.map((tipo) {
                    final sel = _tipoEvento == tipo.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _tipoEvento = tipo.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: sel
                              ? LinearGradient(
                                  colors: [
                                    Color(0xFF0D9488),
                                    Color(0xFF34D399),
                                  ],
                                )
                              : null,
                          color: sel
                              ? null
                              : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF0D9488)
                                : Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(tipo.$2, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              tipo.$1,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: sel ? Colors.white : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // ── Título ───────────────────────────────────────────────────
              _DarkLabel(icono: PhosphorIcons.pencilSimple(), texto: l10n.eventTitleLabel),
              const SizedBox(height: 10),
              _DarkField(
                controller: _tituloCtrl,
                hint: l10n.eventTitleHint,
                validator: (v) => v == null || v.trim().isEmpty
                    ? l10n.eventTitleError
                    : null,
              ),

              const SizedBox(height: 24),

              // ── Descripción ──────────────────────────────────────────────
              _DarkLabel(
                icono: PhosphorIcons.textAlignLeft(),
                texto: l10n.eventDescLabel,
              ),
              const SizedBox(height: 10),
              _DarkField(
                controller: _descripcionCtrl,
                hint: l10n.eventDescHint,
                maxLines: 4,
              ),

              const SizedBox(height: 24),

              // ── Fecha y hora ─────────────────────────────────────────────
              _DarkLabel(
                icono: PhosphorIcons.calendarBlank(),
                texto: l10n.eventDateLabel,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SelectorTile(
                      icono: PhosphorIcons.calendarBlank(),
                      label: _fechaFormateada(l10n),
                      activo: _fecha != null,
                      onTap: _elegirFecha,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SelectorTile(
                      icono: PhosphorIcons.clock(),
                      label: _horaFormateada(l10n),
                      activo: _hora != null,
                      onTap: _elegirHora,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Lugar (Places autocomplete) ──────────────────────────────
              _DarkLabel(icono: PhosphorIcons.mapPin(), texto: l10n.eventLocationLabel),
              const SizedBox(height: 10),
              LocationAutocompleteField(
                controller: _lugarCtrl,
                hint: l10n.eventLocationHint,
                dark: true,
                onSelected: (pred, detail) {
                  _locationPlaceId = pred.placeId;
                  _lugarCtrl.text = pred.description;
                },
              ),

              const SizedBox(height: 24),

              // ── Capacidad máxima ─────────────────────────────────────────
              _DarkLabel(
                icono: PhosphorIcons.users(),
                texto: l10n.eventCapacityLabel,
              ),
              const SizedBox(height: 10),
              _DarkField(
                controller: _capacidadCtrl,
                hint: l10n.eventCapacityHint,
                keyboardType: TextInputType.number,
                prefixIcon: PhosphorIcons.users(),
              ),

              const SizedBox(height: 42),

              // ── Botón crear ──────────────────────────────────────────────
              GestureDetector(
                onTap: _guardando ? null : _guardar,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF34D399)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: _guardando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                PhosphorIcons.calendarPlus(),
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.eventCreateButton,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares oscuros ────────────────────────────────────────────────

class _DarkLabel extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _DarkLabel({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 14, color: const Color(0xFF0D9488)),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _DarkField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.prefixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: const Color(0xFF5EEAD4), size: 18)
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: InputBorder.none,
          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
        ),
      ),
    );
  }
}

class _SelectorTile extends StatelessWidget {
  final IconData icono;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _SelectorTile({
    required this.icono,
    required this.label,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: activo
              ? const Color(0xFF0D9488).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: activo
                ? const Color(0xFF0D9488).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icono,
              size: 15,
              color: activo ? const Color(0xFF0D9488) : Colors.white38,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
                  color: activo ? Colors.white : Colors.white38,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

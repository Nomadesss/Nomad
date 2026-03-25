import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../services/places_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LocationAutocompleteField — campo de ubicación con sugerencias en tiempo real
//
// Uso:
//   LocationAutocompleteField(
//     hint: 'ej: Buenos Aires, Argentina',
//     onSelected: (prediction, detail) {
//       // prediction.description = "Buenos Aires, Argentina"
//       // detail?.lat / detail?.lng (si se llamó getDetails)
//     },
//   )
//
// Parámetros:
//   dark: true  → fondo oscuro (nueva publicación / evento)
//   dark: false → fondo blanco
// ─────────────────────────────────────────────────────────────────────────────

class LocationAutocompleteField extends StatefulWidget {
  final String hint;
  final bool dark;
  final void Function(PlacePrediction prediction, PlaceDetail? detail) onSelected;
  final TextEditingController? controller;

  const LocationAutocompleteField({
    super.key,
    required this.onSelected,
    this.hint = 'Buscar ubicación...',
    this.dark = true,
    this.controller,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends State<LocationAutocompleteField> {
  late final TextEditingController _ctrl;
  final _sessionToken = const Uuid().v4();
  final _layerLink    = LayerLink();

  List<PlacePrediction> _sugerencias = [];
  Timer? _debounce;
  bool _buscando    = false;
  bool _mostrarLista = false;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cerrarOverlay();
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    final text = _ctrl.text.trim();

    if (text.length < 3) {
      _cerrarOverlay();
      setState(() => _sugerencias = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () => _buscar(text));
  }

  Future<void> _buscar(String query) async {
    if (!mounted) return;
    setState(() => _buscando = true);

    final resultados = await PlacesService.autocomplete(
      query,
      sessionToken: _sessionToken,
    );

    if (!mounted) return;
    setState(() {
      _sugerencias   = resultados;
      _buscando      = false;
      _mostrarLista  = resultados.isNotEmpty;
    });

    if (resultados.isNotEmpty) _mostrarOverlay();
    else _cerrarOverlay();
  }

  Future<void> _seleccionar(PlacePrediction pred) async {
    _ctrl.text = pred.description;
    _cerrarOverlay();
    setState(() => _sugerencias = []);

    // Obtener coordenadas en segundo plano
    final detail = await PlacesService.getDetails(
      pred.placeId,
      sessionToken: _sessionToken,
    );

    if (mounted) widget.onSelected(pred, detail);
  }

  // ── Overlay ────────────────────────────────────────────────────────────────

  void _mostrarOverlay() {
    _cerrarOverlay();
    _overlay = OverlayEntry(builder: (_) => _buildOverlay());
    Overlay.of(context).insert(_overlay!);
  }

  void _cerrarOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildOverlay() {
    return Positioned(
      width: 0,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 52),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: widget.dark ? const Color(0xFF1A1A24) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF0D9488).withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              itemCount: _sugerencias.length,
              itemBuilder: (_, i) {
                final pred = _sugerencias[i];
                return InkWell(
                  onTap: () => _seleccionar(pred),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.mapPin(),
                          size: 15,
                          color: const Color(0xFF0D9488),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pred.mainText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: widget.dark
                                      ? Colors.white
                                      : const Color(0xFF134E4A),
                                ),
                              ),
                              if (pred.secondaryText.isNotEmpty)
                                Text(
                                  pred.secondaryText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: widget.dark
                                        ? Colors.white38
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        decoration: BoxDecoration(
          color: widget.dark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.dark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0xFFE6FAF8),
          ),
        ),
        child: TextField(
          controller: _ctrl,
          style: TextStyle(
            color: widget.dark ? Colors.white : const Color(0xFF134E4A),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: widget.dark ? Colors.white38 : const Color(0xFF9CA3AF),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              PhosphorIcons.mapPin(),
              color: const Color(0xFF0D9488),
              size: 18,
            ),
            suffixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                  )
                : _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 16,
                          color: widget.dark ? Colors.white38 : Colors.grey,
                        ),
                        onPressed: () {
                          _ctrl.clear();
                          _cerrarOverlay();
                        },
                      )
                    : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
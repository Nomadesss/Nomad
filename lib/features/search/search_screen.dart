import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../feed/widgets/bottom_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
// search_screen.dart  –  Nomad App
// Búsqueda inteligente con sugerencias contextuales para migrantes.
// ─────────────────────────────────────────────────────────────────────────────

const _teal = Color(0xFF0D9488);
const _tealLight = Color(0xFF5EEAD4);
const _tealDark = Color(0xFF134E4A);
const _tealBg = Color(0xFFF0FAF9);
const _bgMain = Color(0xFFF8FFFE);

// ─────────────────────────────────────────────────────────────────────────────
// Datos de ejemplo (reemplazar con llamadas a Firestore)
// ─────────────────────────────────────────────────────────────────────────────

const _categoriasIcons = [
  Icons.person_outline_rounded,
  Icons.event_outlined,
  Icons.location_on_outlined,
  Icons.people_outline_rounded,
  Icons.lightbulb_outline_rounded,
  Icons.work_outline_rounded,
];
const _categoriasColors = [
  0xFF0D9488,
  0xFF0891B2,
  0xFF7C3AED,
  0xFF059669,
  0xFFD97706,
  0xFFE11D48,
];

final _sugerenciasPopulares = [
  'Migrantes en México DF',
  'Cómo abrir cuenta bancaria',
  'Visa de trabajo España',
  'Alojamiento temporal Barcelona',
  'Comunidad argentina en Europa',
  'NIE España trámites',
  'Networking nómadas digitales',
  'Seguro médico extranjero',
];

final _resultadosEjemplo = [
  {
    'tipo': 'persona',
    'nombre': 'Lucía Martínez',
    'username': 'lu_martinez',
    'flag': '🇦🇷',
    'ciudad': 'Barcelona',
    'mutualAmigos': 3,
    'siguiendo': false,
  },
  {
    'tipo': 'persona',
    'nombre': 'Carlos Mendoza',
    'username': 'carlosmx',
    'flag': '🇲🇽',
    'ciudad': 'Ciudad de México',
    'mutualAmigos': 1,
    'siguiendo': true,
  },
  {
    'tipo': 'evento',
    'titulo': 'Encuentro de migrantes latinoamericanos',
    'fecha': '15 Abr 2025',
    'lugar': 'Ciudad de México',
    'asistentes': 34,
    'emoji': '🎉',
  },
  {
    'tipo': 'comunidad',
    'nombre': 'Argentinos en España',
    'miembros': 1240,
    'emoji': '🇦🇷🇪🇸',
    'descripcion': 'La comunidad más grande de argentinos en la península',
  },
  {
    'tipo': 'persona',
    'nombre': 'Ana Lima',
    'username': 'analimabr',
    'flag': '🇧🇷',
    'ciudad': 'Lisboa',
    'mutualAmigos': 0,
    'siguiendo': false,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  bool _isSearching = false;
  bool _hasResults = false;
  String _query = '';
  int _categoriaActiveIndex = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _focus.addListener(() {
      setState(() => _isSearching = _focus.hasFocus);
    });

    _ctrl.addListener(() {
      final q = _ctrl.text.trim();
      setState(() {
        _query = q;
        _hasResults = q.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onSugerencia(String text) {
    HapticFeedback.selectionClick();
    _ctrl.text = text;
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    _focus.requestFocus();
  }

  void _limpiar() {
    _ctrl.clear();
    setState(() {
      _query = '';
      _hasResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categorias = [
      {'label': l10n.searchPeople,       'icon': _categoriasIcons[0], 'color': _categoriasColors[0]},
      {'label': l10n.searchEvents,       'icon': _categoriasIcons[1], 'color': _categoriasColors[1]},
      {'label': l10n.searchPlaces,       'icon': _categoriasIcons[2], 'color': _categoriasColors[2]},
      {'label': l10n.searchCommunities,  'icon': _categoriasIcons[3], 'color': _categoriasColors[3]},
      {'label': l10n.searchTips,         'icon': _categoriasIcons[4], 'color': _categoriasColors[4]},
      {'label': l10n.searchJobs,         'icon': _categoriasIcons[5], 'color': _categoriasColors[5]},
    ];

    return Scaffold(
      backgroundColor: _bgMain,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              _buildSearchBar(l10n),
              if (_isSearching && !_hasResults)
                _buildSugerenciasRapidas(l10n)
              else if (_hasResults)
                _buildFiltrosCategorias(categorias),
              Expanded(
                child: _hasResults
                    ? _buildResultados(l10n)
                    : _buildDescubreContenido(l10n, categorias),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar(AppLocalizations l10n) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.fromLTRB(
        16,
        _isSearching ? 12 : 20,
        16,
        _isSearching ? 8 : 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              decoration: BoxDecoration(
                color: _isSearching ? Colors.white : _tealBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isSearching ? _teal : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: _isSearching
                    ? [
                        BoxShadow(
                          color: _teal.withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontSize: 15,
                  color: _tealDark,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: '${l10n.searchPeople}, ${l10n.searchPlaces}, ${l10n.searchEvents}...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  prefixIcon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isSearching
                          ? Icons.search_rounded
                          : Icons.search_rounded,
                      key: ValueKey(_isSearching),
                      color: _isSearching ? _teal : const Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ),
                  suffixIcon: _hasResults
                      ? GestureDetector(
                          onTap: _limpiar,
                          child: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: (_) {},
              ),
            ),
          ),
          if (_isSearching) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                _focus.unfocus();
                _limpiar();
              },
              child: Text(
                l10n.cancelButton,
                style: const TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sugerencias rápidas (cuando el campo está vacío y enfocado) ───────────

  Widget _buildSugerenciasRapidas(AppLocalizations l10n) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.trending_up_rounded, size: 14, color: _teal),
                const SizedBox(width: 6),
                Text(
                  'Nomad',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _teal,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sugerenciasPopulares.take(6).map((s) {
              return GestureDetector(
                onTap: () => _onSugerencia(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _tealBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _tealLight.withOpacity(0.5)),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _tealDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Chips de categorías ───────────────────────────────────────────────────

  Widget _buildFiltrosCategorias(List<Map<String, Object>> categorias) {
    return Container(
      color: Colors.white,
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: categorias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categorias[i];
          final selected = _categoriaActiveIndex == i;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _categoriaActiveIndex = i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? Color(cat['color'] as int)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    cat['icon'] as IconData,
                    size: 14,
                    color: selected ? Colors.white : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    cat['label'] as String,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Resultados de búsqueda ────────────────────────────────────────────────

  Widget _buildResultados(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sugerencias inteligentes basadas en query
        if (_query.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SugerenciaInteligenteCard(query: _query),
          ),

        _ResultSectionLabel(l10n.searchPeople),

        ..._resultadosEjemplo.map((r) {
          if (r['tipo'] == 'persona') {
            return _PersonaResult(data: r);
          } else if (r['tipo'] == 'evento') {
            return _EventoResult(data: r);
          } else if (r['tipo'] == 'comunidad') {
            return _ComunidadResult(data: r);
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  // ── Contenido descubrimiento (estado inicial) ─────────────────────────────

  Widget _buildDescubreContenido(AppLocalizations l10n, List<Map<String, Object>> categorias) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Categorías visuales
        const _ResultSectionLabel('·'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: categorias.map((cat) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _focus.requestFocus();
                _onSugerencia(cat['label'] as String);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Color(cat['color'] as int).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Color(cat['color'] as int).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 28,
                      color: Color(cat['color'] as int),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(cat['color'] as int),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Nómadas cerca tuyo
        _ResultSectionLabel(l10n.mapMigrants),

        const SizedBox(height: 10),

        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _NomadNearbyCard(
                nombre: 'Valeria R.',
                flag: '🇦🇷',
                ciudad: 'CDMX',
                distancia: '2 km',
              ),
              _NomadNearbyCard(
                nombre: 'Pedro S.',
                flag: '🇧🇷',
                ciudad: 'CDMX',
                distancia: '5 km',
              ),
              _NomadNearbyCard(
                nombre: 'Sofía G.',
                flag: '🇨🇴',
                ciudad: 'CDMX',
                distancia: '8 km',
              ),
              _NomadNearbyCard(
                nombre: 'Martín F.',
                flag: '🇺🇾',
                ciudad: 'CDMX',
                distancia: '12 km',
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Búsquedas recientes
        const _ResultSectionLabel('·'),
        const SizedBox(height: 8),
        ..._sugerenciasPopulares
            .take(4)
            .map(
              (s) => _RecentSearchTile(
                texto: s,
                onTap: () => _onSugerencia(s),
                onDelete: () {},
              ),
            ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets de resultado
// ─────────────────────────────────────────────────────────────────────────────

class _SugerenciaInteligenteCard extends StatelessWidget {
  final String query;
  const _SugerenciaInteligenteCard({required this.query});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sugerencia inteligente',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '¿Buscás info sobre "$query" para migrantes en CDMX?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white70,
            size: 14,
          ),
        ],
      ),
    );
  }
}

class _PersonaResult extends StatefulWidget {
  final Map<String, dynamic> data;
  const _PersonaResult({required this.data});

  @override
  State<_PersonaResult> createState() => _PersonaResultState();
}

class _PersonaResultState extends State<_PersonaResult> {
  late bool _siguiendo;

  @override
  void initState() {
    super.initState();
    _siguiendo = widget.data['siguiendo'] as bool;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_teal, _tealLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                d['flag'] as String,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d['nombre'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _tealDark,
                  ),
                ),
                Text(
                  '@${d['username']}',
                  style: const TextStyle(fontSize: 12, color: _teal),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      d['ciudad'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    if ((d['mutualAmigos'] as int) > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.people_outline_rounded,
                        size: 11,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${d['mutualAmigos']} en común',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Botón seguir
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _siguiendo = !_siguiendo);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _siguiendo ? _tealBg : _teal,
                borderRadius: BorderRadius.circular(20),
                border: _siguiendo ? Border.all(color: _tealLight) : null,
              ),
              child: Text(
                _siguiendo ? 'Siguiendo' : 'Seguir',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _siguiendo ? _teal : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventoResult extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EventoResult({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF0891B2).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                data['emoji'] as String,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0891B2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'EVENTO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0891B2),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  data['titulo'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _tealDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      data['fecha'] as String,
                      style: const TextStyle(fontSize: 11, color: _teal),
                    ),
                    const Text(
                      ' · ',
                      style: TextStyle(color: Color(0xFFCBD5E1)),
                    ),
                    Text(
                      data['lugar'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComunidadResult extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ComunidadResult({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                data['emoji'] as String,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'COMUNIDAD',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF059669),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  data['nombre'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _tealDark,
                  ),
                ),
                Text(
                  '${data['miembros']} miembros',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Unirse',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NomadNearbyCard extends StatelessWidget {
  final String nombre;
  final String flag;
  final String ciudad;
  final String distancia;

  const _NomadNearbyCard({
    required this.nombre,
    required this.flag,
    required this.ciudad,
    required this.distancia,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_teal, _tealLight]),
            ),
            child: Center(
              child: Text(flag, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            nombre,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _tealDark,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            distancia,
            style: const TextStyle(fontSize: 10, color: _teal),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentSearchTile({
    required this.texto,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(fontSize: 14, color: _tealDark),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSectionLabel extends StatelessWidget {
  final String text;
  const _ResultSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _teal,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

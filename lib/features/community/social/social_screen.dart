import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import '../../../services/social_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SocialScreen — listado de grupos + detalle + chat grupal
//
// Ubicación: lib/features/community/social/social_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

// Datos de ejemplo — reemplazar con SocialService.streamGroups() cuando
// Firestore tenga datos reales.
final _mockGroups = [
  _GroupData(
    id:          'g1',
    name:        'Fútbol los domingos',
    location:    'Madrid',
    category:    GroupCategory.sport,
    cover:       [Color(0xFFDCFCE7), Color(0xFF86EFAC)],
    emoji:       '⚽',
    description: 'Grupo de fútbol recreativo para migrantes en Madrid. Todos los niveles bienvenidos. Nos juntamos cada domingo en el Retiro para jugar partidos amistosos.',
    freq:        'Cada domingo 10:00',
    place:       'Parque del Retiro',
    memberCount: 34,
    memberInitials: [('L', Color(0xFF86EFAC), Color(0xFF166534)),
                     ('M', Color(0xFFFCA5A5), Color(0xFF7F1D1D)),
                     ('R', Color(0xFF93C5FD), Color(0xFF1E3A8A))],
    events: [
      _EventData(day: '22', mon: 'MAR', title: 'Partido amistoso',    meta: 'Parque del Retiro · 10:00', going: 12),
      _EventData(day: '29', mon: 'MAR', title: 'Torneo de primavera', meta: 'Campo Vallecas · 10:00',   going: 28),
    ],
    messages: [
      _MsgData(initial: 'L', bg: Color(0xFF86EFAC), fg: Color(0xFF166534), name: 'Lucas M.', text: '¿Alguien trae pecheras esta semana?', time: '10:32', isMe: false),
      _MsgData(initial: 'R', bg: Color(0xFF93C5FD), fg: Color(0xFF1E3A8A), name: 'Rodrigo P.', text: 'Yo llevo las rojas 🙋', time: '10:35', isMe: false),
      _MsgData(initial: 'T', bg: Color(0xFFCCFBF1), fg: NomadColors.primaryDark, name: 'Vos', text: 'Perfecto, yo llevo las azules entonces', time: '10:41', isMe: true),
    ],
    members: [
      _MemberData(initial: 'L', bg: Color(0xFF86EFAC), fg: Color(0xFF166534), name: 'Lucas Méndez',  origin: '🇺🇾 Uruguay', isAdmin: true),
      _MemberData(initial: 'R', bg: Color(0xFF93C5FD), fg: Color(0xFF1E3A8A), name: 'Rodrigo Ponce', origin: '🇦🇷 Argentina', isAdmin: false),
      _MemberData(initial: 'M', bg: Color(0xFFFCA5A5), fg: Color(0xFF7F1D1D), name: 'María S.',      origin: '🇨🇴 Colombia', isAdmin: false),
    ],
  ),
  _GroupData(
    id:          'g2',
    name:        'Arte y exposiciones',
    location:    'Barcelona',
    category:    GroupCategory.art,
    cover:       [Color(0xFFFEF3C7), Color(0xFFFCD34D)],
    emoji:       '🎨',
    description: 'Grupo para amantes del arte en Barcelona. Visitamos exposiciones, museos y galerías juntos.',
    freq:        'Quincenal',
    place:       'Varios museos',
    memberCount: 21,
    memberInitials: [('A', Color(0xFFFCD34D), Color(0xFF78350F)),
                     ('S', Color(0xFFC4B5FD), Color(0xFF4C1D95)),
                     ('J', Color(0xFF6EE7B7), Color(0xFF064E3B))],
    events: [
      _EventData(day: '25', mon: 'MAR', title: 'MNAC — Arte románico', meta: 'Museu Nacional · 11:00', going: 8),
      _EventData(day: '5',  mon: 'ABR', title: 'Fundació Miró',        meta: 'Fundació Miró · 10:30', going: 14),
    ],
    messages: [
      _MsgData(initial: 'A', bg: Color(0xFFFCD34D), fg: Color(0xFF78350F), name: 'Ana F.', text: '¡La expo de Dalí en el MNAC es increíble!', time: 'Ayer', isMe: false),
      _MsgData(initial: 'S', bg: Color(0xFFC4B5FD), fg: Color(0xFF4C1D95), name: 'Sofía R.', text: '¿Alguien va el sábado? Me anoto', time: '09:15', isMe: false),
      _MsgData(initial: 'T', bg: Color(0xFFCCFBF1), fg: NomadColors.primaryDark, name: 'Vos', text: 'Yo también voy, quedamos al mediodía', time: '09:22', isMe: true),
    ],
    members: [
      _MemberData(initial: 'A', bg: Color(0xFFFCD34D), fg: Color(0xFF78350F), name: 'Ana Fernández', origin: '🇺🇾 Uruguay',  isAdmin: true),
      _MemberData(initial: 'S', bg: Color(0xFFC4B5FD), fg: Color(0xFF4C1D95), name: 'Sofía Ruiz',    origin: '🇲🇽 México',   isAdmin: false),
      _MemberData(initial: 'J', bg: Color(0xFF6EE7B7), fg: Color(0xFF064E3B), name: 'Julián O.',     origin: '🇦🇷 Argentina', isAdmin: false),
    ],
  ),
  _GroupData(
    id:          'g3',
    name:        'Charlas de migrantes',
    location:    'Madrid',
    category:    GroupCategory.talks,
    cover:       [Color(0xFFEDE9FE), Color(0xFFC4B5FD)],
    emoji:       '🗣️',
    description: 'Espacio para compartir experiencias de migración, consejos y apoyo mutuo. Un lugar donde hablar sin filtros.',
    freq:        'Cada jueves 19:30',
    place:       'Café Central',
    memberCount: 58,
    memberInitials: [('P', Color(0xFFC4B5FD), Color(0xFF4C1D95)),
                     ('C', Color(0xFFFCA5A5), Color(0xFF7F1D1D)),
                     ('D', Color(0xFF93C5FD), Color(0xFF1E3A8A))],
    events: [
      _EventData(day: '20', mon: 'MAR', title: 'Tema: Primer año en España', meta: 'Café Central · 19:30', going: 22),
      _EventData(day: '27', mon: 'MAR', title: 'Tema: Trabajo y visas',      meta: 'Café Central · 19:30', going: 18),
    ],
    messages: [
      _MsgData(initial: 'P', bg: Color(0xFFC4B5FD), fg: Color(0xFF4C1D95), name: 'Pablo T.', text: 'Próxima charla: cómo sobrevivir el primer año 🙌', time: 'Ayer', isMe: false),
      _MsgData(initial: 'C', bg: Color(0xFFFCA5A5), fg: Color(0xFF7F1D1D), name: 'Carmen R.', text: '¡Me anoto! Llevo 3 meses y necesito tips', time: '20:10', isMe: false),
      _MsgData(initial: 'T', bg: Color(0xFFCCFBF1), fg: NomadColors.primaryDark, name: 'Vos', text: 'Genial, hasta el jueves a todos', time: '20:15', isMe: true),
    ],
    members: [
      _MemberData(initial: 'P', bg: Color(0xFFC4B5FD), fg: Color(0xFF4C1D95), name: 'Pablo Torres', origin: '🇺🇾 Uruguay', isAdmin: true),
      _MemberData(initial: 'C', bg: Color(0xFFFCA5A5), fg: Color(0xFF7F1D1D), name: 'Carmen Ríos',  origin: '🇨🇱 Chile',   isAdmin: false),
      _MemberData(initial: 'D', bg: Color(0xFF93C5FD), fg: Color(0xFF1E3A8A), name: 'Diego M.',     origin: '🇺🇾 Uruguay', isAdmin: false),
    ],
  ),
];

// ── SocialScreen ──────────────────────────────────────────────────────────────

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  String _activeFilter = 'Todos';
  final _filters = ['Todos', 'Deporte', 'Arte', 'Idiomas', 'Gastronomía', 'Charlas'];

  List<_GroupData> get _filtered {
    if (_activeFilter == 'Todos') return _mockGroups;
    final map = {
      'Deporte': GroupCategory.sport,
      'Arte': GroupCategory.art,
      'Idiomas': GroupCategory.language,
      'Gastronomía': GroupCategory.food,
      'Charlas': GroupCategory.talks,
    };
    final cat = map[_activeFilter];
    return cat == null
        ? _mockGroups
        : _mockGroups.where((g) => g.category == cat).toList();
  }

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
                icon:  const Icon(Icons.add_rounded, size: 24),
                color: NomadColors.feedIconColor,
                onPressed: () {},
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Social',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: NomadColors.primary, letterSpacing: .12)),
                  const SizedBox(height: 4),
                  const Text('Encontrá tu tribu',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 26,
                      fontWeight: FontWeight.w700, color: NomadColors.feedIconColor,
                      letterSpacing: -0.4)),
                  const SizedBox(height: 4),
                  Text('Grupos de interés para conectar con otros nomads',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500,
                      fontWeight: FontWeight.w300)),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // Filtros
          SliverToBoxAdapter(
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f      = _filters[i];
                  final active = f == _activeFilter;
                  return GestureDetector(
                    onTap: () => setState(() => _activeFilter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? NomadColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: active
                              ? NomadColors.primary
                              : Colors.black.withValues(alpha: 0.1),
                          width: 0.8,
                        ),
                      ),
                      child: Text(f,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: active ? Colors.white : Colors.grey.shade600)),
                    ),
                  );
                },
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('GRUPOS CERCA TUYO · MADRID',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400, letterSpacing: .08)),
            ),
          ),

          // Lista de grupos
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GroupCard(
                    group: _filtered[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(group: _filtered[i]),
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
}

// ── _GroupCard ────────────────────────────────────────────────────────────────

class _GroupCard extends StatefulWidget {
  final _GroupData   group;
  final VoidCallback onTap;

  const _GroupCard({required this.group, required this.onTap});

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _joined = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Cover
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: g.cover,
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(g.emoji,
                    style: const TextStyle(fontSize: 40)),
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name,
                      style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w600, color: NomadColors.feedIconColor)),
                    const SizedBox(height: 2),
                    Text('${g.category.label} · ${g.freq} · ${g.place}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        // Avatars + count
                        Row(
                          children: [
                            SizedBox(
                              width: (g.memberInitials.length * 18.0) + 4,
                              height: 24,
                              child: Stack(
                                children: g.memberInitials.asMap().entries.map((e) =>
                                  Positioned(
                                    left: e.key * 16.0,
                                    child: Container(
                                      width:  24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color:  e.value.$2,
                                        shape:  BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: Center(
                                        child: Text(e.value.$1,
                                          style: TextStyle(fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: e.value.$3)),
                                      ),
                                    ),
                                  ),
                                ).toList(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('+${g.memberCount} miembros',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),

                        // Botón unirse
                        GestureDetector(
                          onTap: () => setState(() => _joined = !_joined),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: _joined ? NomadColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: NomadColors.primary),
                            ),
                            child: Text(
                              _joined ? 'Unido ✓' : 'Unirse',
                              style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _joined ? Colors.white : NomadColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
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

// ── GroupDetailScreen ─────────────────────────────────────────────────────────

class GroupDetailScreen extends StatefulWidget {
  final _GroupData group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  int  _tabIndex = 0;
  bool _joined   = false;
  final _tabs    = ['Eventos', 'Chat', 'Miembros'];

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return Scaffold(
      backgroundColor: NomadColors.feedBg,
      body: CustomScrollView(
        slivers: [

          // App bar con cover
          SliverAppBar(
            expandedHeight: 140,
            pinned:         true,
            elevation:      0,
            backgroundColor: g.cover[0],
            leading: IconButton(
              icon:  const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: Colors.black54,
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: g.cover,
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(g.emoji,
                    style: const TextStyle(fontSize: 64)),
                ),
              ),
            ),
          ),

          // Info del grupo
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 22,
                      fontWeight: FontWeight.w700, color: NomadColors.feedIconColor)),
                  const SizedBox(height: 4),
                  Text('${g.category.label} · ${g.freq} · ${g.place}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
                  const SizedBox(height: 12),

                  // Stats
                  Row(
                    children: [
                      _StatBox(value: '${g.memberCount}', label: 'Miembros'),
                      const SizedBox(width: 16),
                      _StatBox(value: '${g.events.length}', label: 'Eventos'),
                      const SizedBox(width: 16),
                      const _StatBox(value: 'Activo', label: 'Estado'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(g.description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.6)),
                  const SizedBox(height: 14),

                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _joined = !_joined),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _joined ? NomadColors.success : NomadColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                _joined ? '✓ Ya sos miembro' : 'Unirse al grupo',
                                style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width:  44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.grey.shade200),
                        ),
                        child: Icon(Icons.share_outlined,
                          color: Colors.grey.shade500, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tabs
          SliverToBoxAdapter(
            child: Container(
              color:  Colors.white,
              child: Row(
                children: _tabs.asMap().entries.map((e) {
                  final active = e.key == _tabIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: active ? NomadColors.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(e.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? NomadColors.primary : Colors.grey.shade400)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Contenido según tab
          if (_tabIndex == 0) _buildEventos(g),
          if (_tabIndex == 1) _buildChat(g),
          if (_tabIndex == 2) _buildMiembros(g),
        ],
      ),
    );
  }

  Widget _buildEventos(_GroupData g) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final e = g.events[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.07), width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width:  46,
                    height: 46,
                    decoration: BoxDecoration(
                      color:        NomadColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(e.day,
                          style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w600, color: NomadColors.primaryDark,
                            height: 1)),
                        Text(e.mon,
                          style: const TextStyle(fontSize: 9,
                            color: NomadColors.primary, letterSpacing: .04)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title,
                          style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: NomadColors.feedIconColor)),
                        const SizedBox(height: 2),
                        Text(e.meta,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(height: 4),
                        Text('${e.going} personas van',
                          style: const TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w500, color: NomadColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: g.events.length,
        ),
      ),
    );
  }

  Widget _buildChat(_GroupData g) {
    final msgCtrl = TextEditingController();
    return SliverToBoxAdapter(
      child: Column(
        children: [
          ...g.messages.map((m) => Align(
            alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                m.isMe ? 60 : 20, 8, m.isMe ? 20 : 60, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!m.isMe) ...[
                    Container(
                      width:  28, height: 28,
                      decoration: BoxDecoration(
                        color: m.bg, shape: BoxShape.circle),
                      child: Center(
                        child: Text(m.initial,
                          style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w600, color: m.fg))),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: m.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (!m.isMe)
                          Text(m.name,
                            style: TextStyle(fontSize: 10,
                              color: Colors.grey.shade400)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: m.isMe ? NomadColors.primary : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft:     const Radius.circular(14),
                              topRight:    const Radius.circular(14),
                              bottomLeft:  Radius.circular(m.isMe ? 14 : 4),
                              bottomRight: Radius.circular(m.isMe ? 4 : 14),
                            ),
                            border: m.isMe ? null : Border.all(
                              color: Colors.black.withValues(alpha: 0.07),
                              width: 0.5),
                          ),
                          child: Text(m.text,
                            style: TextStyle(fontSize: 13, height: 1.4,
                              color: m.isMe
                                  ? Colors.white
                                  : NomadColors.feedIconColor)),
                        ),
                        const SizedBox(height: 2),
                        Text(m.time,
                          style: TextStyle(fontSize: 10,
                            color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                  if (m.isMe) ...[
                    const SizedBox(width: 8),
                    Container(
                      width:  28, height: 28,
                      decoration: BoxDecoration(
                        color: NomadColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                      child: const Center(
                        child: Text('Yo',
                          style: TextStyle(fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: NomadColors.primaryDark))),
                    ),
                  ],
                ],
              ),
            ),
          )),
          const SizedBox(height: 16),

          // Input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:      msgCtrl,
                    textInputAction: TextInputAction.send,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText:  'Escribí un mensaje…',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13),
                      filled:    true,
                      fillColor: NomadColors.feedBg,
                      border:    OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:   BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width:  38, height: 38,
                  decoration: BoxDecoration(
                    color:        NomadColors.primary,
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 17),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiembros(_GroupData g) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.07), width: 0.5),
        ),
        child: Column(
          children: g.members.asMap().entries.map((e) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width:  40, height: 40,
                      decoration: BoxDecoration(
                        color: e.value.bg, shape: BoxShape.circle),
                      child: Center(
                        child: Text(e.value.initial,
                          style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: e.value.fg))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value.name,
                            style: const TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: NomadColors.feedIconColor)),
                          Text(e.value.origin,
                            style: TextStyle(fontSize: 12,
                              color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    if (e.value.isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color:        NomadColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(99)),
                        child: const Text('Admin',
                          style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: NomadColors.primaryDark)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: Colors.grey.shade200)),
                        child: Text('Conectar',
                          style: TextStyle(fontSize: 11,
                            color: Colors.grey.shade500)),
                      ),
                  ],
                ),
              ),
              if (e.key < g.members.length - 1)
                Divider(height: 1, color: Colors.grey.shade100),
            ],
          )).toList(),
        ),
      ),
    );
  }
}

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
            color: NomadColors.feedIconColor)),
        Text(label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}

// ── Modelos locales ───────────────────────────────────────────────────────────

class _GroupData {
  final String                               id;
  final String                               name;
  final String                               location;
  final GroupCategory                        category;
  final List<Color>                          cover;
  final String                               emoji;
  final String                               description;
  final String                               freq;
  final String                               place;
  final int                                  memberCount;
  final List<(String, Color, Color)>         memberInitials;
  final List<_EventData>                     events;
  final List<_MsgData>                       messages;
  final List<_MemberData>                    members;

  const _GroupData({
    required this.id,
    required this.name,
    required this.location,
    required this.category,
    required this.cover,
    required this.emoji,
    required this.description,
    required this.freq,
    required this.place,
    required this.memberCount,
    required this.memberInitials,
    required this.events,
    required this.messages,
    required this.members,
  });
}

class _EventData {
  final String day, mon, title, meta;
  final int    going;
  const _EventData({
    required this.day,
    required this.mon,
    required this.title,
    required this.meta,
    required this.going,
  });
}

class _MsgData {
  final String initial, name, text, time;
  final Color  bg, fg;
  final bool   isMe;
  const _MsgData({
    required this.initial,
    required this.bg,
    required this.fg,
    required this.name,
    required this.text,
    required this.time,
    required this.isMe,
  });
}

class _MemberData {
  final String initial, name, origin;
  final Color  bg, fg;
  final bool   isAdmin;
  const _MemberData({
    required this.initial,
    required this.bg,
    required this.fg,
    required this.name,
    required this.origin,
    required this.isAdmin,
  });
}
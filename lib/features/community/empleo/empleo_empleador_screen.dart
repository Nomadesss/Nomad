import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta (misma que el resto de la app)
// ─────────────────────────────────────────────────────────────────────────────
const _teal = Color(0xFF0D9488);
const _tealDark = Color(0xFF134E4A);
const _purple = Color(0xFF7C3AED);
const _purpleBg = Color(0xFFF5F0FF);

// ─────────────────────────────────────────────────────────────────────────────
// EmpleoEmpleadorScreen
// ─────────────────────────────────────────────────────────────────────────────

class EmpleoEmpleadorScreen extends StatefulWidget {
  const EmpleoEmpleadorScreen({super.key});

  @override
  State<EmpleoEmpleadorScreen> createState() => _EmpleoEmpleadorScreenState();
}

class _EmpleoEmpleadorScreenState extends State<EmpleoEmpleadorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String? _myId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: _tealDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Empleador',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _tealDark,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _purple,
          labelColor: _purple,
          unselectedLabelColor: Colors.grey.shade400,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Mis ofertas'),
            Tab(text: 'Postulantes'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nueva oferta',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: () => _showPublicarOferta(context),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TabMisOfertas(myId: _myId),
          _TabPostulantes(myId: _myId),
        ],
      ),
    );
  }

  void _showPublicarOferta(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PublicarOfertaSheet(myId: _myId),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Mis ofertas publicadas
// ─────────────────────────────────────────────────────────────────────────────

class _TabMisOfertas extends StatelessWidget {
  final String? myId;
  const _TabMisOfertas({required this.myId});

  @override
  Widget build(BuildContext context) {
    if (myId == null) {
      return const Center(child: Text('Iniciá sesión para ver tus ofertas'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('job_offers')
          .where('employerId', isEqualTo: myId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _purple));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _EmptyState(
            emoji: '📋',
            title: 'Sin ofertas publicadas',
            subtitle:
                'Tocá "Nueva oferta" para publicar tu primer puesto de trabajo.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final docId = docs[i].id;
            return _OfertaCard(docId: docId, data: data, myId: myId!);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Postulantes a todas mis ofertas
// ─────────────────────────────────────────────────────────────────────────────

class _TabPostulantes extends StatelessWidget {
  final String? myId;
  const _TabPostulantes({required this.myId});

  @override
  Widget build(BuildContext context) {
    if (myId == null) {
      return const Center(child: Text('Iniciá sesión'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('job_applications')
          .where('employerId', isEqualTo: myId)
          .orderBy('appliedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _purple));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _EmptyState(
            emoji: '👥',
            title: 'Sin postulantes aún',
            subtitle:
                'Cuando alguien se postule a una de tus ofertas, aparecerá acá.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final docId = docs[i].id;
            return _PostulanteCard(docId: docId, data: data);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de oferta publicada
// ─────────────────────────────────────────────────────────────────────────────

class _OfertaCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String myId;

  const _OfertaCard({
    required this.docId,
    required this.data,
    required this.myId,
  });

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return DateFormat('d MMM', 'es').format(dt);
  }

  Future<void> _eliminar(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar oferta',
          style: TextStyle(fontWeight: FontWeight.w700, color: _tealDark),
        ),
        content: const Text(
          '¿Estás seguro? Esta acción no se puede deshacer.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: _teal)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance
        .collection('job_offers')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Puesto sin título';
    final company = data['company'] as String? ?? '';
    final location = data['location'] as String? ?? '';
    final modality = data['modality'] as String? ?? '';
    final salary = data['salary'] as String? ?? '';
    final isActive = data['active'] as bool? ?? true;
    final createdAt = data['createdAt'] as Timestamp?;

    // Conteo de postulantes en tiempo real
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('job_applications')
          .where('offerId', isEqualTo: docId)
          .snapshots(),
      builder: (context, countSnap) {
        final applicantsCount = countSnap.data?.docs.length ?? 0;

        return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isActive
                      ? _purple.withOpacity(0.15)
                      : Colors.grey.shade200,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _purpleBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('💼', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _tealDark,
                              ),
                            ),
                            if (company.isNotEmpty)
                              Text(
                                company,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Menú tres puntos
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (val) async {
                          if (val == 'toggle') {
                            await FirebaseFirestore.instance
                                .collection('job_offers')
                                .doc(docId)
                                .update({'active': !isActive});
                          } else if (val == 'delete') {
                            await _eliminar(context);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  isActive
                                      ? Icons.pause_circle_outline_rounded
                                      : Icons.play_circle_outline_rounded,
                                  size: 18,
                                  color: _teal,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isActive ? 'Pausar oferta' : 'Activar oferta',
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Tags
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (location.isNotEmpty)
                        _Tag(
                          icon: Icons.location_on_outlined,
                          label: location,
                          color: _teal,
                        ),
                      if (modality.isNotEmpty)
                        _Tag(
                          icon: Icons.work_outline_rounded,
                          label: modality,
                          color: _purple,
                        ),
                      if (salary.isNotEmpty)
                        _Tag(
                          icon: Icons.attach_money_rounded,
                          label: salary,
                          color: const Color(0xFF059669),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Footer
                  Row(
                    children: [
                      // Badge activo/pausado
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _teal.withOpacity(0.10)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isActive ? '● Activa' : '⏸ Pausada',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive ? _teal : Colors.grey.shade500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Postulantes
                      Icon(
                        Icons.people_outline_rounded,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$applicantsCount postulante${applicantsCount != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeAgo(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de postulante
// ─────────────────────────────────────────────────────────────────────────────

class _PostulanteCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _PostulanteCard({required this.docId, required this.data});

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return DateFormat('d MMM', 'es').format(dt);
  }

  Future<void> _updateStatus(String status) async {
    await FirebaseFirestore.instance
        .collection('job_applications')
        .doc(docId)
        .update({'status': status});
  }

  @override
  Widget build(BuildContext context) {
    final applicantName = data['applicantName'] as String? ?? 'Postulante';
    final applicantAvatar = data['applicantAvatar'] as String?;
    final offerTitle = data['offerTitle'] as String? ?? '';
    final message = data['message'] as String? ?? '';
    final status = data['status'] as String? ?? 'pending';
    final appliedAt = data['appliedAt'] as Timestamp?;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'accepted':
        statusColor = _teal;
        statusLabel = '✓ Aceptado';
        break;
      case 'rejected':
        statusColor = Colors.redAccent;
        statusLabel = '✗ Rechazado';
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = '⏳ Pendiente';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera postulante
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _purpleBg,
                backgroundImage: applicantAvatar != null
                    ? NetworkImage(applicantAvatar)
                    : null,
                child: applicantAvatar == null
                    ? Text(
                        applicantName.isNotEmpty
                            ? applicantName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _purple,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      applicantName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _tealDark,
                      ),
                    ),
                    if (offerTitle.isNotEmpty)
                      Text(
                        'Postulado a: $offerTitle',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              // Badge de estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          // Mensaje del postulante
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FFFE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0F2F0)),
              ),
              child: Text(
                '"$message"',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Acciones + fecha
          Row(
            children: [
              Text(
                _timeAgo(appliedAt),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
              const Spacer(),
              if (status == 'pending') ...[
                // Rechazar
                _ActionBtn(
                  label: 'Rechazar',
                  color: Colors.redAccent,
                  onTap: () => _updateStatus('rejected'),
                ),
                const SizedBox(width: 8),
                // Aceptar
                _ActionBtn(
                  label: 'Aceptar',
                  color: _teal,
                  filled: true,
                  onTap: () => _updateStatus('accepted'),
                ),
              ] else
                // Revertir a pendiente
                TextButton(
                  onPressed: () => _updateStatus('pending'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Revertir',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet para publicar una oferta
// ─────────────────────────────────────────────────────────────────────────────

class _PublicarOfertaSheet extends StatefulWidget {
  final String? myId;
  const _PublicarOfertaSheet({required this.myId});

  @override
  State<_PublicarOfertaSheet> createState() => _PublicarOfertaSheetState();
}

class _PublicarOfertaSheetState extends State<_PublicarOfertaSheet> {
  final _titleCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _modality = 'Presencial';
  bool _publishing = false;

  static const _modalities = ['Presencial', 'Remoto', 'Híbrido'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _companyCtrl.dispose();
    _locationCtrl.dispose();
    _salaryCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título del puesto es obligatorio')),
      );
      return;
    }
    if (widget.myId == null) return;

    setState(() => _publishing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('job_offers').add({
        'employerId': widget.myId,
        'employerName': user?.displayName ?? '',
        'title': _titleCtrl.text.trim(),
        'company': _companyCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'salary': _salaryCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'modality': _modality,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Oferta publicada con éxito!'),
            backgroundColor: _teal,
          ),
        );
      }
    } catch (e) {
      debugPrint('[EmpleoEmpleador] Error publicando oferta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al publicar. Intentá de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottom + 28),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FFFE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCCE8E6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Publicar oferta',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _tealDark,
              ),
            ),
            const SizedBox(height: 20),

            // Puesto *
            _FormField(
              label: 'Puesto *',
              hint: 'ej: Desarrollador Flutter, Cocinero, Diseñador...',
              controller: _titleCtrl,
            ),
            const SizedBox(height: 14),

            // Empresa
            _FormField(
              label: 'Empresa / Negocio',
              hint: 'Nombre de tu empresa (opcional)',
              controller: _companyCtrl,
            ),
            const SizedBox(height: 14),

            // Ubicación
            _FormField(
              label: 'Ubicación',
              hint: 'Ciudad, país o "Remoto"',
              controller: _locationCtrl,
            ),
            const SizedBox(height: 14),

            // Modalidad
            const Text(
              'Modalidad',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _teal,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: _modalities.map((m) {
                final selected = _modality == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _modality = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? _purple : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? _purple : Colors.grey.shade200,
                        ),
                      ),
                      child: Text(
                        m,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Salario
            _FormField(
              label: 'Salario / Remuneración',
              hint: 'ej: USD 1.200, A convenir...',
              controller: _salaryCtrl,
            ),
            const SizedBox(height: 14),

            // Descripción
            _FormField(
              label: 'Descripción del puesto',
              hint: 'Tareas, requisitos, beneficios, horarios, condiciones...',
              controller: _descCtrl,
              maxLines: 5,
            ),
            const SizedBox(height: 24),

            // Botón publicar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _publishing ? null : _publish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _purple.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _publishing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Publicar oferta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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

// ─────────────────────────────────────────────────────────────────────────────
// Widgets reutilizables
// ─────────────────────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _teal,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: _tealDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13.5),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
              borderSide: const BorderSide(color: _teal, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Tag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
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
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _tealDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

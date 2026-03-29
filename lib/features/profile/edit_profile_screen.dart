import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/user_service.dart';

// ─── Paleta Nomad ─────────────────────────────────────────────────────────────
const _teal = Color(0xFF0D9488);
const _tealLight = Color(0xFF5EEAD4);
const _tealDark = Color(0xFF134E4A);
const _tealBg = Color(0xFFF0FAF9);
const _bgMain = Color(0xFFF8FFFE);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  late TextEditingController _nombreController;
  late TextEditingController _userController;
  late TextEditingController _bioController;

  // ── Estado username ──────────────────────────────────────────
  String _usernameOriginal = '';
  String _usernameError = '';
  bool _usernameAvailable = false;
  bool _checkingUsername = false;
  Timer? _debounceTimer;

  // ── Ciudades vividas ─────────────────────────────────────────
  List<Map<String, String>> _ciudadesVividas = [];

  // ── Otros ────────────────────────────────────────────────────
  bool _esPrivada = false;
  bool _isLoading = true;
  bool _isSaving = false;

  AnimationController? _animController;
  Animation<double> _fadeAnim = const AlwaysStoppedAnimation(1.0);

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController();
    _userController = TextEditingController();
    _bioController = TextEditingController();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController!,
      curve: Curves.easeOut,
    );

    _cargarDatos();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _animController?.dispose();
    _nombreController.dispose();
    _userController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ── Carga inicial ─────────────────────────────────────────────────────────

  Future<void> _cargarDatos() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final data = await _userService.getUserData(user.uid);
    if (data != null && mounted) {
      final ciudadesRaw = data['ciudadesVividas'];
      final List<Map<String, String>> ciudades = ciudadesRaw is List
          ? ciudadesRaw.map((e) => Map<String, String>.from(e as Map)).toList()
          : [];

      setState(() {
        _nombreController.text = data['displayName'] ?? '';
        _userController.text = data['username'] ?? '';
        _usernameOriginal = data['username'] ?? '';
        _usernameAvailable = true;
        _bioController.text = data['bio'] ?? '';
        _ciudadesVividas = ciudades;
        _esPrivada = data['esPrivada'] ?? false;
        _isLoading = false;
      });
      _animController?.forward();
    }
  }

  // ── Validación username ───────────────────────────────────────────────────

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();
    final username = value.trim();

    if (username == _usernameOriginal) {
      setState(() {
        _usernameError = '';
        _usernameAvailable = true;
        _checkingUsername = false;
      });
      return;
    }

    setState(() {
      _usernameAvailable = false;
      _usernameError = '';
      _checkingUsername = username.length >= 3;
    });

    if (username.length < 3) return;

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      final regex = RegExp(r'^[a-zA-Z0-9_]{6,15}$');

      if (!regex.hasMatch(username)) {
        if (!mounted) return;
        setState(() {
          _usernameError = 'Entre 6 y 15 caracteres, solo letras, números y _';
          _usernameAvailable = false;
          _checkingUsername = false;
        });
        return;
      }

      final result = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (!mounted) return;

      if (result.docs.isNotEmpty) {
        setState(() {
          _usernameError = 'Ese username ya está en uso';
          _usernameAvailable = false;
          _checkingUsername = false;
        });
      } else {
        setState(() {
          _usernameError = '';
          _usernameAvailable = true;
          _checkingUsername = false;
        });
      }
    });
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_usernameAvailable || _usernameError.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar('Corregí el username antes de guardar', isError: true),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _userService.updateProfile(user.uid, {
          'displayName': _nombreController.text.trim(),
          'username': _userController.text.trim().toLowerCase(),
          'bio': _bioController.text.trim(),
          'ciudadesVividas': _ciudadesVividas,
          'esPrivada': _esPrivada,
        });
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(_snackBar('Error al guardar: $e', isError: true));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  SnackBar _snackBar(String msg, {bool isError = false}) => SnackBar(
    content: Text(msg),
    backgroundColor: isError ? Colors.redAccent : _teal,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  // ── Modal ciudades ────────────────────────────────────────────────────────

  void _mostrarModalCiudades() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CiudadesModal(
        ciudades: List.from(_ciudadesVividas),
        onGuardar: (nuevas) => setState(() => _ciudadesVividas = nuevas),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bgMain,
        body: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }

    return Scaffold(
      backgroundColor: _bgMain,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: _tealDark,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _isSaving
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _guardar,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _AppBarBackground(
          inicial: _nombreController.text.isNotEmpty
              ? _nombreController.text[0].toUpperCase()
              : '?',
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Información básica ──
          const _SectionHeader(
            icon: Icons.person_outline_rounded,
            label: 'Información básica',
          ),
          const SizedBox(height: 12),
          _StyledField(
            label: 'Nombre completo',
            controller: _nombreController,
            hint: 'Tu nombre real',
            icon: Icons.badge_outlined,
          ),
          _UsernameField(
            controller: _userController,
            error: _usernameError,
            available: _usernameAvailable,
            checking: _checkingUsername,
            onChanged: _onUsernameChanged,
          ),
          _StyledField(
            label: 'Bio',
            controller: _bioController,
            hint: 'Cuéntale al mundo quién eres…',
            icon: Icons.edit_note_rounded,
            maxLines: 3,
          ),

          const SizedBox(height: 24),

          // ── Ciudades vividas ──
          const _SectionHeader(
            icon: Icons.map_outlined,
            label: 'Tu historia de viajes',
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Agregá las ciudades donde viviste para conectar con personas que compartieron tus mismos lugares.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
          _CiudadesSection(
            ciudades: _ciudadesVividas,
            onAgregar: _mostrarModalCiudades,
          ),

          const SizedBox(height: 24),

          // ── Privacidad ──
          const _SectionHeader(
            icon: Icons.shield_outlined,
            label: 'Privacidad',
          ),
          const SizedBox(height: 12),
          _PrivacyToggle(
            value: _esPrivada,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              setState(() => _esPrivada = val);
            },
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _tealLight,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Guardar cambios',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppBar background
// ─────────────────────────────────────────────────────────────────────────────

class _AppBarBackground extends StatelessWidget {
  final String inicial;
  const _AppBarBackground({required this.inicial});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_tealDark, _teal, Color(0xFF0891B2)],
            ),
          ),
        ),
        Positioned(
          top: -30,
          right: -20,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: -40,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: _tealLight.withOpacity(0.3),
                        child: Text(
                          inicial,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: _teal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Editar Perfil',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Username field con validación visual
// ─────────────────────────────────────────────────────────────────────────────

class _UsernameField extends StatelessWidget {
  final TextEditingController controller;
  final String error;
  final bool available;
  final bool checking;
  final ValueChanged<String> onChanged;

  const _UsernameField({
    required this.controller,
    required this.error,
    required this.available,
    required this.checking,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.transparent;
    Widget? suffix;

    if (checking) {
      suffix = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
      );
    } else if (error.isNotEmpty) {
      borderColor = Colors.redAccent;
      suffix = const Icon(
        Icons.cancel_rounded,
        color: Colors.redAccent,
        size: 20,
      );
    } else if (available && controller.text.isNotEmpty) {
      borderColor = _teal;
      suffix = const Icon(Icons.check_circle_rounded, color: _teal, size: 20);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Username',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _teal,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 15,
              color: _tealDark,
              fontWeight: FontWeight.w500,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: InputDecoration(
              hintText: 'tu_usuario',
              hintStyle: const TextStyle(
                color: Color(0xFFB0C4C3),
                fontSize: 14,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 14, right: 10),
                child: Icon(
                  Icons.alternate_email_rounded,
                  size: 18,
                  color: _teal,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              prefixText: '@',
              prefixStyle: const TextStyle(
                color: _teal,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              suffixIcon: suffix != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: suffix,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              filled: true,
              fillColor: _tealBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: error.isNotEmpty ? Colors.redAccent : _teal,
                  width: 1.5,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: error.isNotEmpty
                ? Padding(
                    key: const ValueKey('error'),
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      error,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : Padding(
                    key: const ValueKey('hint'),
                    padding: const EdgeInsets.only(top: 6, left: 4, bottom: 8),
                    child: Text(
                      'Entre 6 y 15 caracteres. Solo letras, números y _',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección ciudades en el formulario principal
// ─────────────────────────────────────────────────────────────────────────────

class _CiudadesSection extends StatelessWidget {
  final List<Map<String, String>> ciudades;
  final VoidCallback onAgregar;
  const _CiudadesSection({required this.ciudades, required this.onAgregar});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...ciudades.map(
          (c) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _teal.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: _teal.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(c['emoji'] ?? '🌍', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c['ciudad']}, ${c['pais']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _tealDark,
                        ),
                      ),
                      if ((c['años'] ?? '').isNotEmpty)
                        Text(
                          c['años']!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: onAgregar,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _tealBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _teal.withOpacity(0.25), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add_location_alt_outlined,
                    size: 16,
                    color: _teal,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Gestionar ciudades donde viviste',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _teal,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _teal.withOpacity(0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal: gestionar ciudades vividas
// ─────────────────────────────────────────────────────────────────────────────

class _CiudadesModal extends StatefulWidget {
  final List<Map<String, String>> ciudades;
  final ValueChanged<List<Map<String, String>>> onGuardar;

  const _CiudadesModal({required this.ciudades, required this.onGuardar});

  @override
  State<_CiudadesModal> createState() => _CiudadesModalState();
}

class _CiudadesModalState extends State<_CiudadesModal> {
  late List<Map<String, String>> _ciudades;
  bool _mostrandoFormulario = false;

  final _ciudadCtrl = TextEditingController();
  final _paisCtrl = TextEditingController();
  final _anosCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();

  // Errores individuales por campo
  String? _errCiudad;
  String? _errPais;
  String? _errAnos;

  // Letras unicode + espacios + guion + punto (cubre acentos, ñ, etc.)
  static final _letrasRegex = RegExp(r"^[\p{L}\s\-'\.]+", unicode: true);
  // Período: 2020 | 2015-2020 | 2015–2020 | 2015-hoy
  static final _periodRegex = RegExp(
    r'^(19|20)\d{2}([-\u2013](19|20)\d{2}|[-\u2013]hoy)?$',
  );

  @override
  void initState() {
    super.initState();
    _ciudades = List.from(widget.ciudades);
  }

  @override
  void dispose() {
    _ciudadCtrl.dispose();
    _paisCtrl.dispose();
    _anosCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  // ── Validadores por campo ─────────────────────────────────────────────────

  String? _validarCiudad(String v) {
    if (v.isEmpty) return 'Campo obligatorio';
    if (v.length < 2) return 'Mínimo 2 caracteres';
    if (v.length > 60) return 'Máximo 60 caracteres';
    if (!_letrasRegex.hasMatch(v)) return 'Solo letras y espacios';
    return null;
  }

  String? _validarPais(String v) {
    if (v.isEmpty) return 'Campo obligatorio';
    if (v.length < 2) return 'Mínimo 2 caracteres';
    if (v.length > 60) return 'Máximo 60 caracteres';
    if (!_letrasRegex.hasMatch(v)) return 'Solo letras y espacios';
    return null;
  }

  String? _validarPeriodo(String v) {
    if (v.isEmpty) return null; // opcional
    if (!_periodRegex.hasMatch(v)) {
      return 'Ej: 2015, 2015-2020 o 2015-hoy';
    }
    final parts = v.split(RegExp(r'[-\u2013]'));
    if (parts.length == 2 && parts[1] != 'hoy') {
      final inicio = int.tryParse(parts[0]);
      final fin = int.tryParse(parts[1]);
      if (inicio != null && fin != null && inicio > fin) {
        return 'El inicio no puede ser mayor al fin';
      }
    }
    return null;
  }

  String _capitalizar(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '\${w[0].toUpperCase()}\${w.substring(1)}')
      .join(' ');

  void _agregarCiudad() {
    final ciudad = _ciudadCtrl.text.trim();
    final pais = _paisCtrl.text.trim();
    final anos = _anosCtrl.text.trim();

    final errC = _validarCiudad(ciudad);
    final errP = _validarPais(pais);
    final errA = _validarPeriodo(anos);

    setState(() {
      _errCiudad = errC;
      _errPais = errP;
      _errAnos = errA;
    });

    if (errC != null || errP != null || errA != null) return;

    setState(() {
      _ciudades.add({
        'ciudad': _capitalizar(ciudad),
        'pais': _capitalizar(pais),
        'años': anos,
        'emoji': _emojiCtrl.text.trim().isEmpty ? '🌍' : _emojiCtrl.text.trim(),
      });
      _ciudadCtrl.clear();
      _paisCtrl.clear();
      _anosCtrl.clear();
      _emojiCtrl.clear();
      _mostrandoFormulario = false;
      _errCiudad = null;
      _errPais = null;
      _errAnos = null;
    });
  }

  void _eliminar(int index) {
    HapticFeedback.lightImpact();
    setState(() => _ciudades.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.map_outlined, size: 18, color: _teal),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu historia de viajes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _tealDark,
                        ),
                      ),
                      Text(
                        'Conectá con personas de los mismos lugares',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.onGuardar(_ciudades);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: _teal),
                  child: const Text(
                    'Listo',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Estado vacío
            if (_ciudades.isEmpty && !_mostrandoFormulario)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: _tealBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Text('🌍', style: TextStyle(fontSize: 32)),
                    SizedBox(height: 8),
                    Text(
                      'Todavía no agregaste ciudades',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _tealDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Compartí tu historia migratoria',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              )
            else
              // Lista
              Column(
                children: List.generate(
                  _ciudades.length,
                  (i) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _teal.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: _teal.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          _ciudades[i]['emoji'] ?? '🌍',
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_ciudades[i]['ciudad']}, ${_ciudades[i]['pais']}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _tealDark,
                                ),
                              ),
                              if ((_ciudades[i]['años'] ?? '').isNotEmpty)
                                Text(
                                  _ciudades[i]['años']!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () => _eliminar(i),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Formulario nueva ciudad
            if (_mostrandoFormulario) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _tealBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _teal.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nueva ciudad',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _tealDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Emoji (sin validación)
                    Row(
                      children: [
                        Expanded(
                          child: _ModalField(
                            ctrl: _emojiCtrl,
                            hint: '🏙️',
                            label: 'Emoji',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: _ModalField(
                            ctrl: _ciudadCtrl,
                            hint: 'Ej: Buenos Aires',
                            label: 'Ciudad *',
                            error: _errCiudad,
                            onChanged: (v) => setState(
                              () => _errCiudad = _validarCiudad(v.trim()),
                            ),
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r"[\p{L}\s\-'\.]", unicode: true),
                              ),
                              LengthLimitingTextInputFormatter(60),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _ModalField(
                            ctrl: _paisCtrl,
                            hint: 'Ej: Argentina',
                            label: 'País *',
                            error: _errPais,
                            onChanged: (v) => setState(
                              () => _errPais = _validarPais(v.trim()),
                            ),
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r"[\p{L}\s\-'\.]", unicode: true),
                              ),
                              LengthLimitingTextInputFormatter(60),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _ModalField(
                            ctrl: _anosCtrl,
                            hint: '2015–2020',
                            label: 'Período',
                            error: _errAnos,
                            onChanged: (v) => setState(
                              () => _errAnos = _validarPeriodo(v.trim()),
                            ),
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9\-–]'),
                              ),
                              LengthLimitingTextInputFormatter(9),
                            ],
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _mostrandoFormulario = false;
                              _ciudadCtrl.clear();
                              _paisCtrl.clear();
                              _anosCtrl.clear();
                              _emojiCtrl.clear();
                              _errCiudad = null;
                              _errPais = null;
                              _errAnos = null;
                            }),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _teal,
                              side: const BorderSide(color: _teal),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _agregarCiudad,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _teal,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Agregar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            if (!_mostrandoFormulario) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _mostrandoFormulario = true),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Agregar ciudad'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _teal,
                    side: const BorderSide(color: _teal),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModalField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final String label;
  final String? error;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? formatters;
  final TextInputType? keyboardType;

  const _ModalField({
    required this.ctrl,
    required this.hint,
    required this.label,
    this.error,
    this.onChanged,
    this.formatters,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: hasError ? Colors.redAccent : _teal,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          inputFormatters: formatters,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, color: _tealDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0C4C3), fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: hasError
                  ? const BorderSide(color: Colors.redAccent, width: 1.2)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: hasError ? Colors.redAccent : _teal,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 2),
            child: Text(
              error!,
              style: const TextStyle(fontSize: 10, color: Colors.redAccent),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets reutilizables
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: _teal),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _tealDark,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_teal.withOpacity(0.3), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StyledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? prefix;
  final int maxLines;

  const _StyledField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.prefix,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _teal,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 15,
              color: _tealDark,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              prefixText: prefix,
              prefixStyle: const TextStyle(
                color: _teal,
                fontWeight: FontWeight.w600,
              ),
              hintStyle: const TextStyle(
                color: Color(0xFFB0C4C3),
                fontSize: 14,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, size: 18, color: _teal),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              filled: true,
              fillColor: _tealBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _teal, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PrivacyToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _tealBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value
                  ? _teal.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              value ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 18,
              color: value ? _teal : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cuenta privada',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _tealDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value
                      ? 'Solo tus seguidores ven tu contenido'
                      : 'Tu perfil es visible para todos',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _teal,
            activeTrackColor: _tealLight.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}

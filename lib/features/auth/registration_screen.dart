import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../auth/terms_acceptance_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Flags: el usuario tocó este campo al menos una vez
  bool _touchedNombres = false;
  bool _touchedApellidos = false;
  bool _touchedEmail = false;
  bool _touchedPassword = false;
  bool _touchedConfirmPassword = false;

  // FocusNode para apellidos — al perder foco abre el calendario
  final _apellidosFocus = FocusNode();

  DateTime? _fechaNacimiento;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1, curve: Curves.easeIn),
      ),
    );
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();

    // Cuando apellidos pierde el foco, abrir el calendario
    _apellidosFocus.addListener(() {
      if (!_apellidosFocus.hasFocus && _fechaNacimiento == null) {
        _pickFecha();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _apellidosFocus.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Validaciones puras (sin side effects) ────────────────────

  String? _checkNombres(String v) {
    if (v.trim().isEmpty) return 'Ingresá tu nombre';
    if (v.trim().length < 2) return 'Mínimo 2 caracteres';
    return null;
  }

  String? _checkApellidos(String v) {
    if (v.trim().isEmpty) return 'Ingresá tu apellido';
    if (v.trim().length < 2) return 'Mínimo 2 caracteres';
    return null;
  }

  String? _checkEmail(String v) {
    if (v.trim().isEmpty) return 'Ingresá tu email';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v.trim())) return 'Email inválido';
    return null;
  }

  String? _checkPassword(String v) {
    if (v.isEmpty) return 'Ingresá una contraseña';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(v))
      return 'Debe incluir al menos una mayúscula';
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\\/]').hasMatch(v))
      return 'Debe incluir al menos un símbolo';
    return null;
  }

  String? _checkConfirmPassword(String v) {
    if (v.isEmpty) return 'Confirmá tu contraseña';
    if (v != _passwordController.text) return 'Las contraseñas no coinciden';
    return null;
  }

  // ── Handlers onChanged ────────────────────────────────────────

  void _onNombresChanged(String v) => setState(() => _touchedNombres = true);

  void _onApellidosChanged(String v) =>
      setState(() => _touchedApellidos = true);

  void _onEmailChanged(String v) => setState(() => _touchedEmail = true);

  void _onPasswordChanged(String v) {
    setState(() {
      _touchedPassword = true;
      // Solo re-evaluar confirm si ya fue tocado
      // (sin cambiar su touchedFlag)
    });
  }

  void _onConfirmPasswordChanged(String v) =>
      setState(() => _touchedConfirmPassword = true);

  // ── Validación al enviar (marca todos como tocados) ───────────

  bool _submitValidate() {
    setState(() {
      _touchedNombres = true;
      _touchedApellidos = true;
      _touchedEmail = true;
      _touchedPassword = true;
      _touchedConfirmPassword = true;
    });
    return _checkNombres(_nombresController.text) == null &&
        _checkApellidos(_apellidosController.text) == null &&
        _checkEmail(_emailController.text) == null &&
        _checkPassword(_passwordController.text) == null &&
        _checkConfirmPassword(_confirmPasswordController.text) == null &&
        _fechaNacimiento != null;
  }

  // ── Selector de fecha ─────────────────────────────────────────

  Future<void> _pickFecha() async {
    final hoy = DateTime.now();
    final minAge = DateTime(hoy.year - 100, hoy.month, hoy.day);
    final maxAge = DateTime(hoy.year - 13, hoy.month, hoy.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? maxAge,
      firstDate: minAge,
      lastDate: maxAge,
      locale: const Locale('es', 'AR'),
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF5C6EF5),
            onPrimary: Colors.white,
            surface: Color(0xFF1A1A2E),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF0F0F1A),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF5C6EF5),
            ),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) setState(() => _fechaNacimiento = picked);
  }

  // ── Registro ──────────────────────────────────────────────────

  Future<void> _registrar() async {
    if (!_submitValidate()) {
      if (_fechaNacimiento == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seleccioná tu fecha de nacimiento'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    final error = await AuthService().registrarConEmail(
      nombres: _nombresController.text.trim(),
      apellidos: _apellidosController.text.trim(),
      fechaNacimiento: _fechaNacimiento!,
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Todo ok → navegar a términos y condiciones
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TermsAcceptanceScreen()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Calcular errores solo para campos tocados
    final errorNombres = _touchedNombres
        ? _checkNombres(_nombresController.text)
        : null;
    final errorApellidos = _touchedApellidos
        ? _checkApellidos(_apellidosController.text)
        : null;
    final errorEmail = _touchedEmail
        ? _checkEmail(_emailController.text)
        : null;
    final errorPassword = _touchedPassword
        ? _checkPassword(_passwordController.text)
        : null;
    final errorConfirmPassword = _touchedConfirmPassword
        ? _checkConfirmPassword(_confirmPasswordController.text)
        : null;

    final validNombres = _touchedNombres && errorNombres == null;
    final validApellidos = _touchedApellidos && errorApellidos == null;
    final validEmail = _touchedEmail && errorEmail == null;
    final validPassword = _touchedPassword && errorPassword == null;
    final validConfirmPassword =
        _touchedConfirmPassword && errorConfirmPassword == null;

    final pass = _passwordController.text;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F0F1A),
                  Color(0xFF14101F),
                  Color(0xFF0F1A14),
                ],
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Back + Logo ────────────────────────
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Hero(
                            tag: "logo",
                            child: Material(
                              color: Colors.transparent,
                              child: const Text(
                                "Nomad",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),
                      const Text(
                        "Crear cuenta",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Completá los datos para unirte a tu comunidad",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Nombres + Apellidos ────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              controller: _nombresController,
                              label: 'Nombres',
                              hint: 'Juan',
                              icon: Icons.person_outline_rounded,
                              error: errorNombres,
                              isValid: validNombres,
                              onChanged: _onNombresChanged,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildField(
                              controller: _apellidosController,
                              focusNode: _apellidosFocus,
                              label: 'Apellidos',
                              hint: 'García',
                              icon: Icons.person_outline_rounded,
                              error: errorApellidos,
                              isValid: validApellidos,
                              onChanged: _onApellidosChanged,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Fecha de nacimiento ────────────────
                      _buildLabel('Fecha de nacimiento'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickFecha,
                        child: Container(
                          height: 54,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _fechaNacimiento != null
                                  ? const Color(
                                      0xFF27AE60,
                                    ).withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.12),
                              width: _fechaNacimiento != null ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: _fechaNacimiento != null
                                    ? const Color(0xFF27AE60)
                                    : Colors.white.withValues(alpha: 0.35),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _fechaNacimiento != null
                                    ? DateFormat(
                                        'dd / MM / yyyy',
                                      ).format(_fechaNacimiento!)
                                    : 'DD / MM / AAAA',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _fechaNacimiento != null
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.3),
                                  fontWeight: _fechaNacimiento != null
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                              const Spacer(),
                              _fechaNacimiento != null
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF27AE60),
                                      size: 18,
                                    )
                                  : Icon(
                                      Icons.expand_more_rounded,
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      size: 20,
                                    ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Email ──────────────────────────────
                      _buildField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'juan@ejemplo.com',
                        icon: Icons.email_outlined,
                        error: errorEmail,
                        isValid: validEmail,
                        onChanged: _onEmailChanged,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 16),

                      // ── Contraseña ─────────────────────────
                      _buildPasswordField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        hint: 'Mínimo 8 caracteres',
                        isVisible: _showPassword,
                        error: errorPassword,
                        isValid: validPassword,
                        onChanged: _onPasswordChanged,
                        textInputAction: TextInputAction.next,
                        onToggle: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),

                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _reqChip('8+ caracteres', pass.length >= 8),
                          const SizedBox(width: 8),
                          _reqChip(
                            'Mayúscula',
                            RegExp(r'[A-Z]').hasMatch(pass),
                          ),
                          const SizedBox(width: 8),
                          _reqChip(
                            'Símbolo',
                            RegExp(
                              r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\\/]',
                            ).hasMatch(pass),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Confirmar contraseña ───────────────
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        label: 'Confirmar contraseña',
                        hint: 'Repetí tu contraseña',
                        isVisible: _showConfirmPassword,
                        error: errorConfirmPassword,
                        isValid: validConfirmPassword,
                        onChanged: _onConfirmPasswordChanged,
                        textInputAction: TextInputAction.done,
                        onToggle: () => setState(
                          () => _showConfirmPassword = !_showConfirmPassword,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Botón registrar ────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF5C6EF5),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5C6EF5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _registrar,
                                child: const Text(
                                  "Crear mi cuenta",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets helper ────────────────────────────────────────────

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 0.65),
      letterSpacing: 0.1,
    ),
  );

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? error,
    required bool isValid,
    required ValueChanged<String> onChanged,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _inputDecoration(
            hint: hint,
            icon: icon,
            error: error,
            isValid: isValid,
          ),
        ),
        _buildFieldFeedback(error: error, isValid: isValid),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isVisible,
    required VoidCallback onToggle,
    required String? error,
    required bool isValid,
    required ValueChanged<String> onChanged,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: !isVisible,
          textInputAction: textInputAction,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _inputDecoration(
            hint: hint,
            icon: Icons.lock_outline_rounded,
            error: error,
            isValid: isValid,
            suffix: GestureDetector(
              onTap: onToggle,
              child: Icon(
                isVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
          ),
        ),
        _buildFieldFeedback(error: error, isValid: isValid),
      ],
    );
  }

  Widget _buildFieldFeedback({required String? error, required bool isValid}) {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 13),
            const SizedBox(width: 4),
            Text(
              error,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11.5),
            ),
          ],
        ),
      );
    }
    if (isValid) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 4),
        child: Row(
          children: const [
            Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF27AE60),
              size: 13,
            ),
            SizedBox(width: 4),
            Text(
              'Correcto',
              style: TextStyle(
                color: Color(0xFF27AE60),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox(height: 0);
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required String? error,
    required bool isValid,
    Widget? suffix,
  }) {
    final Color borderColor = error != null
        ? Colors.redAccent
        : isValid
        ? const Color(0xFF27AE60)
        : Colors.white.withValues(alpha: 0.12);
    final double borderWidth = (error != null || isValid) ? 1.5 : 1.0;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.28),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.35),
        size: 20,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: borderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: error != null
              ? Colors.redAccent
              : isValid
              ? const Color(0xFF27AE60)
              : const Color(0xFF5C6EF5),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _reqChip(String label, bool met) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: met
            ? const Color(0xFF1A3A2A)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: met
              ? const Color(0xFF27AE60).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_rounded : Icons.circle_outlined,
            size: 11,
            color: met
                ? const Color(0xFF27AE60)
                : Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: met
                  ? const Color(0xFF27AE60)
                  : Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

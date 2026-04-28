import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../auth/terms_acceptance_screen.dart';
import '../../l10n/app_localizations.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _nombresController          = TextEditingController();
  final _apellidosController        = TextEditingController();
  final _emailController            = TextEditingController();
  final _passwordController         = TextEditingController();
  final _confirmPasswordController  = TextEditingController();

  // Flags: el usuario tocó este campo al menos una vez
  bool _touchedNombres          = false;
  bool _touchedApellidos        = false;
  bool _touchedEmail            = false;
  bool _touchedPassword         = false;
  bool _touchedConfirmPassword  = false;

  // FocusNode para apellidos — al perder foco abre el calendario
  final _apellidosFocus = FocusNode();

  DateTime? _fechaNacimiento;
  bool _isLoading           = false;
  bool _showPassword        = false;
  bool _showConfirmPassword = false;

  late AnimationController _animController;
  late Animation<double>   _fadeIn;
  late Animation<Offset>   _slideIn;

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
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
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

  // ── Validaciones puras (sin side effects) ─────────────────────

  String? _checkNombres(String v, AppLocalizations l10n) {
    if (v.trim().isEmpty) return l10n.regErrorFirstName;
    if (v.trim().length < 2) return l10n.regErrorFirstNameMin;
    return null;
  }

  String? _checkApellidos(String v, AppLocalizations l10n) {
    if (v.trim().isEmpty) return l10n.regErrorLastName;
    if (v.trim().length < 2) return l10n.regErrorFirstNameMin;
    return null;
  }

  String? _checkEmail(String v, AppLocalizations l10n) {
    if (v.trim().isEmpty) return l10n.regErrorEmail;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v.trim())) return l10n.regErrorEmailInvalid;
    return null;
  }

  String? _checkPassword(String v, AppLocalizations l10n) {
    if (v.isEmpty) return l10n.regErrorPassword;
    if (v.length < 8) return l10n.regErrorPasswordMin;
    if (!RegExp(r'[A-Z]').hasMatch(v)) return l10n.regErrorPasswordUppercase;
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\\/]').hasMatch(v))
      return l10n.regErrorPasswordSymbol;
    return null;
  }

  String? _checkConfirmPassword(String v, AppLocalizations l10n) {
    if (v.isEmpty) return l10n.regErrorConfirmPassword;
    if (v != _passwordController.text) return l10n.regErrorPasswordMismatch;
    return null;
  }

  // ── Handlers onChanged ────────────────────────────────────────

  void _onNombresChanged(String v)        => setState(() => _touchedNombres = true);
  void _onApellidosChanged(String v)      => setState(() => _touchedApellidos = true);
  void _onEmailChanged(String v)          => setState(() => _touchedEmail = true);
  void _onPasswordChanged(String v)       => setState(() => _touchedPassword = true);
  void _onConfirmPasswordChanged(String v)=> setState(() => _touchedConfirmPassword = true);

  // ── Validación al enviar (marca todos como tocados) ───────────

  bool _submitValidate(AppLocalizations l10n) {
    setState(() {
      _touchedNombres         = true;
      _touchedApellidos       = true;
      _touchedEmail           = true;
      _touchedPassword        = true;
      _touchedConfirmPassword = true;
    });
    return _checkNombres(_nombresController.text, l10n)         == null &&
        _checkApellidos(_apellidosController.text, l10n)        == null &&
        _checkEmail(_emailController.text, l10n)                == null &&
        _checkPassword(_passwordController.text, l10n)          == null &&
        _checkConfirmPassword(_confirmPasswordController.text, l10n) == null &&
        _fechaNacimiento != null;
  }

  // ── Selector de fecha ─────────────────────────────────────────

  Future<void> _pickFecha() async {
    final l10n  = AppLocalizations.of(context);
    final hoy    = DateTime.now();
    final minAge = DateTime(hoy.year - 100, hoy.month, hoy.day);
    final maxAge = DateTime(hoy.year - 13,  hoy.month, hoy.day);

    final picked = await showDatePicker(
      context:     context,
      initialDate: _fechaNacimiento ?? maxAge,
      firstDate:   minAge,
      lastDate:    maxAge,
      locale:      const Locale('es', 'AR'),
      helpText:    l10n.regBirthdateLabel,
      cancelText:  l10n.cancelButton,
      confirmText: l10n.regDateConfirm,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   Color(0xFF0D9488),
            onPrimary: Colors.white,
            surface:   Color(0xFF0D2B28),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF0F0F1A),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF0D9488),
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
    final l10n = AppLocalizations.of(context);
    if (!_submitValidate(l10n)) {
      if (_fechaNacimiento == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text(l10n.regErrorSelectBirthdate),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService().registrarConEmail(
      nombres:         _nombresController.text.trim(),
      apellidos:       _apellidosController.text.trim(),
      fechaNacimiento: _fechaNacimiento!,
      email:           _emailController.text.trim(),
      password:        _passwordController.text,
      gdprAceptadoEn:  DateTime.now(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(result.error!),
          backgroundColor: Colors.redAccent,
          behavior:        SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TermsAcceptanceScreen()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Calcular errores solo para campos tocados
    final errorNombres = _touchedNombres
        ? _checkNombres(_nombresController.text, l10n)
        : null;
    final errorApellidos = _touchedApellidos
        ? _checkApellidos(_apellidosController.text, l10n)
        : null;
    final errorEmail = _touchedEmail
        ? _checkEmail(_emailController.text, l10n)
        : null;
    final errorPassword = _touchedPassword
        ? _checkPassword(_passwordController.text, l10n)
        : null;
    final errorConfirmPassword = _touchedConfirmPassword
        ? _checkConfirmPassword(_confirmPasswordController.text, l10n)
        : null;

    final isValidNombres   = errorNombres == null   && _nombresController.text.trim().length >= 2;
    final isValidApellidos = errorApellidos == null && _apellidosController.text.trim().length >= 2;
    final isValidEmail     = errorEmail == null     && _emailController.text.trim().isNotEmpty;
    final isValidPassword  = errorPassword == null  && _passwordController.text.length >= 8;
    final isValidConfirm   = errorConfirmPassword == null &&
        _confirmPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text == _passwordController.text;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header ───────────────────────────────────────────────
                  const SizedBox(height: 12),
                  Text(
                    l10n.regTitle,
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.regSubtitle,
                    style: TextStyle(
                      color:    Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Nombres ──────────────────────────────────────────────
                  _buildField(
                    controller:         _nombresController,
                    label:              l10n.regFirstNameLabel,
                    hint:               l10n.regFirstNameHint,
                    icon:               Icons.person_outline_rounded,
                    error:              errorNombres,
                    isValid:            isValidNombres,
                    onChanged:          _onNombresChanged,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // ── Apellidos ────────────────────────────────────────────
                  _buildField(
                    controller:         _apellidosController,
                    label:              l10n.regLastNameLabel,
                    hint:               l10n.regLastNameHint,
                    icon:               Icons.badge_outlined,
                    error:              errorApellidos,
                    isValid:            isValidApellidos,
                    onChanged:          _onApellidosChanged,
                    focusNode:          _apellidosFocus,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // ── Fecha de nacimiento ──────────────────────────────────
                  _buildLabel(l10n.regBirthdateLabel),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickFecha,
                    child: Container(
                      width:   double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical:   16,
                      ),
                      decoration: BoxDecoration(
                        color:        Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _fechaNacimiento != null
                              ? const Color(0xFF27AE60)
                              : Colors.white.withValues(alpha: 0.12),
                          width: _fechaNacimiento != null ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: Colors.white.withValues(alpha: 0.35),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _fechaNacimiento != null
                                ? DateFormat('dd/MM/yyyy').format(_fechaNacimiento!)
                                : l10n.regBirthdatePlaceholder,
                            style: TextStyle(
                              color: _fechaNacimiento != null
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.28),
                              fontSize: 14,
                            ),
                          ),
                          if (_fechaNacimiento != null) ...[
                            const Spacer(),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF27AE60),
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Email ────────────────────────────────────────────────
                  _buildField(
                    controller:   _emailController,
                    label:        l10n.regEmailLabel,
                    hint:         l10n.regEmailHint,
                    icon:         Icons.email_outlined,
                    error:        errorEmail,
                    isValid:      isValidEmail,
                    onChanged:    _onEmailChanged,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // ── Contraseña ───────────────────────────────────────────
                  _buildPasswordField(
                    controller:  _passwordController,
                    label:       l10n.regPasswordLabel,
                    hint:        l10n.regPasswordHint,
                    isVisible:   _showPassword,
                    onToggle:    () => setState(() => _showPassword = !_showPassword),
                    error:       errorPassword,
                    isValid:     isValidPassword,
                    onChanged:   _onPasswordChanged,
                  ),
                  const SizedBox(height: 8),

                  // ── Chips de requisitos ──────────────────────────────────
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _reqChip(l10n.regReqLength,    _passwordController.text.length >= 8),
                      _reqChip(l10n.regReqUppercase, RegExp(r'[A-Z]').hasMatch(_passwordController.text)),
                      _reqChip(l10n.regReqSymbol,    RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\\/]').hasMatch(_passwordController.text)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Confirmar contraseña ─────────────────────────────────
                  _buildPasswordField(
                    controller:       _confirmPasswordController,
                    label:            l10n.regConfirmPasswordLabel,
                    hint:             l10n.regConfirmPasswordHint,
                    isVisible:        _showConfirmPassword,
                    onToggle:         () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                    error:            errorConfirmPassword,
                    isValid:          isValidConfirm,
                    onChanged:        _onConfirmPasswordChanged,
                    textInputAction:  TextInputAction.done,
                  ),
                  const SizedBox(height: 32),

                  // ── Botón crear cuenta ───────────────────────────────────
                  SizedBox(
                    width:  double.infinity,
                    height: 52,
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF0D9488),
                            ),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _registrar,
                            child: Text(
                              l10n.regCreateButton,
                              style: const TextStyle(
                                fontSize:      16,
                                fontWeight:    FontWeight.w600,
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
    );
  }

  // ── Widgets helper ────────────────────────────────────────────

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize:      13,
      fontWeight:    FontWeight.w500,
      color:         Colors.white.withValues(alpha: 0.65),
      letterSpacing: 0.1,
    ),
  );

  Widget _buildField({
    required TextEditingController controller,
    required String                label,
    required String                hint,
    required IconData              icon,
    required String?               error,
    required bool                  isValid,
    required ValueChanged<String>  onChanged,
    FocusNode?          focusNode,
    TextInputType       keyboardType       = TextInputType.text,
    TextCapitalization  textCapitalization = TextCapitalization.none,
    TextInputAction     textInputAction    = TextInputAction.next,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller:         controller,
          focusNode:          focusNode,
          keyboardType:       keyboardType,
          textCapitalization: textCapitalization,
          textInputAction:    textInputAction,
          onChanged:          onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _inputDecoration(
            hint:    hint,
            icon:    icon,
            error:   error,
            isValid: isValid,
          ),
        ),
        _buildFieldFeedback(error: error, isValid: isValid),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String                label,
    required String                hint,
    required bool                  isVisible,
    required VoidCallback          onToggle,
    required String?               error,
    required bool                  isValid,
    required ValueChanged<String>  onChanged,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller:      controller,
          obscureText:     !isVisible,
          textInputAction: textInputAction,
          onChanged:       onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: _inputDecoration(
            hint:    hint,
            icon:    Icons.lock_outline_rounded,
            error:   error,
            isValid: isValid,
            suffix:  GestureDetector(
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
            Icon(Icons.check_circle_rounded, color: Color(0xFF27AE60), size: 13),
            SizedBox(width: 4),
            Text(
              'Correcto',
              style: TextStyle(
                color:      Color(0xFF27AE60),
                fontSize:   11.5,
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
    required String  hint,
    required IconData icon,
    required String? error,
    required bool    isValid,
    Widget?          suffix,
  }) {
    final Color  borderColor = error != null
        ? Colors.redAccent
        : isValid
            ? const Color(0xFF27AE60)
            : Colors.white.withValues(alpha: 0.12);
    final double borderWidth = (error != null || isValid) ? 1.5 : 1.0;

    return InputDecoration(
      hintText:  hint,
      hintStyle: TextStyle(
        color:    Colors.white.withValues(alpha: 0.28),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.35),
        size:  20,
      ),
      suffixIcon:   suffix,
      filled:       true,
      fillColor:    Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide(color: borderColor, width: borderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide(color: borderColor, width: borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide(
          color: error != null
              ? Colors.redAccent
              : isValid
                  ? const Color(0xFF27AE60)
                  : const Color(0xFF0D9488),
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
            size:  11,
            color: met
                ? const Color(0xFF27AE60)
                : Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize:   10.5,
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

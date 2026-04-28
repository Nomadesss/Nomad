import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/terms_acceptance_screen.dart';
import '../../l10n/app_localizations.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String verificationId;
  final int? resendToken;
  final String numeroCompleto;

  const PhoneVerificationScreen({
    super.key,
    required this.verificationId,
    required this.resendToken,
    required this.numeroCompleto,
  });

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen>
    with SingleTickerProviderStateMixin {
  // 6 controllers para los 6 dígitos
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  String? _error;
  int _segundosRestantes = 60;
  late String _verificationId;
  int? _resendToken;

  // Countdown timer
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 1, curve: Curves.easeIn),
      ),
    );
    _animController.forward();

    _startCountdown();
  }

  void _startCountdown() {
    _segundosRestantes = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _segundosRestantes--);
      return _segundosRestantes > 0;
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Manejo de input por dígito ────────────────────────────────

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    }
    // Si pegan los 6 dígitos de una
    if (value.length == 6) {
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = value[i];
      }
      FocusScope.of(context).unfocus();
      _verificarCodigo();
    }
    setState(() => _error = null);
  }

  void _onKeyPressed(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
  }

  String get _codigoCompleto => _controllers.map((c) => c.text).join();

  // ── Verificar código ──────────────────────────────────────────

  Future<void> _verificarCodigo() async {
    final l10n = AppLocalizations.of(context);
    final codigo = _codigoCompleto;

    if (codigo.length < 6) {
      setState(() => _error = l10n.phoneVerifErrorDigits);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: codigo,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TermsAcceptanceScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final l10nInner = AppLocalizations.of(context);
      setState(() {
        _isLoading = false;
      });
      switch (e.code) {
        case 'invalid-verification-code':
          setState(() => _error = l10nInner.phoneVerifErrorWrong);
          break;
        case 'session-expired':
          setState(() => _error = l10nInner.phoneVerifErrorExpired);
          break;
        default:
          setState(() => _error = l10nInner.phoneVerifErrorGeneric);
      }
    } catch (_) {
      if (!mounted) return;
      final l10nInner = AppLocalizations.of(context);
      setState(() {
        _isLoading = false;
        _error = l10nInner.phoneVerifErrorUnexpected;
      });
    }
  }

  // ── Reenviar código ───────────────────────────────────────────

  Future<void> _reenviarCodigo() async {
    if (_segundosRestantes > 0 || _isResending) return;
    setState(() => _isResending = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.numeroCompleto,
      forceResendingToken: _resendToken,

      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      },

      verificationFailed: (e) {
        if (!mounted) return;
        setState(() => _isResending = false);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.phoneVerifResendError),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },

      codeSent: (newVerificationId, newResendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = newVerificationId;
          _resendToken = newResendToken;
          _isResending = false;
          for (final c in _controllers) {
            c.clear();
          }
          _error = null;
        });
        FocusScope.of(context).requestFocus(_focusNodes[0]);
        _startCountdown();
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.phoneVerifResendSuccess),
            backgroundColor: const Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },

      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
              child: Padding(
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

                    const SizedBox(height: 36),

                    Text(
                      l10n.phoneVerifTitle,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.phoneVerifCodeSent(widget.numeroCompleto),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── 6 cajas de dígitos ─────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) {
                        return SizedBox(
                          width: 46,
                          height: 56,
                          child: RawKeyboardListener(
                            focusNode: FocusNode(),
                            onKey: (event) => _onKeyPressed(i, event),
                            child: TextField(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.06),
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _error != null
                                        ? Colors.redAccent
                                        : Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _error != null
                                        ? Colors.redAccent
                                        : Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _error != null
                                        ? Colors.redAccent
                                        : const Color(0xFF0D9488),
                                    width: 1.8,
                                  ),
                                ),
                              ),
                              onChanged: (v) => _onDigitChanged(i, v),
                            ),
                          ),
                        );
                      }),
                    ),

                    // Error
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cancel_rounded,
                              color: Colors.redAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── Reenviar código ────────────────────
                    Center(
                      child: _isResending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0D9488),
                              ),
                            )
                          : GestureDetector(
                              onTap: _segundosRestantes > 0
                                  ? null
                                  : _reenviarCodigo,
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text: l10n.phoneVerifNoCode,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    _segundosRestantes > 0
                                        ? TextSpan(
                                            text: l10n.phoneVerifResendIn(_segundosRestantes),
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.35,
                                              ),
                                            ),
                                          )
                                        : TextSpan(
                                            text: l10n.phoneVerifResend,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: Colors.white,
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                            ),
                    ),

                    const Spacer(),

                    // ── Botón verificar ────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF0D9488),
                                strokeWidth: 2.5,
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
                              onPressed: _verificarCodigo,
                              child: Text(
                                l10n.phoneVerifButton,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 24),
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

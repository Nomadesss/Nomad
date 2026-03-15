import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'phone_verification_screen.dart';

// ── Lista de países con prefijo ───────────────────────────────
class PaisPrefix {
  final String nombre;
  final String bandera;
  final String prefijo;
  const PaisPrefix({
    required this.nombre,
    required this.bandera,
    required this.prefijo,
  });
}

const List<PaisPrefix> kPaises = [
  PaisPrefix(nombre: 'Argentina', bandera: '🇦🇷', prefijo: '+54'),
  PaisPrefix(nombre: 'Uruguay', bandera: '🇺🇾', prefijo: '+598'),
  PaisPrefix(nombre: 'México', bandera: '🇲🇽', prefijo: '+52'),
  PaisPrefix(nombre: 'Colombia', bandera: '🇨🇴', prefijo: '+57'),
  PaisPrefix(nombre: 'Chile', bandera: '🇨🇱', prefijo: '+56'),
  PaisPrefix(nombre: 'Perú', bandera: '🇵🇪', prefijo: '+51'),
  PaisPrefix(nombre: 'Venezuela', bandera: '🇻🇪', prefijo: '+58'),
  PaisPrefix(nombre: 'Bolivia', bandera: '🇧🇴', prefijo: '+591'),
  PaisPrefix(nombre: 'Paraguay', bandera: '🇵🇾', prefijo: '+595'),
  PaisPrefix(nombre: 'Ecuador', bandera: '🇪🇨', prefijo: '+593'),
  PaisPrefix(nombre: 'Brasil', bandera: '🇧🇷', prefijo: '+55'),
  PaisPrefix(nombre: 'España', bandera: '🇪🇸', prefijo: '+34'),
  PaisPrefix(nombre: 'Estados Unidos', bandera: '🇺🇸', prefijo: '+1'),
  PaisPrefix(nombre: 'Canadá', bandera: '🇨🇦', prefijo: '+1'),
  PaisPrefix(nombre: 'Reino Unido', bandera: '🇬🇧', prefijo: '+44'),
  PaisPrefix(nombre: 'Alemania', bandera: '🇩🇪', prefijo: '+49'),
  PaisPrefix(nombre: 'Francia', bandera: '🇫🇷', prefijo: '+33'),
  PaisPrefix(nombre: 'Italia', bandera: '🇮🇹', prefijo: '+39'),
  PaisPrefix(nombre: 'Portugal', bandera: '🇵🇹', prefijo: '+351'),
  PaisPrefix(nombre: 'Australia', bandera: '🇦🇺', prefijo: '+61'),
  PaisPrefix(nombre: 'Japón', bandera: '🇯🇵', prefijo: '+81'),
  PaisPrefix(nombre: 'China', bandera: '🇨🇳', prefijo: '+86'),
  PaisPrefix(nombre: 'India', bandera: '🇮🇳', prefijo: '+91'),
  PaisPrefix(nombre: 'Sudáfrica', bandera: '🇿🇦', prefijo: '+27'),
  PaisPrefix(nombre: 'México', bandera: '🇲🇽', prefijo: '+52'),
  PaisPrefix(nombre: 'Israel', bandera: '🇮🇱', prefijo: '+972'),
  PaisPrefix(nombre: 'Emiratos Árabes', bandera: '🇦🇪', prefijo: '+971'),
  PaisPrefix(nombre: 'Suiza', bandera: '🇨🇭', prefijo: '+41'),
  PaisPrefix(nombre: 'Países Bajos', bandera: '🇳🇱', prefijo: '+31'),
  PaisPrefix(nombre: 'Bélgica', bandera: '🇧🇪', prefijo: '+32'),
  PaisPrefix(nombre: 'Suecia', bandera: '🇸🇪', prefijo: '+46'),
  PaisPrefix(nombre: 'Noruega', bandera: '🇳🇴', prefijo: '+47'),
  PaisPrefix(nombre: 'Dinamarca', bandera: '🇩🇰', prefijo: '+45'),
  PaisPrefix(nombre: 'Polonia', bandera: '🇵🇱', prefijo: '+48'),
  PaisPrefix(nombre: 'Rusia', bandera: '🇷🇺', prefijo: '+7'),
  PaisPrefix(nombre: 'Turquía', bandera: '🇹🇷', prefijo: '+90'),
  PaisPrefix(nombre: 'Corea del Sur', bandera: '🇰🇷', prefijo: '+82'),
];

// ── Pantalla ──────────────────────────────────────────────────

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen>
    with SingleTickerProviderStateMixin {
  PaisPrefix _paisSeleccionado = kPaises[0]; // Argentina por defecto
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorTelefono;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Selector de país ──────────────────────────────────────────

  void _abrirSelectorPais() {
    final busquedaController = TextEditingController();
    List<PaisPrefix> filtrados = kPaises.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Título
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Text(
                        'Seleccioná tu país',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Buscador
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: busquedaController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar país...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 20,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.07),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF5C6EF5),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (v) {
                          setModalState(() {
                            filtrados = kPaises
                                .where(
                                  (p) =>
                                      p.nombre.toLowerCase().contains(
                                        v.toLowerCase(),
                                      ) ||
                                      p.prefijo.contains(v),
                                )
                                .toList();
                          });
                        },
                      ),
                    ),
                    // Lista
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtrados.length,
                        itemBuilder: (_, i) {
                          final pais = filtrados[i];
                          final seleccionado =
                              pais.prefijo == _paisSeleccionado.prefijo &&
                              pais.nombre == _paisSeleccionado.nombre;
                          return ListTile(
                            leading: Text(
                              pais.bandera,
                              style: const TextStyle(fontSize: 22),
                            ),
                            title: Text(
                              pais.nombre,
                              style: TextStyle(
                                color: seleccionado
                                    ? const Color(0xFF5C6EF5)
                                    : Colors.white,
                                fontSize: 14,
                                fontWeight: seleccionado
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: Text(
                              pais.prefijo,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                            onTap: () {
                              setState(() => _paisSeleccionado = pais);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Enviar SMS ────────────────────────────────────────────────

  Future<void> _enviarCodigo() async {
    final numero = _phoneController.text.trim();

    if (numero.isEmpty) {
      setState(() => _errorTelefono = 'Ingresá tu número de teléfono');
      return;
    }
    if (numero.length < 6) {
      setState(() => _errorTelefono = 'Número demasiado corto');
      return;
    }

    setState(() {
      _errorTelefono = null;
      _isLoading = true;
    });

    final numeroCompleto = '${_paisSeleccionado.prefijo}$numero';

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: numeroCompleto,

      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verificación en Android
        await FirebaseAuth.instance.signInWithCredential(credential);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      },

      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        String msg;
        switch (e.code) {
          case 'invalid-phone-number':
            msg = 'Número de teléfono inválido';
            break;
          case 'too-many-requests':
            msg = 'Demasiados intentos. Esperá unos minutos.';
            break;
          case 'network-request-failed':
            msg = 'Sin conexión. Verificá tu internet.';
            break;
          default:
            msg = 'Error al enviar el código. Intentá de nuevo.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },

      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhoneVerificationScreen(
              verificationId: verificationId,
              resendToken: resendToken,
              numeroCompleto: numeroCompleto,
            ),
          ),
        );
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        // Timeout silencioso — el usuario ya está en la pantalla de código
      },

      timeout: const Duration(seconds: 60),
    );
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Stack(
        children: [
          // Fondo
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Back + Logo ──────────────────────
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

                      const Text(
                        "Tu número de celular",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Te enviaremos un código de verificación por SMS",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Selector país + número ───────────
                      Text(
                        'Número de teléfono',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Prefijo
                          GestureDetector(
                            onTap: _abrirSelectorPais,
                            child: Container(
                              height: 54,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _paisSeleccionado.bandera,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _paisSeleccionado.prefijo,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.expand_more_rounded,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Número
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textInputAction: TextInputAction.done,
                              onChanged: (_) {
                                if (_errorTelefono != null) {
                                  setState(() => _errorTelefono = null);
                                }
                              },
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: '11 2345 6789',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.28),
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.06),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _errorTelefono != null
                                        ? Colors.redAccent
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _errorTelefono != null
                                        ? Colors.redAccent
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _errorTelefono != null
                                        ? Colors.redAccent
                                        : const Color(0xFF5C6EF5),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_errorTelefono != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cancel_rounded,
                                color: Colors.redAccent,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _errorTelefono!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),

                      Text(
                        'Ingresá solo el número sin el prefijo de país.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),

                      const Spacer(),

                      // ── Botón enviar ─────────────────────
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
                                onPressed: _enviarCodigo,
                                child: const Text(
                                  "Enviar código",
                                  style: TextStyle(
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
          ),
        ],
      ),
    );
  }
}

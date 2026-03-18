import 'package:flutter/material.dart';

// ── Paleta de colores de Nomad ────────────────────────────────
// Cambiá los valores acá y se aplica en toda la app.

class NomadColors {
  // Verde principal (antes azul #5C6EF5)
  static const primary = Color(0xFF0D9488); // teal-600
  static const primaryLight = Color(0xFF34D399); // teal-400
  static const primaryDark = Color(0xFF0F766E); // teal-700

  // Fondos oscuros (pantallas de registro/login)
  static const darkBg = Color(0xFF0F0F14);
  static const darkCard = Color(0xFF1A1A2E);
  static const darkCircle = Color(0xFF0D3D38); // antes #1E3A5F
  static const darkCircleSel = Color(0xFF0F5950); // antes #1E3A8A

  // Acentos secundarios (sin cambio)
  static const heartBlue = Color(0xFF6366F1);
  static const hugBlueL = Color(0xFF38BDF8);
  static const hugBlueR = Color(0xFF0284C7);
  static const megaBlue = Color(0xFF38BDF8);

  // Estados
  static const success = Color(0xFF27AE60);
  static const error = Color(0xFFEF4444);
  static const warning = Colors.orange;

  // Feed / UI claro
  static const feedBg = Color(0xFFF5F6FA);
  static const feedHeaderBg = Color(0xFFFDFDFD);
  static const feedIconColor = Color(
    0xFF134E4A,
  ); // antes #134E4A (ya era verde)

  // Tick de selección
  static const tick = Color(0xFF0EA5E9); // azul celeste, se mantiene
}

// ── Tema principal de la app ──────────────────────────────────

class NomadTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: NomadColors.primary,
      primary: NomadColors.primary,
      secondary: NomadColors.primaryLight,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: NomadColors.feedBg,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: NomadColors.feedHeaderBg,
      foregroundColor: NomadColors.feedIconColor,
      elevation: 0,
    ),

    // ElevatedButton — botón principal (Continuar, Finalizar, etc.)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: NomadColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.15),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NomadColors.primary,
        side: const BorderSide(color: NomadColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    // TextField
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.07),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: NomadColors.primary, width: 1.5),
      ),
    ),

    // CircularProgressIndicator
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: NomadColors.primary,
    ),

    // BottomNavigationBar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: NomadColors.primary,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      elevation: 0,
    ),

    // Tipografía base
    fontFamily: 'Georgia',
  );
}

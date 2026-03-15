import 'package:firebase_auth/firebase_auth.dart';
import 'location_service.dart';

/// Score de confianza del usuario basado en señales del dispositivo.
/// Rango: 0 a 100.
///
/// Distribución de puntos:
///   GPS verificado              → hasta 35 pts
///   IP consistente con GPS      → hasta 25 pts
///   Timezone consistente        → hasta 15 pts
///   Teléfono verificado         → 20 pts
///   Email verificado            → 5 pts
///
/// El score final es calculado aquí en el cliente y luego
/// validado/enriquecido por la Cloud Function.

class TrustScoreResult {
  final int score;
  final int gpsPoints;
  final int ipPoints;
  final int timezonePoints;
  final int phonePoints;
  final int emailPoints;
  final String level; // bajo / medio / alto
  final List<String> signals; // señales que contribuyeron positivamente
  final List<String> warnings; // inconsistencias detectadas

  const TrustScoreResult({
    required this.score,
    required this.gpsPoints,
    required this.ipPoints,
    required this.timezonePoints,
    required this.phonePoints,
    required this.emailPoints,
    required this.level,
    required this.signals,
    required this.warnings,
  });

  String get levelEmoji {
    switch (level) {
      case 'alto':
        return '🟢';
      case 'medio':
        return '🟡';
      default:
        return '🔴';
    }
  }

  Map<String, dynamic> toMap() => {
    'score': score,
    'level': level,
    'breakdown': {
      'gps': gpsPoints,
      'ip': ipPoints,
      'timezone': timezonePoints,
      'phone': phonePoints,
      'email': emailPoints,
    },
    'signals': signals,
    'warnings': warnings,
    'calculatedAt': DateTime.now().millisecondsSinceEpoch,
    'source': 'client',
  };
}

class TrustScoreService {
  static TrustScoreResult calculate({
    required LocationData location,
    required User user,
  }) {
    int gpsPoints = 0;
    int ipPoints = 0;
    int timezonePoints = 0;
    int phonePoints = 0;
    int emailPoints = 0;
    final signals = <String>[];
    final warnings = <String>[];

    // ── 1. GPS (hasta 35 pts) ─────────────────────────────────
    if (location.gpsGranted && location.lat != null) {
      gpsPoints += 25; // GPS concedido y con coordenadas
      signals.add('GPS verificado');

      if (location.accuracy != null && location.accuracy! < 50) {
        gpsPoints += 10; // Alta precisión (< 50 metros)
        signals.add('Alta precisión GPS');
      } else if (location.accuracy != null && location.accuracy! < 200) {
        gpsPoints += 5; // Precisión media
      }
    } else {
      warnings.add('GPS no disponible o denegado');
    }

    // ── 2. IP (hasta 25 pts) ──────────────────────────────────
    if (location.ipResolved && location.ipCountryCode != null) {
      ipPoints += 10; // IP resuelta
      signals.add('IP pública resuelta');

      // Comparar país de IP con país de GPS
      if (location.gpsGranted &&
          location.countryCode != null &&
          location.ipCountryCode != null) {
        if (location.countryCode!.toLowerCase() ==
            location.ipCountryCode!.toLowerCase()) {
          ipPoints += 15; // IP y GPS coinciden en país
          signals.add('IP consistente con GPS');
        } else {
          warnings.add(
            'IP (${location.ipCountryCode}) no coincide con GPS (${location.countryCode})',
          );
        }
      }
    } else {
      warnings.add('No se pudo resolver IP pública');
    }

    // ── 3. Timezone (hasta 15 pts) ────────────────────────────
    if (location.timezone != null) {
      timezonePoints += 5; // Timezone disponible
      signals.add('Zona horaria detectada');

      // Verificar consistencia timezone con país de GPS
      if (location.gpsGranted && location.countryCode != null) {
        final consistent = _isTimezoneConsistentWithCountry(
          location.timezoneOffsetMinutes,
          location.countryCode!,
        );
        if (consistent) {
          timezonePoints += 10;
          signals.add('Timezone consistente con país');
        } else {
          timezonePoints += 3; // Partial — al menos tenemos timezone
          warnings.add('Timezone puede no coincidir con ubicación GPS');
        }
      } else {
        timezonePoints +=
            5; // Sin GPS para comparar, damos beneficio de la duda
      }
    }

    // ── 4. Teléfono verificado (20 pts) ───────────────────────
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      phonePoints = 20;
      signals.add('Teléfono verificado');
    } else {
      warnings.add('Teléfono no verificado');
    }

    // ── 5. Email verificado (5 pts) ───────────────────────────
    if (user.emailVerified) {
      emailPoints = 5;
      signals.add('Email verificado');
    }

    // ── Score final ───────────────────────────────────────────
    final total =
        (gpsPoints + ipPoints + timezonePoints + phonePoints + emailPoints)
            .clamp(0, 100);

    String level;
    if (total >= 70) {
      level = 'alto';
    } else if (total >= 40) {
      level = 'medio';
    } else {
      level = 'bajo';
    }

    return TrustScoreResult(
      score: total,
      gpsPoints: gpsPoints,
      ipPoints: ipPoints,
      timezonePoints: timezonePoints,
      phonePoints: phonePoints,
      emailPoints: emailPoints,
      level: level,
      signals: signals,
      warnings: warnings,
    );
  }

  // ── Heurística timezone vs país ───────────────────────────────
  // Rangos de offset UTC en minutos para cada país/región

  static bool _isTimezoneConsistentWithCountry(
    int offsetMinutes,
    String countryCode,
  ) {
    final ranges = _countryTimezoneRanges[countryCode.toUpperCase()];
    if (ranges == null) return true; // País no mapeado → no penalizar
    for (final range in ranges) {
      if (offsetMinutes >= range.$1 && offsetMinutes <= range.$2) return true;
    }
    return false;
  }

  // Mapeo país → lista de rangos UTC válidos (min, max) en minutos
  static const Map<String, List<(int, int)>> _countryTimezoneRanges = {
    'AR': [(-180, -180)], // UTC-3
    'UY': [(-180, -120)], // UTC-3 / UTC-2 (DST)
    'MX': [(-420, -300)], // UTC-7 a UTC-5
    'CO': [(-300, -300)], // UTC-5
    'CL': [(-240, -180)], // UTC-4 / UTC-3 (DST)
    'PE': [(-300, -300)], // UTC-5
    'VE': [(-270, -270)], // UTC-4:30
    'BO': [(-240, -240)], // UTC-4
    'PY': [(-240, -180)], // UTC-4 / UTC-3 (DST)
    'EC': [(-300, -300)], // UTC-5
    'BR': [(-180, -120)], // UTC-3 a UTC-2 (DST, mayoría)
    'ES': [(60, 120)], // UTC+1 / UTC+2 (DST)
    'US': [(-600, -240)], // UTC-10 a UTC-4
    'CA': [(-480, -180)], // UTC-8 a UTC-3
    'GB': [(0, 60)], // UTC+0 / UTC+1 (DST)
    'DE': [(60, 120)], // UTC+1 / UTC+2 (DST)
    'FR': [(60, 120)], // UTC+1 / UTC+2 (DST)
    'IT': [(60, 120)], // UTC+1 / UTC+2 (DST)
    'PT': [(0, 60)], // UTC+0 / UTC+1 (DST)
    'AU': [(480, 660)], // UTC+8 a UTC+11
    'JP': [(540, 540)], // UTC+9
    'CN': [(480, 480)], // UTC+8
    'IN': [(330, 330)], // UTC+5:30
    'ZA': [(120, 120)], // UTC+2
    'IL': [(120, 180)], // UTC+2 / UTC+3 (DST)
    'AE': [(240, 240)], // UTC+4
    'CH': [(60, 120)], // UTC+1 / UTC+2 (DST)
    'NL': [(60, 120)], // UTC+1 / UTC+2 (DST)
    'BE': [(60, 120)], // UTC+1 / UTC+2 (DST)
    'SE': [(60, 120)], // UTC+1 / UTC+2 (DST)
    'NO': [(60, 120)], // UTC+1 / UTC+2 (DST)
    'DK': [(60, 120)], // UTC+1 / UTC+2 (DST)
    'PL': [(60, 120)], // UTC+1 / UTC+2 (DST)
    'RU': [(180, 720)], // UTC+3 a UTC+12
    'TR': [(180, 180)], // UTC+3
    'KR': [(540, 540)], // UTC+9
  };
}

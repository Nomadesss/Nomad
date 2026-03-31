import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// LocationService — recolección de datos de ubicación para Nomad
//
// Estrategia de dos capas:
//   1. GPS  → precisión alta, requiere permiso del usuario.
//   2. IP   → fallback cuando GPS no está disponible o fue denegado.
//
// El resultado de collect() alimenta a:
//   - UserService.updateUbicacion()    → guarda en Firestore
//   - TrustScoreService.calculate()   → calcula el score de confianza
//
// CORRECCIÓN respecto al original:
//   ip-api.com usaba HTTP plano → bloqueado por ATS en iOS.
//   Reemplazado por ipinfo.io (HTTPS nativo, 50k req/mes gratis).
// ─────────────────────────────────────────────────────────────────────────────

// Token de ipinfo.io.
// En producción: leer desde variables de entorno o Flutter --dart-define.
// Para el MVP podés usar el plan gratuito sin token (límite 50k/mes).
// Registrarse en: https://ipinfo.io/signup
const _kIpInfoToken = String.fromEnvironment(
  'IPINFO_TOKEN',
  defaultValue: '', // vacío = plan gratuito
);

// ─────────────────────────────────────────────────────────────────────────────
// LocationData — resultado consolidado de GPS + IP + timezone
// ─────────────────────────────────────────────────────────────────────────────

class LocationData {
  // ── GPS ────────────────────────────────────────────────────────────────────
  final double? lat;
  final double? lng;
  final double? accuracy;
  final String? city; // ciudad por GPS + geocoding
  final String? country; // país por GPS + geocoding
  final String? countryCode; // código ISO por GPS (ej: 'UY')
  final bool gpsGranted;

  // ── IP ─────────────────────────────────────────────────────────────────────
  final String? ipAddress;
  final String? ipCountry;
  final String? ipCountryCode; // código ISO por IP (ej: 'ES')
  final String? ipCity;
  final String? ipOrg; // ISP u organización de la IP
  final bool ipResolved;

  // ── Timezone ───────────────────────────────────────────────────────────────
  final String? timezone;
  final int timezoneOffsetMinutes;

  const LocationData({
    this.lat,
    this.lng,
    this.accuracy,
    this.city,
    this.country,
    this.countryCode,
    this.gpsGranted = false,
    this.ipAddress,
    this.ipCountry,
    this.ipCountryCode,
    this.ipCity,
    this.ipOrg,
    this.ipResolved = false,
    this.timezone,
    this.timezoneOffsetMinutes = 0,
  });

  // ── Getters de mejor valor disponible ─────────────────────────────────────
  //
  // NUEVO respecto al original.
  //
  // Antes el caller tenía que hacer:
  //   final city = location.city ?? location.ipCity ?? 'desconocida';
  // en cada lugar que usaba la ubicación.
  //
  // Ahora el getter lo resuelve acá, donde tiene todo el contexto:
  //   final city = location.cityEffective;
  //
  // GPS tiene prioridad sobre IP cuando está disponible.

  /// Mejor ciudad disponible: GPS primero, IP como fallback.
  String? get cityEffective => city ?? ipCity;

  /// Mejor código de país disponible: GPS primero, IP como fallback.
  String? get countryCodeEffective => countryCode ?? ipCountryCode;

  /// Mejor nombre de país disponible: GPS primero, IP como fallback.
  String? get countryEffective => country ?? ipCountry;

  /// True si tenemos al menos algún dato de ubicación (GPS o IP).
  bool get hasAnyLocation => gpsGranted || ipResolved;

  // ── Serialización ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'gps': {
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'city': city,
      'country': country,
      'countryCode': countryCode,
      'granted': gpsGranted,
    },
    'ip': {
      'address': ipAddress,
      'country': ipCountry,
      'countryCode': ipCountryCode,
      'city': ipCity,
      'org': ipOrg,
      'resolved': ipResolved,
    },
    'timezone': {'name': timezone, 'offsetMinutes': timezoneOffsetMinutes},
    // Campos promovidos al nivel raíz para facilitar queries en Firestore.
    // FeedService filtra por 'city' directamente sin navegar en el objeto.
    'cityEffective': cityEffective?.trim().toLowerCase(),
    'countryCodeEffective': countryCodeEffective,
    'capturedAt': DateTime.now().millisecondsSinceEpoch,
  };

  @override
  String toString() =>
      'LocationData(city: $cityEffective, country: $countryCodeEffective, '
      'gps: $gpsGranted, ip: $ipResolved)';
}

// ─────────────────────────────────────────────────────────────────────────────
// LocationService
// ─────────────────────────────────────────────────────────────────────────────

class LocationService {
  // ── GPS ────────────────────────────────────────────────────────────────────

  static Future<
    ({
      Position? position,
      String? city,
      String? country,
      String? countryCode,
      bool granted,
    })
  >
  getGPS() async {
    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (
          position: null,
          city: null,
          country: null,
          countryCode: null,
          granted: false,
        );
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (
          position: null,
          city: null,
          country: null,
          countryCode: null,
          granted: false,
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      String? city, country, countryCode;

      try {
        final placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          city = p.locality ?? p.subAdministrativeArea;
          country = p.country;
          countryCode = p.isoCountryCode;
        }
      } catch (_) {
        // El geocoding puede fallar sin conexión.
        // Devolvemos las coordenadas igual — son suficientes para trust score.
      }

      return (
        position: pos,
        city: city,
        country: country,
        countryCode: countryCode,
        granted: true,
      );
    } catch (_) {
      return (
        position: null,
        city: null,
        country: null,
        countryCode: null,
        granted: false,
      );
    }
  }

  // ── IP pública ─────────────────────────────────────────────────────────────
  //
  // CORRECCIÓN: reemplaza http://ip-api.com (HTTP → bloqueado en iOS)
  // por https://ipinfo.io (HTTPS nativo, gratuito hasta 50k req/mes).
  //
  // Respuesta de ipinfo.io:
  //   { "ip": "1.2.3.4", "city": "Madrid", "country": "ES",
  //     "org": "AS3352 TELEFONICA", "timezone": "Europe/Madrid" }
  //
  // Si el token está vacío, usa el plan gratuito (sin autenticación).
  // Si el token está configurado, lo incluye en el header Authorization.

  static Future<
    ({
      String? ip,
      String? country,
      String? countryCode,
      String? city,
      String? org,
      bool resolved,
    })
  >
  getIPInfo() async {
    // Intentar primero con ipinfo.io (HTTPS, gratuito).
    final ipinfoResult = await _getFromIpinfo();
    if (ipinfoResult.resolved) return ipinfoResult;

    // Fallback: ip-api.com por HTTPS.
    // Requiere plan Pro ($15/mes). Si no tenés el plan, este fallback
    // también fallará — en ese caso el trust score simplemente no suma
    // los puntos de IP, sin crashear la app.
    if (kDebugMode) {
      debugPrint('[LocationService] ipinfo.io falló, intentando ip-api.com...');
    }
    return await _getFromIpApi();
  }

  static Future<
    ({
      String? ip,
      String? country,
      String? countryCode,
      String? city,
      String? org,
      bool resolved,
    })
  >
  _getFromIpinfo() async {
    try {
      final headers = <String, String>{};
      if (_kIpInfoToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_kIpInfoToken';
      }

      final response = await http
          .get(Uri.parse('https://ipinfo.io/json'), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // ipinfo.io devuelve el país como código ISO directamente (ej: 'ES').
        // No hay campo 'countryName' — lo mapeamos al mismo campo.
        final countryCode = data['country'] as String?;

        return (
          ip: data['ip'] as String?,
          // ipinfo.io no devuelve nombre de país, solo el código.
          // En UserModel guardamos el código y lo resolvemos en la UI.
          country: countryCode,
          countryCode: countryCode,
          city: data['city'] as String?,
          org: data['org'] as String?,
          resolved: true,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationService] ipinfo.io error: $e');
      }
    }

    return (
      ip: null,
      country: null,
      countryCode: null,
      city: null,
      org: null,
      resolved: false,
    );
  }

  static Future<
    ({
      String? ip,
      String? country,
      String? countryCode,
      String? city,
      String? org,
      bool resolved,
    })
  >
  _getFromIpApi() async {
    try {
      // NOTA: ip-api.com HTTPS requiere plan Pro.
      // En plan gratuito solo funciona HTTP, que está bloqueado en iOS.
      // Esta URL solo funcionará si tenés el plan Pro activo.
      final response = await http
          .get(
            Uri.parse(
              'https://pro.ip-api.com/json/'
              '?fields=status,country,countryCode,city,org,query'
              '&lang=es',
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          return (
            ip: data['query'] as String?,
            country: data['country'] as String?,
            countryCode: data['countryCode'] as String?,
            city: data['city'] as String?,
            org: data['org'] as String?,
            resolved: true,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationService] ip-api.com error: $e');
      }
    }

    return (
      ip: null,
      country: null,
      countryCode: null,
      city: null,
      org: null,
      resolved: false,
    );
  }

  // ── Timezone ───────────────────────────────────────────────────────────────

  static ({String name, int offsetMinutes}) getTimezone() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    return (name: now.timeZoneName, offsetMinutes: offset.inMinutes);
  }

  // ── Recolectar todo ────────────────────────────────────────────────────────
  //
  // GPS e IP se ejecutan en paralelo con Future.wait para minimizar
  // el tiempo total de espera. En la práctica:
  //   - GPS:  hasta 15 segundos si el chip tarda en fijar posición.
  //   - IP:   hasta 8 segundos.
  //   - Total: max(GPS, IP) en lugar de GPS + IP.

  static Future<LocationData> collect() async {
    final results = await Future.wait([getGPS(), getIPInfo()]);

    final gps =
        results[0]
            as ({
              Position? position,
              String? city,
              String? country,
              String? countryCode,
              bool granted,
            });

    final ip =
        results[1]
            as ({
              String? ip,
              String? country,
              String? countryCode,
              String? city,
              String? org,
              bool resolved,
            });

    final tz = getTimezone();

    return LocationData(
      // GPS
      lat: gps.position?.latitude,
      lng: gps.position?.longitude,
      accuracy: gps.position?.accuracy,
      city: gps.city,
      country: gps.country,
      countryCode: gps.countryCode,
      gpsGranted: gps.granted,
      // IP
      ipAddress: ip.ip,
      ipCountry: ip.country,
      ipCountryCode: ip.countryCode,
      ipCity: ip.city,
      ipOrg: ip.org,
      ipResolved: ip.resolved,
      // Timezone
      timezone: tz.name,
      timezoneOffsetMinutes: tz.offsetMinutes,
    );
  }

  // ── Búsqueda de ciudades del mundo ───────────────────────────────────────────
  // Usa OpenStreetMap (gratis, sin API key)

  static Future<List<Map<String, String>>> searchCities(String query) async {
    if (query.trim().length < 2) return [];

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=$query'
        '&format=json'
        '&addressdetails=1'
        '&limit=5',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'NomadApp/1.0'},
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as List;

      return data
          .map((e) {
            final address = e['address'] as Map<String, dynamic>? ?? {};

            // Forzamos el tipado a <String, String> para que coincida con el Future
            return <String, String>{
              'ciudad':
                  (address['city'] ??
                          address['town'] ??
                          address['village'] ??
                          '')
                      .toString(),
              'pais': (address['country'] ?? '').toString(),
              'pais_code': (address['country_code'] ?? '')
                  .toString(), // <-- Clave para el emoji de la bandera
              'lat': (e['lat'] ?? '').toString(),
              'lng': (e['lon'] ?? '').toString(),
            };
          })
          .where((e) => e['ciudad']!.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

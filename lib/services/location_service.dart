import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class LocationData {
  final double? lat;
  final double? lng;
  final double? accuracy;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? ipAddress;
  final String? ipCountry;
  final String? ipCountryCode;
  final String? ipCity;
  final String? ipOrg;
  final String? timezone;
  final int timezoneOffsetMinutes;
  final bool gpsGranted;
  final bool ipResolved;

  const LocationData({
    this.lat,
    this.lng,
    this.accuracy,
    this.city,
    this.country,
    this.countryCode,
    this.ipAddress,
    this.ipCountry,
    this.ipCountryCode,
    this.ipCity,
    this.ipOrg,
    this.timezone,
    this.timezoneOffsetMinutes = 0,
    this.gpsGranted = false,
    this.ipResolved = false,
  });

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
    'capturedAt': DateTime.now().millisecondsSinceEpoch,
  };
}

class LocationService {
  // ── GPS ───────────────────────────────────────────────────────

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

      // ── FIX: usar desiredAccuracy en lugar de locationSettings ──
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
      } catch (_) {}

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

  // ── IP pública ────────────────────────────────────────────────

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
    try {
      final response = await http
          .get(
            Uri.parse(
              'http://ip-api.com/json/?fields=status,country,countryCode,city,org,query',
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
    } catch (_) {}

    return (
      ip: null,
      country: null,
      countryCode: null,
      city: null,
      org: null,
      resolved: false,
    );
  }

  // ── Timezone ──────────────────────────────────────────────────

  static ({String name, int offsetMinutes}) getTimezone() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    return (name: now.timeZoneName, offsetMinutes: offset.inMinutes);
  }

  // ── Recolectar todo ───────────────────────────────────────────

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
      lat: gps.position?.latitude,
      lng: gps.position?.longitude,
      accuracy: gps.position?.accuracy,
      city: gps.city,
      country: gps.country,
      countryCode: gps.countryCode,
      gpsGranted: gps.granted,
      ipAddress: ip.ip,
      ipCountry: ip.country,
      ipCountryCode: ip.countryCode,
      ipCity: ip.city,
      ipOrg: ip.org,
      ipResolved: ip.resolved,
      timezone: tz.name,
      timezoneOffsetMinutes: tz.offsetMinutes,
    );
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// PlacesService — autocompletado de ubicaciones via Google Places API
//
// SETUP (una vez):
//   1. Ir a https://console.cloud.google.com
//   2. Habilitar "Places API" en APIs & Services
//   3. Crear una API Key (restringirla a Android + iOS en producción)
//   4. Pegar la key en _apiKey abajo
//   5. En Android: agregar en AndroidManifest.xml:
//        <meta-data android:name="com.google.android.geo.API_KEY"
//                   android:value="TU_API_KEY"/>
//   6. En iOS: agregar en AppDelegate.swift:
//        GMSPlacesClient.provideAPIKey("TU_API_KEY")
// ─────────────────────────────────────────────────────────────────────────────

class PlacesService {
  static const _apiKey = 'AIzaSyBgx90VnKLBc0hIkYWM6juup1jFWHllhhc';

  // ── Autocompletar ──────────────────────────────────────────────────────────
  //
  // Devuelve hasta 5 sugerencias de lugares para el texto ingresado.
  // sessionToken agrupa las requests de una misma sesión para facturación.

  static Future<List<PlacePrediction>> autocomplete(
    String input, {
    String? sessionToken,
    String language = 'es',
  }) async {
    if (input.trim().length < 3) return [];

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
      ).replace(queryParameters: {
        'input':        input,
        'key':          _apiKey,
        'language':     language,
        'sessiontoken': sessionToken ?? '',
        // Opcional: limitar a ciudades/países
        // 'types': '(cities)',
        // 'components': 'country:ar',
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List<dynamic>;
          return predictions
              .map((p) => PlacePrediction.fromJson(p))
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }

  // ── Obtener detalles de un lugar (coordenadas, dirección completa) ─────────
  //
  // Llamar cuando el usuario selecciona una sugerencia.
  // sessionToken debe ser el mismo que se usó en autocomplete().

  static Future<PlaceDetail?> getDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json',
      ).replace(queryParameters: {
        'place_id':     placeId,
        'key':          _apiKey,
        'fields':       'formatted_address,geometry,name',
        'sessiontoken': sessionToken ?? '',
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return PlaceDetail.fromJson(data['result']);
        }
      }
    } catch (_) {}

    return null;
  }
}

// ── Modelos ───────────────────────────────────────────────────────────────────

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] as Map<String, dynamic>? ?? {};
    return PlacePrediction(
      placeId:       json['place_id'] as String,
      description:   json['description'] as String,
      mainText:      structured['main_text'] as String? ?? json['description'] as String,
      secondaryText: structured['secondary_text'] as String? ?? '',
    );
  }
}

class PlaceDetail {
  final String name;
  final String formattedAddress;
  final double? lat;
  final double? lng;

  const PlaceDetail({
    required this.name,
    required this.formattedAddress,
    this.lat,
    this.lng,
  });

  factory PlaceDetail.fromJson(Map<String, dynamic> json) {
    final location = json['geometry']?['location'];
    return PlaceDetail(
      name:             json['name'] as String? ?? '',
      formattedAddress: json['formatted_address'] as String? ?? '',
      lat:              location?['lat']?.toDouble(),
      lng:              location?['lng']?.toDouble(),
    );
  }
}
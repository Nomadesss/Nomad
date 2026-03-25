import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// SpotifyService — búsqueda de canciones via Spotify Web API
//
// Usa Client Credentials Flow (sin OAuth del usuario).
// Solo lectura: buscar canciones y obtener previews de 30 segundos.
//
// SETUP (una vez):
//   1. Ir a https://developer.spotify.com/dashboard
//   2. Crear una app
//   3. Copiar Client ID y Client Secret acá abajo
//   4. No se necesita redirect URI para Client Credentials
// ─────────────────────────────────────────────────────────────────────────────

class SpotifyService {
  // ── Credenciales — reemplazar con las tuyas ────────────────────────────────
  static const _clientId     = '6e06d76d90bb4b5483d6ee0ff762c6db';
  static const _clientSecret = 'a7ca436d37b549f1ba07e9d88c0df4ec';

  static String? _accessToken;
  static DateTime? _tokenExpiry;

  // ── Obtener/renovar token ──────────────────────────────────────────────────

  static Future<String?> _getToken() async {
    // Reutilizar token si todavía es válido (con 60s de margen)
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(seconds: 60)))) {
      return _accessToken;
    }

    final credentials = base64Encode(
      utf8.encode('$_clientId:$_clientSecret'),
    );

    try {
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'client_credentials'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'] as String;
        _tokenExpiry = DateTime.now().add(
          Duration(seconds: (data['expires_in'] as int)),
        );
        return _accessToken;
      }
    } catch (_) {}

    return null;
  }

  // ── Buscar canciones ───────────────────────────────────────────────────────

  static Future<List<SpotifyTrack>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final token = await _getToken();
    if (token == null) return [];

    try {
      final uri = Uri.parse('https://api.spotify.com/v1/search').replace(
        queryParameters: {
          'q':     query,
          'type':  'track',
          'limit': '10',
          'market': 'AR', // cambiar según tu mercado principal
        },
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['tracks']['items'] as List<dynamic>;
        return items
            .where((item) => item['preview_url'] != null)
            .map((item) => SpotifyTrack.fromJson(item))
            .toList();
      }
    } catch (_) {}

    return [];
  }
}

// ── Modelo de canción ─────────────────────────────────────────────────────────

class SpotifyTrack {
  final String id;
  final String name;
  final String artist;
  final String? albumArt;    // URL de la imagen del álbum
  final String? previewUrl;  // Preview de 30 segundos

  const SpotifyTrack({
    required this.id,
    required this.name,
    required this.artist,
    this.albumArt,
    this.previewUrl,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    final artists = (json['artists'] as List<dynamic>)
        .map((a) => a['name'] as String)
        .join(', ');

    final images = json['album']?['images'] as List<dynamic>?;
    final albumArt = images != null && images.isNotEmpty
        ? images[0]['url'] as String?
        : null;

    return SpotifyTrack(
      id:         json['id'] as String,
      name:       json['name'] as String,
      artist:     artists,
      albumArt:   albumArt,
      previewUrl: json['preview_url'] as String?,
    );
  }
}
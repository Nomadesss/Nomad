// ─────────────────────────────────────────────────────────────────────────────
// migration_guide_service.dart  –  Nomad App
// Ubicación: lib/services/migration_guide_service.dart
//
// Servicio que lee la colección /migration_guides de Firestore y
// aplica los filtros del perfil del usuario (país destino, objetivo,
// pasaporte UE) para devolver guías relevantes.
//
// Colección Firestore: migration_guides
// Índices requeridos:
//   - paisIso ASC + categoria ASC
//   - paisIso ASC + objetivos ARRAY_CONTAINS
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'migration_guide_model.dart';

class MigrationGuideService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Cargar perfil del usuario ───────────────────────────────────────────────

  static Future<UserMigrationFilter> loadUserFilter() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const UserMigrationFilter(paisDestinoIso: 'ES');
    }
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      return UserMigrationFilter.fromFirestoreData(data);
    } catch (e) {
      return const UserMigrationFilter(paisDestinoIso: 'ES');
    }
  }

  // ── Guardar objetivo en el perfil del usuario ───────────────────────────────

  static Future<void> saveUserObjective({
    required String objetivo,
    required bool tienePasaporteUe,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'migracionObjetivo': objetivo,
      'tienePasaporteUe': tienePasaporteUe,
    });
  }

  // ── Update Pais de destino ───────────────────────────────────────────────

  static Future<void> updateDestinationCountry(String paisIso) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      "destinationCountry": paisIso,
    });
  }

  // ── Cargar guías filtradas ──────────────────────────────────────────────────

  /// Devuelve todas las guías para el país destino del usuario,
  /// filtradas por su objetivo y si tiene pasaporte UE.
  static Future<List<MigrationGuide>> getGuidesForUser({
    UserMigrationFilter? filter,
  }) async {
    final f = filter ?? await loadUserFilter();

    try {
      // Obtener todas las guías del país destino
      final snap = await _db
          .collection('migration_guides')
          .where('paisIso', isEqualTo: f.paisDestinoIso)
          .get();

      final guides = snap.docs
          .map((d) => MigrationGuide.fromFirestore(d))
          .where(
            (g) => g.aplicaA(
              objetivoUsuario: f.objetivo,
              tienePasaporteUe: f.tienePasaporteUe,
            ),
          )
          .toList();

      // Ordenar: primero las de la categoría que coincide con el objetivo,
      // luego el resto. Dentro de cada grupo, por título.
      guides.sort((a, b) {
        final aPrimario =
            f.objetivo != null && a.objetivos.contains(f.objetivo);
        final bPrimario =
            f.objetivo != null && b.objetivos.contains(f.objetivo);
        if (aPrimario && !bPrimario) return -1;
        if (!aPrimario && bPrimario) return 1;
        return a.titulo.compareTo(b.titulo);
      });

      return guides;
    } catch (e) {
      debugPrint('[MigrationGuideService] Error: $e');
      return [];
    }
  }

  /// Devuelve guías por categoría específica
  static Future<List<MigrationGuide>> getGuidesByCategory({
    required String paisIso,
    required GuideCategory categoria,
  }) async {
    try {
      final snap = await _db
          .collection('migration_guides')
          .where('paisIso', isEqualTo: paisIso)
          .where('categoria', isEqualTo: _categoryToString(categoria))
          .get();

      return snap.docs.map((d) => MigrationGuide.fromFirestore(d)).toList()
        ..sort((a, b) => a.titulo.compareTo(b.titulo));
    } catch (e) {
      debugPrint('[MigrationGuideService] Error: $e');
      return [];
    }
  }

  /// Devuelve todos los países disponibles en la colección
  static Future<List<Map<String, String>>> getAvailableCountries() async {
    try {
      final snap = await _db.collection('migration_guides').get();
      final paises = <String, Map<String, String>>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final iso = d['paisIso'] as String? ?? '';
        final name = d['paisNombre'] as String? ?? '';
        final flag = d['paisFlag'] as String? ?? '🌍';
        if (iso.isNotEmpty) {
          paises[iso] = {'iso': iso, 'nombre': name, 'flag': flag};
        }
      }
      return paises.values.toList()
        ..sort((a, b) => a['nombre']!.compareTo(b['nombre']!));
    } catch (e) {
      return [];
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _categoryToString(GuideCategory cat) {
    switch (cat) {
      case GuideCategory.estudios:
        return 'estudios';
      case GuideCategory.trabajo:
        return 'trabajo';
      case GuideCategory.emprender:
        return 'emprender';
      case GuideCategory.familiar:
        return 'familiar';
      case GuideCategory.residencia:
        return 'residencia';
      case GuideCategory.circunstanciasExcepcionales:
        return 'circunstancias_excepcionales';
      case GuideCategory.nomadaDigital:
        return 'nomada_digital';
      case GuideCategory.retorno:
        return 'retorno';
      case GuideCategory.documento:
        return 'documento';
      case GuideCategory.menores:
        return 'menores';
      case GuideCategory.otro:
        return 'otro';
    }
  }
}

// Necesario para debugPrint fuera de widget
void debugPrint(String msg) => print(msg);

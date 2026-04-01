import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────
// Service Cartes NYME — Rotation automatique multi-clés
//
// PRIORITÉ :
// 1. Google Maps (5 clés × 26 500 req = 132 500 req/mois)
// 2. Mapbox (5 clés × 48 500 req = 242 500 req/mois)
// 3. OSRM OpenStreetMap (illimité, gratuit)
//
// LOGIQUE :
// - Chaque clé a un compteur de requêtes mensuel
// - Quand une clé atteint sa limite → passe à la suivante
// - Remise à zéro automatique au 1er du mois
// - Si toutes les clés Google épuisées → bascule sur Mapbox
// - Si toutes Mapbox épuisées → bascule sur OSRM
// - Fonctionne avec 1 seule clé de chaque (les autres sont vides)
// - Ajouter des clés = juste renseigner dans les listes
// ─────────────────────────────────────────────────────────────

class ItineraireResult {
  final List<LatLng> polyline;
  final double distanceKm;
  final int dureeMinutes;
  final String apiUtilisee;
  final String cleUtilisee;

  const ItineraireResult({
    required this.polyline,
    required this.distanceKm,
    required this.dureeMinutes,
    required this.apiUtilisee,
    required this.cleUtilisee,
  });
}

// ── Configuration d'une clé API ──
class _CleApi {
  final String cle;
  final int limiteParMois;
  final String provider; // 'google', 'mapbox', 'osrm'

  const _CleApi({
    required this.cle,
    required this.limiteParMois,
    required this.provider,
  });

  bool get estVide => cle.isEmpty || cle.startsWith('VOTRE_');
}

class MapService {
  final Dio _dio;

  MapService() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  // ════════════════════════════════════════════════════════
  // CONFIGURATION DES CLÉS
  // Ajouter simplement vos clés dans ces listes
  // Les clés vides ou 'VOTRE_...' sont ignorées automatiquement
  // ════════════════════════════════════════════════════════

  static const List<_CleApi> _clesGoogle = [
    _CleApi(cle: 'VOTRE_CLE_GOOGLE_1', limiteParMois: 26500, provider: 'google'),
    _CleApi(cle: 'VOTRE_CLE_GOOGLE_2', limiteParMois: 26500, provider: 'google'),
    _CleApi(cle: 'VOTRE_CLE_GOOGLE_3', limiteParMois: 26500, provider: 'google'),
    _CleApi(cle: 'VOTRE_CLE_GOOGLE_4', limiteParMois: 26500, provider: 'google'),
    _CleApi(cle: 'VOTRE_CLE_GOOGLE_5', limiteParMois: 26500, provider: 'google'),
  ];

  static const List<_CleApi> _clesMapbox = [
    _CleApi(cle: 'VOTRE_TOKEN_MAPBOX_1', limiteParMois: 48500, provider: 'mapbox'),
    _CleApi(cle: 'VOTRE_TOKEN_MAPBOX_2', limiteParMois: 48500, provider: 'mapbox'),
    _CleApi(cle: 'VOTRE_TOKEN_MAPBOX_3', limiteParMois: 48500, provider: 'mapbox'),
    _CleApi(cle: 'VOTRE_TOKEN_MAPBOX_4', limiteParMois: 48500, provider: 'mapbox'),
    _CleApi(cle: 'VOTRE_TOKEN_MAPBOX_5', limiteParMois: 48500, provider: 'mapbox'),
  ];

  // OSRM est toujours disponible (illimité, pas de clé)
  static const _cleOsrm = _CleApi(cle: 'osrm', limiteParMois: 999999, provider: 'osrm');

  // ════════════════════════════════════════════════════════
  // MÉTHODE PRINCIPALE — calculer un itinéraire
  // ════════════════════════════════════════════════════════

  Future<ItineraireResult?> calculerItineraire({
    required LatLng depart,
    required LatLng arrivee,
  }) async {
    await _verifierResetMensuel();

    // 1. Essayer toutes les clés Google disponibles
    final googleDispo = _clesGoogle.where((c) => !c.estVide).toList();
    for (final cle in googleDispo) {
      final ok = await _quotaDisponible(cle);
      if (!ok) {
        debugPrint('[Maps] Google clé ${_indexCle(cle)} épuisée, suivante...');
        continue;
      }
      try {
        final result = await _googleRoute(depart, arrivee, cle);
        await _incrementerCompteur(cle);
        debugPrint('[Maps] Google clé ${_indexCle(cle)} ✅ (${await _compteurActuel(cle)} req)');
        return result;
      } catch (e) {
        debugPrint('[Maps] Google clé ${_indexCle(cle)} erreur: $e');
        continue;
      }
    }

    // 2. Essayer toutes les clés Mapbox disponibles
    final mapboxDispo = _clesMapbox.where((c) => !c.estVide).toList();
    for (final cle in mapboxDispo) {
      final ok = await _quotaDisponible(cle);
      if (!ok) {
        debugPrint('[Maps] Mapbox clé ${_indexCle(cle)} épuisée, suivante...');
        continue;
      }
      try {
        final result = await _mapboxRoute(depart, arrivee, cle);
        await _incrementerCompteur(cle);
        debugPrint('[Maps] Mapbox clé ${_indexCle(cle)} ✅ (${await _compteurActuel(cle)} req)');
        return result;
      } catch (e) {
        debugPrint('[Maps] Mapbox clé ${_indexCle(cle)} erreur: $e');
        continue;
      }
    }

    // 3. Fallback OSRM (toujours gratuit, illimité)
    debugPrint('[Maps] Fallback OSRM (toutes clés épuisées ou absentes)');
    try {
      final result = await _osrmRoute(depart, arrivee);
      debugPrint('[Maps] OSRM ✅');
      return result;
    } catch (e) {
      debugPrint('[Maps] OSRM erreur: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════
  // APIS
  // ════════════════════════════════════════════════════════

  Future<ItineraireResult> _googleRoute(LatLng dep, LatLng arr, _CleApi cle) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${dep.latitude},${dep.longitude}'
        '&destination=${arr.latitude},${arr.longitude}'
        '&mode=driving&key=${cle.cle}';

    final response = await _dio.get(url);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

    final data = response.data as Map<String, dynamic>;
    if (data['status'] != 'OK') throw Exception('Google status: ${data['status']}');

    final leg = data['routes'][0]['legs'][0];
    final steps = leg['steps'] as List;
    final List<LatLng> polyline = [];
    for (final step in steps) {
      polyline.addAll(_decoderPolylineGoogle(step['polyline']['points']));
    }

    return ItineraireResult(
      polyline: polyline,
      distanceKm: (leg['distance']['value'] as num) / 1000.0,
      dureeMinutes: ((leg['duration']['value'] as num) / 60).round(),
      apiUtilisee: 'Google Maps',
      cleUtilisee: 'Google clé ${_indexCle(cle)}',
    );
  }

  Future<ItineraireResult> _mapboxRoute(LatLng dep, LatLng arr, _CleApi cle) async {
    final url =
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${dep.longitude},${dep.latitude};'
        '${arr.longitude},${arr.latitude}'
        '?geometries=geojson&access_token=${cle.cle}';

    final response = await _dio.get(url);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

    final data = response.data as Map<String, dynamic>;
    if ((data['routes'] as List?)?.isEmpty ?? true) throw Exception('Mapbox: aucune route');

    final route = data['routes'][0];
    final coords = route['geometry']['coordinates'] as List;
    final polyline = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();

    return ItineraireResult(
      polyline: polyline,
      distanceKm: (route['distance'] as num) / 1000.0,
      dureeMinutes: ((route['duration'] as num) / 60).round(),
      apiUtilisee: 'Mapbox',
      cleUtilisee: 'Mapbox clé ${_indexCle(cle)}',
    );
  }

  Future<ItineraireResult> _osrmRoute(LatLng dep, LatLng arr) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${dep.longitude},${dep.latitude};'
        '${arr.longitude},${arr.latitude}'
        '?overview=full&geometries=geojson';

    final response = await _dio.get(url);
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

    final data = response.data as Map<String, dynamic>;
    if (data['code'] != 'Ok') throw Exception('OSRM: ${data['code']}');

    final route = data['routes'][0];
    final coords = route['geometry']['coordinates'] as List;
    final polyline = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();

    return ItineraireResult(
      polyline: polyline,
      distanceKm: (route['distance'] as num) / 1000.0,
      dureeMinutes: ((route['duration'] as num) / 60).round(),
      apiUtilisee: 'OSRM (OpenStreetMap)',
      cleUtilisee: 'osrm_gratuit',
    );
  }

  // ════════════════════════════════════════════════════════
  // GESTION DES QUOTAS ET COMPTEURS
  // ════════════════════════════════════════════════════════

  String _clePrefsKey(String provider, int index) => 'maps_count_${provider}_$index';
  String _cleMoisKey(String provider, int index) => 'maps_mois_${provider}_$index';
  int _indexCle(_CleApi cle) {
    final liste = cle.provider == 'google' ? _clesGoogle : _clesMapbox;
    return liste.indexOf(cle) + 1;
  }

  // Vérifier si le quota est disponible pour une clé
  Future<bool> _quotaDisponible(_CleApi cle) async {
    if (cle.estVide) return false;
    final prefs = await SharedPreferences.getInstance();
    final provider = cle.provider;
    final index = _indexCle(cle);
    final count = prefs.getInt(_clePrefsKey(provider, index)) ?? 0;
    return count < cle.limiteParMois;
  }

  // Incrémenter le compteur d'une clé
  Future<void> _incrementerCompteur(_CleApi cle) async {
    final prefs = await SharedPreferences.getInstance();
    final provider = cle.provider;
    final index = _indexCle(cle);
    final key = _clePrefsKey(provider, index);
    final count = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, count + 1);
  }

  // Lire le compteur actuel
  Future<int> _compteurActuel(_CleApi cle) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_clePrefsKey(cle.provider, _indexCle(cle))) ?? 0;
  }

  // Vérifier et appliquer la remise à zéro mensuelle
  Future<void> _verifierResetMensuel() async {
    final prefs = await SharedPreferences.getInstance();
    final moisActuel = DateTime.now().month;
    final anneeActuelle = DateTime.now().year;
    final cleReset = 'maps_reset_mois';
    final cleResetAnnee = 'maps_reset_annee';

    final moisStocke = prefs.getInt(cleReset) ?? 0;
    final anneeStockee = prefs.getInt(cleResetAnnee) ?? 0;

    if (moisActuel != moisStocke || anneeActuelle != anneeStockee) {
      debugPrint('[Maps] Remise à zéro mensuelle des compteurs 🔄');
      // Remettre à zéro tous les compteurs
      for (int i = 1; i <= 5; i++) {
        await prefs.setInt(_clePrefsKey('google', i), 0);
        await prefs.setInt(_clePrefsKey('mapbox', i), 0);
      }
      await prefs.setInt(cleReset, moisActuel);
      await prefs.setInt(cleResetAnnee, anneeActuelle);
    }
  }

  // ════════════════════════════════════════════════════════
  // STATISTIQUES (pour debug/admin)
  // ════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getStatistiques() async {
    final prefs = await SharedPreferences.getInstance();
    final stats = <String, dynamic>{};

    for (int i = 1; i <= 5; i++) {
      final countGoogle = prefs.getInt(_clePrefsKey('google', i)) ?? 0;
      final countMapbox = prefs.getInt(_clePrefsKey('mapbox', i)) ?? 0;
      final dispo = !_clesGoogle[i - 1].estVide;
      final dispoMapbox = !_clesMapbox[i - 1].estVide;

      stats['google_$i'] = {
        'actif': dispo,
        'utilise': countGoogle,
        'limite': 26500,
        'restant': dispo ? (26500 - countGoogle) : 0,
        'pourcent': dispo ? ((countGoogle / 26500) * 100).round() : 0,
      };
      stats['mapbox_$i'] = {
        'actif': dispoMapbox,
        'utilise': countMapbox,
        'limite': 48500,
        'restant': dispoMapbox ? (48500 - countMapbox) : 0,
        'pourcent': dispoMapbox ? ((countMapbox / 48500) * 100).round() : 0,
      };
    }

    stats['osrm'] = {'actif': true, 'utilise': 'illimité', 'limite': '∞'};
    return stats;
  }

  // ════════════════════════════════════════════════════════
  // CALCUL DU PRIX
  // ════════════════════════════════════════════════════════

  double calculerPrix({
    required double distanceKm,
    required int dureeMinutes,
    double tarifKm = 500,
    double tarifMinute = 50,
    double fraisFixe = 500,
    bool estUrgent = false,
    double multiplicateurUrgent = 1.30,
  }) {
    final base = (distanceKm * tarifKm) + (dureeMinutes * tarifMinute) + fraisFixe;
    final prix = estUrgent ? base * multiplicateurUrgent : base;
    return (prix / 50).round() * 50; // Arrondi au multiple de 50
  }

  // ════════════════════════════════════════════════════════
  // DÉCODEUR POLYLINE GOOGLE
  // ════════════════════════════════════════════════════════

  List<LatLng> _decoderPolylineGoogle(String encoded) {
    final List<LatLng> result = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0, b, res = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        res |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
      lat += dlat;

      shift = 0;
      res = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        res |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
      lng += dlng;

      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }
}

final mapServiceProvider = Provider<MapService>((ref) => MapService());


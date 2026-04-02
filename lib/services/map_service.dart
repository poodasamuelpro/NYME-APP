import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'env.dart';

// ─────────────────────────────────────────────────────────────
// lib/services/map_service.dart
// Rotation automatique : Google (5 clés) → Mapbox (5 tokens) → OSRM
// Compteur mensuel auto — remise à zéro le 1er du mois
// Fonctionne avec 1 seule clé de chaque (les vides sont ignorées)
// ─────────────────────────────────────────────────────────────

class ItineraireResult {
  final List<LatLng> polyline;
  final double distanceKm;
  final int dureeMinutes;
  final String apiUtilisee;

  const ItineraireResult({
    required this.polyline,
    required this.distanceKm,
    required this.dureeMinutes,
    required this.apiUtilisee,
  });
}

class _CleApi {
  final String cle;
  final int limiteParMois;
  final String provider;
  final int index;

  const _CleApi({
    required this.cle,
    required this.limiteParMois,
    required this.provider,
    required this.index,
  });

  bool get estDisponible => cle.isNotEmpty && !cle.startsWith('VOTRE_') && !cle.startsWith('pk.eyJ1Ijoi') || _estMapboxValide;
  bool get _estMapboxValide => provider == 'mapbox' && cle.startsWith('pk.eyJ1');
  String get prefKey => 'maps_count_${provider}_$index';
  String get prefMoisKey => 'maps_mois_${provider}_$index';
}

class MapService {
  final Dio _dio;

  MapService() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  // ── Toutes les clés Google (5 slots) ──
  static List<_CleApi> get _clesGoogle => [
    _CleApi(cle: Env.googleMapsKey1, limiteParMois: 26500, provider: 'google', index: 1),
    _CleApi(cle: Env.googleMapsKey2, limiteParMois: 26500, provider: 'google', index: 2),
    _CleApi(cle: Env.googleMapsKey3, limiteParMois: 26500, provider: 'google', index: 3),
    _CleApi(cle: Env.googleMapsKey4, limiteParMois: 26500, provider: 'google', index: 4),
    _CleApi(cle: Env.googleMapsKey5, limiteParMois: 26500, provider: 'google', index: 5),
  ].where((c) => c.cle.isNotEmpty && !c.cle.startsWith('VOTRE_')).toList();

  // ── Toutes les clés Mapbox (5 slots) ──
  static List<_CleApi> get _clesMapbox => [
    _CleApi(cle: Env.mapboxToken1, limiteParMois: 48500, provider: 'mapbox', index: 1),
    _CleApi(cle: Env.mapboxToken2, limiteParMois: 48500, provider: 'mapbox', index: 2),
    _CleApi(cle: Env.mapboxToken3, limiteParMois: 48500, provider: 'mapbox', index: 3),
    _CleApi(cle: Env.mapboxToken4, limiteParMois: 48500, provider: 'mapbox', index: 4),
    _CleApi(cle: Env.mapboxToken5, limiteParMois: 48500, provider: 'mapbox', index: 5),
  ].where((c) => c.cle.isNotEmpty && !c.cle.startsWith('VOTRE_')).toList();

  // ════════════════════════════════════════════════════════
  // MÉTHODE PRINCIPALE
  // ════════════════════════════════════════════════════════

  Future<ItineraireResult?> calculerItineraire({
    required LatLng depart,
    required LatLng arrivee,
  }) async {
    await _verifierResetMensuel();

    // 1. Essayer Google Maps clé par clé
    for (final cle in _clesGoogle) {
      if (!await _quotaOk(cle)) {
        debugPrint('[Maps] Google #${cle.index} épuisée → suivante');
        continue;
      }
      try {
        final r = await _googleRoute(depart, arrivee, cle);
        await _incrementer(cle);
        debugPrint('[Maps] ✅ Google #${cle.index} (${await _compteur(cle)}/${cle.limiteParMois})');
        return r;
      } catch (e) {
        debugPrint('[Maps] ❌ Google #${cle.index}: $e');
      }
    }

    // 2. Essayer Mapbox token par token
    for (final cle in _clesMapbox) {
      if (!await _quotaOk(cle)) {
        debugPrint('[Maps] Mapbox #${cle.index} épuisée → suivante');
        continue;
      }
      try {
        final r = await _mapboxRoute(depart, arrivee, cle);
        await _incrementer(cle);
        debugPrint('[Maps] ✅ Mapbox #${cle.index} (${await _compteur(cle)}/${cle.limiteParMois})');
        return r;
      } catch (e) {
        debugPrint('[Maps] ❌ Mapbox #${cle.index}: $e');
      }
    }

    // 3. OSRM — toujours disponible, illimité
    debugPrint('[Maps] Fallback OSRM (gratuit illimité)');
    try {
      return await _osrmRoute(depart, arrivee);
    } catch (e) {
      debugPrint('[Maps] ❌ OSRM: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════
  // APPELS API
  // ════════════════════════════════════════════════════════

  Future<ItineraireResult> _googleRoute(LatLng dep, LatLng arr, _CleApi cle) async {
    final url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${dep.latitude},${dep.longitude}'
        '&destination=${arr.latitude},${arr.longitude}'
        '&mode=driving&key=${cle.cle}';

    final res = await _dio.get(url);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = res.data as Map<String, dynamic>;
    if (data['status'] != 'OK') throw Exception('status: ${data['status']}');

    final leg = data['routes'][0]['legs'][0];
    final polyline = <LatLng>[];
    for (final step in leg['steps'] as List) {
      polyline.addAll(_decoderGoogle(step['polyline']['points']));
    }

    return ItineraireResult(
      polyline: polyline,
      distanceKm: (leg['distance']['value'] as num) / 1000.0,
      dureeMinutes: ((leg['duration']['value'] as num) / 60).round(),
      apiUtilisee: 'Google Maps #${cle.index}',
    );
  }

  Future<ItineraireResult> _mapboxRoute(LatLng dep, LatLng arr, _CleApi cle) async {
    final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${dep.longitude},${dep.latitude};${arr.longitude},${arr.latitude}'
        '?geometries=geojson&access_token=${cle.cle}';

    final res = await _dio.get(url);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = res.data as Map<String, dynamic>;
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) throw Exception('Aucune route');

    final route = routes[0];
    final coords = route['geometry']['coordinates'] as List;
    final polyline = coords.map((c) => LatLng(
      (c[1] as num).toDouble(), (c[0] as num).toDouble()
    )).toList();

    return ItineraireResult(
      polyline: polyline,
      distanceKm: (route['distance'] as num) / 1000.0,
      dureeMinutes: ((route['duration'] as num) / 60).round(),
      apiUtilisee: 'Mapbox #${cle.index}',
    );
  }

  Future<ItineraireResult> _osrmRoute(LatLng dep, LatLng arr) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${dep.longitude},${dep.latitude};${arr.longitude},${arr.latitude}'
        '?overview=full&geometries=geojson';

    final res = await _dio.get(url);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = res.data as Map<String, dynamic>;
    if (data['code'] != 'Ok') throw Exception('code: ${data['code']}');

    final route = data['routes'][0];
    final coords = route['geometry']['coordinates'] as List;
    final polyline = coords.map((c) => LatLng(
      (c[1] as num).toDouble(), (c[0] as num).toDouble()
    )).toList();

    return ItineraireResult(
      polyline: polyline,
      distanceKm: (route['distance'] as num) / 1000.0,
      dureeMinutes: ((route['duration'] as num) / 60).round(),
      apiUtilisee: 'OSRM (gratuit)',
    );
  }

  // ════════════════════════════════════════════════════════
  // GESTION QUOTAS MENSUELS
  // ════════════════════════════════════════════════════════

  Future<bool> _quotaOk(_CleApi cle) async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(cle.prefKey) ?? 0;
    return count < cle.limiteParMois;
  }

  Future<void> _incrementer(_CleApi cle) async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(cle.prefKey) ?? 0;
    await prefs.setInt(cle.prefKey, count + 1);
  }

  Future<int> _compteur(_CleApi cle) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(cle.prefKey) ?? 0;
  }

  Future<void> _verifierResetMensuel() async {
    final prefs = await SharedPreferences.getInstance();
    final maintenant = DateTime.now();
    final moisCourant = maintenant.month;
    final anneeCourante = maintenant.year;
    final moisStocke = prefs.getInt('maps_reset_mois') ?? 0;
    final anneeStockee = prefs.getInt('maps_reset_annee') ?? 0;

    if (moisCourant != moisStocke || anneeCourante != anneeStockee) {
      debugPrint('[Maps] 🔄 Remise à zéro mensuelle des compteurs');
      for (int i = 1; i <= 5; i++) {
        await prefs.setInt('maps_count_google_$i', 0);
        await prefs.setInt('maps_count_mapbox_$i', 0);
      }
      await prefs.setInt('maps_reset_mois', moisCourant);
      await prefs.setInt('maps_reset_annee', anneeCourante);
    }
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
    return (prix / 50).round() * 50;
  }

  // ── Statistiques quotas ──
  Future<Map<String, dynamic>> getStatistiques() async {
    final prefs = await SharedPreferences.getInstance();
    final stats = <String, dynamic>{};
    for (int i = 1; i <= 5; i++) {
      stats['google_$i'] = {
        'compte': prefs.getInt('maps_count_google_$i') ?? 0,
        'limite': 26500,
        'active': i == 1 ? Env.googleMapsKey1.isNotEmpty : i == 2 ? Env.googleMapsKey2.isNotEmpty : false,
      };
      stats['mapbox_$i'] = {
        'compte': prefs.getInt('maps_count_mapbox_$i') ?? 0,
        'limite': 48500,
        'active': i == 1 ? Env.mapboxToken1.isNotEmpty : i == 2 ? Env.mapboxToken2.isNotEmpty : false,
      };
    }
    return stats;
  }

  // ── Décodeur polyline Google ──
  List<LatLng> _decoderGoogle(String encoded) {
    final result = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int shift = 0, b, res = 0;
      do { b = encoded.codeUnitAt(index++) - 63; res |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lat += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
      shift = 0; res = 0;
      do { b = encoded.codeUnitAt(index++) - 63; res |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lng += (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }
}

final mapServiceProvider = Provider<MapService>((ref) => MapService());


import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Modèle résultat itinéraire
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

// Configuration des APIs
class _ApiConfig {
  final String nom;
  final int limiteParMois;

  const _ApiConfig({required this.nom, required this.limiteParMois});
}

const _apis = [
  _ApiConfig(nom: 'mapbox', limiteParMois: 50000),
  _ApiConfig(nom: 'google', limiteParMois: 40000), // ~200$/mois offerts
  _ApiConfig(nom: 'osrm', limiteParMois: 999999),  // illimité open source
];

class MapService {
  final Dio _dio;
  static const String _mapboxToken =
      'VOTRE_TOKEN_MAPBOX'; // Dashboard Mapbox
  static const String _googleKey =
      'VOTRE_CLE_GOOGLE_MAPS'; // Console Google Cloud

  MapService() : _dio = Dio();

  // ── Calculer itinéraire avec rotation automatique ──
  Future<ItineraireResult?> calculerItineraire({
    required LatLng depart,
    required LatLng arrivee,
  }) async {
    // Essayer chaque API dans l'ordre
    for (final api in _apis) {
      // Vérifier quota mensuel
      final quotaOk = await _verifierQuota(api.nom, api.limiteParMois);
      if (!quotaOk && api.nom != 'osrm') {
        print('[MapService] Quota ${api.nom} atteint, passage à la suivante');
        continue;
      }

      try {
        ItineraireResult? result;
        switch (api.nom) {
          case 'mapbox':
            result = await _mapboxRoute(depart, arrivee);
            break;
          case 'google':
            result = await _googleRoute(depart, arrivee);
            break;
          case 'osrm':
            result = await _osrmRoute(depart, arrivee);
            break;
        }

        if (result != null) {
          await _incrementerCompteur(api.nom);
          return result;
        }
      } catch (e) {
        print('[MapService] Erreur ${api.nom}: $e');
        continue;
      }
    }

    return null;
  }

  // ── Mapbox Directions API ──
  Future<ItineraireResult?> _mapboxRoute(LatLng dep, LatLng arr) async {
    final url =
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${dep.longitude},${dep.latitude};'
        '${arr.longitude},${arr.latitude}'
        '?geometries=geojson&access_token=$_mapboxToken';

    final response = await _dio.get(url);
    if (response.statusCode != 200) throw Exception('Mapbox erreur ${response.statusCode}');

    final data = response.data;
    if (data['routes'] == null || (data['routes'] as List).isEmpty) {
      throw Exception('Mapbox: aucune route trouvée');
    }

    final route = data['routes'][0];
    final coords = route['geometry']['coordinates'] as List;
    final polyline = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();

    return ItineraireResult(
      polyline: polyline,
      distanceKm: (route['distance'] / 1000).toDouble(),
      dureeMinutes: (route['duration'] / 60).round(),
      apiUtilisee: 'Mapbox',
    );
  }

  // ── Google Maps Directions API ──
  Future<ItineraireResult?> _googleRoute(LatLng dep, LatLng arr) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${dep.latitude},${dep.longitude}'
        '&destination=${arr.latitude},${arr.longitude}'
        '&mode=driving&key=$_googleKey';

    final response = await _dio.get(url);
    if (response.statusCode != 200) throw Exception('Google erreur');

    final data = response.data;
    if (data['status'] != 'OK') throw Exception('Google: ${data['status']}');

    final leg = data['routes'][0]['legs'][0];
    final steps = leg['steps'] as List;

    // Décoder la polyline Google
    final List<LatLng> polyline = [];
    for (final step in steps) {
      final decoded = _decoderPolylineGoogle(step['polyline']['points']);
      polyline.addAll(decoded);
    }

    return ItineraireResult(
      polyline: polyline,
      distanceKm: leg['distance']['value'] / 1000.0,
      dureeMinutes: (leg['duration']['value'] / 60).round(),
      apiUtilisee: 'Google Maps',
    );
  }

  // ── OSRM (Open Source, illimité) ──
  Future<ItineraireResult?> _osrmRoute(LatLng dep, LatLng arr) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${dep.longitude},${dep.latitude};'
        '${arr.longitude},${arr.latitude}'
        '?overview=full&geometries=geojson';

    final response = await _dio.get(url);
    if (response.statusCode != 200) throw Exception('OSRM erreur');

    final data = response.data;
    if (data['code'] != 'Ok') throw Exception('OSRM: ${data['code']}');

    final route = data['routes'][0];
    final coords = route['geometry']['coordinates'] as List;
    final polyline = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();

    return ItineraireResult(
      polyline: polyline,
      distanceKm: (route['distance'] / 1000).toDouble(),
      dureeMinutes: (route['duration'] / 60).round(),
      apiUtilisee: 'OSRM (OpenStreetMap)',
    );
  }

  // ── Gestion des quotas (remise à zéro mensuelle auto) ──
  Future<bool> _verifierQuota(String api, int limite) async {
    final prefs = await SharedPreferences.getInstance();
    final moisKey = 'quota_mois_$api';
    final countKey = 'quota_count_$api';

    final moisActuel = DateTime.now().month;
    final moisStocke = prefs.getInt(moisKey) ?? 0;

    // Remise à zéro si nouveau mois
    if (moisActuel != moisStocke) {
      await prefs.setInt(moisKey, moisActuel);
      await prefs.setInt(countKey, 0);
      return true;
    }

    final count = prefs.getInt(countKey) ?? 0;
    return count < limite;
  }

  Future<void> _incrementerCompteur(String api) async {
    final prefs = await SharedPreferences.getInstance();
    final countKey = 'quota_count_$api';
    final count = prefs.getInt(countKey) ?? 0;
    await prefs.setInt(countKey, count + 1);
  }

  // ── Statistiques quotas (pour debug/admin) ──
  Future<Map<String, int>> getStatistiquesQuotas() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'mapbox': prefs.getInt('quota_count_mapbox') ?? 0,
      'google': prefs.getInt('quota_count_google') ?? 0,
      'osrm': prefs.getInt('quota_count_osrm') ?? 0,
    };
  }

  // ── Calculer prix estimé ──
  double calculerPrix({
    required double distanceKm,
    required int dureeMinutes,
    double tarifKm = 500,
    double tarifMinute = 50,
    double fraisFixe = 500,
    double multiplicateurUrgent = 1.3,
    bool estUrgent = false,
  }) {
    final prixBase = (distanceKm * tarifKm) + (dureeMinutes * tarifMinute) + fraisFixe;
    return estUrgent ? prixBase * multiplicateurUrgent : prixBase;
  }

  // ── Décodeur polyline Google ──
  List<LatLng> _decoderPolylineGoogle(String encoded) {
    final List<LatLng> result = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0, result2 = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result2 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result2 & 1) != 0 ? ~(result2 >> 1) : result2 >> 1;
      lat += dlat;

      shift = 0;
      result2 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result2 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result2 & 1) != 0 ? ~(result2 >> 1) : result2 >> 1;
      lng += dlng;

      result.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return result;
  }
}

final mapServiceProvider = Provider<MapService>((ref) => MapService());

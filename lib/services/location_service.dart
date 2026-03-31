import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

class LocationService {
  final SupabaseClient _supabase;
  Timer? _trackingTimer;
  StreamSubscription<Position>? _positionStream;
  bool _tracking = false;

  LocationService(this._supabase);

  // ── Vérifier et demander les permissions GPS ──
  Future<bool> demanderPermissions() async {
    bool serviceActive = await Geolocator.isLocationServiceEnabled();
    if (!serviceActive) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  // ── Obtenir position actuelle ──
  Future<LatLng?> getPositionActuelle() async {
    try {
      final permOk = await demanderPermissions();
      if (!permOk) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('[LocationService] Erreur position: $e');
      return null;
    }
  }

  // ── Démarrer le tracking GPS (pour le coursier) ──
  Future<void> demarrerTracking({
    required String coursierId,
    String? livraisonId,
    Duration intervalle = const Duration(seconds: 3),
  }) async {
    if (_tracking) return;

    final permOk = await demanderPermissions();
    if (!permOk) throw Exception('Permission GPS refusée');

    _tracking = true;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Mettre à jour si déplacé de +5m
      ),
    ).listen((position) async {
      await _envoyerPosition(
        coursierId: coursierId,
        livraisonId: livraisonId,
        latitude: position.latitude,
        longitude: position.longitude,
        vitesse: position.speed * 3.6, // m/s → km/h
        direction: position.heading,
      );
    });
  }

  // ── Envoyer position dans Supabase (Realtime) ──
  Future<void> _envoyerPosition({
    required String coursierId,
    String? livraisonId,
    required double latitude,
    required double longitude,
    double? vitesse,
    double? direction,
  }) async {
    try {
      await _supabase.from(SupabaseConfig.tableLocalisationCoursier).insert({
        'coursier_id': coursierId,
        'livraison_id': livraisonId,
        'latitude': latitude,
        'longitude': longitude,
        'vitesse': vitesse,
        'direction': direction,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Mettre à jour aussi la position courante du coursier
      await _supabase
          .from(SupabaseConfig.tableCoursiers)
          .update({
            'lat_actuelle': latitude,
            'lng_actuelle': longitude,
            'derniere_activite': DateTime.now().toIso8601String(),
          })
          .eq('id', coursierId);
    } catch (e) {
      print('[LocationService] Erreur envoi position: $e');
    }
  }

  // ── Arrêter le tracking ──
  Future<void> arreterTracking() async {
    _tracking = false;
    await _positionStream?.cancel();
    _positionStream = null;
    _trackingTimer?.cancel();
    _trackingTimer = null;
  }

  // ── Écouter position d'un coursier en temps réel ──
  RealtimeChannel ecouterPositionCoursier({
    required String coursierId,
    required void Function(double lat, double lng) onPosition,
  }) {
    return _supabase
        .channel('localisation_$coursierId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.tableLocalisationCoursier,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'coursier_id',
            value: coursierId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            onPosition(
              data['latitude'].toDouble(),
              data['longitude'].toDouble(),
            );
          },
        )
        .subscribe();
  }

  // ── Trouver les coursiers disponibles proches ──
  Future<List<Map<String, dynamic>>> trouverCoursiersProches({
    required double lat,
    required double lng,
    double rayonKm = 5.0,
  }) async {
    // Utiliser la fonction SQL Supabase (voir migration)
    final result = await _supabase.rpc('coursiers_proches', params: {
      'lat_client': lat,
      'lng_client': lng,
      'rayon_km': rayonKm,
    });

    return List<Map<String, dynamic>>.from(result);
  }

  void dispose() {
    arreterTracking();
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService(Supabase.instance.client);
  ref.onDispose(() => service.dispose());
  return service;
});

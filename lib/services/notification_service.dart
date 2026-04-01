import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/supabase_config.dart';

// ─────────────────────────────────────────────────────────────
// Notification Service NYME
// Firebase est optionnel : si non configuré, les notifications
// locales et in-app fonctionnent quand même
// ─────────────────────────────────────────────────────────────

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _firebaseDisponible = false;
  static bool _initialise = false;

  // URL de ton backend Vercel
  static const String _vercelUrl = 'https://fcn-backend-zva5gaxix-poodasamuelpros-projects.vercel.app/api/send';

  // Canal Android
  static const AndroidNotificationChannel _canal = AndroidNotificationChannel(
    'nyme_canal',
    'Notifications NYME',
    description: 'Alertes livraisons, messages et statuts',
    importance: Importance.high,
    playSound: true,
  );

  // ── Initialisation principale (appelée depuis main.dart) ──
  static Future<void> initializeAvecFirebase() async {
    await _initialiserLocal();

    // Essayer Firebase sans bloquer si absent
    try {
      await _initialiserFirebase();
      _firebaseDisponible = true;
      debugPrint('[Notifications] Firebase OK ✅');
    } catch (e) {
      _firebaseDisponible = false;
      debugPrint('[Notifications] Firebase absent, notifications locales uniquement ⚠️');
    }

    _initialise = true;
  }

  // ── Initialisation notifications locales ──
  static Future<void> _initialiserLocal() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canal);
  }

  // ── Initialisation Firebase (peut échouer silencieusement) ──
  static Future<void> _initialiserFirebase() async {
    final firebase = await _chargerFirebase();
    if (firebase == null) throw Exception('Firebase non configuré');
  }

  static Future<dynamic> _chargerFirebase() async {
    try {
      final core = await compute(_initFirebaseIsolate, null);
      return core;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _initFirebaseIsolate(void _) async {
    // Placeholder pour l'init Firebase isolée
  }

  // ── Callback tap sur notification ──
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('[Notifications] Tap: ${response.payload}');
    // TODO: naviguer vers l'écran correspondant selon payload
  }

  // ── Afficher une notification locale immédiate ──
  static Future<void> afficher({
    required String titre,
    required String corps,
    String? payload,
    int id = 0,
  }) async {
    await _local.show(
      id,
      titre,
      corps,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _canal.id,
          _canal.name,
          channelDescription: _canal.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF1A4FBF),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ── Sauvegarder token FCM dans Supabase ──
  static Future<void> sauvegarderToken(String userId, String token) async {
    try {
      await Supabase.instance.client
          .from(SupabaseConfig.tableUtilisateurs)
          .update({'fcm_token': token})
          .eq('id', userId);
      debugPrint('[Notifications] Token FCM sauvegardé pour $userId');
    } catch (e) {
      debugPrint('[Notifications] Erreur sauvegarde token: $e');
    }
  }

  // ── Enregistrer notification dans Supabase (in-app) ──
  static Future<void> enregistrer({
    required String userId,
    required String type,
    required String titre,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await Supabase.instance.client
          .from(SupabaseConfig.tableNotifications)
          .insert({
        'user_id': userId,
        'type': type,
        'titre': titre,
        'message': message,
        'data': data,
        'lu': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      await afficher(titre: titre, corps: message, payload: type);
    } catch (e) {
      debugPrint('[Notifications] Erreur enregistrement: $e');
    }
  }

  // ── Envoyer via backend Vercel (push réel) ──
  static Future<void> envoyerPush({
    required String destinataireId,
    required String titre,
    required String corps,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 1. Récupérer le token FCM de l'utilisateur
      final userResponse = await Supabase.instance.client
          .from(SupabaseConfig.tableUtilisateurs)
          .select('fcm_token')
          .eq('id', destinataireId)
          .single();

      final token = userResponse['fcm_token'];
      if (token == null || token == '') {
        debugPrint('[Notifications] Pas de FCM token pour $destinataireId');
        return;
      }

      // 2. Appeler le backend Vercel
      final response = await http.post(
        Uri.parse(_vercelUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'titre': titre,
          'corps': corps,
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('[Notifications] Push envoyé avec succès');
      } else {
        debugPrint('[Notifications] Erreur Vercel: ${response.body}');
      }
    } catch (e) {
      debugPrint('[Notifications] Erreur envoi push: $e');
    }
  }

  // ── Écouter les notifications en temps réel (Supabase Realtime) ──
  static RealtimeChannel ecouterNotifications({
    required String userId,
    required void Function(Map<String, dynamic>) onNouvelle,
  }) {
    return Supabase.instance.client
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.tableNotifications,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            onNouvelle(data);
            afficher(
              titre: data['titre'] ?? 'NYME',
              corps: data['message'] ?? '',
              payload: data['type'],
            );
          },
        )
        .subscribe();
  }

  // ── Marquer notifications comme lues ──
  static Future<void> marquerToutesLues(String userId) async {
    await Supabase.instance.client
        .from(SupabaseConfig.tableNotifications)
        .update({'lu': true})
        .eq('user_id', userId)
        .eq('lu', false);
  }

  // ── Compter non lues ──
  static Future<int> compterNonLues(String userId) async {
    final result = await Supabase.instance.client
        .from(SupabaseConfig.tableNotifications)
        .select('id')
        .eq('user_id', userId)
        .eq('lu', false);
    return (result as List).length;
  }

  // ── Types de notifications ──
  static const String typeNouvelleProposition = 'nouvelle_proposition';
  static const String typeCoursierAssigne = 'coursier_assigne';
  static const String typeStatutChange = 'statut_change';
  static const String typeNouveauMessage = 'nouveau_message';
  static const String typeLivraisonLivree = 'livraison_livree';
  static const String typeNouvelleOffre = 'nouvelle_offre';
  static const String typeDossierValide = 'dossier_valide';
  static const String typeDossierRejete = 'dossier_rejete';

  static bool get estInitialise => _initialise;
  static bool get firebaseActif => _firebaseDisponible;
}

// Provider
final notificationServiceProvider =
    Provider<NotificationService>((_) => NotificationService());
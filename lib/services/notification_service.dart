import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  print('[FCM Background] ${message.notification?.title}');
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'nyme_channel',
    'NYME Notifications',
    description: 'Notifications de livraison NYME',
    importance: Importance.high,
  );

  // ── Initialisation ──
  static Future<void> initialize() async {
    // Demander permissions iOS
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configurer notifications locales
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Background handler
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Foreground handler
    FirebaseMessaging.onMessage.listen((message) {
      _afficherNotificationLocale(message);
    });
  }

  // ── Obtenir et sauvegarder le token FCM ──
  static Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  static Future<void> sauvegarderToken(String userId) async {
    final token = await getToken();
    if (token != null) {
      await Supabase.instance.client
          .from(SupabaseConfig.tableUtilisateurs)
          .update({'fcm_token': token})
          .eq('id', userId);
    }

    // Écouter les refresh de token
    _fcm.onTokenRefresh.listen((newToken) async {
      await Supabase.instance.client
          .from(SupabaseConfig.tableUtilisateurs)
          .update({'fcm_token': newToken})
          .eq('id', userId);
    });
  }

  // ── Afficher notification locale ──
  static void _afficherNotificationLocale(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ── Enregistrer notification dans Supabase ──
  static Future<void> enregistrerNotification({
    required String userId,
    required String type,
    required String titre,
    required String message,
    Map<String, dynamic>? data,
  }) async {
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
  }

  // ── Envoyer notification push via FCM (depuis Edge Function Supabase) ──
  // Cette méthode appelle une Edge Function Supabase qui envoie le push
  static Future<void> envoyerPush({
    required String destinataireId,
    required String titre,
    required String corps,
    Map<String, dynamic>? data,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'envoyer-notification',
        body: {
          'destinataire_id': destinataireId,
          'titre': titre,
          'corps': corps,
          'data': data ?? {},
        },
      );
    } catch (e) {
      print('[NotificationService] Erreur envoi push: $e');
    }
  }

  // Types de notifications
  static const String typeNouvelleProposition = 'nouvelle_proposition';
  static const String typeCoursierAssigne = 'coursier_assigne';
  static const String typeStatutChange = 'statut_change';
  static const String typeNouveauMessage = 'nouveau_message';
  static const String typeLivraisonLivree = 'livraison_livree';
  static const String typeNouvelleOffre = 'nouvelle_offre';
}

final notificationServiceProvider = Provider<NotificationService>((_) => NotificationService());

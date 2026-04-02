/// Configuration des clés API et variables d'environnement NYME
/// Ce fichier contient les clés sensibles nécessaires au fonctionnement des services.
class Env {
  Env._();

  // ── Google Maps ──
  static const String googleMapsApiKey = 'VOTRE_CLE_GOOGLE_MAPS';

  // ── Mapbox ──
  static const String mapboxAccessToken = 'VOTRE_CLE_MAPBOX';

  // ── CinetPay ──
  static const String cinetPayApiKey = 'VOTRE_API_KEY_CINETPAY';
  static const String cinetPaySiteId = 'VOTRE_SITE_ID_CINETPAY';

  // ── Flutterwave (Optionnel) ──
  static const String flutterwavePublicKey = 'VOTRE_CLE_PUBLIQUE_FLUTTERWAVE';

  // ── Firebase ──
  static const String firebaseServerKey = 'VOTRE_CLE_SERVEUR_FIREBASE';

  // ── Brevo (Email) ──
  static const String brevoApiKey = 'VOTRE_API_KEY_BREVO';
}
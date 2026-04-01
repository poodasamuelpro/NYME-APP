import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────
// Fonctions utilitaires globales NYME
// ─────────────────────────────────────────────────────────────

class Helpers {
  Helpers._();

  // ── Dates ──

  static String dateComplete(DateTime dt) =>
      DateFormat("dd/MM/yyyy 'à' HH:mm", 'fr_FR').format(dt.toLocal());

  static String dateCourte(DateTime dt) =>
      DateFormat('dd/MM/yyyy', 'fr_FR').format(dt.toLocal());

  static String heureMinute(DateTime dt) =>
      DateFormat('HH:mm').format(dt.toLocal());

  static String tempsEcoule(DateTime dt) {
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    return timeago.format(dt, locale: 'fr');
  }

  static String dateRelative(DateTime dt) {
    final maintenant = DateTime.now();
    final diff = maintenant.difference(dt);
    if (diff.inDays == 0) return 'Aujourd\'hui à ${heureMinute(dt)}';
    if (diff.inDays == 1) return 'Hier à ${heureMinute(dt)}';
    return dateComplete(dt);
  }

  // ── Texte ──

  static String initiales(String nom) {
    final parts = nom.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nom.isNotEmpty ? nom[0].toUpperCase() : '?';
  }

  static String masquerTelephone(String tel) {
    if (tel.length <= 4) return tel;
    final debut = tel.substring(0, tel.length - 4);
    return '$debut****';
  }

  static String capitaliser(String texte) {
    if (texte.isEmpty) return texte;
    return texte[0].toUpperCase() + texte.substring(1).toLowerCase();
  }

  static String truncate(String texte, int max) {
    if (texte.length <= max) return texte;
    return '${texte.substring(0, max)}...';
  }

  // ── Validation ──

  static bool emailValide(String email) =>
      RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email);

  static bool telephoneValide(String tel) =>
      RegExp(r'^\+?[\d\s]{8,15}$').hasMatch(tel);

  // ── Distance GPS ──

  static double distanceKm(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = _sin2(dLat / 2) +
        _cos(_rad(lat1)) * _cos(_rad(lat2)) * _sin2(dLng / 2);
    final c = 2 * _asin(_sqrt(a));
    return r * c;
  }

  static double _rad(double deg) => deg * 3.141592653589793 / 180;
  static double _sin2(double x) => _sin(x) * _sin(x);
  static double _sin(double x) => x - x * x * x / 6;
  static double _cos(double x) => 1 - x * x / 2;
  static double _asin(double x) => x + x * x * x / 6;
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 10; i++) r = (r + x / r) / 2;
    return r;
  }

  // ── Couleur statut livraison ──

  static Color couleurStatut(String statut) {
    switch (statut) {
      case 'en_attente': return const Color(0xFFF59E0B);
      case 'acceptee': return const Color(0xFF3B82F6);
      case 'en_rout_depart':
      case 'colis_recupere':
      case 'en_route_arrivee': return const Color(0xFF8B5CF6);
      case 'livree': return const Color(0xFF22C55E);
      case 'annulee': return const Color(0xFFEF4444);
      default: return const Color(0xFF6B7280);
    }
  }

  static String labelStatut(String statut) {
    switch (statut) {
      case 'en_attente': return 'En attente';
      case 'acceptee': return 'Acceptée';
      case 'en_rout_depart': return 'En route (départ)';
      case 'colis_recupere': return 'Colis récupéré';
      case 'en_route_arrivee': return 'En route (destination)';
      case 'livree': return 'Livrée ✓';
      case 'annulee': return 'Annulée';
      default: return statut;
    }
  }

  static String emojiStatut(String statut) {
    switch (statut) {
      case 'en_attente': return '⏳';
      case 'acceptee': return '✅';
      case 'en_rout_depart': return '🏍️';
      case 'colis_recupere': return '📦';
      case 'en_route_arrivee': return '🚀';
      case 'livree': return '🎉';
      case 'annulee': return '❌';
      default: return '📋';
    }
  }

  // ── Lancer URL externe ──

  static Future<void> ouvrirTelephone(String numero) async {
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  static Future<void> ouvrirWhatsApp(String numero, {String? message}) async {
    final num = numero.replaceAll(RegExp(r'[^\d+]'), '');
    final msg = Uri.encodeComponent(message ?? 'Bonjour, je vous contacte via NYME.');
    final uri = Uri.parse('https://wa.me/$num?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Snackbar rapide ──

  static void snackSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF22C55E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  static void snackErreur(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  static void snackInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF1A4FBF),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}


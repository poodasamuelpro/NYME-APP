import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────
// Service Email NYME
// Les emails sont envoyés via une Edge Function Supabase
// qui utilise Resend ou Brevo en arrière-plan
// ─────────────────────────────────────────────────────────────

class EmailService {
  EmailService._();

  static final _supabase = Supabase.instance.client;

  // ── Envoyer un email via Edge Function ──
  static Future<bool> _envoyer({
    required String destinataire,
    required String sujet,
    required String html,
    String? nomDestinataire,
  }) async {
    try {
      await _supabase.functions.invoke(
        'envoyer-email',
        body: {
          'destinataire': destinataire,
          'nom_destinataire': nomDestinataire,
          'sujet': sujet,
          'html': html,
        },
      );
      return true;
    } catch (e) {
      debugPrint('[EmailService] Erreur envoi email: $e');
      return false;
    }
  }

  // ── Template : Bienvenue nouveau client ──
  static Future<bool> envoyerBienvenue({
    required String email,
    required String nom,
  }) async {
    return _envoyer(
      destinataire: email,
      nomDestinataire: nom,
      sujet: '🎉 Bienvenue sur NYME !',
      html: _templateBienvenue(nom),
    );
  }

  // ── Template : Livraison créée (confirmation client) ──
  static Future<bool> envoyerConfirmationLivraison({
    required String emailClient,
    required String nomClient,
    required String livraisonId,
    required String adresseDepart,
    required String adresseArrivee,
    required String prixFinal,
  }) async {
    return _envoyer(
      destinataire: emailClient,
      nomDestinataire: nomClient,
      sujet: '📦 Votre livraison NYME est confirmée',
      html: _templateConfirmationLivraison(
        nom: nomClient,
        livraisonId: livraisonId,
        depart: adresseDepart,
        arrivee: adresseArrivee,
        prix: prixFinal,
      ),
    );
  }

  // ── Template : Notification destinataire (livraison pour tiers) ──
  static Future<bool> envoyerNotificationDestinataire({
    required String emailDestinataire,
    required String nomDestinataire,
    required String nomExpediteur,
    required String livraisonId,
    required String adresseArrivee,
  }) async {
    return _envoyer(
      destinataire: emailDestinataire,
      nomDestinataire: nomDestinataire,
      sujet: '📬 Un colis est en route pour vous via NYME',
      html: _templateNotificationDestinataire(
        nomDestinataire: nomDestinataire,
        nomExpediteur: nomExpediteur,
        livraisonId: livraisonId,
        adresse: adresseArrivee,
      ),
    );
  }

  // ── Template : Livraison effectuée ──
  static Future<bool> envoyerCompteRendu({
    required String emailClient,
    required String nomClient,
    required String livraisonId,
    required String nomCoursier,
    required String heurelivraison,
    required String prixFinal,
    required String distanceKm,
  }) async {
    return _envoyer(
      destinataire: emailClient,
      nomDestinataire: nomClient,
      sujet: '✅ Livraison effectuée avec succès - NYME',
      html: _templateCompteRendu(
        nom: nomClient,
        livraisonId: livraisonId,
        coursier: nomCoursier,
        heure: heurelivraison,
        prix: prixFinal,
        distance: distanceKm,
      ),
    );
  }

  // ── Template : Dossier coursier validé ──
  static Future<bool> envoyerDossierValide({
    required String email,
    required String nom,
  }) async {
    return _envoyer(
      destinataire: email,
      nomDestinataire: nom,
      sujet: '✅ Votre dossier NYME a été validé !',
      html: _templateDossierValide(nom),
    );
  }

  // ── Template : Dossier coursier rejeté ──
  static Future<bool> envoyerDossierRejete({
    required String email,
    required String nom,
    required String motifRejet,
  }) async {
    return _envoyer(
      destinataire: email,
      nomDestinataire: nom,
      sujet: '⚠️ Votre dossier NYME nécessite des corrections',
      html: _templateDossierRejete(nom, motifRejet),
    );
  }

  // ════════════════════════════════════════════════
  // TEMPLATES HTML
  // ════════════════════════════════════════════════

  static String _base(String contenu) => '''
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { font-family: Arial, sans-serif; background: #F3F4F6; margin: 0; padding: 20px; }
  .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; }
  .header { background: linear-gradient(135deg, #1A4FBF, #0A2E8A); padding: 32px 24px; text-align: center; }
  .header h1 { color: white; margin: 0; font-size: 32px; letter-spacing: 6px; }
  .header p { color: rgba(255,255,255,0.8); margin: 8px 0 0; font-size: 14px; }
  .body { padding: 32px 24px; }
  .body h2 { color: #1A1A2E; font-size: 20px; }
  .body p { color: #374151; line-height: 1.6; }
  .badge { display: inline-block; background: #F0F4FF; color: #1A4FBF; padding: 8px 16px; border-radius: 20px; font-weight: bold; font-size: 13px; }
  .info-box { background: #F8FAFF; border-left: 4px solid #1A4FBF; padding: 16px; border-radius: 8px; margin: 16px 0; }
  .info-box p { margin: 4px 0; color: #374151; font-size: 14px; }
  .btn { display: inline-block; background: #1A4FBF; color: white; padding: 14px 28px; border-radius: 12px; text-decoration: none; font-weight: bold; margin: 16px 0; }
  .footer { background: #F8FAFF; padding: 20px 24px; text-align: center; border-top: 1px solid #E5E7EB; }
  .footer p { color: #9CA3AF; font-size: 12px; margin: 0; }
  .orange { color: #E87722; }
  .succes { color: #22C55E; }
  .erreur { color: #EF4444; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>NYME</h1>
    <p>Livraison Rapide & Intelligente</p>
  </div>
  <div class="body">$contenu</div>
  <div class="footer">
    <p>© 2025 NYME · Ouagadougou, Burkina Faso</p>
    <p>Cet email a été envoyé automatiquement, ne pas répondre.</p>
  </div>
</div>
</body>
</html>
''';

  static String _templateBienvenue(String nom) => _base('''
<h2>Bienvenue $nom ! 🎉</h2>
<p>Votre compte NYME a été créé avec succès.</p>
<p>Vous pouvez maintenant :</p>
<ul>
  <li>🚀 Commander des livraisons en quelques secondes</li>
  <li>📍 Suivre vos colis en temps réel</li>
  <li>💬 Communiquer directement avec les coursiers</li>
  <li>💰 Négocier les prix selon vos besoins</li>
</ul>
<p>Ouvrez l'application NYME et commencez dès maintenant !</p>
''');

  static String _templateConfirmationLivraison({
    required String nom,
    required String livraisonId,
    required String depart,
    required String arrivee,
    required String prix,
  }) =>
      _base('''
<h2>Livraison confirmée 📦</h2>
<p>Bonjour $nom,</p>
<p>Votre demande de livraison a été enregistrée. Les coursiers disponibles vont bientôt proposer leurs offres.</p>
<div class="info-box">
  <p><strong>N° de livraison :</strong> <span class="badge">${livraisonId.substring(0, 8).toUpperCase()}</span></p>
  <p><strong>📍 Départ :</strong> $depart</p>
  <p><strong>🏁 Destination :</strong> $arrivee</p>
  <p><strong>💰 Prix :</strong> $prix</p>
</div>
<p>Vous serez notifié dès qu'un coursier accepte votre livraison.</p>
''');

  static String _templateNotificationDestinataire({
    required String nomDestinataire,
    required String nomExpediteur,
    required String livraisonId,
    required String adresse,
  }) =>
      _base('''
<h2>Un colis arrive pour vous ! 📬</h2>
<p>Bonjour $nomDestinataire,</p>
<p><strong>$nomExpediteur</strong> vous envoie un colis via NYME.</p>
<div class="info-box">
  <p><strong>N° de livraison :</strong> <span class="badge">${livraisonId.substring(0, 8).toUpperCase()}</span></p>
  <p><strong>🏁 Adresse de livraison :</strong> $adresse</p>
</div>
<p>Vous recevrez une notification quand le coursier sera en route.</p>
<p>Téléchargez l'app NYME pour suivre votre colis en temps réel.</p>
''');

  static String _templateCompteRendu({
    required String nom,
    required String livraisonId,
    required String coursier,
    required String heure,
    required String prix,
    required String distance,
  }) =>
      _base('''
<h2 class="succes">Livraison effectuée avec succès ✅</h2>
<p>Bonjour $nom,</p>
<p>Votre colis a été livré avec succès !</p>
<div class="info-box">
  <p><strong>N° :</strong> <span class="badge">${livraisonId.substring(0, 8).toUpperCase()}</span></p>
  <p><strong>🏍️ Coursier :</strong> $coursier</p>
  <p><strong>🕐 Livré à :</strong> $heure</p>
  <p><strong>📏 Distance :</strong> $distance km</p>
  <p><strong>💰 Total payé :</strong> $prix</p>
</div>
<p>Merci de noter votre coursier dans l'application pour l'aider à améliorer son service !</p>
''');

  static String _templateDossierValide(String nom) => _base('''
<h2 class="succes">Dossier validé ! ✅</h2>
<p>Bonjour $nom,</p>
<p>Félicitations ! Votre dossier de vérification a été <strong>validé</strong> par notre équipe.</p>
<p>Vous pouvez maintenant :</p>
<ul>
  <li>✅ Accepter des livraisons</li>
  <li>💰 Gagner de l'argent</li>
  <li>⭐ Construire votre réputation</li>
</ul>
<p>Ouvrez l'application NYME, activez votre disponibilité et commencez à recevoir des courses !</p>
''');

  static String _templateDossierRejete(String nom, String motif) => _base('''
<h2 class="erreur">Corrections requises ⚠️</h2>
<p>Bonjour $nom,</p>
<p>Votre dossier de vérification n'a pas pu être validé pour la raison suivante :</p>
<div class="info-box">
  <p><strong>Motif :</strong> $motif</p>
</div>
<p>Veuillez corriger les informations et soumettre à nouveau votre dossier dans l'application NYME.</p>
<p>En cas de questions, contactez notre support.</p>
''');
}


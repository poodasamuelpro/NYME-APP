import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────
// lib/core/utils/brevo_email_service.dart
// Emails via Edge Function Supabase + Brevo
// Expéditeur : nyme.contact@gmail.com
// ─────────────────────────────────────────────────────────────

class BrevoEmailService {
  BrevoEmailService._();

  static Future<bool> _envoyer({
    required String destinataire,
    required String nomDestinataire,
    required String sujet,
    required String html,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'nyme-notifications',
        body: {
          'action': 'email',
          'destinataire': destinataire,
          'nom_destinataire': nomDestinataire,
          'sujet': sujet,
          'html': html,
        },
      );
      debugPrint('[Email] ✅ Envoyé à $destinataire');
      return true;
    } catch (e) {
      debugPrint('[Email] ❌ Erreur: $e');
      return false;
    }
  }

  // ── Bienvenue nouveau membre ──
  static Future<bool> envoyerBienvenue({
    required String email,
    required String nom,
    required String role,
  }) async {
    final isCoursier = role == 'coursier';
    return _envoyer(
      destinataire: email,
      nomDestinataire: nom,
      sujet: '🎉 Bienvenue sur NYME, $nom !',
      html: _base('''
<h2>Bienvenue $nom ! 🎉</h2>
<p>Votre compte NYME a été créé avec succès.</p>
${isCoursier ? '''
<div class="alerte"><p><strong>⚠️ Étape suivante :</strong> Soumettez vos documents (CNI, permis, carte grise) pour commencer à livrer.</p></div>
''' : '''
<ul>
  <li>🚀 Commandez une livraison en quelques secondes</li>
  <li>📍 Suivez vos colis en temps réel</li>
  <li>💰 Négociez les prix avec les coursiers</li>
  <li>⭐ Notez vos coursiers favoris</li>
</ul>
'''}
<p>Ouvrez l'application NYME pour commencer !</p>
'''),
    );
  }

  // ── Notification destinataire (livraison pour tiers) ──
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
      html: _base('''
<h2>Un colis arrive pour vous ! 📬</h2>
<p>Bonjour <strong>$nomDestinataire</strong>,</p>
<p><strong>$nomExpediteur</strong> vous envoie un colis via NYME.</p>
<div class="info">
  <p><strong>N° :</strong> <span class="badge">${livraisonId.substring(0, 8).toUpperCase()}</span></p>
  <p><strong>📍 Adresse :</strong> $adresseArrivee</p>
</div>
<p>Vous serez notifié dès que le coursier est en route.</p>
'''),
    );
  }

  // ── Compte rendu livraison effectuée ──
  static Future<bool> envoyerCompteRendu({
    required String emailClient,
    required String nomClient,
    required String livraisonId,
    required String nomCoursier,
    required String heureLivraison,
    required String prixFinal,
    required String distanceKm,
  }) async {
    return _envoyer(
      destinataire: emailClient,
      nomDestinataire: nomClient,
      sujet: '✅ Compte rendu livraison NYME',
      html: _base('''
<h2>Livraison effectuée ✅</h2>
<p>Bonjour <strong>$nomClient</strong>,</p>
<div class="info">
  <p><strong>N° :</strong> <span class="badge">${livraisonId.substring(0, 8).toUpperCase()}</span></p>
  <p><strong>🏍️ Coursier :</strong> $nomCoursier</p>
  <p><strong>🕐 Livré à :</strong> $heureLivraison</p>
  <p><strong>📏 Distance :</strong> $distanceKm km</p>
</div>
<div class="prix"><div class="montant">$prixFinal</div><div class="label">Total payé</div></div>
<p>Notez votre coursier dans l'application !</p>
'''),
    );
  }

  // ── Dossier coursier validé ──
  static Future<bool> envoyerDossierValide({
    required String email,
    required String nom,
  }) async {
    return _envoyer(
      destinataire: email,
      nomDestinataire: nom,
      sujet: '✅ Dossier NYME validé !',
      html: _base('''
<h2>Dossier validé ! ✅</h2>
<p>Bonjour <strong>$nom</strong>,</p>
<div class="succes"><p>Félicitations ! Votre dossier a été <strong>validé</strong>. Vous pouvez maintenant accepter des livraisons.</p></div>
<ul>
  <li>✅ Accepter des courses</li>
  <li>💰 Gagner de l'argent</li>
  <li>⭐ Construire votre réputation</li>
</ul>
<p>Activez votre disponibilité dans l'application NYME !</p>
'''),
    );
  }

  // ── Dossier coursier rejeté ──
  static Future<bool> envoyerDossierRejete({
    required String email,
    required String nom,
    required String motif,
  }) async {
    return _envoyer(
      destinataire: email,
      nomDestinataire: nom,
      sujet: '⚠️ Corrections requises — Dossier NYME',
      html: _base('''
<h2>Corrections requises ⚠️</h2>
<p>Bonjour <strong>$nom</strong>,</p>
<div class="erreur"><p><strong>Motif :</strong> $motif</p></div>
<p>Corrigez vos informations dans l'application NYME et soumettez à nouveau.</p>
'''),
    );
  }

  // ── Confirmation réclamation ──
  static Future<bool> envoyerConfirmationReclamation({
    required String email,
    required String nom,
    required String livraisonId,
    required String motif,
    required String numeroReclamation,
  }) async {
    return _envoyer(
      destinataire: email,
      nomDestinataire: nom,
      sujet: '📩 Réclamation reçue — NYME #$numeroReclamation',
      html: _base('''
<h2>Réclamation reçue 📩</h2>
<p>Bonjour <strong>$nom</strong>,</p>
<div class="info">
  <p><strong>N° réclamation :</strong> <span class="badge">#$numeroReclamation</span></p>
  <p><strong>Livraison :</strong> ${livraisonId.length > 8 ? livraisonId.substring(0,8).toUpperCase() : livraisonId}</p>
  <p><strong>Motif :</strong> $motif</p>
  <p><strong>Délai :</strong> 24 à 48 heures ouvrées</p>
</div>
<p>Conservez ce numéro <strong>#$numeroReclamation</strong> pour le suivi.</p>
'''),
    );
  }

  // ── Compte rendu réclamation ──
  static Future<bool> envoyerCompteRenduReclamation({
    required String email,
    required String nom,
    required String numeroReclamation,
    required String statut,
    required String reponseAdmin,
    String? compensation,
  }) async {
    final resolu = statut == 'resolue';
    return _envoyer(
      destinataire: email,
      nomDestinataire: nom,
      sujet: resolu ? '✅ Réclamation #$numeroReclamation résolue' : '❌ Réclamation #$numeroReclamation — Décision',
      html: _base('''
<h2>${resolu ? 'Réclamation résolue ✅' : 'Décision finale ❌'}</h2>
<p>Bonjour <strong>$nom</strong>,</p>
${resolu ? '<div class="succes">' : '<div class="erreur">'}
  <p><strong>Réponse :</strong> $reponseAdmin</p>
  ${compensation != null ? '<p><strong>Compensation :</strong> $compensation</p>' : ''}
</div>
<p>Merci de votre confiance en NYME.</p>
'''),
    );
  }

  // ── Réinitialisation mot de passe ──
  static Future<bool> envoyerReinitialisationMdp({
    required String email,
    required String nom,
    required String lien,
  }) async {
    return _envoyer(
      destinataire: email,
      nomDestinataire: nom,
      sujet: '🔐 Réinitialisation mot de passe NYME',
      html: _base('''
<h2>Réinitialisation de mot de passe 🔐</h2>
<p>Bonjour <strong>$nom</strong>,</p>
<p>Cliquez sur le bouton ci-dessous pour créer un nouveau mot de passe :</p>
<div style="text-align:center;margin:24px 0;">
  <a href="$lien" style="background:#1A4FBF;color:white;padding:14px 28px;border-radius:12px;text-decoration:none;font-weight:bold;">Réinitialiser mon mot de passe</a>
</div>
<div class="alerte"><p><strong>⚠️ Ce lien expire dans 1 heure.</strong></p></div>
'''),
    );
  }

  // ════════════════════════════════════════════
  // TEMPLATE HTML BASE
  // ════════════════════════════════════════════
  static String _base(String contenu) => '''
<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<style>
*{margin:0;padding:0;box-sizing:border-box;}
body{font-family:Arial,sans-serif;background:#F3F4F6;padding:16px;}
.w{max-width:600px;margin:0 auto;background:white;border-radius:20px;overflow:hidden;box-shadow:0 4px 24px rgba(26,79,191,.1);}
.h{background:linear-gradient(135deg,#1A4FBF,#0A2E8A);padding:28px;text-align:center;}
.logo{font-size:36px;font-weight:900;color:white;letter-spacing:6px;}
.sub{font-size:12px;color:rgba(255,255,255,.7);margin-top:4px;}
.b{padding:28px;}
h2{color:#1A1A2E;font-size:20px;margin-bottom:12px;}
p{color:#374151;font-size:15px;line-height:1.7;margin-bottom:10px;}
ul{padding-left:20px;margin:12px 0;}
li{color:#374151;font-size:14px;line-height:1.8;}
.info{background:#F0F4FF;border-left:4px solid #1A4FBF;border-radius:0 12px 12px 0;padding:14px 18px;margin:16px 0;}
.info p{font-size:14px;margin-bottom:6px;}
.info strong{color:#1A4FBF;}
.badge{display:inline-block;background:#1A4FBF;color:white;padding:4px 12px;border-radius:16px;font-size:12px;font-weight:700;}
.succes{background:#F0FDF4;border-left:4px solid #22C55E;border-radius:0 12px 12px 0;padding:14px 18px;margin:16px 0;}
.erreur{background:#FFF1F1;border-left:4px solid #EF4444;border-radius:0 12px 12px 0;padding:14px 18px;margin:16px 0;}
.alerte{background:#FFF7ED;border-left:4px solid #E87722;border-radius:0 12px 12px 0;padding:14px 18px;margin:16px 0;}
.prix{text-align:center;padding:20px;background:#F0F4FF;border-radius:14px;margin:16px 0;}
.montant{font-size:30px;font-weight:900;color:#1A4FBF;}
.label{font-size:12px;color:#6B7280;margin-top:4px;}
.f{background:#F8FAFF;padding:16px;text-align:center;border-top:1px solid #E5E7EB;}
.f p{color:#9CA3AF;font-size:12px;}
</style></head><body>
<div class="w">
  <div class="h"><div class="logo">NYME</div><div class="sub">Livraison Rapide &amp; Intelligente</div></div>
  <div class="b">$contenu</div>
  <div class="f"><p>© 2025 NYME · Ouagadougou, Burkina Faso</p><p>Email envoyé depuis nyme.contact@gmail.com</p></div>
</div></body></html>''';
}


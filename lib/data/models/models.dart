// ═══════════════════════════════════════════════════════════
// lib/data/models/utilisateur_model.dart
// ═══════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';

enum RoleUtilisateur { client, coursier, admin }
enum StatutVerification { enAttente, verifie, rejete }

class UtilisateurModel {
  final String id;
  final String nom;
  final String telephone;
  final String? email;
  final RoleUtilisateur role;
  final String? avatarUrl;
  final String? whatsapp;
  final bool estVerifie;
  final double noteMoyenne;
  final bool estActif;
  final String? fcmToken;
  final DateTime createdAt;

  const UtilisateurModel({
    required this.id,
    required this.nom,
    required this.telephone,
    this.email,
    required this.role,
    this.avatarUrl,
    this.whatsapp,
    this.estVerifie = false,
    this.noteMoyenne = 0.0,
    this.estActif = true,
    this.fcmToken,
    required this.createdAt,
  });

  factory UtilisateurModel.fromJson(Map<String, dynamic> json) {
    return UtilisateurModel(
      id: json['id'],
      nom: json['nom'],
      telephone: json['telephone'],
      email: json['email'],
      role: RoleUtilisateur.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => RoleUtilisateur.client,
      ),
      avatarUrl: json['avatar_url'],
      whatsapp: json['whatsapp'],
      estVerifie: json['est_verifie'] ?? false,
      noteMoyenne: (json['note_moyenne'] ?? 0.0).toDouble(),
      estActif: json['est_actif'] ?? true,
      fcmToken: json['fcm_token'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'telephone': telephone,
    'email': email,
    'role': role.name,
    'avatar_url': avatarUrl,
    'whatsapp': whatsapp,
    'est_verifie': estVerifie,
    'note_moyenne': noteMoyenne,
    'est_actif': estActif,
    'fcm_token': fcmToken,
    'created_at': createdAt.toIso8601String(),
  };

  UtilisateurModel copyWith({
    String? nom, String? telephone, String? email,
    String? avatarUrl, String? whatsapp, bool? estVerifie,
    double? noteMoyenne, bool? estActif, String? fcmToken,
  }) {
    return UtilisateurModel(
      id: id,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      role: role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      whatsapp: whatsapp ?? this.whatsapp,
      estVerifie: estVerifie ?? this.estVerifie,
      noteMoyenne: noteMoyenne ?? this.noteMoyenne,
      estActif: estActif ?? this.estActif,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CoursierModel
// ═══════════════════════════════════════════════════════════
enum StatutCoursier { horsLigne, disponible, occupe }

class CoursierModel {
  final String id;
  final StatutCoursier statut;
  final StatutVerification statutVerification;
  final String? cniRectoUrl;
  final String? cniVersoUrl;
  final String? permisUrl;
  final int totalCourses;
  final double totalGains;
  final double? latActuelle;
  final double? lngActuelle;
  final DateTime? derniereActivite;

  const CoursierModel({
    required this.id,
    required this.statut,
    required this.statutVerification,
    this.cniRectoUrl,
    this.cniVersoUrl,
    this.permisUrl,
    this.totalCourses = 0,
    this.totalGains = 0.0,
    this.latActuelle,
    this.lngActuelle,
    this.derniereActivite,
  });

  factory CoursierModel.fromJson(Map<String, dynamic> json) {
    return CoursierModel(
      id: json['id'],
      statut: StatutCoursier.values.firstWhere(
        (s) => s.name == json['statut'],
        orElse: () => StatutCoursier.horsLigne,
      ),
      statutVerification: StatutVerification.values.firstWhere(
        (s) => s.name == json['statut_verification'],
        orElse: () => StatutVerification.enAttente,
      ),
      cniRectoUrl: json['cni_recto_url'],
      cniVersoUrl: json['cni_verso_url'],
      permisUrl: json['permis_url'],
      totalCourses: json['total_courses'] ?? 0,
      totalGains: (json['total_gains'] ?? 0.0).toDouble(),
      latActuelle: json['lat_actuelle']?.toDouble(),
      lngActuelle: json['lng_actuelle']?.toDouble(),
      derniereActivite: json['derniere_activite'] != null
          ? DateTime.parse(json['derniere_activite'])
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// VehiculeModel
// ═══════════════════════════════════════════════════════════
enum TypeVehicule { moto, velo, voiture, camionnette }

class VehiculeModel {
  final String id;
  final String coursierId;
  final TypeVehicule type;
  final String marque;
  final String modele;
  final String couleur;
  final String plaque;
  final String? carteGriseUrl;
  final bool estVerifie;

  const VehiculeModel({
    required this.id,
    required this.coursierId,
    required this.type,
    required this.marque,
    required this.modele,
    required this.couleur,
    required this.plaque,
    this.carteGriseUrl,
    this.estVerifie = false,
  });

  factory VehiculeModel.fromJson(Map<String, dynamic> json) {
    return VehiculeModel(
      id: json['id'],
      coursierId: json['coursier_id'],
      type: TypeVehicule.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TypeVehicule.moto,
      ),
      marque: json['marque'],
      modele: json['modele'],
      couleur: json['couleur'],
      plaque: json['plaque'],
      carteGriseUrl: json['carte_grise_url'],
      estVerifie: json['est_verifie'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'coursier_id': coursierId,
    'type': type.name,
    'marque': marque,
    'modele': modele,
    'couleur': couleur,
    'plaque': plaque,
    'carte_grise_url': carteGriseUrl,
    'est_verifie': estVerifie,
  };
}

// ═══════════════════════════════════════════════════════════
// LivraisonModel
// ═══════════════════════════════════════════════════════════
enum StatutLivraison {
  enAttente, acceptee, enRoutDepart, colisRecupere,
  enRouteArrivee, livree, annulee
}
enum TypeCourse { immediate, urgente, programmee }
enum StatutPaiement { enAttente, paye, rembourse }
enum ModePaiement { cash, mobileMoney, carte }

class LivraisonModel {
  final String id;
  final String clientId;
  final String? coursierId;
  final StatutLivraison statut;
  final TypeCourse type;
  final bool pourTiers;
  final String departAdresse;
  final double departLat;
  final double departLng;
  final String arriveeAdresse;
  final double arriveeLat;
  final double arriveeLng;
  final String destinataireNom;
  final String destinataireTel;
  final String? destinataireWhatsapp;
  final String? destinataireEmail;
  final String? instructions;
  final List<String> photosColis;
  final double prixCalcule;
  final double? prixFinal;
  final double? commissionNyme;
  final double? distanceKm;
  final int? dureeEstimee;
  final StatutPaiement statutPaiement;
  final ModePaiement? modePaiement;
  final DateTime? programmeLe;
  final DateTime createdAt;
  final DateTime? accepteeAt;
  final DateTime? livreeAt;

  // Données jointes (optionnel)
  final UtilisateurModel? client;
  final UtilisateurModel? coursier;

  const LivraisonModel({
    required this.id,
    required this.clientId,
    this.coursierId,
    required this.statut,
    required this.type,
    this.pourTiers = false,
    required this.departAdresse,
    required this.departLat,
    required this.departLng,
    required this.arriveeAdresse,
    required this.arriveeLat,
    required this.arriveeLng,
    required this.destinataireNom,
    required this.destinataireTel,
    this.destinataireWhatsapp,
    this.destinataireEmail,
    this.instructions,
    this.photosColis = const [],
    required this.prixCalcule,
    this.prixFinal,
    this.commissionNyme,
    this.distanceKm,
    this.dureeEstimee,
    this.statutPaiement = StatutPaiement.enAttente,
    this.modePaiement,
    this.programmeLe,
    required this.createdAt,
    this.accepteeAt,
    this.livreeAt,
    this.client,
    this.coursier,
  });

  factory LivraisonModel.fromJson(Map<String, dynamic> json) {
    return LivraisonModel(
      id: json['id'],
      clientId: json['client_id'],
      coursierId: json['coursier_id'],
      statut: StatutLivraison.values.firstWhere(
        (s) => s.name == json['statut'],
        orElse: () => StatutLivraison.enAttente,
      ),
      type: TypeCourse.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TypeCourse.immediate,
      ),
      pourTiers: json['pour_tiers'] ?? false,
      departAdresse: json['depart_adresse'],
      departLat: json['depart_lat'].toDouble(),
      departLng: json['depart_lng'].toDouble(),
      arriveeAdresse: json['arrivee_adresse'],
      arriveeLat: json['arrivee_lat'].toDouble(),
      arriveeLng: json['arrivee_lng'].toDouble(),
      destinataireNom: json['destinataire_nom'],
      destinataireTel: json['destinataire_tel'],
      destinataireWhatsapp: json['destinataire_whatsapp'],
      destinataireEmail: json['destinataire_email'],
      instructions: json['instructions'],
      photosColis: List<String>.from(json['photos_colis'] ?? []),
      prixCalcule: json['prix_calcule'].toDouble(),
      prixFinal: json['prix_final']?.toDouble(),
      commissionNyme: json['commission_nyme']?.toDouble(),
      distanceKm: json['distance_km']?.toDouble(),
      dureeEstimee: json['duree_estimee'],
      statutPaiement: StatutPaiement.values.firstWhere(
        (s) => s.name == json['statut_paiement'],
        orElse: () => StatutPaiement.enAttente,
      ),
      modePaiement: json['mode_paiement'] != null
          ? ModePaiement.values.firstWhere((m) => m.name == json['mode_paiement'])
          : null,
      programmeLe: json['programme_le'] != null
          ? DateTime.parse(json['programme_le'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      accepteeAt: json['acceptee_at'] != null
          ? DateTime.parse(json['acceptee_at'])
          : null,
      livreeAt: json['livree_at'] != null
          ? DateTime.parse(json['livree_at'])
          : null,
      client: json['client'] != null
          ? UtilisateurModel.fromJson(json['client'])
          : null,
      coursier: json['coursier'] != null
          ? UtilisateurModel.fromJson(json['coursier'])
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// MessageModel
// ═══════════════════════════════════════════════════════════
class MessageModel {
  final String id;
  final String? livraisonId;
  final String expediteurId;
  final String destinataireId;
  final String contenu;
  final String? photoUrl;
  final bool lu;
  final DateTime createdAt;
  final UtilisateurModel? expediteur;

  const MessageModel({
    required this.id,
    this.livraisonId,
    required this.expediteurId,
    required this.destinataireId,
    required this.contenu,
    this.photoUrl,
    this.lu = false,
    required this.createdAt,
    this.expediteur,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      livraisonId: json['livraison_id'],
      expediteurId: json['expediteur_id'],
      destinataireId: json['destinataire_id'],
      contenu: json['contenu'],
      photoUrl: json['photo_url'],
      lu: json['lu'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      expediteur: json['expediteur'] != null
          ? UtilisateurModel.fromJson(json['expediteur'])
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// AdresseFavoriteModel
// ═══════════════════════════════════════════════════════════
class AdresseFavoriteModel {
  final String id;
  final String userId;
  final String label;
  final String adresse;
  final double latitude;
  final double longitude;
  final bool estDefaut;
  final DateTime createdAt;

  const AdresseFavoriteModel({
    required this.id,
    required this.userId,
    required this.label,
    required this.adresse,
    required this.latitude,
    required this.longitude,
    this.estDefaut = false,
    required this.createdAt,
  });

  factory AdresseFavoriteModel.fromJson(Map<String, dynamic> json) {
    return AdresseFavoriteModel(
      id: json['id'],
      userId: json['user_id'],
      label: json['label'],
      adresse: json['adresse'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      estDefaut: json['est_defaut'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'label': label,
    'adresse': adresse,
    'latitude': latitude,
    'longitude': longitude,
    'est_defaut': estDefaut,
  };
}

// ═══════════════════════════════════════════════════════════
// PropositionPrixModel
// ═══════════════════════════════════════════════════════════
enum StatutProposition { enAttente, accepte, refuse }

class PropositionPrixModel {
  final String id;
  final String livraisonId;
  final String auteurId;
  final String roleAuteur;
  final double montant;
  final StatutProposition statut;
  final DateTime createdAt;
  final UtilisateurModel? auteur;

  const PropositionPrixModel({
    required this.id,
    required this.livraisonId,
    required this.auteurId,
    required this.roleAuteur,
    required this.montant,
    required this.statut,
    required this.createdAt,
    this.auteur,
  });

  factory PropositionPrixModel.fromJson(Map<String, dynamic> json) {
    return PropositionPrixModel(
      id: json['id'],
      livraisonId: json['livraison_id'],
      auteurId: json['auteur_id'],
      roleAuteur: json['role_auteur'],
      montant: json['montant'].toDouble(),
      statut: StatutProposition.values.firstWhere(
        (s) => s.name == json['statut'],
        orElse: () => StatutProposition.enAttente,
      ),
      createdAt: DateTime.parse(json['created_at']),
      auteur: json['auteur'] != null
          ? UtilisateurModel.fromJson(json['auteur'])
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// LocalisationModel
// ═══════════════════════════════════════════════════════════
class LocalisationModel {
  final String id;
  final String coursierId;
  final String? livraisonId;
  final double latitude;
  final double longitude;
  final double? vitesse;
  final double? direction;
  final DateTime createdAt;

  const LocalisationModel({
    required this.id,
    required this.coursierId,
    this.livraisonId,
    required this.latitude,
    required this.longitude,
    this.vitesse,
    this.direction,
    required this.createdAt,
  });

  factory LocalisationModel.fromJson(Map<String, dynamic> json) {
    return LocalisationModel(
      id: json['id'],
      coursierId: json['coursier_id'],
      livraisonId: json['livraison_id'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      vitesse: json['vitesse']?.toDouble(),
      direction: json['direction']?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// NotificationModel
// ═══════════════════════════════════════════════════════════
class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String titre;
  final String message;
  final Map<String, dynamic>? data;
  final bool lu;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.titre,
    required this.message,
    this.data,
    this.lu = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      titre: json['titre'],
      message: json['message'],
      data: json['data'],
      lu: json['lu'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

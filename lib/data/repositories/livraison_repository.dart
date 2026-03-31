import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../../config/supabase_config.dart';
import '../../core/errors/app_exception.dart';

class LivraisonRepository {
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

  LivraisonRepository(this._supabase);

  // ── Créer une livraison ──
  Future<LivraisonModel> creerLivraison({
    required String clientId,
    required String departAdresse,
    required double departLat,
    required double departLng,
    required String arriveeAdresse,
    required double arriveeLat,
    required double arriveeLng,
    required String destinataireNom,
    required String destinataireTel,
    String? destinataireWhatsapp,
    String? destinataireEmail,
    String? instructions,
    required List<File> photosColis,
    required double prixCalcule,
    required TypeCourse type,
    bool pourTiers = false,
    DateTime? programmeLe,
  }) async {
    try {
      // 1. Uploader les photos du colis
      final List<String> photosUrls = [];
      for (final photo in photosColis) {
        final url = await _uploaderPhotoColis(photo);
        photosUrls.add(url);
      }

      // 2. Insérer la livraison
      final livraisonData = {
        'client_id': clientId,
        'statut': StatutLivraison.enAttente.name,
        'type': type.name,
        'pour_tiers': pourTiers,
        'depart_adresse': departAdresse,
        'depart_lat': departLat,
        'depart_lng': departLng,
        'arrivee_adresse': arriveeAdresse,
        'arrivee_lat': arriveeLat,
        'arrivee_lng': arriveeLng,
        'destinataire_nom': destinataireNom,
        'destinataire_tel': destinataireTel,
        'destinataire_whatsapp': destinataireWhatsapp,
        'destinataire_email': destinataireEmail,
        'instructions': instructions,
        'photos_colis': photosUrls,
        'prix_calcule': prixCalcule,
        'statut_paiement': StatutPaiement.enAttente.name,
        'programme_le': programmeLe?.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase
          .from(SupabaseConfig.tableLivraisons)
          .insert(livraisonData)
          .select()
          .single();

      // 3. Enregistrer statut initial dans l'historique
      await _supabase.from(SupabaseConfig.tableStatutsLivraison).insert({
        'livraison_id': result['id'],
        'statut': StatutLivraison.enAttente.name,
        'changed_at': DateTime.now().toIso8601String(),
      });

      return LivraisonModel.fromJson(result);
    } catch (e) {
      throw AppException('Erreur création livraison: $e');
    }
  }

  // ── Récupérer livraisons d'un client ──
  Future<List<LivraisonModel>> getLivraisonsClient(String clientId) async {
    final data = await _supabase
        .from(SupabaseConfig.tableLivraisons)
        .select('*, coursier:coursier_id(id, nom, avatar_url, telephone, note_moyenne)')
        .eq('client_id', clientId)
        .order('created_at', ascending: false);

    return (data as List).map((d) => LivraisonModel.fromJson(d)).toList();
  }

  // ── Récupérer livraisons disponibles pour coursier ──
  Future<List<LivraisonModel>> getLivraisonsDisponibles({
    required double lat,
    required double lng,
    double rayonKm = 10.0,
  }) async {
    // Utiliser la fonction SQL Supabase
    final data = await _supabase.rpc('livraisons_proches_disponibles', params: {
      'lat_coursier': lat,
      'lng_coursier': lng,
      'rayon_km': rayonKm,
    });

    return (data as List).map((d) => LivraisonModel.fromJson(d)).toList();
  }

  // ── Récupérer une livraison par ID ──
  Future<LivraisonModel> getLivraison(String id) async {
    final data = await _supabase
        .from(SupabaseConfig.tableLivraisons)
        .select('*, client:client_id(id, nom, telephone, avatar_url), coursier:coursier_id(id, nom, telephone, avatar_url, note_moyenne)')
        .eq('id', id)
        .single();

    return LivraisonModel.fromJson(data);
  }

  // ── Écouter une livraison en temps réel ──
  RealtimeChannel ecouterLivraison({
    required String livraisonId,
    required void Function(LivraisonModel) onUpdate,
  }) {
    return _supabase
        .channel('livraison_$livraisonId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConfig.tableLivraisons,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: livraisonId,
          ),
          callback: (payload) {
            onUpdate(LivraisonModel.fromJson(payload.newRecord));
          },
        )
        .subscribe();
  }

  // ── Mettre à jour le statut ──
  Future<void> mettreAJourStatut({
    required String livraisonId,
    required StatutLivraison statut,
  }) async {
    final updates = <String, dynamic>{'statut': statut.name};

    // Ajouter les timestamps selon le statut
    switch (statut) {
      case StatutLivraison.acceptee:
        updates['acceptee_at'] = DateTime.now().toIso8601String();
        break;
      case StatutLivraison.livree:
        updates['livree_at'] = DateTime.now().toIso8601String();
        break;
      default:
        break;
    }

    await _supabase
        .from(SupabaseConfig.tableLivraisons)
        .update(updates)
        .eq('id', livraisonId);

    // Historique des statuts
    await _supabase.from(SupabaseConfig.tableStatutsLivraison).insert({
      'livraison_id': livraisonId,
      'statut': statut.name,
      'changed_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Assigner un coursier ──
  Future<void> assignerCoursier({
    required String livraisonId,
    required String coursierId,
    required double prixFinal,
  }) async {
    final commission = prixFinal * 0.15; // 15% commission NYME

    await _supabase
        .from(SupabaseConfig.tableLivraisons)
        .update({
          'coursier_id': coursierId,
          'statut': StatutLivraison.acceptee.name,
          'prix_final': prixFinal,
          'commission_nyme': commission,
          'acceptee_at': DateTime.now().toIso8601String(),
        })
        .eq('id', livraisonId);

    // Mettre à jour statut coursier
    await _supabase
        .from(SupabaseConfig.tableCoursiers)
        .update({'statut': StatutCoursier.occupe.name})
        .eq('id', coursierId);
  }

  // ── Propositions de prix ──
  Future<PropositionPrixModel> proposerPrix({
    required String livraisonId,
    required String auteurId,
    required String roleAuteur,
    required double montant,
  }) async {
    final data = await _supabase
        .from(SupabaseConfig.tablePropositionsPrix)
        .insert({
          'livraison_id': livraisonId,
          'auteur_id': auteurId,
          'role_auteur': roleAuteur,
          'montant': montant,
          'statut': StatutProposition.enAttente.name,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('*, auteur:auteur_id(id, nom, avatar_url)')
        .single();

    return PropositionPrixModel.fromJson(data);
  }

  Future<List<PropositionPrixModel>> getPropositions(String livraisonId) async {
    final data = await _supabase
        .from(SupabaseConfig.tablePropositionsPrix)
        .select('*, auteur:auteur_id(id, nom, avatar_url, note_moyenne)')
        .eq('livraison_id', livraisonId)
        .order('created_at', ascending: false);

    return (data as List).map((d) => PropositionPrixModel.fromJson(d)).toList();
  }

  Future<void> accepterProposition(String propositionId) async {
    await _supabase
        .from(SupabaseConfig.tablePropositionsPrix)
        .update({'statut': StatutProposition.accepte.name})
        .eq('id', propositionId);
  }

  // ── Écouter propositions en temps réel ──
  RealtimeChannel ecouterPropositions({
    required String livraisonId,
    required void Function(PropositionPrixModel) onNouvelle,
  }) {
    return _supabase
        .channel('propositions_$livraisonId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.tablePropositionsPrix,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'livraison_id',
            value: livraisonId,
          ),
          callback: (payload) {
            onNouvelle(PropositionPrixModel.fromJson(payload.newRecord));
          },
        )
        .subscribe();
  }

  // ── Upload photo colis ──
  Future<String> _uploaderPhotoColis(File fichier) async {
    final path = 'colis/${_uuid.v4()}.jpg';
    await _supabase.storage
        .from(SupabaseConfig.bucketPhotos)
        .upload(path, fichier);
    return _supabase.storage
        .from(SupabaseConfig.bucketPhotos)
        .getPublicUrl(path);
  }

  // ── Annuler livraison ──
  Future<void> annulerLivraison(String livraisonId) async {
    await mettreAJourStatut(
      livraisonId: livraisonId,
      statut: StatutLivraison.annulee,
    );
  }
}

final livraisonRepositoryProvider = Provider<LivraisonRepository>((ref) {
  return LivraisonRepository(Supabase.instance.client);
});

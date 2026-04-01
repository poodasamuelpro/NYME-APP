import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../../config/supabase_config.dart';
import '../../core/errors/app_exception.dart';

// ─────────────────────────────────────────────────────────────
// Coursier Repository — toute la logique liée aux coursiers
// Compatible avec les tables : coursiers, vehicules,
// coursiers_favoris, evaluations, localisation_coursier
// ─────────────────────────────────────────────────────────────

class CoursierRepository {
  final SupabaseClient _supabase;
  CoursierRepository(this._supabase);

  // ── Profil complet d'un coursier ──
  Future<Map<String, dynamic>> getProfilComplet(String coursierId) async {
    final data = await _supabase
        .from(SupabaseConfig.tableCoursiers)
        .select('''
          *,
          utilisateur:id(id, nom, telephone, email, whatsapp, avatar_url, note_moyenne, created_at),
          vehicules(*)
        ''')
        .eq('id', coursierId)
        .single();
    return data;
  }

  // ── Mettre à jour le statut (disponible/hors_ligne/occupe) ──
  Future<void> mettreAJourStatut(String coursierId, StatutCoursier statut) async {
    await _supabase
        .from(SupabaseConfig.tableCoursiers)
        .update({'statut': statut.name})
        .eq('id', coursierId);
  }

  // ── Coursiers disponibles proches (via fonction SQL) ──
  Future<List<Map<String, dynamic>>> getCoursiersProches({
    required double lat,
    required double lng,
    double rayonKm = 5.0,
  }) async {
    final result = await _supabase.rpc('coursiers_proches', params: {
      'lat_client': lat,
      'lng_client': lng,
      'rayon_km': rayonKm,
    });
    return List<Map<String, dynamic>>.from(result);
  }

  // ── Ajouter un coursier en favori ──
  Future<void> ajouterFavori({
    required String clientId,
    required String coursierId,
  }) async {
    try {
      await _supabase.from(SupabaseConfig.tableCoursiersFavoris).insert({
        'client_id': clientId,
        'coursier_id': coursierId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (e.toString().contains('unique')) return; // déjà en favori
      throw AppException('Erreur ajout favori: $e');
    }
  }

  // ── Retirer un coursier des favoris ──
  Future<void> retirerFavori({
    required String clientId,
    required String coursierId,
  }) async {
    await _supabase
        .from(SupabaseConfig.tableCoursiersFavoris)
        .delete()
        .eq('client_id', clientId)
        .eq('coursier_id', coursierId);
  }

  // ── Vérifier si un coursier est en favori ──
  Future<bool> estFavori({
    required String clientId,
    required String coursierId,
  }) async {
    final result = await _supabase
        .from(SupabaseConfig.tableCoursiersFavoris)
        .select('id')
        .eq('client_id', clientId)
        .eq('coursier_id', coursierId);
    return (result as List).isNotEmpty;
  }

  // ── Liste des coursiers favoris d'un client ──
  Future<List<Map<String, dynamic>>> getMesFavoris(String clientId) async {
    final data = await _supabase
        .from(SupabaseConfig.tableCoursiersFavoris)
        .select('''
          *,
          coursier:coursier_id(
            id, statut, total_courses,
            utilisateur:id(id, nom, telephone, whatsapp, avatar_url, note_moyenne)
          )
        ''')
        .eq('client_id', clientId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Noter un coursier ──
  Future<void> noterCoursier({
    required String livraisonId,
    required String evaluateurId,
    required String evalueId,
    required int note,
    String? commentaire,
  }) async {
    await _supabase.from(SupabaseConfig.tableEvaluations).insert({
      'livraison_id': livraisonId,
      'evaluateur_id': evaluateurId,
      'evalue_id': evalueId,
      'note': note,
      'commentaire': commentaire,
      'created_at': DateTime.now().toIso8601String(),
    });
    // La note_moyenne est mise à jour automatiquement par le trigger SQL
  }

  // ── Évaluations reçues par un coursier ──
  Future<List<Map<String, dynamic>>> getEvaluations(String coursierId) async {
    final data = await _supabase
        .from(SupabaseConfig.tableEvaluations)
        .select('''
          *,
          evaluateur:evaluateur_id(id, nom, avatar_url)
        ''')
        .eq('evalue_id', coursierId)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Historique des courses d'un coursier ──
  Future<List<LivraisonModel>> getHistoriqueCourses(String coursierId) async {
    final data = await _supabase
        .from(SupabaseConfig.tableLivraisons)
        .select('''
          *,
          client:client_id(id, nom, avatar_url, telephone)
        ''')
        .eq('coursier_id', coursierId)
        .order('created_at', ascending: false);
    return (data as List).map((d) => LivraisonModel.fromJson(d)).toList();
  }

  // ── Stats du coursier (gains, courses, note) ──
  Future<Map<String, dynamic>> getStats(String coursierId) async {
    final coursier = await _supabase
        .from(SupabaseConfig.tableCoursiers)
        .select('total_courses, total_gains')
        .eq('id', coursierId)
        .single();

    final utilisateur = await _supabase
        .from(SupabaseConfig.tableUtilisateurs)
        .select('note_moyenne')
        .eq('id', coursierId)
        .single();

    final wallet = await _supabase
        .from(SupabaseConfig.tableWallets)
        .select('solde')
        .eq('user_id', coursierId)
        .single();

    // Courses du mois en cours
    final debutMois = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final coursesMois = await _supabase
        .from(SupabaseConfig.tableLivraisons)
        .select('id, prix_final')
        .eq('coursier_id', coursierId)
        .eq('statut', 'livree')
        .gte('created_at', debutMois.toIso8601String());

    double gainsMois = 0;
    for (final c in coursesMois as List) {
      if (c['prix_final'] != null) {
        gainsMois += (c['prix_final'] as num).toDouble() * 0.85;
      }
    }

    return {
      'total_courses': coursier['total_courses'] ?? 0,
      'total_gains': coursier['total_gains'] ?? 0.0,
      'note_moyenne': utilisateur['note_moyenne'] ?? 0.0,
      'solde_wallet': wallet['solde'] ?? 0.0,
      'courses_mois': (coursesMois as List).length,
      'gains_mois': gainsMois,
    };
  }

  // ── Demander un retrait de gains ──
  Future<void> demanderRetrait({
    required String coursierId,
    required double montant,
    required String modePaiement,
    required String numeroMobileMoney,
  }) async {
    // Vérifier le solde
    final wallet = await _supabase
        .from(SupabaseConfig.tableWallets)
        .select('solde')
        .eq('user_id', coursierId)
        .single();

    final solde = (wallet['solde'] as num).toDouble();
    if (montant > solde) {
      throw AppException('Solde insuffisant (${solde.toStringAsFixed(0)} FCFA disponible)');
    }

    // Enregistrer la demande de retrait
    await _supabase.from(SupabaseConfig.tableTransactionsWallet).insert({
      'user_id': coursierId,
      'type': 'retrait',
      'montant': -montant,
      'solde_avant': solde,
      'solde_apres': solde - montant,
      'reference': numeroMobileMoney,
      'note': 'Retrait via $modePaiement',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Déduire du wallet
    await _supabase
        .from(SupabaseConfig.tableWallets)
        .update({'solde': solde - montant})
        .eq('user_id', coursierId);
  }

  // ── Transactions du wallet ──
  Future<List<Map<String, dynamic>>> getTransactions(String coursierId) async {
    final data = await _supabase
        .from(SupabaseConfig.tableTransactionsWallet)
        .select()
        .eq('user_id', coursierId)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Signaler un utilisateur ──
  Future<void> signaler({
    required String signalantId,
    required String signaleId,
    required String motif,
    String? description,
    String? livraisonId,
  }) async {
    await _supabase.from(SupabaseConfig.tableSignalements).insert({
      'signalant_id': signalantId,
      'signale_id': signaleId,
      'livraison_id': livraisonId,
      'motif': motif,
      'description': description,
      'statut': 'en_attente',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

final coursierRepositoryProvider = Provider<CoursierRepository>((ref) {
  return CoursierRepository(Supabase.instance.client);
});


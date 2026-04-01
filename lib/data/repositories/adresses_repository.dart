import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../../config/supabase_config.dart';
import '../../core/errors/app_exception.dart';

// ─────────────────────────────────────────────────────────────
// Adresses & Contacts favoris Repository
// Tables : adresses_favorites, contacts_favoris
// ─────────────────────────────────────────────────────────────

class AdressesRepository {
  final SupabaseClient _supabase;
  AdressesRepository(this._supabase);

  // ════════════════════════════════
  // ADRESSES FAVORITES
  // ════════════════════════════════

  Future<List<AdresseFavoriteModel>> getAdresses(String userId) async {
    final data = await _supabase
        .from(SupabaseConfig.tableAdressesFavorites)
        .select()
        .eq('user_id', userId)
        .order('est_defaut', ascending: false)
        .order('created_at', ascending: false);
    return (data as List).map((d) => AdresseFavoriteModel.fromJson(d)).toList();
  }

  Future<AdresseFavoriteModel> ajouterAdresse({
    required String userId,
    required String label,
    required String adresse,
    required double latitude,
    required double longitude,
    bool estDefaut = false,
  }) async {
    // Si on la marque par défaut, retirer l'ancien défaut
    if (estDefaut) {
      await _supabase
          .from(SupabaseConfig.tableAdressesFavorites)
          .update({'est_defaut': false})
          .eq('user_id', userId);
    }

    final data = await _supabase
        .from(SupabaseConfig.tableAdressesFavorites)
        .insert({
          'user_id': userId,
          'label': label,
          'adresse': adresse,
          'latitude': latitude,
          'longitude': longitude,
          'est_defaut': estDefaut,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return AdresseFavoriteModel.fromJson(data);
  }

  Future<void> modifierAdresse({
    required String adresseId,
    String? label,
    String? adresse,
    double? latitude,
    double? longitude,
    bool? estDefaut,
    required String userId,
  }) async {
    if (estDefaut == true) {
      await _supabase
          .from(SupabaseConfig.tableAdressesFavorites)
          .update({'est_defaut': false})
          .eq('user_id', userId);
    }
    final updates = <String, dynamic>{};
    if (label != null) updates['label'] = label;
    if (adresse != null) updates['adresse'] = adresse;
    if (latitude != null) updates['latitude'] = latitude;
    if (longitude != null) updates['longitude'] = longitude;
    if (estDefaut != null) updates['est_defaut'] = estDefaut;
    await _supabase
        .from(SupabaseConfig.tableAdressesFavorites)
        .update(updates)
        .eq('id', adresseId);
  }

  Future<void> supprimerAdresse(String adresseId) async {
    await _supabase
        .from(SupabaseConfig.tableAdressesFavorites)
        .delete()
        .eq('id', adresseId);
  }

  Future<void> definirDefaut({
    required String adresseId,
    required String userId,
  }) async {
    await _supabase
        .from(SupabaseConfig.tableAdressesFavorites)
        .update({'est_defaut': false})
        .eq('user_id', userId);
    await _supabase
        .from(SupabaseConfig.tableAdressesFavorites)
        .update({'est_defaut': true})
        .eq('id', adresseId);
  }

  // ════════════════════════════════
  // CONTACTS FAVORIS
  // ════════════════════════════════

  Future<List<Map<String, dynamic>>> getContacts(String userId) async {
    final data = await _supabase
        .from(SupabaseConfig.tableContactsFavoris)
        .select()
        .eq('user_id', userId)
        .order('nom', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> ajouterContact({
    required String userId,
    required String nom,
    required String telephone,
    String? whatsapp,
    String? email,
  }) async {
    try {
      final data = await _supabase
          .from(SupabaseConfig.tableContactsFavoris)
          .insert({
            'user_id': userId,
            'nom': nom,
            'telephone': telephone,
            'whatsapp': whatsapp ?? telephone,
            'email': email,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return data;
    } catch (e) {
      if (e.toString().contains('unique')) {
        throw AppException('Ce contact existe déjà');
      }
      throw AppException('Erreur ajout contact: $e');
    }
  }

  Future<void> modifierContact({
    required String contactId,
    String? nom,
    String? telephone,
    String? whatsapp,
    String? email,
  }) async {
    final updates = <String, dynamic>{};
    if (nom != null) updates['nom'] = nom;
    if (telephone != null) updates['telephone'] = telephone;
    if (whatsapp != null) updates['whatsapp'] = whatsapp;
    if (email != null) updates['email'] = email;
    await _supabase
        .from(SupabaseConfig.tableContactsFavoris)
        .update(updates)
        .eq('id', contactId);
  }

  Future<void> supprimerContact(String contactId) async {
    await _supabase
        .from(SupabaseConfig.tableContactsFavoris)
        .delete()
        .eq('id', contactId);
  }
}

final adressesRepositoryProvider = Provider<AdressesRepository>((ref) {
  return AdressesRepository(Supabase.instance.client);
});


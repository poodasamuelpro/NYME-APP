import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../../config/supabase_config.dart';

class ChatRepository {
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

  ChatRepository(this._supabase);

  // ── Envoyer un message ──
  Future<MessageModel> envoyerMessage({
    required String expediteurId,
    required String destinataireId,
    required String contenu,
    String? livraisonId,
    File? photo,
  }) async {
    String? photoUrl;
    if (photo != null) {
      photoUrl = await _uploaderPhotoMessage(photo);
    }

    final data = await _supabase
        .from(SupabaseConfig.tableMessages)
        .insert({
          'expediteur_id': expediteurId,
          'destinataire_id': destinataireId,
          'livraison_id': livraisonId,
          'contenu': contenu,
          'photo_url': photoUrl,
          'lu': false,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('*, expediteur:expediteur_id(id, nom, avatar_url)')
        .single();

    return MessageModel.fromJson(data);
  }

  // ── Récupérer les messages d'une conversation ──
  Future<List<MessageModel>> getMessages({
    required String userId1,
    required String userId2,
    String? livraisonId,
    int limit = 50,
  }) async {
    var query = _supabase
        .from(SupabaseConfig.tableMessages)
        .select('*, expediteur:expediteur_id(id, nom, avatar_url)')
        .or('and(expediteur_id.eq.$userId1,destinataire_id.eq.$userId2),and(expediteur_id.eq.$userId2,destinataire_id.eq.$userId1)')
        .order('created_at', ascending: true)
        .limit(limit);

    if (livraisonId != null) {
      query = query.eq('livraison_id', livraisonId);
    }

    final data = await query;
    return (data as List).map((d) => MessageModel.fromJson(d)).toList();
  }

  // ── Écouter les nouveaux messages en temps réel ──
  RealtimeChannel ecouterMessages({
    required String userId,
    required void Function(MessageModel) onNouveau,
  }) {
    return _supabase
        .channel('messages_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.tableMessages,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'destinataire_id',
            value: userId,
          ),
          callback: (payload) async {
            // Charger avec les données de l'expéditeur
            final data = await _supabase
                .from(SupabaseConfig.tableMessages)
                .select('*, expediteur:expediteur_id(id, nom, avatar_url)')
                .eq('id', payload.newRecord['id'])
                .single();
            onNouveau(MessageModel.fromJson(data));
          },
        )
        .subscribe();
  }

  // ── Marquer messages comme lus ──
  Future<void> marquerCommeRus({
    required String destinataireId,
    required String expediteurId,
  }) async {
    await _supabase
        .from(SupabaseConfig.tableMessages)
        .update({'lu': true})
        .eq('destinataire_id', destinataireId)
        .eq('expediteur_id', expediteurId)
        .eq('lu', false);
  }

  // ── Compter messages non lus ──
  Future<int> compterNonLus(String userId) async {
    final result = await _supabase
        .from(SupabaseConfig.tableMessages)
        .select('id')
        .eq('destinataire_id', userId)
        .eq('lu', false);

    return (result as List).length;
  }

  // ── Liste des conversations d'un utilisateur ──
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    // Fonction SQL Supabase pour récupérer les derniers messages par conversation
    final result = await _supabase.rpc('get_conversations', params: {
      'user_id_param': userId,
    });

    return List<Map<String, dynamic>>.from(result);
  }

  // ── Upload photo message ──
  Future<String> _uploaderPhotoMessage(File fichier) async {
    final path = 'messages/${_uuid.v4()}.jpg';
    await _supabase.storage
        .from(SupabaseConfig.bucketPhotos)
        .upload(path, fichier);
    return _supabase.storage
        .from(SupabaseConfig.bucketPhotos)
        .getPublicUrl(path);
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(Supabase.instance.client);
});

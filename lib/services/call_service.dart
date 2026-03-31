import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

enum TypeAppel { telephoneNatif, whatsapp, voip }

class CallService {
  final SupabaseClient _supabase;

  CallService(this._supabase);

  // ── Appel téléphonique natif ──
  Future<bool> appelerTelephone({
    required String appelantId,
    required String appelantRole,
    required String destinataireId,
    required String numero,
    String? livraisonId,
  }) async {
    final uri = Uri.parse('tel:$numero');
    if (await canLaunchUrl(uri)) {
      await _loggerAppel(
        appelantId: appelantId,
        appelantRole: appelantRole,
        destinataireId: destinataireId,
        livraisonId: livraisonId,
        type: TypeAppel.telephoneNatif,
        numero: numero,
      );
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  // ── Redirection WhatsApp ──
  Future<bool> ouvrirWhatsApp({
    required String appelantId,
    required String appelantRole,
    required String destinataireId,
    required String numeroWhatsapp,
    String? livraisonId,
    String? messageInitial,
  }) async {
    final numero = numeroWhatsapp.replaceAll(RegExp(r'[^\d+]'), '');
    final message = messageInitial ?? 'Bonjour, je vous contacte via NYME.';
    final messageEncode = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$numero?text=$messageEncode');

    if (await canLaunchUrl(uri)) {
      await _loggerAppel(
        appelantId: appelantId,
        appelantRole: appelantRole,
        destinataireId: destinataireId,
        livraisonId: livraisonId,
        type: TypeAppel.whatsapp,
        numero: numeroWhatsapp,
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  // ── Logger l'appel pour traçabilité ──
  Future<void> _loggerAppel({
    required String appelantId,
    required String appelantRole,
    required String destinataireId,
    required TypeAppel type,
    required String numero,
    String? livraisonId,
  }) async {
    try {
      await _supabase.from(SupabaseConfig.tableLogsAppels).insert({
        'appelant_id': appelantId,
        'appelant_role': appelantRole,
        'destinataire_id': destinataireId,
        'livraison_id': livraisonId,
        'type': type.name,
        'numero': numero,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('[CallService] Erreur log appel: $e');
    }
  }

  // ── Récupérer historique des appels ──
  Future<List<Map<String, dynamic>>> getHistoriqueAppels(String userId) async {
    final data = await _supabase
        .from(SupabaseConfig.tableLogsAppels)
        .select()
        .or('appelant_id.eq.$userId,destinataire_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(data);
  }
}

final callServiceProvider = Provider<CallService>((ref) {
  return CallService(Supabase.instance.client);
});

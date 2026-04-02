import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/supabase_config.dart';
import '../../core/errors/app_exception.dart';

class WalletRepository {
  final SupabaseClient _supabase;
  WalletRepository(this._supabase);

  // ── Récupérer le solde du wallet ──
  Future<double> getSolde(String userId) async {
    try {
      final data = await _supabase
          .from(SupabaseConfig.tableWallets)
          .select('solde')
          .eq('user_id', userId)
          .single();
      return (data['solde'] as num).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  // ── Récupérer l'historique des transactions ──
  Future<List<Map<String, dynamic>>> getTransactions(String userId) async {
    final data = await _supabase
        .from(SupabaseConfig.tableTransactionsWallet)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── Demander un retrait ──
  Future<void> demanderRetrait({
    required String userId,
    required double montant,
    required String mode,
    required String reference,
  }) async {
    final soldeActuel = await getSolde(userId);
    if (montant > soldeActuel) {
      throw const AppException('Solde insuffisant pour ce retrait');
    }

    // 1. Créer la transaction de débit (négative)
    await _supabase.from(SupabaseConfig.tableTransactionsWallet).insert({
      'user_id': userId,
      'type': 'retrait',
      'montant': -montant,
      'solde_avant': soldeActuel,
      'solde_apres': soldeActuel - montant,
      'reference': reference,
      'note': 'Retrait via $mode',
      'created_at': DateTime.now().toIso8601String(),
    });

    // 2. Mettre à jour le solde du wallet
    await _supabase
        .from(SupabaseConfig.tableWallets)
        .update({'solde': soldeActuel - montant})
        .eq('user_id', userId);
  }

  // ── Créditer le wallet (ex: après une course payée en ligne) ──
  Future<void> crediterWallet({
    required String userId,
    required double montant,
    required String reference,
    String? note,
  }) async {
    final soldeActuel = await getSolde(userId);

    await _supabase.from(SupabaseConfig.tableTransactionsWallet).insert({
      'user_id': userId,
      'type': 'gain',
      'montant': montant,
      'solde_avant': soldeActuel,
      'solde_apres': soldeActuel + montant,
      'reference': reference,
      'note': note ?? 'Gain de course',
      'created_at': DateTime.now().toIso8601String(),
    });

    await _supabase
        .from(SupabaseConfig.tableWallets)
        .update({'solde': soldeActuel + montant})
        .eq('user_id', userId);
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(Supabase.instance.client);
});
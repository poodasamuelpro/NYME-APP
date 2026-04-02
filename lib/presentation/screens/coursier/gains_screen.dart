import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/format_prix.dart';
import '../../../data/repositories/coursier_repository.dart';
import '../../widgets/common/widgets.dart';

// ─────────────────────────────────────────────────────────────
// Écran Gains & Portefeuille Coursier
// Route : /coursier/gains
// Fichier : lib/presentation/screens/coursier/gains_screen.dart
// Données réelles depuis Supabase : wallets + transactions_wallet
// ─────────────────────────────────────────────────────────────

class GainsScreen extends ConsumerStatefulWidget {
  const GainsScreen({super.key});

  @override
  ConsumerState<GainsScreen> createState() => _State();
}

class _State extends ConsumerState<GainsScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  String _userId = '';

  final _montantRetraitCtrl = TextEditingController();
  String _modeRetrait = 'mobile_money';
  final _numeroRetraitCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _charger();
  }

  @override
  void dispose() {
    _montantRetraitCtrl.dispose();
    _numeroRetraitCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(coursierRepositoryProvider);
      final stats = await repo.getStats(_userId);
      final transactions = await repo.getTransactions(_userId);
      setState(() {
        _stats = stats;
        _transactions = transactions;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _demanderRetrait() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.grisClair, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Retrait de gains', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Solde disponible : ${FormatPrix.fcfa(_stats?['solde_wallet'] ?? 0.0)}',
                  style: const TextStyle(color: AppColors.gris, fontSize: 13)),
              const SizedBox(height: 16),

              // Mode de retrait
              const Text('Mode de retrait', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ModeRetrait('Orange Money', 'mobile_money', _modeRetrait, (v) => setModal(() => _modeRetrait = v)),
                  const SizedBox(width: 8),
                  _ModeRetrait('Wave', 'wave', _modeRetrait, (v) => setModal(() => _modeRetrait = v)),
                  const SizedBox(width: 8),
                  _ModeRetrait('Moov', 'moov', _modeRetrait, (v) => setModal(() => _modeRetrait = v)),
                ],
              ),
              const SizedBox(height: 14),

              NymeTextField(
                controller: _numeroRetraitCtrl,
                label: 'Numéro Mobile Money',
                hint: '+226 70 00 00 00',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              NymeTextField(
                controller: _montantRetraitCtrl,
                label: 'Montant en FCFA',
                hint: '5000',
                prefixIcon: Icons.attach_money,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),

              NymeButton(
                label: 'Demander le retrait',
                onPressed: () async {
                  final montant = double.tryParse(_montantRetraitCtrl.text);
                  final numero = _numeroRetraitCtrl.text.trim();
                  if (montant == null || montant <= 0 || numero.isEmpty) {
                    Helpers.snackErreur(ctx, 'Remplissez tous les champs');
                    return;
                  }
                  try {
                    await ref.read(coursierRepositoryProvider).demanderRetrait(
                      coursierId: _userId,
                      montant: montant,
                      modePaiement: _modeRetrait,
                      numeroMobileMoney: numero,
                    );
                    Navigator.pop(ctx);
                    await _charger();
                    if (mounted) Helpers.snackSuccess(context, 'Demande de retrait envoyée !');
                  } catch (e) {
                    Helpers.snackErreur(ctx, e.toString());
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      appBar: AppBar(title: const Text('Gains & Portefeuille')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.bleuPrimaire))
          : RefreshIndicator(
              onRefresh: _charger,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Wallet principal
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: AppColors.succes.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        children: [
                          const Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(
                            FormatPrix.fcfa((_stats?['solde_wallet'] ?? 0.0).toDouble()),
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _demanderRetrait,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.succes,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.account_balance_outlined, size: 18),
                            label: const Text('Retirer mes gains', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    // Stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(child: _StatCard('Ce mois', FormatPrix.fcfa((_stats?['gains_mois'] ?? 0.0).toDouble()), Icons.calendar_today_outlined, AppColors.bleuPrimaire)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard('Total gagné', FormatPrix.fcfa((_stats?['total_gains'] ?? 0.0).toDouble()), Icons.savings_outlined, AppColors.orange)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard('Courses/mois', '${_stats?['courses_mois'] ?? 0}', Icons.delivery_dining, AppColors.succes)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Historique transactions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Historique', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.noir)),
                          Text('${_transactions.length} transaction(s)', style: const TextStyle(color: AppColors.gris, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_transactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('Aucune transaction pour le moment', style: TextStyle(color: AppColors.gris))),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _CarteTransaction(_transactions[i]),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String titre, valeur;
  final IconData icone;
  final Color couleur;
  const _StatCard(this.titre, this.valeur, this.icone, this.couleur);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 20),
          const SizedBox(height: 6),
          Text(valeur, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: couleur)),
          Text(titre, style: const TextStyle(fontSize: 11, color: AppColors.gris)),
        ],
      ),
    );
  }
}

class _CarteTransaction extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const _CarteTransaction(this.transaction);

  Color get _couleur {
    final type = transaction['type'] as String? ?? '';
    if (type == 'gain' || type == 'bonus') return AppColors.succes;
    if (type == 'retrait') return AppColors.erreur;
    return AppColors.gris;
  }

  IconData get _icone {
    final type = transaction['type'] as String? ?? '';
    if (type == 'gain') return Icons.arrow_downward;
    if (type == 'retrait') return Icons.arrow_upward;
    if (type == 'commission') return Icons.percent;
    if (type == 'bonus') return Icons.star;
    return Icons.swap_horiz;
  }

  String get _label {
    final type = transaction['type'] as String? ?? '';
    switch (type) {
      case 'gain': return 'Gain de livraison';
      case 'retrait': return 'Retrait';
      case 'commission': return 'Commission NYME';
      case 'bonus': return 'Bonus';
      default: return 'Transaction';
    }
  }

  @override
  Widget build(BuildContext context) {
    final montant = (transaction['montant'] as num?)?.toDouble() ?? 0;
    final isPositif = montant >= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blanc,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppColors.ombre, blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _couleur.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(_icone, color: _couleur, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                if (transaction['created_at'] != null)
                  Text(
                    Helpers.dateRelative(DateTime.parse(transaction['created_at'])),
                    style: const TextStyle(color: AppColors.grisClair, fontSize: 12),
                  ),
              ],
            ),
          ),
          Text(
            '${isPositif ? '+' : ''}${FormatPrix.fcfa(montant.abs())}',
            style: TextStyle(fontWeight: FontWeight.bold, color: _couleur, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ModeRetrait extends StatelessWidget {
  final String label, value, selected;
  final void Function(String) onTap;
  const _ModeRetrait(this.label, this.value, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppColors.bleuPrimaire : AppColors.fondInput,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: sel ? Colors.white : AppColors.gris, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/wallet_model.dart';
import '../../../domain/usecases/wallet_usecases.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format_prix.dart';
import '../../widgets/common/nyme_button.dart';

class GainsScreen extends ConsumerStatefulWidget {
  const GainsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GainsScreen> createState() => _GainsScreenState();
}

class _GainsScreenState extends ConsumerState<GainsScreen> {
  bool _isLoading = false;
  DateTime? _lastWithdrawalDate;

  @override
  void initState() {
    super.initState();
    _checkLastWithdrawalDate();
  }

  Future<void> _checkLastWithdrawalDate() async {
    // À implémenter: récupérer la date du dernier retrait depuis la base de données
    // Pour l'exemple, nous utilisons une date fictive
    setState(() {
      _lastWithdrawalDate = DateTime.now().subtract(const Duration(days: 3));
    });
  }

  bool _canWithdraw() {
    if (_lastWithdrawalDate == null) return true;
    final daysSinceLastWithdrawal = DateTime.now().difference(_lastWithdrawalDate!).inDays;
    return daysSinceLastWithdrawal >= 2;
  }

  String _getWithdrawalMessage() {
    if (_canWithdraw()) {
      return 'Vous pouvez retirer vos fonds maintenant';
    }
    final daysSinceLastWithdrawal = DateTime.now().difference(_lastWithdrawalDate!).inDays;
    final daysRemaining = 2 - daysSinceLastWithdrawal;
    return 'Prochain retrait disponible dans $daysRemaining jour(s)';
  }

  Future<void> _demanderRetrait() async {
    if (!_canWithdraw()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getWithdrawalMessage())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = ref.read(userIdProvider); // À implémenter
      final walletUseCases = ref.read(walletUseCasesProvider);

      final solde = await walletUseCases.getSolde(userId);

      if (solde <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Votre solde est insuffisant pour un retrait')),
        );
        return;
      }

      // Afficher une confirmation avant le retrait
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmer le retrait'),
          content: Text('Êtes-vous sûr de vouloir retirer ${formatPrix(solde)} FCFA?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await walletUseCases.demanderRetrait(
        userId: userId,
        montant: solde,
        reference: 'RETRAIT_${DateTime.now().millisecondsSinceEpoch}',
        note: 'Demande de retrait de fonds',
      );

      setState(() {
        _lastWithdrawalDate = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande de retrait effectuée avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Gains'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Affichage du solde
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Column(
                children: [
                  const Text(
                    'Solde disponible',
                    style: TextStyle(color: Colors.white, fontSize: 14.0),
                  ),
                  const SizedBox(height: 8.0),
                  Consumer(
                    builder: (context, ref, child) {
                      final walletUseCases = ref.watch(walletUseCasesProvider);
                      return FutureBuilder<double>(
                        future: walletUseCases.getSolde('user_id'), // À remplacer par l'ID utilisateur réel
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator(color: Colors.white);
                          }
                          if (snapshot.hasError) {
                            return Text(
                              'Erreur: ${snapshot.error}',
                              style: const TextStyle(color: Colors.white),
                            );
                          }
                          final solde = snapshot.data ?? 0.0;
                          return Text(
                            formatPrix(solde),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32.0,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // Statut du retrait
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: _canWithdraw() ? Colors.green[100] : Colors.orange[100],
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: _canWithdraw() ? Colors.green : Colors.orange,
                ),
              ),
              child: Text(
                _getWithdrawalMessage(),
                style: TextStyle(
                  color: _canWithdraw() ? Colors.green[900] : Colors.orange[900],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // Bouton de retrait
            NymeButton(
              label: 'Demander un retrait',
              onPressed: _isLoading ? null : _demanderRetrait,
              isLoading: _isLoading,
              backgroundColor: _canWithdraw() ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(height: 24.0),

            // Historique des transactions
            Text(
              'Historique des transactions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12.0),
            Consumer(
              builder: (context, ref, child) {
                final walletUseCases = ref.watch(walletUseCasesProvider);
                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: walletUseCases.getTransactions('user_id'), // À remplacer par l'ID utilisateur réel
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('Erreur: ${snapshot.error}');
                    }
                    final transactions = snapshot.data ?? [];
                    if (transactions.isEmpty) {
                      return const Center(child: Text('Aucune transaction'));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        final isGain = transaction['montant'] > 0;
                        return ListTile(
                          title: Text(transaction['type'] ?? 'Transaction'),
                          subtitle: Text(transaction['note'] ?? ''),
                          trailing: Text(
                            '${isGain ? '+' : ''}${formatPrix(transaction['montant'])}',
                            style: TextStyle(
                              color: isGain ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Provider pour l'ID utilisateur (à adapter selon votre implémentation d'authentification)
final userIdProvider = Provider<String>((ref) {
  // À remplacer par votre logique d'authentification réelle
  return 'user_id';
});

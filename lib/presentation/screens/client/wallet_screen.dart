import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/wallet_model.dart';
import '../../../domain/usecases/wallet_usecases.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/format_prix.dart';
import '../../widgets/common/nyme_button.dart';
import '../../widgets/common/nyme_text_field.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  late TextEditingController _montantController;
  String _selectedPaymentMethod = 'mobile_money'; // 'mobile_money', 'carte', 'wallet'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _montantController = TextEditingController();
  }

  @override
  void dispose() {
    _montantController.dispose();
    super.dispose();
  }

  Future<void> _rechargerWallet() async {
    final montant = double.tryParse(_montantController.text);
    if (montant == null || montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un montant valide')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = ref.read(userIdProvider); // À implémenter
      final walletUseCases = ref.read(walletUseCasesProvider);

      await walletUseCases.rechargerWallet(
        userId: userId,
        montant: montant,
        reference: 'RECHARGE_${DateTime.now().millisecondsSinceEpoch}',
        note: 'Recharge via $_selectedPaymentMethod',
      );

      _montantController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recharge effectuée avec succès')),
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
        title: const Text('Mon Portefeuille'),
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

            // Section de recharge
            Text(
              'Recharger votre portefeuille',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12.0),

            // Champ de montant
            NymeTextField(
              controller: _montantController,
              label: 'Montant (FCFA)',
              keyboardType: TextInputType.number,
              prefixIcon: Icons.attach_money,
            ),
            const SizedBox(height: 12.0),

            // Sélection du mode de paiement
            Text(
              'Mode de paiement',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8.0),
            DropdownButton<String>(
              value: _selectedPaymentMethod,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                DropdownMenuItem(value: 'carte', child: Text('Carte Bancaire')),
              ],
              onChanged: (value) {
                setState(() => _selectedPaymentMethod = value ?? 'mobile_money');
              },
            ),
            const SizedBox(height: 16.0),

            // Bouton de recharge
            NymeButton(
              label: 'Recharger',
              onPressed: _isLoading ? null : _rechargerWallet,
              isLoading: _isLoading,
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
                        return ListTile(
                          title: Text(transaction['type'] ?? 'Transaction'),
                          subtitle: Text(transaction['note'] ?? ''),
                          trailing: Text(
                            '${transaction['montant'] > 0 ? '+' : ''}${formatPrix(transaction['montant'])}',
                            style: TextStyle(
                              color: transaction['montant'] > 0 ? Colors.green : Colors.red,
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

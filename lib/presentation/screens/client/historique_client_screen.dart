import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/format_prix.dart';
import '../../../data/repositories/livraison_repository.dart';
import '../../../data/models/models.dart';
import '../../../config/router.dart';
import '../../widgets/common/widgets.dart';

// ─────────────────────────────────────────────────────────────
// Écran Historique Client
// Route : /client/historique
// Fichier : lib/presentation/screens/client/historique_client_screen.dart
// Affiche toutes les livraisons passées avec filtres
// ─────────────────────────────────────────────────────────────

class HistoriqueClientScreen extends ConsumerStatefulWidget {
  const HistoriqueClientScreen({super.key});

  @override
  ConsumerState<HistoriqueClientScreen> createState() => _State();
}

class _State extends ConsumerState<HistoriqueClientScreen> {
  List<LivraisonModel> _livraisons = [];
  List<LivraisonModel> _filtrees = [];
  bool _loading = true;
  String _filtre = 'toutes'; // toutes, en_cours, livrees, annulees

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _loading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final data = await ref.read(livraisonRepositoryProvider).getLivraisonsClient(userId);
      setState(() {
        _livraisons = data;
        _appliquerFiltre();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _appliquerFiltre() {
    switch (_filtre) {
      case 'en_cours':
        _filtrees = _livraisons.where((l) =>
          l.statut != StatutLivraison.livree && l.statut != StatutLivraison.annulee
        ).toList();
        break;
      case 'livrees':
        _filtrees = _livraisons.where((l) => l.statut == StatutLivraison.livree).toList();
        break;
      case 'annulees':
        _filtrees = _livraisons.where((l) => l.statut == StatutLivraison.annulee).toList();
        break;
      default:
        _filtrees = List.from(_livraisons);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      appBar: AppBar(title: const Text('Mes livraisons')),
      body: Column(
        children: [
          // Filtres
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _Filtre('Toutes', 'toutes', _livraisons.length, _filtre, (v) {
                  setState(() => _filtre = v);
                  _appliquerFiltre();
                }),
                const SizedBox(width: 8),
                _Filtre('En cours', 'en_cours',
                  _livraisons.where((l) => l.statut != StatutLivraison.livree && l.statut != StatutLivraison.annulee).length,
                  _filtre, (v) { setState(() => _filtre = v); _appliquerFiltre(); }),
                const SizedBox(width: 8),
                _Filtre('Livrées', 'livrees',
                  _livraisons.where((l) => l.statut == StatutLivraison.livree).length,
                  _filtre, (v) { setState(() => _filtre = v); _appliquerFiltre(); }),
                const SizedBox(width: 8),
                _Filtre('Annulées', 'annulees',
                  _livraisons.where((l) => l.statut == StatutLivraison.annulee).length,
                  _filtre, (v) { setState(() => _filtre = v); _appliquerFiltre(); }),
              ],
            ),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.bleuPrimaire))
                : _filtrees.isEmpty
                    ? _Vide(filtre: _filtre)
                    : RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtrees.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _CarteLivraison(
                            livraison: _filtrees[i],
                            onTap: () => context.push('/client/detail/${_filtrees[i].id}'),
                            onSuivre: _filtrees[i].statut != StatutLivraison.livree &&
                                      _filtrees[i].statut != StatutLivraison.annulee
                                ? () => context.push('/client/suivi/${_filtrees[i].id}')
                                : null,
                            onReclamer: () => context.push('/reclamation?livraison=${_filtrees[i].id}'),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Carte d'une livraison ──
class _CarteLivraison extends StatelessWidget {
  final LivraisonModel livraison;
  final VoidCallback onTap;
  final VoidCallback? onSuivre;
  final VoidCallback onReclamer;

  const _CarteLivraison({
    required this.livraison,
    required this.onTap,
    this.onSuivre,
    required this.onReclamer,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.blanc,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.ombre, blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${livraison.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.bleuPrimaire, fontSize: 13),
                ),
                StatutBadge(statut: livraison.statut.name),
              ],
            ),
            const SizedBox(height: 10),

            // Itinéraire
            Row(
              children: [
                Column(
                  children: [
                    const Icon(Icons.radio_button_checked, color: AppColors.orange, size: 16),
                    Container(width: 1, height: 16, color: AppColors.grisClair),
                    const Icon(Icons.location_on, color: AppColors.erreur, size: 16),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        livraison.departAdresse,
                        style: const TextStyle(fontSize: 13, color: AppColors.gris),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        livraison.arriveeAdresse,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.noir),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Helpers.dateRelative(livraison.createdAt),
                        style: const TextStyle(color: AppColors.grisClair, fontSize: 12)),
                    if (livraison.prixFinal != null)
                      Text(FormatPrix.fcfa(livraison.prixFinal!),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.bleuPrimaire, fontSize: 14)),
                  ],
                ),
                Row(
                  children: [
                    if (onSuivre != null)
                      GestureDetector(
                        onTap: onSuivre,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.bleuPrimaire,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Suivre', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    if (livraison.statut == StatutLivraison.livree) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onReclamer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Réclamation', style: TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Filtre extends StatelessWidget {
  final String label;
  final String value;
  final int count;
  final String selected;
  final void Function(String) onTap;

  const _Filtre(this.label, this.value, this.count, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.bleuPrimaire : AppColors.blanc,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.bleuPrimaire : AppColors.grisClair),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.gris, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: sel ? Colors.white.withOpacity(0.2) : AppColors.fondInput,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(color: sel ? Colors.white : AppColors.gris, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  final String filtre;
  const _Vide({required this.filtre});

  @override
  Widget build(BuildContext context) {
    final messages = {
      'toutes': 'Aucune livraison pour le moment\nCommandez votre première livraison !',
      'en_cours': 'Aucune livraison en cours',
      'livrees': 'Aucune livraison livrée',
      'annulees': 'Aucune livraison annulée',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.grisClair),
          const SizedBox(height: 16),
          Text(
            messages[filtre] ?? 'Aucune livraison',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gris, fontSize: 15),
          ),
        ],
      ),
    );
  }
}


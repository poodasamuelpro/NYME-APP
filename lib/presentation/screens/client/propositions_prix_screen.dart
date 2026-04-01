import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/format_prix.dart';
import '../../../data/repositories/livraison_repository.dart';
import '../../../data/repositories/coursier_repository.dart';
import '../../../data/models/models.dart';
import '../../../services/notification_service.dart';
import '../../../config/router.dart';
import '../../widgets/common/widgets.dart';

// ─────────────────────────────────────────────────────────────
// Écran Propositions de Prix — style InDrive
// Le client voit les offres des coursiers en temps réel
// et peut accepter ou contre-proposer
// ─────────────────────────────────────────────────────────────

class PropositionsPrixScreen extends ConsumerStatefulWidget {
  final String livraisonId;
  const PropositionsPrixScreen({super.key, required this.livraisonId});

  @override
  ConsumerState<PropositionsPrixScreen> createState() => _State();
}

class _State extends ConsumerState<PropositionsPrixScreen> {
  LivraisonModel? _livraison;
  List<PropositionPrixModel> _propositions = [];
  bool _loading = true;
  bool _enAttente = true;
  dynamic _channelProps;
  final _monPrixCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _charger();
    _ecouterPropositions();
  }

  @override
  void dispose() {
    _monPrixCtrl.dispose();
    // TODO: unsubscribe channel
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final liv = await ref.read(livraisonRepositoryProvider).getLivraison(widget.livraisonId);
      final props = await ref.read(livraisonRepositoryProvider).getPropositions(widget.livraisonId);
      setState(() { _livraison = liv; _propositions = props; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _ecouterPropositions() {
    _channelProps = ref.read(livraisonRepositoryProvider).ecouterPropositions(
      livraisonId: widget.livraisonId,
      onNouvelle: (prop) {
        setState(() => _propositions.insert(0, prop));
        Helpers.snackInfo(context, '🏍️ Nouveau coursier a proposé ${FormatPrix.fcfa(prop.montant)}');
      },
    );
  }

  Future<void> _accepterProposition(PropositionPrixModel prop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accepter cette offre ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Coursier : ${prop.auteur?.nom ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Prix : ${FormatPrix.fcfa(prop.montant)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.bleuPrimaire)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.bleuPrimaire),
            child: const Text('Accepter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref.read(livraisonRepositoryProvider).accepterProposition(prop.id);
      await ref.read(livraisonRepositoryProvider).assignerCoursier(
        livraisonId: widget.livraisonId,
        coursierId: prop.auteurId,
        prixFinal: prop.montant,
      );

      // Notifier le coursier
      await NotificationService.envoyerPush(
        destinataireId: prop.auteurId,
        titre: 'Course acceptée ! 🎉',
        corps: 'Votre offre de ${FormatPrix.fcfa(prop.montant)} a été acceptée.',
        data: {'livraison_id': widget.livraisonId, 'type': 'course_acceptee'},
      );

      if (!mounted) return;
      Helpers.snackSuccess(context, 'Coursier assigné !');
      context.go('/client/suivi/${widget.livraisonId}');
    } catch (e) {
      Helpers.snackErreur(context, e.toString());
    }
  }

  Future<void> _proposerMonPrix() async {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grisClair, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Proposer votre prix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Les coursiers verront votre offre et pourront l\'accepter', style: TextStyle(color: AppColors.gris, fontSize: 13)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: NymeTextField(
                    controller: _monPrixCtrl,
                    label: 'Mon prix en FCFA',
                    hint: '${_livraison?.prixCalcule.toInt() ?? 0}',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.attach_money,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.fondInput, borderRadius: BorderRadius.circular(12)),
                  child: const Text('FCFA', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gris)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            NymeButton(
              label: 'Envoyer mon prix',
              onPressed: () async {
                final montant = double.tryParse(_monPrixCtrl.text);
                if (montant == null || montant <= 0) {
                  Helpers.snackErreur(context, 'Entrez un montant valide');
                  return;
                }
                Navigator.pop(context);
                // TODO: prop.auteurId = currentUser
                await ref.read(livraisonRepositoryProvider).proposerPrix(
                  livraisonId: widget.livraisonId,
                  auteurId: 'CURRENT_USER_ID',
                  roleAuteur: 'client',
                  montant: montant,
                );
                Helpers.snackSuccess(context, 'Prix proposé aux coursiers !');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _annuler() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la livraison ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Garder')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Annuler', style: TextStyle(color: AppColors.erreur))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(livraisonRepositoryProvider).annulerLivraison(widget.livraisonId);
      if (mounted) context.go(AppRoutes.clientHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      appBar: AppBar(
        title: const Text('Trouver un coursier'),
        actions: [
          TextButton(
            onPressed: _annuler,
            child: const Text('Annuler', style: TextStyle(color: AppColors.erreur)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.bleuPrimaire))
          : Column(
              children: [
                // Prix calculé par l'app
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.bleuPrimaire, AppColors.bleuFonce]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text('Prix estimé par NYME', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        FormatPrix.fcfa(_livraison?.prixCalcule ?? 0),
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Flexible(child: Text(
                            '${_livraison?.departAdresse ?? ''} → ${_livraison?.arriveeAdresse ?? ''}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          )),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status attente
                if (_propositions.isEmpty) ...[
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.bleuPrimaire),
                        ),
                        SizedBox(height: 20),
                        Text('Recherche de coursiers...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.noir)),
                        SizedBox(height: 8),
                        Text('Les coursiers proches vont voir votre demande', style: TextStyle(color: AppColors.gris), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_propositions.length} offre(s)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        TextButton.icon(
                          onPressed: _proposerMonPrix,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Proposer mon prix'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _propositions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _CarteProposition(
                        proposition: _propositions[i],
                        prixApp: _livraison?.prixCalcule ?? 0,
                        onAccepter: () => _accepterProposition(_propositions[i]),
                      ),
                    ),
                  ),
                ],

                // Bouton proposer son prix
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SafeArea(
                    top: false,
                    child: NymeButton(
                      label: 'Proposer mon propre prix',
                      onPressed: _proposerMonPrix,
                      outlined: true,
                      icon: Icons.price_change_outlined,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CarteProposition extends StatelessWidget {
  final PropositionPrixModel proposition;
  final double prixApp;
  final VoidCallback onAccepter;

  const _CarteProposition({required this.proposition, required this.prixApp, required this.onAccepter});

  Color get _couleurPrix {
    if (proposition.montant < prixApp) return AppColors.succes;
    if (proposition.montant > prixApp * 1.2) return AppColors.erreur;
    return AppColors.bleuPrimaire;
  }

  String get _comparaison {
    final diff = ((proposition.montant - prixApp) / prixApp * 100).round();
    if (diff < 0) return '${diff}% moins cher';
    if (diff > 0) return '+$diff% par rapport au prix NYME';
    return 'Prix NYME';
  }

  @override
  Widget build(BuildContext context) {
    final coursier = proposition.auteur;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blanc,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.ombre, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Avatar coursier
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.fondInput,
            backgroundImage: coursier?.avatarUrl != null ? NetworkImage(coursier!.avatarUrl!) : null,
            child: coursier?.avatarUrl == null
                ? Text(Helpers.initiales(coursier?.nom ?? '?'), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.bleuPrimaire))
                : null,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(coursier?.nom ?? 'Coursier', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 6),
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    Text(' ${coursier?.noteMoyenne.toStringAsFixed(1) ?? '0.0'}', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  Helpers.tempsEcoule(proposition.createdAt),
                  style: const TextStyle(color: AppColors.grisClair, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(_comparaison, style: TextStyle(color: _couleurPrix, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                FormatPrix.fcfa(proposition.montant),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _couleurPrix),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onAccepter,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bleuPrimaire,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Choisir', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/format_prix.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/livraison_repository.dart';
import '../../widgets/common/widgets.dart';

class DetailLivraisonScreen extends ConsumerStatefulWidget {
  final String livraisonId;
  const DetailLivraisonScreen({super.key, required this.livraisonId});

  @override
  ConsumerState<DetailLivraisonScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<DetailLivraisonScreen> {
  LivraisonModel? _livraison;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final liv = await ref.read(livraisonRepositoryProvider).getLivraison(widget.livraisonId);
    setState(() { _livraison = liv; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      appBar: AppBar(title: Text('Livraison ${widget.livraisonId.substring(0, 8).toUpperCase()}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.bleuPrimaire))
          : _livraison == null
              ? const Center(child: Text('Livraison introuvable'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Statut
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Helpers.couleurStatut(_livraison!.statut.name).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Helpers.couleurStatut(_livraison!.statut.name).withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(Helpers.emojiStatut(_livraison!.statut.name), style: const TextStyle(fontSize: 36)),
                            const SizedBox(height: 8),
                            StatutBadge(statut: _livraison!.statut.name),
                            const SizedBox(height: 4),
                            Text(Helpers.dateRelative(_livraison!.createdAt), style: const TextStyle(color: AppColors.gris, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Itinéraire
                      _Section(
                        titre: '📍 Itinéraire',
                        enfants: [
                          _LignDetail('Départ', _livraison!.departAdresse, Icons.radio_button_checked, AppColors.orange),
                          _LignDetail('Destination', _livraison!.arriveeAdresse, Icons.location_on, AppColors.erreur),
                          if (_livraison!.distanceKm != null)
                            _LignDetail('Distance', '${_livraison!.distanceKm!.toStringAsFixed(1)} km', Icons.straighten, AppColors.bleuPrimaire),
                          if (_livraison!.dureeEstimee != null)
                            _LignDetail('Durée estimée', '${_livraison!.dureeEstimee} min', Icons.timer_outlined, AppColors.bleuPrimaire),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Destinataire
                      _Section(
                        titre: '👤 Destinataire',
                        enfants: [
                          _LignDetail('Nom', _livraison!.destinataireNom, Icons.person_outline, AppColors.bleuPrimaire),
                          _LignDetail('Téléphone', _livraison!.destinataireTel, Icons.phone_outlined, AppColors.bleuPrimaire),
                          if (_livraison!.destinataireWhatsapp != null)
                            _LignDetail('WhatsApp', _livraison!.destinataireWhatsapp!, Icons.chat_outlined, AppColors.succes),
                          if (_livraison!.instructions != null)
                            _LignDetail('Instructions', _livraison!.instructions!, Icons.info_outline, AppColors.orange),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Prix & Paiement
                      _Section(
                        titre: '💰 Prix & Paiement',
                        enfants: [
                          _LignDetail('Prix calculé', FormatPrix.fcfa(_livraison!.prixCalcule), Icons.calculate_outlined, AppColors.bleuPrimaire),
                          if (_livraison!.prixFinal != null)
                            _LignDetail('Prix final', FormatPrix.fcfa(_livraison!.prixFinal!), Icons.check_circle_outline, AppColors.succes),
                          _LignDetail('Paiement', _livraison!.statutPaiement.name, Icons.payment_outlined, AppColors.bleuPrimaire),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Coursier
                      if (_livraison!.coursier != null) ...[
                        _Section(
                          titre: '🏍️ Coursier',
                          enfants: [
                            _LignDetail('Nom', _livraison!.coursier!.nom, Icons.person_outline, AppColors.bleuPrimaire),
                            _LignDetail('Téléphone', _livraison!.coursier!.telephone, Icons.phone_outlined, AppColors.bleuPrimaire),
                            _LignDetail('Note', '⭐ ${_livraison!.coursier!.noteMoyenne.toStringAsFixed(1)}', Icons.star_outline, Colors.amber),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Photos du colis
                      if (_livraison!.photosColis.isNotEmpty) ...[
                        _Section(
                          titre: '📸 Photos du colis',
                          enfants: [
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                              itemCount: _livraison!.photosColis.length,
                              itemBuilder: (_, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(_livraison!.photosColis[i], fit: BoxFit.cover),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Bouton suivi si en cours
                      if (_livraison!.statut != StatutLivraison.livree && _livraison!.statut != StatutLivraison.annulee)
                        NymeButton(
                          label: 'Voir le suivi en direct',
                          onPressed: () => context.push('/client/suivi/${widget.livraisonId}'),
                          icon: Icons.map_outlined,
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titre;
  final List<Widget> enfants;
  const _Section({required this.titre, required this.enfants});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blanc,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.ombre, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.noir)),
          const SizedBox(height: 12),
          ...enfants,
        ],
      ),
    );
  }
}

class _LignDetail extends StatelessWidget {
  final String label, valeur;
  final IconData icone;
  final Color couleur;
  const _LignDetail(this.label, this.valeur, this.icone, this.couleur);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icone, color: couleur, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.gris, fontSize: 12)),
                Text(valeur, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.noir)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
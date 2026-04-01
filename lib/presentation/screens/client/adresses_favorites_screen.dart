import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/repositories/adresses_repository.dart';
import '../../../data/models/models.dart';
import '../../widgets/common/widgets.dart';

// ─────────────────────────────────────────────────────────────
// Écran Adresses Favorites
// Table : adresses_favorites
// ─────────────────────────────────────────────────────────────

class AdressesFavoritesScreen extends ConsumerStatefulWidget {
  final void Function(AdresseFavoriteModel)? onSelectionner;
  const AdressesFavoritesScreen({super.key, this.onSelectionner});

  @override
  ConsumerState<AdressesFavoritesScreen> createState() => _State();
}

class _State extends ConsumerState<AdressesFavoritesScreen> {
  List<AdresseFavoriteModel> _adresses = [];
  bool _loading = true;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final repo = ref.read(adressesRepositoryProvider);
      // TODO: remplacer par currentUserId depuis authProvider
      final data = await repo.getAdresses(_userId);
      setState(() { _adresses = data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _ajouterAdresse() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormulaireAdresse(
        onSauvegarder: (label, adresse, lat, lng, defaut) async {
          await ref.read(adressesRepositoryProvider).ajouterAdresse(
            userId: _userId,
            label: label,
            adresse: adresse,
            latitude: lat,
            longitude: lng,
            estDefaut: defaut,
          );
          await _charger();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _definirDefaut(AdresseFavoriteModel adresse) async {
    await ref.read(adressesRepositoryProvider).definirDefaut(
      adresseId: adresse.id,
      userId: _userId,
    );
    await _charger();
    if (mounted) Helpers.snackSuccess(context, 'Adresse définie par défaut');
  }

  Future<void> _supprimer(AdresseFavoriteModel adresse) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer "${adresse.label}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.erreur)),
          ),
        ],
      ),
    );
    if (confirme == true) {
      await ref.read(adressesRepositoryProvider).supprimerAdresse(adresse.id);
      await _charger();
      if (mounted) Helpers.snackSuccess(context, 'Adresse supprimée');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      appBar: AppBar(
        title: const Text('Adresses favorites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _ajouterAdresse,
            tooltip: 'Ajouter une adresse',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.bleuPrimaire))
          : _adresses.isEmpty
              ? _Vide(onAjouter: _ajouterAdresse)
              : RefreshIndicator(
                  onRefresh: _charger,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _adresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _CarteAdresse(
                      adresse: _adresses[i],
                      onTap: widget.onSelectionner != null
                          ? () {
                              widget.onSelectionner!(_adresses[i]);
                              Navigator.pop(context);
                            }
                          : null,
                      onDefaut: () => _definirDefaut(_adresses[i]),
                      onSupprimer: () => _supprimer(_adresses[i]),
                    ),
                  ),
                ),
      floatingActionButton: _adresses.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _ajouterAdresse,
              backgroundColor: AppColors.bleuPrimaire,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Ajouter', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}

// ── Carte d'une adresse ──
class _CarteAdresse extends StatelessWidget {
  final AdresseFavoriteModel adresse;
  final VoidCallback? onTap;
  final VoidCallback onDefaut;
  final VoidCallback onSupprimer;

  const _CarteAdresse({
    required this.adresse,
    this.onTap,
    required this.onDefaut,
    required this.onSupprimer,
  });

  IconData get _icone {
    final label = adresse.label.toLowerCase();
    if (label.contains('maison') || label.contains('home')) return Icons.home_outlined;
    if (label.contains('bureau') || label.contains('travail')) return Icons.business_outlined;
    if (label.contains('maman') || label.contains('papa') || label.contains('famille')) return Icons.family_restroom;
    return Icons.location_on_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.blanc,
          borderRadius: BorderRadius.circular(16),
          border: adresse.estDefaut
              ? Border.all(color: AppColors.bleuPrimaire, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: AppColors.ombre,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.bleuPrimaire.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icone, color: AppColors.bleuPrimaire, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        adresse.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.noir,
                        ),
                      ),
                      if (adresse.estDefaut) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bleuPrimaire,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Défaut',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adresse.adresse,
                    style: const TextStyle(color: AppColors.gris, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.gris),
              onSelected: (v) {
                if (v == 'defaut') onDefaut();
                if (v == 'supprimer') onSupprimer();
              },
              itemBuilder: (_) => [
                if (!adresse.estDefaut)
                  const PopupMenuItem(value: 'defaut', child: Text('Définir par défaut')),
                const PopupMenuItem(
                  value: 'supprimer',
                  child: Text('Supprimer', style: TextStyle(color: AppColors.erreur)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── État vide ──
class _Vide extends StatelessWidget {
  final VoidCallback onAjouter;
  const _Vide({required this.onAjouter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.fondInput,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.location_on_outlined, size: 48, color: AppColors.grisClair),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucune adresse favorite',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.noir),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoutez vos adresses fréquentes\npour commander plus vite',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gris),
            ),
            const SizedBox(height: 24),
            NymeButton(label: 'Ajouter une adresse', onPressed: onAjouter, icon: Icons.add),
          ],
        ),
      ),
    );
  }
}

// ── Formulaire ajout adresse ──
class _FormulaireAdresse extends StatefulWidget {
  final Future<void> Function(String label, String adresse, double lat, double lng, bool defaut) onSauvegarder;
  const _FormulaireAdresse({required this.onSauvegarder});

  @override
  State<_FormulaireAdresse> createState() => _FormulaireAdresseState();
}

class _FormulaireAdresseState extends State<_FormulaireAdresse> {
  final _labelCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  bool _defaut = false;
  bool _loading = false;

  final List<String> _labelsRapides = ['🏠 Maison', '💼 Bureau', '👨‍👩‍👧 Famille', '🏪 Boutique'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poignée
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.grisClair, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Nouvelle adresse', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Labels rapides
            Wrap(
              spacing: 8,
              children: _labelsRapides.map((l) => ActionChip(
                label: Text(l),
                onPressed: () => _labelCtrl.text = l.replaceAll(RegExp(r'[^\w\s]'), '').trim(),
                backgroundColor: AppColors.fondInput,
              )).toList(),
            ),
            const SizedBox(height: 12),

            NymeTextField(controller: _labelCtrl, label: 'Nom du lieu', hint: 'Ex: Maison, Bureau...', prefixIcon: Icons.label_outline),
            const SizedBox(height: 12),
            NymeTextField(controller: _adresseCtrl, label: 'Adresse complète', hint: 'Secteur 10, Ouagadougou', prefixIcon: Icons.location_on_outlined, maxLines: 2),
            const SizedBox(height: 12),

            // Définir par défaut
            SwitchListTile.adaptive(
              title: const Text('Adresse par défaut'),
              subtitle: const Text('Utilisée automatiquement au départ'),
              value: _defaut,
              onChanged: (v) => setState(() => _defaut = v),
              activeColor: AppColors.bleuPrimaire,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            NymeButton(
              label: 'Enregistrer',
              loading: _loading,
              onPressed: () async {
                if (_labelCtrl.text.isEmpty || _adresseCtrl.text.isEmpty) {
                  Helpers.snackErreur(context, 'Remplissez tous les champs');
                  return;
                }
                setState(() => _loading = true);
                // TODO: géocoder l'adresse pour obtenir lat/lng réelles
                // Pour l'instant on utilise des coordonnées de Ouagadougou par défaut
                await widget.onSauvegarder(
                  _labelCtrl.text.trim(),
                  _adresseCtrl.text.trim(),
                  12.3569, // lat Ouagadougou par défaut
                  -1.5353, // lng Ouagadougou par défaut
                  _defaut,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


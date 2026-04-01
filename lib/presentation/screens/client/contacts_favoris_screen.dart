import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/repositories/adresses_repository.dart';
import '../../widgets/common/widgets.dart';

// ─────────────────────────────────────────────────────────────
// Écran Contacts Favoris
// Table : contacts_favoris
// Permet de sauvegarder des destinataires fréquents
// ─────────────────────────────────────────────────────────────

class ContactsFavorisScreen extends ConsumerStatefulWidget {
  final void Function(Map<String, dynamic>)? onSelectionner;
  const ContactsFavorisScreen({super.key, this.onSelectionner});

  @override
  ConsumerState<ContactsFavorisScreen> createState() => _State();
}

class _State extends ConsumerState<ContactsFavorisScreen> {
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filtres = [];
  bool _loading = true;
  String _userId = '';
  final _rechercheCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _charger();
    _rechercheCtrl.addListener(_filtrer);
  }

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final data = await ref.read(adressesRepositoryProvider).getContacts(_userId);
      setState(() { _contacts = data; _filtres = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _filtrer() {
    final q = _rechercheCtrl.text.toLowerCase();
    setState(() {
      _filtres = _contacts.where((c) {
        return c['nom'].toString().toLowerCase().contains(q) ||
            c['telephone'].toString().contains(q);
      }).toList();
    });
  }

  Future<void> _ajouterContact() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormulaireContact(
        onSauvegarder: (nom, tel, whatsapp, email) async {
          await ref.read(adressesRepositoryProvider).ajouterContact(
            userId: _userId,
            nom: nom,
            telephone: tel,
            whatsapp: whatsapp,
            email: email,
          );
          await _charger();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _supprimer(Map<String, dynamic> contact) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer "${contact['nom']}" de vos contacts ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.erreur)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(adressesRepositoryProvider).supprimerContact(contact['id']);
      await _charger();
      if (mounted) Helpers.snackSuccess(context, 'Contact supprimé');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      appBar: AppBar(
        title: const Text('Contacts favoris'),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_outlined), onPressed: _ajouterContact),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _rechercheCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher un contact...',
                prefixIcon: const Icon(Icons.search, color: AppColors.gris),
                filled: true,
                fillColor: AppColors.blanc,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.bleuPrimaire))
                : _contacts.isEmpty
                    ? _Vide(onAjouter: _ajouterContact)
                    : _filtres.isEmpty
                        ? const Center(child: Text('Aucun résultat', style: TextStyle(color: AppColors.gris)))
                        : RefreshIndicator(
                            onRefresh: _charger,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filtres.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => _CarteContact(
                                contact: _filtres[i],
                                onTap: widget.onSelectionner != null
                                    ? () {
                                        widget.onSelectionner!(_filtres[i]);
                                        Navigator.pop(context);
                                      }
                                    : null,
                                onAppeler: () => Helpers.ouvrirTelephone(_filtres[i]['telephone']),
                                onWhatsApp: () => Helpers.ouvrirWhatsApp(
                                  _filtres[i]['whatsapp'] ?? _filtres[i]['telephone'],
                                  message: 'Bonjour, je vous envoie un colis via NYME !',
                                ),
                                onSupprimer: () => _supprimer(_filtres[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: _contacts.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _ajouterContact,
              backgroundColor: AppColors.bleuPrimaire,
              icon: const Icon(Icons.person_add_outlined, color: Colors.white),
              label: const Text('Ajouter', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}

class _CarteContact extends StatelessWidget {
  final Map<String, dynamic> contact;
  final VoidCallback? onTap;
  final VoidCallback onAppeler;
  final VoidCallback onWhatsApp;
  final VoidCallback onSupprimer;

  const _CarteContact({
    required this.contact,
    this.onTap,
    required this.onAppeler,
    required this.onWhatsApp,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blanc,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.ombre, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Avatar initiales
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.bleuPrimaire.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                Helpers.initiales(contact['nom'] ?? '?'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.bleuPrimaire,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact['nom'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.noir),
                  ),
                  const SizedBox(height: 3),
                  Text(contact['telephone'] ?? '', style: const TextStyle(color: AppColors.gris, fontSize: 13)),
                  if (contact['email'] != null && (contact['email'] as String).isNotEmpty)
                    Text(contact['email'], style: const TextStyle(color: AppColors.grisClair, fontSize: 12)),
                ],
              ),
            ),
          ),

          // Actions rapides
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BoutonAction(icon: Icons.phone_outlined, couleur: AppColors.bleuPrimaire, onTap: onAppeler),
              const SizedBox(width: 6),
              _BoutonAction(icon: Icons.chat_outlined, couleur: AppColors.succes, onTap: onWhatsApp),
              const SizedBox(width: 6),
              _BoutonAction(icon: Icons.delete_outline, couleur: AppColors.erreur, onTap: onSupprimer),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoutonAction extends StatelessWidget {
  final IconData icon;
  final Color couleur;
  final VoidCallback onTap;
  const _BoutonAction({required this.icon, required this.couleur, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: couleur.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: couleur, size: 18),
      ),
    );
  }
}

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
              width: 100, height: 100,
              decoration: BoxDecoration(color: AppColors.fondInput, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.people_outline, size: 48, color: AppColors.grisClair),
            ),
            const SizedBox(height: 20),
            const Text('Aucun contact favori', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.noir)),
            const SizedBox(height: 8),
            const Text('Ajoutez vos destinataires fréquents\npour envoyer plus vite', textAlign: TextAlign.center, style: TextStyle(color: AppColors.gris)),
            const SizedBox(height: 24),
            NymeButton(label: 'Ajouter un contact', onPressed: onAjouter, icon: Icons.person_add_outlined),
          ],
        ),
      ),
    );
  }
}

class _FormulaireContact extends StatefulWidget {
  final Future<void> Function(String nom, String tel, String? whatsapp, String? email) onSauvegarder;
  const _FormulaireContact({required this.onSauvegarder});

  @override
  State<_FormulaireContact> createState() => _FormulaireContactState();
}

class _FormulaireContactState extends State<_FormulaireContact> {
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

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
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.grisClair, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Nouveau contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            NymeTextField(controller: _nomCtrl, label: 'Nom complet', hint: 'Jean Dupont', prefixIcon: Icons.person_outline),
            const SizedBox(height: 12),
            NymeTextField(controller: _telCtrl, label: 'Téléphone *', hint: '+226 70 00 00 00', prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            NymeTextField(controller: _whatsappCtrl, label: 'WhatsApp (si différent)', hint: '+226 70 00 00 00', prefixIcon: Icons.chat_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            NymeTextField(controller: _emailCtrl, label: 'Email (optionnel)', hint: 'jean@email.com', prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 20),
            NymeButton(
              label: 'Enregistrer le contact',
              loading: _loading,
              onPressed: () async {
                if (_nomCtrl.text.isEmpty || _telCtrl.text.isEmpty) {
                  Helpers.snackErreur(context, 'Nom et téléphone obligatoires');
                  return;
                }
                setState(() => _loading = true);
                await widget.onSauvegarder(
                  _nomCtrl.text.trim(),
                  _telCtrl.text.trim(),
                  _whatsappCtrl.text.isEmpty ? null : _whatsappCtrl.text.trim(),
                  _emailCtrl.text.isEmpty ? null : _emailCtrl.text.trim(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


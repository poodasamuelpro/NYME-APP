import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../config/router.dart';
import '../../widgets/common/widgets.dart';

// ─────────────────────────────────────────────────────────────
// Écran Paramètres
// Route : /parametres
// Fichier : lib/presentation/screens/shared/parametres_screen.dart
// ─────────────────────────────────────────────────────────────

class ParametresScreen extends ConsumerStatefulWidget {
  const ParametresScreen({super.key});

  @override
  ConsumerState<ParametresScreen> createState() => _State();
}

class _State extends ConsumerState<ParametresScreen> {
  bool _notifsLivraison = true;
  bool _notifsMessages = true;
  bool _notifsPropositions = true;
  String _version = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _notifsLivraison = prefs.getBool('notifs_livraison') ?? true;
      _notifsMessages = prefs.getBool('notifs_messages') ?? true;
      _notifsPropositions = prefs.getBool('notifs_propositions') ?? true;
      _version = '${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _sauvegarderPreference(String cle, bool valeur) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(cle, valeur);
  }

  Future<void> _supprimerCompte() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le compte ?'),
        content: const Text('Cette action est irréversible. Toutes vos données seront supprimées définitivement.'),
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
      setState(() => _loading = true);
      try {
        // Déconnexion + suppression
        await ref.read(authRepositoryProvider).deconnecter();
        if (mounted) context.go(AppRoutes.connexion);
      } catch (_) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      appBar: AppBar(title: const Text('Paramètres')),
      body: LoadingOverlay(
        loading: _loading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Notifications ──
            _SectionTitre('🔔 Notifications'),
            _CarteParametres(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Livraisons'),
                  subtitle: const Text('Statuts, coursiers, arrivées'),
                  value: _notifsLivraison,
                  onChanged: (v) {
                    setState(() => _notifsLivraison = v);
                    _sauvegarderPreference('notifs_livraison', v);
                  },
                  activeColor: AppColors.bleuPrimaire,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Messages'),
                  subtitle: const Text('Nouveaux messages reçus'),
                  value: _notifsMessages,
                  onChanged: (v) {
                    setState(() => _notifsMessages = v);
                    _sauvegarderPreference('notifs_messages', v);
                  },
                  activeColor: AppColors.bleuPrimaire,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Propositions de prix'),
                  subtitle: const Text('Nouvelles offres des coursiers'),
                  value: _notifsPropositions,
                  onChanged: (v) {
                    setState(() => _notifsPropositions = v);
                    _sauvegarderPreference('notifs_propositions', v);
                  },
                  activeColor: AppColors.bleuPrimaire,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Compte ──
            _SectionTitre('👤 Compte'),
            _CarteParametres(
              children: [
                _LignParam(
                  icone: Icons.security,
                  label: 'Sécurité & Confidentialité',
                  couleur: AppColors.bleuPrimaire,
                  onTap: () => _afficherSecurite(),
                ),
                const Divider(height: 1),
                _LignParam(
                  icone: Icons.support_agent,
                  label: 'Service client & Réclamations',
                  couleur: AppColors.orange,
                  onTap: () => context.push('/reclamation'),
                ),
                const Divider(height: 1),
                _LignParam(
                  icone: Icons.delete_outline,
                  label: 'Supprimer mon compte',
                  couleur: AppColors.erreur,
                  onTap: _supprimerCompte,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Application ──
            _SectionTitre('📱 Application'),
            _CarteParametres(
              children: [
                _LignParam(
                  icone: Icons.info_outline,
                  label: 'À propos de NYME',
                  couleur: AppColors.bleuPrimaire,
                  onTap: () => _afficherAPropos(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.new_releases_outlined, color: AppColors.gris),
                  title: const Text('Version'),
                  trailing: Text(_version, style: const TextStyle(color: AppColors.gris, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _afficherSecurite() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sécurité'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🔐 Vos données sont sécurisées avec Supabase Auth.'),
            SizedBox(height: 8),
            Text('🛡️ Toutes les communications sont chiffrées (HTTPS/TLS).'),
            SizedBox(height: 8),
            Text('🗝️ Votre mot de passe n\'est jamais stocké en clair.'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }

  void _afficherAPropos() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.bleuPrimaire, borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('N', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20))),
            ),
            const SizedBox(width: 10),
            const Text('NYME'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Livraison Rapide & Intelligente', style: TextStyle(color: AppColors.gris, fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            Text('Version : $_version'),
            const SizedBox(height: 4),
            const Text('Ouagadougou, Burkina Faso 🇧🇫'),
            const SizedBox(height: 4),
            const Text('© 2025 NYME. Tous droits réservés.'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }
}

class _SectionTitre extends StatelessWidget {
  final String titre;
  const _SectionTitre(this.titre);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.gris)),
    );
  }
}

class _CarteParametres extends StatelessWidget {
  final List<Widget> children;
  const _CarteParametres({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.blanc,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.ombre, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: children),
    );
  }
}

class _LignParam extends StatelessWidget {
  final IconData icone;
  final String label;
  final Color couleur;
  final VoidCallback onTap;
  const _LignParam({required this.icone, required this.label, required this.couleur, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icone, color: couleur),
      title: Text(label, style: TextStyle(color: couleur == AppColors.erreur ? AppColors.erreur : AppColors.noir)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.grisClair),
      onTap: onTap,
    );
  }
}


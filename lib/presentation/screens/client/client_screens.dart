// ═══════════════════════════════════════════════════
// lib/presentation/screens/client/client_shell.dart
// ═══════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../config/router.dart';

class ClientShell extends StatelessWidget {
  final Widget child;
  const ClientShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith(AppRoutes.clientHome) && loc == AppRoutes.clientHome) return 0;
    if (loc.startsWith(AppRoutes.tableauBordClient)) return 1;
    if (loc.startsWith(AppRoutes.historiqueClient)) return 2;
    if (loc.startsWith(AppRoutes.profilClient)) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex(context),
        onTap: (i) {
          switch (i) {
            case 0: context.go(AppRoutes.clientHome); break;
            case 1: context.go(AppRoutes.tableauBordClient); break;
            case 2: context.go(AppRoutes.historiqueClient); break;
            case 3: context.go(AppRoutes.profilClient); break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Tableau'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historique'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// accueil_client_screen.dart
// ═══════════════════════════════════════════════════

class AccueilClientScreen extends ConsumerWidget {
  const AccueilClientScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bonjour 👋', style: TextStyle(color: AppColors.gris, fontSize: 14)),
                      Text('Client', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.noir)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () => context.push(AppRoutes.notifications),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat_outlined),
                        onPressed: () => context.push(AppRoutes.listeConversations),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Bouton principale - Nouvelle livraison
              GestureDetector(
                onTap: () => context.push(AppRoutes.nouvelleLivraison),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.bleuPrimaire, AppColors.bleuFonce],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Nouvelle livraison', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Envoyez un colis maintenant', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Types de courses
              Row(
                children: [
                  Expanded(child: _TypeCourseCard(
                    icon: '⚡',
                    label: 'Urgente',
                    subtitle: '+20%',
                    color: AppColors.orange,
                    onTap: () => context.push(AppRoutes.nouvelleLivraison, extra: {'type': 'urgente'}),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _TypeCourseCard(
                    icon: '📅',
                    label: 'Programmée',
                    subtitle: 'Planifier',
                    color: AppColors.bleuPrimaire,
                    onTap: () => context.push(AppRoutes.nouvelleLivraison, extra: {'type': 'programmee'}),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _TypeCourseCard(
                    icon: '👤',
                    label: 'Pour tiers',
                    subtitle: 'Envoyer',
                    color: AppColors.succes,
                    onTap: () => context.push(AppRoutes.nouvelleLivraison, extra: {'pourTiers': true}),
                  )),
                ],
              ),

              const SizedBox(height: 28),
              const Text('Livraisons récentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.noir)),
              const SizedBox(height: 12),

              // Liste livraisons récentes (placeholder - sera rempli par le provider)
              _ListeLivraisonsRecentes(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCourseCard extends StatelessWidget {
  final String icon, label, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _TypeCourseCard({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.gris)),
          ],
        ),
      ),
    );
  }
}

class _ListeLivraisonsRecentes extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: connecter au provider livraisonsClientProvider
    return const Center(child: Text('Aucune livraison récente', style: TextStyle(color: AppColors.gris)));
  }
}

// ═══════════════════════════════════════════════════
// tableau_bord_client_screen.dart
// ═══════════════════════════════════════════════════
class TableauBordClientScreen extends ConsumerWidget {
  const TableauBordClientScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Stats
            Row(
              children: [
                Expanded(child: _StatCard(titre: 'Total courses', valeur: '0', icone: Icons.local_shipping_outlined, couleur: AppColors.bleuPrimaire)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(titre: 'En cours', valeur: '0', icone: Icons.delivery_dining, couleur: AppColors.orange)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard(titre: 'Livrées', valeur: '0', icone: Icons.check_circle_outline, couleur: AppColors.succes)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(titre: 'Annulées', valeur: '0', icone: Icons.cancel_outlined, couleur: AppColors.erreur)),
              ],
            ),
            const SizedBox(height: 24),

            // Raccourcis
            _RaccourciTile(icon: Icons.location_on_outlined, label: 'Mes adresses favorites', onTap: () => context.push(AppRoutes.adressesFavorites)),
            _RaccourciTile(icon: Icons.people_outline, label: 'Mes contacts favoris', onTap: () => context.push(AppRoutes.contactsFavoris)),
            _RaccourciTile(icon: Icons.history, label: 'Historique des livraisons', onTap: () => context.push(AppRoutes.historiqueClient)),
            _RaccourciTile(icon: Icons.chat_outlined, label: 'Messagerie', onTap: () => context.push(AppRoutes.listeConversations)),
            _RaccourciTile(icon: Icons.support_agent, label: 'Service client', onTap: () => context.push(AppRoutes.listeConversations)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String titre, valeur;
  final IconData icone;
  final Color couleur;
  const _StatCard({required this.titre, required this.valeur, required this.icone, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 24),
          const SizedBox(height: 8),
          Text(valeur, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: couleur)),
          Text(titre, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
        ],
      ),
    );
  }
}

class _RaccourciTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RaccourciTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.fondInput, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.bleuPrimaire, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.gris),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════════
// historique_client_screen.dart
// ═══════════════════════════════════════════════════
class HistoriqueClientScreen extends ConsumerWidget {
  const HistoriqueClientScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      body: const Center(child: Text('Historique des livraisons', style: TextStyle(color: AppColors.gris))),
    );
  }
}

// Imports manquants - à mettre en haut de chaque fichier séparé
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../config/router.dart';

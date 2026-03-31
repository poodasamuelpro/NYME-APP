import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../config/router.dart';
import '../../../data/models/models.dart';
import '../../../services/location_service.dart';
import '../../widgets/common/widgets.dart';

// ═══════════════════════════════════════════════════
// coursier_shell.dart
// ═══════════════════════════════════════════════════
class CoursierShell extends StatelessWidget {
  final Widget child;
  const CoursierShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc == AppRoutes.coursierHome) return 0;
    if (loc.startsWith(AppRoutes.tableauBordCoursier)) return 1;
    if (loc.startsWith(AppRoutes.gainsCoursier)) return 2;
    if (loc.startsWith(AppRoutes.profilCoursier)) return 3;
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
            case 0: context.go(AppRoutes.coursierHome); break;
            case 1: context.go(AppRoutes.tableauBordCoursier); break;
            case 2: context.go(AppRoutes.gainsCoursier); break;
            case 3: context.go(AppRoutes.profilCoursier); break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.delivery_dining), label: 'Courses'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Tableau'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Gains'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// accueil_coursier_screen.dart
// ═══════════════════════════════════════════════════
class AccueilCoursierScreen extends ConsumerStatefulWidget {
  const AccueilCoursierScreen({super.key});
  @override
  ConsumerState<AccueilCoursierScreen> createState() => _AccueilCoursierState();
}

class _AccueilCoursierState extends ConsumerState<AccueilCoursierScreen> {
  bool _disponible = false;

  Future<void> _toggleDisponibilite() async {
    setState(() => _disponible = !_disponible);
    // TODO: mettre à jour statut dans Supabase
    // TODO: démarrer/arrêter le tracking GPS
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      body: SafeArea(
        child: Column(
          children: [
            // Header avec toggle disponibilité
            Container(
              padding: const EdgeInsets.all(20),
              color: AppColors.blanc,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bonjour Coursier 🏍️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.noir)),
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: _disponible ? AppColors.succes : AppColors.gris,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(_disponible ? 'Disponible' : 'Hors ligne', style: TextStyle(color: _disponible ? AppColors.succes : AppColors.gris, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: _disponible,
                    onChanged: (_) => _toggleDisponibilite(),
                    activeColor: AppColors.succes,
                  ),
                ],
              ),
            ),

            // Livraisons disponibles
            Expanded(
              child: _disponible
                  ? _ListeLivraisonsDisponibles()
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delivery_dining, size: 80, color: AppColors.grisClair),
                          const SizedBox(height: 16),
                          const Text('Activez votre disponibilité', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.noir)),
                          const SizedBox(height: 8),
                          const Text('pour voir les livraisons disponibles', style: TextStyle(color: AppColors.gris)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeLivraisonsDisponibles extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: connecter au provider livraisonsDisponiblesProvider
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 0, // Remplacer par les vraies données
      itemBuilder: (_, i) => const SizedBox.shrink(),
    );
  }
}

// ═══════════════════════════════════════════════════
// carte_coursier_screen.dart - Carte GPS temps réel
// ═══════════════════════════════════════════════════
class CarteCoursierScreen extends ConsumerStatefulWidget {
  final String livraisonId;
  const CarteCoursierScreen({super.key, required this.livraisonId});
  @override
  ConsumerState<CarteCoursierScreen> createState() => _CarteCoursierState();
}

class _CarteCoursierState extends ConsumerState<CarteCoursierScreen> {
  final MapController _mapCtrl = MapController();
  List<LatLng> _polyline = [];
  LatLng? _positionCoursier;
  LatLng? _positionDepart;
  LatLng? _positionArrivee;
  StatutLivraison _statut = StatutLivraison.acceptee;

  @override
  void initState() {
    super.initState();
    _chargerLivraison();
  }

  Future<void> _chargerLivraison() async {
    // TODO: charger depuis le repository
    // TODO: démarrer le tracking GPS
    // TODO: calculer itinéraire
  }

  Future<void> _mettreAJourStatut(StatutLivraison nouveauStatut) async {
    // TODO: mettre à jour statut via repository
    setState(() => _statut = nouveauStatut);
  }

  String _prochainStatutLabel() {
    switch (_statut) {
      case StatutLivraison.acceptee: return 'En route vers le colis';
      case StatutLivraison.enRoutDepart: return 'Colis récupéré';
      case StatutLivraison.colisRecupere: return 'En route vers destination';
      case StatutLivraison.enRouteArrivee: return 'Marquer comme livré';
      default: return '';
    }
  }

  StatutLivraison? _prochainStatut() {
    switch (_statut) {
      case StatutLivraison.acceptee: return StatutLivraison.enRoutDepart;
      case StatutLivraison.enRoutDepart: return StatutLivraison.colisRecupere;
      case StatutLivraison.colisRecupere: return StatutLivraison.enRouteArrivee;
      case StatutLivraison.enRouteArrivee: return StatutLivraison.livree;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Carte FlutterMap (OpenStreetMap)
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _positionCoursier ?? const LatLng(12.3569, -1.5353),
              initialZoom: 14,
            ),
            children: [
              // Tuiles OpenStreetMap (gratuit)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.nyme.app',
              ),

              // Itinéraire
              if (_polyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polyline,
                      strokeWidth: 4,
                      color: AppColors.bleuPrimaire,
                    ),
                  ],
                ),

              // Marqueurs
              MarkerLayer(
                markers: [
                  if (_positionCoursier != null)
                    Marker(
                      point: _positionCoursier!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: const BoxDecoration(color: AppColors.bleuPrimaire, shape: BoxShape.circle),
                        child: const Icon(Icons.delivery_dining, color: Colors.white, size: 22),
                      ),
                    ),
                  if (_positionDepart != null)
                    Marker(
                      point: _positionDepart!,
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.circle, color: Colors.white, size: 16),
                      ),
                    ),
                  if (_positionArrivee != null)
                    Marker(
                      point: _positionArrivee!,
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.location_on, color: AppColors.erreur, size: 36),
                    ),
                ],
              ),
            ],
          ),

          // Panel en bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatutBadge(statut: _statut.name),
                  const SizedBox(height: 16),
                  if (_prochainStatut() != null)
                    NymeButton(
                      label: _prochainStatutLabel(),
                      onPressed: () => _mettreAJourStatut(_prochainStatut()!),
                    ),
                  const SizedBox(height: 8),
                  // Actions contact
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {/* TODO: appeler client */},
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text('Appeler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {/* TODO: WhatsApp */},
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text('Chat'),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.succes, side: const BorderSide(color: AppColors.succes)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bouton retour
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: FloatingActionButton.small(
              onPressed: () => context.pop(),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.noir,
              child: const Icon(Icons.arrow_back_ios, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// tableau_bord_coursier_screen.dart
// ═══════════════════════════════════════════════════
class TableauBordCoursierScreen extends ConsumerWidget {
  const TableauBordCoursierScreen({super.key});
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
                Expanded(child: _StatCoursier(titre: 'Courses', valeur: '0', couleur: AppColors.bleuPrimaire, icone: '🏍️')),
                const SizedBox(width: 12),
                Expanded(child: _StatCoursier(titre: 'Note', valeur: '⭐ 0.0', couleur: AppColors.orange, icone: '⭐')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCoursier(titre: 'Gains total', valeur: '0 FCFA', couleur: AppColors.succes, icone: '💰')),
                const SizedBox(width: 12),
                Expanded(child: _StatCoursier(titre: 'Ce mois', valeur: '0 FCFA', couleur: AppColors.bleuClair, icone: '📅')),
              ],
            ),
            const SizedBox(height: 24),

            // Raccourcis
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.bleuPrimaire),
              title: const Text('Historique des courses'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.succes),
              title: const Text('Mon portefeuille'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => context.push(AppRoutes.gainsCoursier),
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined, color: AppColors.orange),
              title: const Text('Messagerie'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => context.push(AppRoutes.listeConversations),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCoursier extends StatelessWidget {
  final String titre, valeur, icone;
  final Color couleur;
  const _StatCoursier({required this.titre, required this.valeur, required this.couleur, required this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: couleur.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icone, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(valeur, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: couleur)),
          Text(titre, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// gains_screen.dart
// ═══════════════════════════════════════════════════
class GainsScreen extends ConsumerWidget {
  const GainsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gains & Portefeuille')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Solde wallet
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.succes, Color(0xFF16A34A)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  SizedBox(height: 8),
                  Text('0 FCFA', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 24),
            NymeButton(label: 'Demander un retrait', onPressed: () {}, outlined: true, icon: Icons.account_balance_outlined),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Historique des transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            const Center(child: Text('Aucune transaction', style: TextStyle(color: AppColors.gris))),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// profil_coursier_screen.dart
// ═══════════════════════════════════════════════════
class ProfilCoursierScreen extends ConsumerWidget {
  const ProfilCoursierScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, backgroundColor: AppColors.fondInput, child: Icon(Icons.person, size: 50, color: AppColors.gris)),
            const SizedBox(height: 12),
            const Text('Coursier', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('⭐ 0.0 · 0 courses', style: TextStyle(color: AppColors.gris)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.badge_outlined, color: AppColors.bleuPrimaire),
              title: const Text('Documents de vérification'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => context.push(AppRoutes.verificationCoursier),
            ),
            ListTile(
              leading: const Icon(Icons.directions_bike_outlined, color: AppColors.orange),
              title: const Text('Mon véhicule'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: AppColors.gris),
              title: const Text('Paramètres'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => context.push(AppRoutes.parametres),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.erreur),
              title: const Text('Se déconnecter', style: TextStyle(color: AppColors.erreur)),
              onTap: () async {
                // TODO: déconnexion
              },
            ),
          ],
        ),
      ),
    );
  }
}

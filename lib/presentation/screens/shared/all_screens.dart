// ═══════════════════════════════════════════════
// lib/core/errors/app_exception.dart
// ═══════════════════════════════════════════════
class AppException implements Exception {
  final String message;
  const AppException(this.message);
  @override
  String toString() => message;
}

// ═══════════════════════════════════════════════
// lib/core/utils/format_prix.dart
// ═══════════════════════════════════════════════
import 'package:intl/intl.dart';

class FormatPrix {
  static final _fmt = NumberFormat('#,###', 'fr_FR');

  static String fcfa(double montant) => '${_fmt.format(montant.round())} FCFA';
  static String fcfaInt(int montant) => '${_fmt.format(montant)} FCFA';
  static String court(double montant) => _fmt.format(montant.round());
}

// ═══════════════════════════════════════════════
// lib/core/utils/helpers.dart
// ═══════════════════════════════════════════════
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class Helpers {
  static String dateComplete(DateTime dt) =>
      DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(dt);

  static String dateCourte(DateTime dt) =>
      DateFormat('dd/MM/yyyy', 'fr_FR').format(dt);

  static String heureMinute(DateTime dt) =>
      DateFormat('HH:mm').format(dt);

  static String tempsEcoule(DateTime dt) => timeago.format(dt, locale: 'fr');

  static String masquerTelephone(String tel) {
    if (tel.length < 4) return tel;
    return '${tel.substring(0, tel.length - 4)}****';
  }

  static String initiales(String nom) {
    final parts = nom.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return nom.isNotEmpty ? nom[0].toUpperCase() : '?';
  }
}

// ═══════════════════════════════════════════════
// lib/presentation/screens/admin/admin_shell.dart
// ═══════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../config/router.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.verified_user_outlined), label: 'Vérifs'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Utilisateurs'),
          BottomNavigationBarItem(icon: Icon(Icons.report_outlined), label: 'Litiges'),
        ],
        onTap: (i) {
          switch(i) {
            case 0: context.go(AppRoutes.adminHome); break;
            case 1: context.go(AppRoutes.verifications); break;
            case 2: context.go(AppRoutes.utilisateurs); break;
            case 3: context.go(AppRoutes.litiges); break;
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// lib/presentation/screens/admin/tableau_bord_admin_screen.dart
// ═══════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';

class TableauBordAdminScreen extends ConsumerWidget {
  const TableauBordAdminScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administration NYME')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: _AdminStat('Total courses', '0', Icons.local_shipping, AppColors.bleuPrimaire)),
              const SizedBox(width: 12),
              Expanded(child: _AdminStat('Revenus', '0 FCFA', Icons.attach_money, AppColors.succes)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _AdminStat('Coursiers actifs', '0', Icons.delivery_dining, AppColors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _AdminStat('Dossiers en attente', '0', Icons.pending_outlined, AppColors.avertissement)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _AdminStat extends StatelessWidget {
  final String titre, valeur;
  final IconData icone;
  final Color couleur;
  const _AdminStat(this.titre, this.valeur, this.icone, this.couleur);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: couleur.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icone, color: couleur),
      const SizedBox(height: 8),
      Text(valeur, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: couleur)),
      Text(titre, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
    ]),
  );
}

// ═══════════════════════════════════════════════
// lib/presentation/screens/admin/verifications_screen.dart
// ═══════════════════════════════════════════════
class VerificationsScreen extends ConsumerWidget {
  const VerificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérifications coursiers')),
      body: const Center(child: Text('Liste des dossiers en attente')),
    );
  }
}

// ═══════════════════════════════════════════════
// lib/presentation/screens/admin/utilisateurs_screen.dart
// ═══════════════════════════════════════════════
class UtilisateursScreen extends ConsumerWidget {
  const UtilisateursScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      body: const Center(child: Text('Gestion des utilisateurs')),
    );
  }
}

// ═══════════════════════════════════════════════
// lib/presentation/screens/admin/litiges_screen.dart
// ═══════════════════════════════════════════════
class LitigesScreen extends ConsumerWidget {
  const LitigesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Litiges & Signalements')),
      body: const Center(child: Text('Signalements à traiter')),
    );
  }
}

// ═══════════════════════════════════════════════
// lib/presentation/screens/shared/notifications_screen.dart
// ═══════════════════════════════════════════════
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(child: Text('Vos notifications')),
    );
  }
}

// ═══════════════════════════════════════════════
// lib/presentation/screens/shared/parametres_screen.dart
// ═══════════════════════════════════════════════
class ParametresScreen extends ConsumerWidget {
  const ParametresScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: const [
          ListTile(leading: Icon(Icons.language), title: Text('Langue'), trailing: Text('Français')),
          ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Notifications')),
          ListTile(leading: Icon(Icons.security), title: Text('Sécurité & Confidentialité')),
          ListTile(leading: Icon(Icons.help_outline), title: Text('Aide & Support')),
          ListTile(leading: Icon(Icons.info_outline), title: Text('À propos de NYME')),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// lib/presentation/screens/client/nouvelle_livraison_screen.dart
// ═══════════════════════════════════════════════
class NouvelleLivraisonScreen extends ConsumerStatefulWidget {
  const NouvelleLivraisonScreen({super.key});
  @override
  ConsumerState<NouvelleLivraisonScreen> createState() => _NouvelleLivraisonState();
}

class _NouvelleLivraisonState extends ConsumerState<NouvelleLivraisonScreen> {
  final _departCtrl = TextEditingController();
  final _arriveeCtrl = TextEditingController();
  final _nomDestCtrl = TextEditingController();
  final _telDestCtrl = TextEditingController();
  final _whatsappDestCtrl = TextEditingController();
  final _emailDestCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  bool _pourTiers = false;
  String _typeCourse = 'immediate';
  DateTime? _dateProgrammee;
  List<File> _photos = [];
  double? _prixCalcule;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle livraison')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type de course
            const Text('Type de course', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TypeChip('immediate', '⚡ Immédiate', _typeCourse, (v) => setState(() => _typeCourse = v)),
                  const SizedBox(width: 8),
                  _TypeChip('urgente', '🔥 Urgente', _typeCourse, (v) => setState(() => _typeCourse = v)),
                  const SizedBox(width: 8),
                  _TypeChip('programmee', '📅 Programmée', _typeCourse, (v) => setState(() => _typeCourse = v)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pour tiers
            SwitchListTile.adaptive(
              title: const Text('Commander pour quelqu\'un d\'autre'),
              value: _pourTiers,
              onChanged: (v) => setState(() => _pourTiers = v),
              activeColor: AppColors.bleuPrimaire,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Adresses
            const Text('Adresses', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            NymeTextField(controller: _departCtrl, label: 'Point de départ', prefixIcon: Icons.circle_outlined, hint: 'Adresse de départ'),
            const SizedBox(height: 12),
            NymeTextField(controller: _arriveeCtrl, label: 'Destination', prefixIcon: Icons.location_on, hint: 'Adresse de destination'),
            const SizedBox(height: 20),

            // Destinataire
            const Text('Destinataire', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            NymeTextField(controller: _nomDestCtrl, label: 'Nom du destinataire', prefixIcon: Icons.person_outline),
            const SizedBox(height: 12),
            NymeTextField(controller: _telDestCtrl, label: 'Téléphone', prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            NymeTextField(controller: _whatsappDestCtrl, label: 'WhatsApp', prefixIcon: Icons.chat_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            NymeTextField(controller: _emailDestCtrl, label: 'Email (optionnel)', prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            NymeTextField(controller: _instructionsCtrl, label: 'Instructions spéciales', maxLines: 3, hint: 'Ex: Appeler avant d\'arriver, laisser à la gardienne...'),
            const SizedBox(height: 20),

            // Photos colis
            const Text('Photos du colis', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // TODO: Grille de photos
            NymeButton(label: 'Ajouter des photos', onPressed: () {}, outlined: true, icon: Icons.camera_alt_outlined),
            const SizedBox(height: 32),

            NymeButton(
              label: 'Calculer le prix et continuer',
              onPressed: _continuer,
              loading: _loading,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _continuer() async {
    // TODO: calculer itinéraire, afficher prix, continuer vers propositions
  }
}

class _TypeChip extends StatelessWidget {
  final String valeur, label, selected;
  final void Function(String) onTap;
  const _TypeChip(this.valeur, this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = valeur == selected;
    return GestureDetector(
      onTap: () => onTap(valeur),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bleuPrimaire : AppColors.fondInput,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.gris, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// Stubs des écrans restants
class SuiviLivraisonScreen extends ConsumerWidget {
  final String livraisonId;
  const SuiviLivraisonScreen({super.key, required this.livraisonId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('Suivi livraison')));
}

class DetailLivraisonScreen extends ConsumerWidget {
  final String livraisonId;
  const DetailLivraisonScreen({super.key, required this.livraisonId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('Détail livraison')));
}

class PropositionsPrixScreen extends ConsumerWidget {
  final String livraisonId;
  const PropositionsPrixScreen({super.key, required this.livraisonId});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('Propositions de prix')));
}

class AdressesFavoritesScreen extends ConsumerWidget {
  const AdressesFavoritesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('Adresses favorites')));
}

class ContactsFavorisScreen extends ConsumerWidget {
  const ContactsFavorisScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('Contacts favoris')));
}

class ProfilClientScreen extends ConsumerWidget {
  const ProfilClientScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('Mon profil')));
}

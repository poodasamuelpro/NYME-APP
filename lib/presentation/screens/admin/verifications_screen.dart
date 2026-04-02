import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../config/supabase_config.dart';
import '../../../services/notification_service.dart';
import '../../../services/brevo_email_service.dart';
import '../../widgets/common/widgets.dart';

// ─────────────────────────────────────────────────────────────
// Écran Vérifications Admin
// Route : /admin/verifications
// Fichier : lib/presentation/screens/admin/verifications_screen.dart
// L'admin valide ou rejette les dossiers des coursiers
// ─────────────────────────────────────────────────────────────

class VerificationsScreen extends ConsumerStatefulWidget {
  const VerificationsScreen({super.key});

  @override
  ConsumerState<VerificationsScreen> createState() => _State();
}

class _State extends ConsumerState<VerificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _enAttente = [];
  List<Map<String, dynamic>> _traites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _charger();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _loading = true);
    try {
      final attente = await Supabase.instance.client
          .from(SupabaseConfig.tableCoursiers)
          .select('''
            *,
            utilisateur:id(id, nom, email, telephone, whatsapp, avatar_url, created_at),
            vehicules(*)
          ''')
          .eq('statut_verification', 'en_attente')
          .order('created_at', ascending: false);

      final traites = await Supabase.instance.client
          .from(SupabaseConfig.tableCoursiers)
          .select('''
            *,
            utilisateur:id(id, nom, email, telephone, avatar_url)
          ''')
          .inFilter('statut_verification', ['verifie', 'rejete'])
          .order('created_at', ascending: false)
          .limit(20);

      setState(() {
        _enAttente = List<Map<String, dynamic>>.from(attente);
        _traites = List<Map<String, dynamic>>.from(traites);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _valider(Map<String, dynamic> coursier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Valider ce dossier ?'),
        content: Text('Valider le dossier de ${coursier['utilisateur']['nom']} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.succes),
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await Supabase.instance.client
        .from(SupabaseConfig.tableCoursiers)
        .update({'statut_verification': 'verifie'})
        .eq('id', coursier['id']);

    // Valider aussi le véhicule
    await Supabase.instance.client
        .from(SupabaseConfig.tableVehicules)
        .update({'est_verifie': true})
        .eq('coursier_id', coursier['id']);

    // Notifier le coursier
    await NotificationService.enregistrer(
      userId: coursier['id'],
      type: NotificationService.typeDossierValide,
      titre: 'Dossier validé ! ✅',
      message: 'Félicitations ! Vous pouvez maintenant accepter des livraisons.',
    );

    // Email de validation
    final email = coursier['utilisateur']['email'];
    if (email != null) {
      await BrevoEmailService.envoyerDossierValide(
        email: email,
        nom: coursier['utilisateur']['nom'],
      );
    }

    await _charger();
    if (mounted) Helpers.snackSuccess(context, 'Dossier validé !');
  }

  Future<void> _rejeter(Map<String, dynamic> coursier) async {
    final motifCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rejeter ce dossier ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Motif du rejet pour ${coursier['utilisateur']['nom']} :'),
            const SizedBox(height: 12),
            TextField(
              controller: motifCtrl,
              decoration: const InputDecoration(hintText: 'Ex: Photo CNI illisible...', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.erreur),
            child: const Text('Rejeter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await Supabase.instance.client
        .from(SupabaseConfig.tableCoursiers)
        .update({'statut_verification': 'rejete'})
        .eq('id', coursier['id']);

    // Notifier
    await NotificationService.enregistrer(
      userId: coursier['id'],
      type: NotificationService.typeDossierRejete,
      titre: 'Corrections requises ⚠️',
      message: motifCtrl.text.isEmpty ? 'Votre dossier nécessite des corrections.' : motifCtrl.text,
    );

    // Email
    final email = coursier['utilisateur']['email'];
    if (email != null) {
      await BrevoEmailService.envoyerDossierRejete(
        email: email,
        nom: coursier['utilisateur']['nom'],
        motif: motifCtrl.text.isEmpty ? 'Documents insuffisants ou illisibles' : motifCtrl.text,
      );
    }

    await _charger();
    if (mounted) Helpers.snackSuccess(context, 'Dossier rejeté');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vérifications coursiers'),
            if (_enAttente.isNotEmpty)
              Text('${_enAttente.length} en attente', style: const TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.normal)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.bleuPrimaire,
          unselectedLabelColor: AppColors.gris,
          indicatorColor: AppColors.bleuPrimaire,
          tabs: [
            Tab(text: 'En attente (${_enAttente.length})'),
            Tab(text: 'Traités (${_traites.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.bleuPrimaire))
          : TabBarView(
              controller: _tabs,
              children: [
                _ListeDossiers(
                  dossiers: _enAttente,
                  onRefresh: _charger,
                  onValider: _valider,
                  onRejeter: _rejeter,
                  afficherActions: true,
                ),
                _ListeDossiers(
                  dossiers: _traites,
                  onRefresh: _charger,
                  afficherActions: false,
                ),
              ],
            ),
    );
  }
}

class _ListeDossiers extends StatelessWidget {
  final List<Map<String, dynamic>> dossiers;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic>)? onValider;
  final Future<void> Function(Map<String, dynamic>)? onRejeter;
  final bool afficherActions;

  const _ListeDossiers({
    required this.dossiers,
    required this.onRefresh,
    this.onValider,
    this.onRejeter,
    required this.afficherActions,
  });

  @override
  Widget build(BuildContext context) {
    if (dossiers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(afficherActions ? Icons.check_circle_outline : Icons.folder_open,
                size: 64, color: AppColors.grisClair),
            const SizedBox(height: 16),
            Text(
              afficherActions ? 'Aucun dossier en attente ✓' : 'Aucun dossier traité',
              style: const TextStyle(color: AppColors.gris, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: dossiers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _CarteDossier(
          dossier: dossiers[i],
          onValider: afficherActions ? () => onValider!(dossiers[i]) : null,
          onRejeter: afficherActions ? () => onRejeter!(dossiers[i]) : null,
        ),
      ),
    );
  }
}

class _CarteDossier extends StatefulWidget {
  final Map<String, dynamic> dossier;
  final VoidCallback? onValider;
  final VoidCallback? onRejeter;
  const _CarteDossier({required this.dossier, this.onValider, this.onRejeter});

  @override
  State<_CarteDossier> createState() => _CarteDossierState();
}

class _CarteDossierState extends State<_CarteDossier> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final utilisateur = widget.dossier['utilisateur'] as Map?;
    final vehicules = widget.dossier['vehicules'] as List? ?? [];
    final statut = widget.dossier['statut_verification'] as String? ?? 'en_attente';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.blanc,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.ombre, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header cliquable
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.fondInput,
              backgroundImage: utilisateur?['avatar_url'] != null
                  ? NetworkImage(utilisateur!['avatar_url'])
                  : null,
              child: utilisateur?['avatar_url'] == null
                  ? Text(Helpers.initiales(utilisateur?['nom'] ?? '?'),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.bleuPrimaire))
                  : null,
            ),
            title: Text(utilisateur?['nom'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(utilisateur?['telephone'] ?? '', style: const TextStyle(color: AppColors.gris, fontSize: 13)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BadgeStatut(statut),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),

          // Détails
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Documents
                  const Text('📄 Documents', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _DocMiniature('CNI Recto', widget.dossier['cni_recto_url']),
                      const SizedBox(width: 8),
                      _DocMiniature('CNI Verso', widget.dossier['cni_verso_url']),
                      const SizedBox(width: 8),
                      _DocMiniature('Permis', widget.dossier['permis_url']),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Véhicule
                  if (vehicules.isNotEmpty) ...[
                    const Text('🚗 Véhicule', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('${vehicules[0]['type']} · ${vehicules[0]['marque']} ${vehicules[0]['modele']}',
                        style: const TextStyle(color: AppColors.gris)),
                    Text('Plaque : ${vehicules[0]['plaque']}', style: const TextStyle(color: AppColors.gris)),
                    const SizedBox(height: 6),
                    _DocMiniature('Carte grise', vehicules[0]['carte_grise_url']),
                    const SizedBox(height: 12),
                  ],

                  // Actions
                  if (widget.onValider != null && widget.onRejeter != null)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onRejeter,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Rejeter'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.erreur,
                              side: const BorderSide(color: AppColors.erreur),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onValider,
                            icon: const Icon(Icons.check, size: 18, color: Colors.white),
                            label: const Text('Valider', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.succes,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocMiniature extends StatelessWidget {
  final String label;
  final String? url;
  const _DocMiniature(this.label, this.url);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          GestureDetector(
            onTap: url != null ? () {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: Image.network(url!, fit: BoxFit.contain),
                ),
              );
            } : null,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.fondInput,
                borderRadius: BorderRadius.circular(10),
                image: url != null ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover) : null,
              ),
              child: url == null
                  ? const Center(child: Icon(Icons.image_not_supported_outlined, color: AppColors.grisClair))
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.gris), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _BadgeStatut extends StatelessWidget {
  final String statut;
  const _BadgeStatut(this.statut);

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (statut) {
      case 'verifie': color = AppColors.succes; label = 'Validé'; break;
      case 'rejete': color = AppColors.erreur; label = 'Rejeté'; break;
      default: color = AppColors.avertissement; label = 'En attente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}


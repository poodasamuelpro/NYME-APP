import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/brevo_email_service.dart';
import '../../../config/supabase_config.dart';
import '../../widgets/common/widgets.dart';

// ─────────────────────────────────────────────────────────────
// lib/presentation/screens/shared/reclamation_screen.dart
// Route : /reclamation
// ─────────────────────────────────────────────────────────────

class ReclamationScreen extends ConsumerStatefulWidget {
  final String? livraisonId;
  const ReclamationScreen({super.key, this.livraisonId});

  @override
  ConsumerState<ReclamationScreen> createState() => _State();
}

class _State extends ConsumerState<ReclamationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      appBar: AppBar(
        title: const Text('Service client'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.bleuPrimaire,
          unselectedLabelColor: AppColors.gris,
          indicatorColor: AppColors.bleuPrimaire,
          tabs: const [
            Tab(text: 'Nouvelle réclamation'),
            Tab(text: 'Mes réclamations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _NouvelleReclamation(livraisonId: widget.livraisonId),
          const _MesReclamations(),
        ],
      ),
    );
  }
}

class _NouvelleReclamation extends ConsumerStatefulWidget {
  final String? livraisonId;
  const _NouvelleReclamation({this.livraisonId});

  @override
  ConsumerState<_NouvelleReclamation> createState() => _NouvelleReclamationState();
}

class _NouvelleReclamationState extends ConsumerState<_NouvelleReclamation> {
  final _descriptionCtrl = TextEditingController();
  String _motif = 'colis_endommage';
  bool _loading = false;

  final List<Map<String, String>> _motifs = [
    {'value': 'colis_endommage', 'label': '📦 Colis endommagé'},
    {'value': 'colis_perdu', 'label': '❓ Colis perdu'},
    {'value': 'mauvais_comportement', 'label': '😠 Comportement du coursier'},
    {'value': 'livraison_incorrecte', 'label': '📍 Livraison au mauvais endroit'},
    {'value': 'retard', 'label': '⏰ Retard excessif'},
    {'value': 'paiement', 'label': '💰 Problème de paiement'},
    {'value': 'autre', 'label': '📝 Autre'},
  ];

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _soumettre() async {
    if (_descriptionCtrl.text.trim().length < 20) {
      Helpers.snackErreur(context, 'Décrivez le problème (minimum 20 caractères)');
      return;
    }
    setState(() => _loading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final numero = const Uuid().v4().substring(0, 8).toUpperCase();

      await Supabase.instance.client.from(SupabaseConfig.tableSignalements).insert({
        'signalant_id': userId,
        'signale_id': userId,
        'livraison_id': widget.livraisonId,
        'motif': _motif,
        'description': _descriptionCtrl.text.trim(),
        'statut': 'en_attente',
        'created_at': DateTime.now().toIso8601String(),
      });

      final user = await Supabase.instance.client
          .from(SupabaseConfig.tableUtilisateurs)
          .select('email, nom')
          .eq('id', userId)
          .single();

      if (user['email'] != null) {
        await BrevoEmailService.envoyerConfirmationReclamation(
          email: user['email'],
          nom: user['nom'] ?? 'Client',
          livraisonId: widget.livraisonId ?? 'N/A',
          motif: _motifs.firstWhere((m) => m['value'] == _motif)['label']!,
          numeroReclamation: numero,
        );
      }

      if (!mounted) return;
      _descriptionCtrl.clear();
      Helpers.snackSuccess(context, 'Réclamation #$numero envoyée ! Email de confirmation envoyé.');
    } catch (e) {
      if (mounted) Helpers.snackErreur(context, 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bleuPrimaire.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.support_agent, color: AppColors.bleuPrimaire, size: 22),
                SizedBox(width: 10),
                Expanded(child: Text('Traitement en 24-48h ouvrées. Un email de confirmation vous sera envoyé.',
                    style: TextStyle(color: AppColors.bleuPrimaire, fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Motif *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.noir)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _motifs.map((m) {
              final sel = _motif == m['value'];
              return GestureDetector(
                onTap: () => setState(() => _motif = m['value']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.bleuPrimaire : AppColors.fondInput,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(m['label']!,
                      style: TextStyle(color: sel ? Colors.white : AppColors.gris,
                          fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          const Text('Description *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.noir)),
          const SizedBox(height: 8),
          NymeTextField(
            controller: _descriptionCtrl,
            label: 'Décrivez le problème en détail',
            hint: 'Expliquez ce qui s\'est passé...',
            maxLines: 5,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Text('${_descriptionCtrl.text.length} caractères (min. 20)',
              style: TextStyle(color: _descriptionCtrl.text.length >= 20 ? AppColors.succes : AppColors.grisClair, fontSize: 11)),
          const SizedBox(height: 24),

          NymeButton(label: 'Soumettre la réclamation', onPressed: _soumettre, loading: _loading, icon: Icons.send_outlined),
        ],
      ),
    );
  }
}

class _MesReclamations extends ConsumerStatefulWidget {
  const _MesReclamations();

  @override
  ConsumerState<_MesReclamations> createState() => _MesReclamationsState();
}

class _MesReclamationsState extends ConsumerState<_MesReclamations> {
  List<Map<String, dynamic>> _reclamations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) { setState(() => _loading = false); return; }
    final data = await Supabase.instance.client
        .from(SupabaseConfig.tableSignalements)
        .select()
        .eq('signalant_id', userId)
        .order('created_at', ascending: false);
    setState(() { _reclamations = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Color _couleur(String s) {
    switch (s) {
      case 'traite': return AppColors.succes;
      case 'rejete': return AppColors.erreur;
      default: return AppColors.avertissement;
    }
  }

  String _label(String s) {
    switch (s) {
      case 'traite': return 'Résolu ✓';
      case 'rejete': return 'Non retenu';
      default: return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.bleuPrimaire));
    if (_reclamations.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 64, color: AppColors.grisClair),
        SizedBox(height: 16),
        Text('Aucune réclamation', style: TextStyle(color: AppColors.gris, fontSize: 16)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _reclamations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final r = _reclamations[i];
          final statut = r['statut'] as String? ?? 'en_attente';
          final c = _couleur(statut);
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.blanc, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.ombre, blurRadius: 6, offset: const Offset(0, 2))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(r['motif']?.toString().replaceAll('_', ' ') ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(_label(statut), style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 8),
              Text(r['description'] ?? '', style: const TextStyle(color: AppColors.gris, fontSize: 13),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(Helpers.dateRelative(DateTime.parse(r['created_at'])),
                  style: const TextStyle(color: AppColors.grisClair, fontSize: 12)),
            ]),
          );
        },
      ),
    );
  }
}


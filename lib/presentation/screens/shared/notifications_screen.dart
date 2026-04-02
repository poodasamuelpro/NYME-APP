import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../config/supabase_config.dart';
import '../../../services/notification_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotifState();
}

class _NotifState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _charger();
  }

  Future<void> _charger() async {
    final data = await Supabase.instance.client
        .from(SupabaseConfig.tableNotifications)
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(50);
    setState(() { _notifs = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  Future<void> _toutMarquerLu() async {
    await NotificationService.marquerToutesLues(_userId);
    setState(() {
      _notifs = _notifs.map((n) => {...n, 'lu': true}).toList();
    });
  }

  IconData _icone(String type) {
    switch (type) {
      case 'nouveau_message': return Icons.chat_outlined;
      case 'statut_change': return Icons.local_shipping_outlined;
      case 'livraison_livree': return Icons.check_circle_outline;
      case 'nouvelle_proposition': return Icons.price_change_outlined;
      case 'coursier_assigne': return Icons.delivery_dining;
      case 'dossier_valide': return Icons.verified_outlined;
      case 'dossier_rejete': return Icons.cancel_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _couleur(String type) {
    switch (type) {
      case 'nouveau_message': return AppColors.bleuPrimaire;
      case 'livraison_livree': return AppColors.succes;
      case 'nouvelle_proposition': return AppColors.orange;
      case 'dossier_valide': return AppColors.succes;
      case 'dossier_rejete': return AppColors.erreur;
      default: return AppColors.bleuPrimaire;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nonLues = _notifs.where((n) => n['lu'] == false).length;
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications'),
            if (nonLues > 0)
              Text('$nonLues non lue(s)', style: const TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          if (nonLues > 0)
            TextButton(onPressed: _toutMarquerLu, child: const Text('Tout lire')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.bleuPrimaire))
          : _notifs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_outlined, size: 64, color: AppColors.grisClair),
                      SizedBox(height: 16),
                      Text('Aucune notification', style: TextStyle(color: AppColors.gris, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _charger,
                  child: ListView.separated(
                    itemCount: _notifs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) {
                      final n = _notifs[i];
                      final lu = n['lu'] as bool? ?? false;
                      final couleur = _couleur(n['type'] ?? '');
                      return ListTile(
                        leading: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: couleur.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                          child: Icon(_icone(n['type'] ?? ''), color: couleur, size: 22),
                        ),
                        title: Text(n['titre'] ?? '', style: TextStyle(fontWeight: lu ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['message'] ?? '', style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(Helpers.tempsEcoule(DateTime.parse(n['created_at'])), style: const TextStyle(fontSize: 11, color: AppColors.grisClair)),
                          ],
                        ),
                        tileColor: lu ? null : AppColors.bleuPrimaire.withOpacity(0.04),
                        trailing: lu ? null : Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: AppColors.bleuPrimaire, shape: BoxShape.circle),
                        ),
                        onTap: () {
                          // Marquer comme lu
                          Supabase.instance.client
                              .from(SupabaseConfig.tableNotifications)
                              .update({'lu': true}).eq('id', n['id']);
                          setState(() => _notifs[i] = {...n, 'lu': true});
                          // Naviguer vers le détail si c'est une livraison
                          if (n['type'] == 'statut_change' || n['type'] == 'livraison_livree' || n['type'] == 'nouvelle_proposition' || n['type'] == 'coursier_assigne') {
                            if (n['data'] != null && n['data']['livraison_id'] != null) {
                              context.push('${AppRoutes.clientDetailLivraison}/${n['data']['livraison_id']}');
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/format_prix.dart';
import '../../../data/repositories/livraison_repository.dart';
import '../../../data/models/models.dart';
import '../../../services/location_service.dart';
import '../../../services/call_service.dart';
import '../../../config/router.dart';
import '../../widgets/common/widgets.dart';

// ─────────────────────────────────────────────────────────────
// Écran Suivi Livraison — côté CLIENT
// Affiche la carte avec le coursier en temps réel,
// le statut, et les actions de contact
// ─────────────────────────────────────────────────────────────

class SuiviLivraisonScreen extends ConsumerStatefulWidget {
  final String livraisonId;
  const SuiviLivraisonScreen({super.key, required this.livraisonId});

  @override
  ConsumerState<SuiviLivraisonScreen> createState() => _State();
}

class _State extends ConsumerState<SuiviLivraisonScreen> {
  final MapController _mapCtrl = MapController();
  LivraisonModel? _livraison;
  LatLng? _posCoursier;
  bool _loading = true;
  dynamic _channelLiv, _channelGps;
  List<LatLng> _polyline = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final liv = await ref.read(livraisonRepositoryProvider).getLivraison(widget.livraisonId);
      setState(() { _livraison = liv; _loading = false; });

      // Écouter les updates de statut
      _channelLiv = ref.read(livraisonRepositoryProvider).ecouterLivraison(
        livraisonId: widget.livraisonId,
        onUpdate: (updated) {
          setState(() => _livraison = updated);
          if (updated.statut == StatutLivraison.livree) {
            _onLivraisonTerminee();
          }
        },
      );

      // Écouter le GPS du coursier
      if (liv.coursierId != null) {
        _channelGps = ref.read(locationServiceProvider).ecouterPositionCoursier(
          coursierId: liv.coursierId!,
          onPosition: (lat, lng) {
            setState(() => _posCoursier = LatLng(lat, lng));
            _mapCtrl.move(LatLng(lat, lng), _mapCtrl.camera.zoom);
          },
        );
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _onLivraisonTerminee() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Livraison effectuée ! 🎉'),
        content: const Text('Votre colis a été livré. Souhaitez-vous noter votre coursier ?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/client/detail/${widget.livraisonId}');
            },
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _noterCoursier();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.bleuPrimaire),
            child: const Text('Noter maintenant', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _noterCoursier() async {
    int _noteSelectionnee = 5;
    final commentaireCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Noter votre coursier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setModal(() => _noteSelectionnee = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < _noteSelectionnee ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 16),
              NymeTextField(controller: commentaireCtrl, label: 'Commentaire (optionnel)', hint: 'Rapide, professionnel...', maxLines: 3),
              const SizedBox(height: 16),
              NymeButton(
                label: 'Envoyer la note',
                onPressed: () async {
                  // TODO: appeler coursierRepository.noterCoursier
                  Navigator.pop(context);
                  Helpers.snackSuccess(context, 'Note envoyée, merci !');
                  context.go(AppRoutes.clientHome);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _appelerCoursier() async {
    if (_livraison?.coursier?.telephone == null) return;
    await ref.read(callServiceProvider).appelerTelephone(
      appelantId: 'CURRENT_USER_ID',
      appelantRole: 'client',
      destinataireId: _livraison!.coursierId!,
      numero: _livraison!.coursier!.telephone,
      livraisonId: widget.livraisonId,
    );
  }

  Future<void> _whatsappCoursier() async {
    final num = _livraison?.coursier?.whatsapp ?? _livraison?.coursier?.telephone;
    if (num == null) return;
    await ref.read(callServiceProvider).ouvrirWhatsApp(
      appelantId: 'CURRENT_USER_ID',
      appelantRole: 'client',
      destinataireId: _livraison!.coursierId!,
      numeroWhatsapp: num,
      livraisonId: widget.livraisonId,
      messageInitial: 'Bonjour, je vous contacte pour ma livraison NYME.',
    );
  }

  LatLng get _centreDepart => LatLng(
    _livraison?.departLat ?? 12.3569,
    _livraison?.departLng ?? -1.5353,
  );

  LatLng get _centreArrivee => LatLng(
    _livraison?.arriveeLat ?? 12.3569,
    _livraison?.arriveeLng ?? -1.5353,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.bleuPrimaire))
          : Stack(
              children: [
                // ── Carte ──
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _posCoursier ?? _centreDepart,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.nyme.app',
                    ),
                    if (_polyline.isNotEmpty)
                      PolylineLayer(polylines: [
                        Polyline(points: _polyline, strokeWidth: 4, color: AppColors.bleuPrimaire),
                      ]),
                    MarkerLayer(markers: [
                      // Départ
                      Marker(
                        point: _centreDepart,
                        width: 36, height: 36,
                        child: Container(
                          decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.radio_button_checked, color: Colors.white, size: 20),
                        ),
                      ),
                      // Arrivée
                      Marker(
                        point: _centreArrivee,
                        width: 36, height: 36,
                        child: const Icon(Icons.location_on, color: AppColors.erreur, size: 36),
                      ),
                      // Coursier
                      if (_posCoursier != null)
                        Marker(
                          point: _posCoursier!,
                          width: 50, height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.bleuPrimaire,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: const Icon(Icons.delivery_dining, color: Colors.white, size: 24),
                          ),
                        ),
                    ]),
                  ],
                ),

                // ── Bouton retour ──
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'retour',
                    onPressed: () => context.pop(),
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.noir,
                    child: const Icon(Icons.arrow_back_ios, size: 16),
                  ),
                ),

                // ── Panneau du bas ──
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
                    ),
                    padding: EdgeInsets.only(
                      left: 20, right: 20, top: 20,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Poignée
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grisClair, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 16),

                        // Statut
                        StatutBadge(statut: _livraison?.statut.name ?? 'en_attente'),
                        const SizedBox(height: 12),

                        // Info coursier
                        if (_livraison?.coursier != null) ...[
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.fondInput,
                                backgroundImage: _livraison!.coursier!.avatarUrl != null
                                    ? NetworkImage(_livraison!.coursier!.avatarUrl!)
                                    : null,
                                child: _livraison!.coursier!.avatarUrl == null
                                    ? Text(Helpers.initiales(_livraison!.coursier!.nom), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.bleuPrimaire))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_livraison!.coursier!.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text('⭐ ${_livraison!.coursier!.noteMoyenne.toStringAsFixed(1)} · Votre coursier', style: const TextStyle(color: AppColors.gris, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Boutons contact
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _appelerCoursier,
                                  icon: const Icon(Icons.phone_outlined, size: 18),
                                  label: const Text('Appeler'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.bleuPrimaire,
                                    side: const BorderSide(color: AppColors.bleuPrimaire),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _whatsappCoursier,
                                  icon: const Icon(Icons.chat_outlined, size: 18),
                                  label: const Text('WhatsApp'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.succes,
                                    side: const BorderSide(color: AppColors.succes),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () => context.push('/chat/${widget.livraisonId}/${_livraison!.coursierId}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.orange,
                                  side: const BorderSide(color: AppColors.orange),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  minimumSize: const Size(44, 44),
                                ),
                                child: const Icon(Icons.message_outlined, size: 18),
                              ),
                            ],
                          ),
                        ] else ...[
                          const Text('En attente d\'un coursier...', style: TextStyle(color: AppColors.gris)),
                        ],

                        const SizedBox(height: 8),
                        // Prix final
                        if (_livraison?.prixFinal != null)
                          Text(
                            'Total : ${FormatPrix.fcfa(_livraison!.prixFinal!)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.bleuPrimaire),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}


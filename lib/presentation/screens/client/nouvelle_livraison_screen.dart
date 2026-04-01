import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/format_prix.dart';
import '../../../data/repositories/livraison_repository.dart';
import '../../../data/models/models.dart';
import '../../../services/map_service.dart';
import '../../../config/router.dart';
import '../../widgets/common/widgets.dart';
import 'adresses_favorites_screen.dart';
import 'contacts_favoris_screen.dart';

// ─────────────────────────────────────────────────────────────
// Écran Nouvelle Livraison — étapes :
// 1. Adresses départ / arrivée
// 2. Destinataire
// 3. Colis (photos, instructions)
// 4. Type de course + date programmée
// 5. Calcul prix et confirmation
// ─────────────────────────────────────────────────────────────

class NouvelleLivraisonScreen extends ConsumerStatefulWidget {
  final String? typeInitial;
  final bool? pourTiersInitial;
  const NouvelleLivraisonScreen({super.key, this.typeInitial, this.pourTiersInitial});

  @override
  ConsumerState<NouvelleLivraisonScreen> createState() => _State();
}

class _State extends ConsumerState<NouvelleLivraisonScreen> {
  final _pageCtrl = PageController();
  int _etape = 0;

  // Adresses
  final _departCtrl = TextEditingController();
  final _arriveeCtrl = TextEditingController();
  double? _departLat, _departLng, _arriveeLat, _arriveeLng;

  // Destinataire
  final _nomDestCtrl = TextEditingController();
  final _telDestCtrl = TextEditingController();
  final _whatsappDestCtrl = TextEditingController();
  final _emailDestCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  bool _pourTiers = false;

  // Colis
  final List<File> _photos = [];
  final _picker = ImagePicker();

  // Type de course
  String _typeCourse = 'immediate';
  DateTime? _dateProgrammee;

  // Prix
  double? _prixCalcule;
  double? _distanceKm;
  int? _dureeMin;
  bool _calcul = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _pourTiers = widget.pourTiersInitial ?? false;
    _typeCourse = widget.typeInitial ?? 'immediate';
    _obtenirPositionActuelle();
  }

  Future<void> _obtenirPositionActuelle() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _departLat = pos.latitude;
        _departLng = pos.longitude;
        _departCtrl.text = 'Ma position actuelle';
      });
    } catch (_) {}
  }

  void _etapeSuivante() {
    if (_etape < 3) {
      if (!_validerEtape()) return;
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _etape++);
    } else {
      _calculerEtConfirmer();
    }
  }

  void _etapePrecedente() {
    if (_etape > 0) {
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _etape--);
    } else {
      context.pop();
    }
  }

  bool _validerEtape() {
    switch (_etape) {
      case 0:
        if (_departCtrl.text.isEmpty || _arriveeCtrl.text.isEmpty) {
          Helpers.snackErreur(context, 'Indiquez le départ et la destination');
          return false;
        }
        if (_departLat == null || _arriveeLat == null) {
          Helpers.snackErreur(context, 'Impossible de localiser les adresses');
          return false;
        }
        return true;
      case 1:
        if (_nomDestCtrl.text.isEmpty || _telDestCtrl.text.isEmpty) {
          Helpers.snackErreur(context, 'Nom et téléphone du destinataire obligatoires');
          return false;
        }
        return true;
      case 2:
        return true;
      case 3:
        if (_typeCourse == 'programmee' && _dateProgrammee == null) {
          Helpers.snackErreur(context, 'Choisissez une date et heure');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _calculerEtConfirmer() async {
    setState(() => _calcul = true);
    try {
      final mapService = ref.read(mapServiceProvider);
      final result = await mapService.calculerItineraire(
        depart: LatLng(_departLat!, _departLng!),
        arrivee: LatLng(_arriveeLat!, _arriveeLng!),
      );

      if (result == null) throw Exception('Impossible de calculer l\'itinéraire');

      final prix = mapService.calculerPrix(
        distanceKm: result.distanceKm,
        dureeMinutes: result.dureeMinutes,
        estUrgent: _typeCourse == 'urgente',
      );

      setState(() {
        _distanceKm = result.distanceKm;
        _dureeMin = result.dureeMinutes;
        _prixCalcule = prix;
        _calcul = false;
      });

      _afficherConfirmation();
    } catch (e) {
      setState(() => _calcul = false);
      Helpers.snackErreur(context, 'Erreur calcul: $e');
    }
  }

  Future<void> _afficherConfirmation() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PanneauConfirmation(
        prixCalcule: _prixCalcule!,
        distanceKm: _distanceKm!,
        dureeMin: _dureeMin!,
        typeCourse: _typeCourse,
        onConfirmer: _commander,
      ),
    );
  }

  Future<void> _commander() async {
    Navigator.pop(context); // fermer le panneau
    setState(() => _loading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final livraison = await ref.read(livraisonRepositoryProvider).creerLivraison(
        clientId: userId,
        departAdresse: _departCtrl.text,
        departLat: _departLat!,
        departLng: _departLng!,
        arriveeAdresse: _arriveeCtrl.text,
        arriveeLat: _arriveeLat!,
        arriveeLng: _arriveeLng!,
        destinataireNom: _nomDestCtrl.text.trim(),
        destinataireTel: _telDestCtrl.text.trim(),
        destinataireWhatsapp: _whatsappDestCtrl.text.isEmpty ? null : _whatsappDestCtrl.text.trim(),
        destinataireEmail: _emailDestCtrl.text.isEmpty ? null : _emailDestCtrl.text.trim(),
        instructions: _instructionsCtrl.text.isEmpty ? null : _instructionsCtrl.text.trim(),
        photosColis: _photos,
        prixCalcule: _prixCalcule!,
        type: TypeCourse.values.firstWhere((t) => t.name == _typeCourse),
        pourTiers: _pourTiers,
        programmeLe: _dateProgrammee,
      );

      if (!mounted) return;
      Helpers.snackSuccess(context, 'Livraison créée !');
      // Aller vers les propositions de prix
      context.go('/client/propositions-prix/${livraison.id}');
    } catch (e) {
      Helpers.snackErreur(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ajouterPhoto() async {
    if (_photos.length >= 5) {
      Helpers.snackInfo(context, 'Maximum 5 photos');
      return;
    }
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter une photo'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Caméra'),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          TextButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text('Galerie'),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null) return;
    final xFile = await _picker.pickImage(source: source, imageQuality: 75);
    if (xFile != null) setState(() => _photos.add(File(xFile.path)));
  }

  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 15)),
      locale: const Locale('fr'),
    );
    if (date == null || !mounted) return;

    final heure = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (heure == null) return;

    setState(() {
      _dateProgrammee = DateTime(date.year, date.month, date.day, heure.hour, heure.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      loading: _loading || _calcul,
      child: Scaffold(
        backgroundColor: AppColors.fondPrincipal,
        appBar: AppBar(
          title: Text(_titreEtape()),
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: _etapePrecedente),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_etape + 1) / 4,
              backgroundColor: AppColors.fondInput,
              color: AppColors.bleuPrimaire,
            ),
          ),
        ),
        body: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _EtapeAdresses(
              departCtrl: _departCtrl,
              arriveeCtrl: _arriveeCtrl,
              pourTiers: _pourTiers,
              onToggleTiers: (v) => setState(() => _pourTiers = v),
              onPositionDepart: (lat, lng) => setState(() { _departLat = lat; _departLng = lng; }),
              onPositionArrivee: (lat, lng) => setState(() { _arriveeLat = lat; _arriveeLng = lng; }),
              onAdresseFavorite: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdressesFavoritesScreen(
                    onSelectionner: (a) {
                      setState(() {
                        _arriveeCtrl.text = a.adresse;
                        _arriveeLat = a.latitude;
                        _arriveeLng = a.longitude;
                      });
                    },
                  ),
                ),
              ),
            ),
            _EtapeDestinataire(
              nomCtrl: _nomDestCtrl,
              telCtrl: _telDestCtrl,
              whatsappCtrl: _whatsappDestCtrl,
              emailCtrl: _emailDestCtrl,
              pourTiers: _pourTiers,
              onContactFavori: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContactsFavorisScreen(
                    onSelectionner: (c) {
                      setState(() {
                        _nomDestCtrl.text = c['nom'] ?? '';
                        _telDestCtrl.text = c['telephone'] ?? '';
                        _whatsappDestCtrl.text = c['whatsapp'] ?? '';
                        _emailDestCtrl.text = c['email'] ?? '';
                      });
                    },
                  ),
                ),
              ),
            ),
            _EtapeColis(
              photos: _photos,
              instructionsCtrl: _instructionsCtrl,
              onAjouterPhoto: _ajouterPhoto,
              onSupprimerPhoto: (i) => setState(() => _photos.removeAt(i)),
            ),
            _EtapeType(
              typeCourse: _typeCourse,
              dateProgrammee: _dateProgrammee,
              onTypeChange: (v) => setState(() => _typeCourse = v),
              onChoisirDate: _choisirDate,
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: NymeButton(
              label: _etape == 3 ? 'Calculer le prix' : 'Continuer',
              onPressed: _etapeSuivante,
              loading: _calcul,
              icon: _etape == 3 ? Icons.calculate_outlined : Icons.arrow_forward,
            ),
          ),
        ),
      ),
    );
  }

  String _titreEtape() {
    switch (_etape) {
      case 0: return 'Adresses';
      case 1: return 'Destinataire';
      case 2: return 'Le colis';
      case 3: return 'Type de course';
      default: return 'Nouvelle livraison';
    }
  }
}

// ════════════════════════════════════════
// ÉTAPES
// ════════════════════════════════════════

class _EtapeAdresses extends StatelessWidget {
  final TextEditingController departCtrl, arriveeCtrl;
  final bool pourTiers;
  final void Function(bool) onToggleTiers;
  final void Function(double, double) onPositionDepart;
  final void Function(double, double) onPositionArrivee;
  final VoidCallback onAdresseFavorite;

  const _EtapeAdresses({
    required this.departCtrl, required this.arriveeCtrl,
    required this.pourTiers, required this.onToggleTiers,
    required this.onPositionDepart, required this.onPositionArrivee,
    required this.onAdresseFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            title: const Text('Commander pour quelqu\'un d\'autre', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('La livraison sera faite à un tiers'),
            value: pourTiers,
            onChanged: onToggleTiers,
            activeColor: AppColors.bleuPrimaire,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 24),
          const Text('📍 Départ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          NymeTextField(
            controller: departCtrl,
            label: 'Point de départ',
            hint: 'Adresse ou quartier',
            prefixIcon: Icons.radio_button_checked,
          ),
          const SizedBox(height: 16),
          const Text('🏁 Destination', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          NymeTextField(
            controller: arriveeCtrl,
            label: 'Adresse de livraison',
            hint: 'Secteur, rue, repère...',
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAdresseFavorite,
            icon: const Icon(Icons.star_border, size: 18),
            label: const Text('Choisir une adresse favorite'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.bleuPrimaire,
              side: const BorderSide(color: AppColors.bleuPrimaire),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bleuPrimaire.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.bleuPrimaire, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Soyez précis dans les adresses pour un calcul de prix exact.',
                    style: TextStyle(fontSize: 13, color: AppColors.bleuPrimaire),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EtapeDestinataire extends StatelessWidget {
  final TextEditingController nomCtrl, telCtrl, whatsappCtrl, emailCtrl;
  final bool pourTiers;
  final VoidCallback onContactFavori;

  const _EtapeDestinataire({
    required this.nomCtrl, required this.telCtrl,
    required this.whatsappCtrl, required this.emailCtrl,
    required this.pourTiers, required this.onContactFavori,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pourTiers) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person_outline, color: AppColors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('Vous commandez pour quelqu\'un d\'autre', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w500, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          OutlinedButton.icon(
            onPressed: onContactFavori,
            icon: const Icon(Icons.people_outline, size: 18),
            label: const Text('Choisir depuis mes contacts'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.bleuPrimaire,
              side: const BorderSide(color: AppColors.bleuPrimaire),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          NymeTextField(controller: nomCtrl, label: 'Nom du destinataire *', hint: 'Jean Dupont', prefixIcon: Icons.person_outline),
          const SizedBox(height: 12),
          NymeTextField(controller: telCtrl, label: 'Téléphone *', hint: '+226 70 00 00 00', prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          NymeTextField(controller: whatsappCtrl, label: 'WhatsApp', hint: 'Même numéro ou différent', prefixIcon: Icons.chat_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          NymeTextField(controller: emailCtrl, label: 'Email (optionnel)', hint: 'jean@email.com', prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        ],
      ),
    );
  }
}

class _EtapeColis extends StatelessWidget {
  final List<File> photos;
  final TextEditingController instructionsCtrl;
  final VoidCallback onAjouterPhoto;
  final void Function(int) onSupprimerPhoto;

  const _EtapeColis({
    required this.photos, required this.instructionsCtrl,
    required this.onAjouterPhoto, required this.onSupprimerPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📸 Photos du colis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Jusqu\'à 5 photos (optionnel mais recommandé)', style: TextStyle(color: AppColors.gris, fontSize: 13)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
            ),
            itemCount: photos.length + (photos.length < 5 ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == photos.length) {
                return GestureDetector(
                  onTap: onAjouterPhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.fondInput,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.grisClair, style: BorderStyle.solid),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: AppColors.gris, size: 28),
                        SizedBox(height: 4),
                        Text('Ajouter', style: TextStyle(fontSize: 11, color: AppColors.gris)),
                      ],
                    ),
                  ),
                );
              }
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(photos[i], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => onSupprimerPhoto(i),
                      child: Container(
                        decoration: const BoxDecoration(color: AppColors.erreur, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('📝 Instructions spéciales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          NymeTextField(
            controller: instructionsCtrl,
            label: 'Instructions pour le coursier',
            hint: 'Ex: Appeler avant d\'arriver, colis fragile, laisser à la gardienne...',
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}

class _EtapeType extends StatelessWidget {
  final String typeCourse;
  final DateTime? dateProgrammee;
  final void Function(String) onTypeChange;
  final VoidCallback onChoisirDate;

  const _EtapeType({
    required this.typeCourse, required this.dateProgrammee,
    required this.onTypeChange, required this.onChoisirDate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Type de course', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _CarteType(
            icone: '⚡',
            titre: 'Immédiate',
            sous: 'Le coursier part maintenant',
            couleur: AppColors.bleuPrimaire,
            selectionne: typeCourse == 'immediate',
            onTap: () => onTypeChange('immediate'),
          ),
          const SizedBox(height: 10),
          _CarteType(
            icone: '🔥',
            titre: 'Urgente',
            sous: 'Priorité maximale — tarif +30%',
            couleur: AppColors.erreur,
            selectionne: typeCourse == 'urgente',
            onTap: () => onTypeChange('urgente'),
          ),
          const SizedBox(height: 10),
          _CarteType(
            icone: '📅',
            titre: 'Programmée',
            sous: 'Planifier jusqu\'à 15 jours à l\'avance',
            couleur: AppColors.orange,
            selectionne: typeCourse == 'programmee',
            onTap: () => onTypeChange('programmee'),
          ),
          if (typeCourse == 'programmee') ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onChoisirDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dateProgrammee != null
                            ? Helpers.dateComplete(dateProgrammee!)
                            : 'Choisir date et heure',
                        style: TextStyle(
                          color: dateProgrammee != null ? AppColors.noir : AppColors.gris,
                          fontWeight: dateProgrammee != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.gris),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CarteType extends StatelessWidget {
  final String icone, titre, sous;
  final Color couleur;
  final bool selectionne;
  final VoidCallback onTap;

  const _CarteType({
    required this.icone, required this.titre, required this.sous,
    required this.couleur, required this.selectionne, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selectionne ? couleur.withOpacity(0.08) : AppColors.blanc,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selectionne ? couleur : AppColors.grisClair,
            width: selectionne ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icone, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: selectionne ? couleur : AppColors.noir)),
                  Text(sous, style: const TextStyle(color: AppColors.gris, fontSize: 12)),
                ],
              ),
            ),
            if (selectionne) Icon(Icons.check_circle, color: couleur),
          ],
        ),
      ),
    );
  }
}

// ── Panneau de confirmation prix ──
class _PanneauConfirmation extends StatelessWidget {
  final double prixCalcule, distanceKm;
  final int dureeMin;
  final String typeCourse;
  final VoidCallback onConfirmer;

  const _PanneauConfirmation({
    required this.prixCalcule, required this.distanceKm,
    required this.dureeMin, required this.typeCourse, required this.onConfirmer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grisClair, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Résumé de la livraison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Infos
          _LignInfo('📏 Distance', '${distanceKm.toStringAsFixed(1)} km'),
          _LignInfo('⏱️ Durée estimée', '$dureeMin minutes'),
          if (typeCourse == 'urgente')
            _LignInfo('🔥 Tarif urgent', '+30%', couleur: AppColors.erreur),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Prix total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                FormatPrix.fcfa(prixCalcule),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.bleuPrimaire),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ce prix est indicatif. Vous pouvez proposer un autre montant ou attendre les offres des coursiers.',
            style: TextStyle(color: AppColors.gris, fontSize: 12),
          ),
          const SizedBox(height: 20),

          NymeButton(label: 'Confirmer et trouver un coursier', onPressed: onConfirmer),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Modifier ma demande', style: TextStyle(color: AppColors.gris)),
          ),
        ],
      ),
    );
  }
}

class _LignInfo extends StatelessWidget {
  final String label, valeur;
  final Color? couleur;
  const _LignInfo(this.label, this.valeur, {this.couleur});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.gris)),
          Text(valeur, style: TextStyle(fontWeight: FontWeight.w600, color: couleur ?? AppColors.noir)),
        ],
      ),
    );
  }
}


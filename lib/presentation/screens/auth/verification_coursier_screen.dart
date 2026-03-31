import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../config/supabase_config.dart';
import '../../../config/router.dart';
import '../../widgets/common/nyme_button.dart';
import '../../widgets/common/nyme_text_field.dart';
import '../../widgets/common/loading_overlay.dart';

class VerificationCoursierScreen extends ConsumerStatefulWidget {
  const VerificationCoursierScreen({super.key});
  @override
  ConsumerState<VerificationCoursierScreen> createState() => _State();
}

class _State extends ConsumerState<VerificationCoursierScreen> {
  final _marqueCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _couleurCtrl = TextEditingController();
  final _plaqueCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();

  String _typeVehicule = 'moto';
  File? _cniRecto, _cniVerso, _permis, _carteGrise;
  bool _loading = false;

  final _picker = ImagePicker();

  Future<void> _pickImage(String type) async {
    final xFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (xFile == null) return;
    setState(() {
      final file = File(xFile.path);
      switch (type) {
        case 'cni_recto': _cniRecto = file; break;
        case 'cni_verso': _cniVerso = file; break;
        case 'permis': _permis = file; break;
        case 'carte_grise': _carteGrise = file; break;
      }
    });
  }

  Future<String?> _upload(File file, String path) async {
    await Supabase.instance.client.storage
        .from(SupabaseConfig.bucketIdentites)
        .upload(path, file, fileOptions: const FileOptions(upsert: true));
    return Supabase.instance.client.storage
        .from(SupabaseConfig.bucketIdentites)
        .getPublicUrl(path);
  }

  Future<void> _soumettre() async {
    if (_cniRecto == null || _cniVerso == null || _permis == null || _carteGrise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter tous les documents'), backgroundColor: AppColors.erreur),
      );
      return;
    }
    if (_marqueCtrl.text.isEmpty || _plaqueCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remplissez toutes les infos du véhicule'), backgroundColor: AppColors.erreur),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final cniRectoUrl = await _upload(_cniRecto!, 'cni_recto/$userId.jpg');
      final cniVersoUrl = await _upload(_cniVerso!, 'cni_verso/$userId.jpg');
      final permisUrl = await _upload(_permis!, 'permis/$userId.jpg');
      final carteGriseUrl = await _upload(_carteGrise!, 'carte_grise/$userId.jpg');

      // Mettre à jour le profil coursier
      await Supabase.instance.client
          .from(SupabaseConfig.tableCoursiers)
          .update({
            'cni_recto_url': cniRectoUrl,
            'cni_verso_url': cniVersoUrl,
            'permis_url': permisUrl,
            'statut_verification': 'en_attente',
          }).eq('id', userId);

      // Créer le véhicule
      await Supabase.instance.client.from(SupabaseConfig.tableVehicules).insert({
        'coursier_id': userId,
        'type': _typeVehicule,
        'marque': _marqueCtrl.text.trim(),
        'modele': _modeleCtrl.text.trim(),
        'couleur': _couleurCtrl.text.trim(),
        'plaque': _plaqueCtrl.text.trim().toUpperCase(),
        'carte_grise_url': carteGriseUrl,
        'est_verifie': false,
      });

      // Mettre à jour WhatsApp si fourni
      if (_whatsappCtrl.text.isNotEmpty) {
        await Supabase.instance.client
            .from(SupabaseConfig.tableUtilisateurs)
            .update({'whatsapp': _whatsappCtrl.text.trim()}).eq('id', userId);
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Dossier soumis ✓'),
          content: const Text(
            'Votre dossier est en cours de vérification par notre équipe. '
            'Vous serez notifié dans les 24-48h.',
          ),
          actions: [
            TextButton(
              onPressed: () => context.go(AppRoutes.coursierHome),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.erreur),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      loading: _loading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Vérification d\'identité')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title: '📄 Documents d\'identité'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _DocCard(label: 'CNI Recto', file: _cniRecto, onTap: () => _pickImage('cni_recto'))),
                  const SizedBox(width: 12),
                  Expanded(child: _DocCard(label: 'CNI Verso', file: _cniVerso, onTap: () => _pickImage('cni_verso'))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _DocCard(label: 'Permis de conduire', file: _permis, onTap: () => _pickImage('permis'))),
                  const SizedBox(width: 12),
                  Expanded(child: _DocCard(label: 'Carte grise', file: _carteGrise, onTap: () => _pickImage('carte_grise'))),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: '🛵 Informations du véhicule'),
              const SizedBox(height: 12),

              // Type véhicule
              DropdownButtonFormField<String>(
                value: _typeVehicule,
                decoration: InputDecoration(
                  labelText: 'Type de véhicule',
                  filled: true,
                  fillColor: AppColors.fondInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'moto', child: Text('🏍️ Moto')),
                  DropdownMenuItem(value: 'velo', child: Text('🚲 Vélo')),
                  DropdownMenuItem(value: 'voiture', child: Text('🚗 Voiture')),
                  DropdownMenuItem(value: 'camionnette', child: Text('🚐 Camionnette')),
                ],
                onChanged: (v) => setState(() => _typeVehicule = v!),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: NymeTextField(controller: _marqueCtrl, label: 'Marque', hint: 'Honda')),
                  const SizedBox(width: 12),
                  Expanded(child: NymeTextField(controller: _modeleCtrl, label: 'Modèle', hint: 'CB 125')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: NymeTextField(controller: _couleurCtrl, label: 'Couleur', hint: 'Rouge')),
                  const SizedBox(width: 12),
                  Expanded(child: NymeTextField(controller: _plaqueCtrl, label: 'Plaque', hint: 'AB-1234-BF')),
                ],
              ),
              const SizedBox(height: 12),
              NymeTextField(
                controller: _whatsappCtrl,
                label: 'Numéro WhatsApp',
                hint: '+226 70 00 00 00',
                prefixIcon: Icons.whatsapp,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 32),
              NymeButton(label: AppStrings.soumettreDossier, onPressed: _soumettre),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.noir));
  }
}

class _DocCard extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;
  const _DocCard({required this.label, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: file != null ? AppColors.succes.withOpacity(0.1) : AppColors.fondInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file != null ? AppColors.succes : AppColors.grisClair,
            width: 1.5,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    Image.file(file!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                    Positioned(top: 6, right: 6, child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppColors.succes, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                    )),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, color: AppColors.gris, size: 32),
                  const SizedBox(height: 6),
                  Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
                ],
              ),
      ),
    );
  }
}

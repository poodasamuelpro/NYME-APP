import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../widgets/common/widgets.dart';

class ProfilClientScreen extends ConsumerStatefulWidget {
  const ProfilClientScreen({super.key});

  @override
  ConsumerState<ProfilClientScreen> createState() => _ProfilClientScreenState();
}

class _ProfilClientScreenState extends ConsumerState<ProfilClientScreen> {
  UtilisateurModel? _utilisateur;
  bool _loading = true;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomController;
  late TextEditingController _telephoneController;
  late TextEditingController _emailController;
  late TextEditingController _whatsappController;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController();
    _telephoneController = TextEditingController();
    _emailController = TextEditingController();
    _whatsappController = TextEditingController();
    _chargerProfil();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _chargerProfil() async {
    final authRepo = ref.read(authRepositoryProvider);
    final userId = authRepo.currentUserId;
    if (userId == null) {
      // Gérer le cas où l'utilisateur n'est pas connecté
      setState(() {
        _loading = false;
      });
      return;
    }
    try {
      final user = await authRepo.getProfilUtilisateur(userId);
      setState(() {
        _utilisateur = user;
        _nomController.text = user.nom;
        _telephoneController.text = user.telephone;
        _emailController.text = user.email ?? '';
        _whatsappController.text = user.whatsapp ?? '';
        _loading = false;
      });
    } catch (e) {
      Helpers.showSnackBar(context, 'Erreur de chargement du profil: $e', isError: true);
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _mettreAJourProfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final userId = authRepo.currentUserId;
      if (userId == null) return;

      final updatedUser = await authRepo.mettreAJourProfil(
        userId: userId,
        nom: _nomController.text,
        telephone: _telephoneController.text,
        whatsapp: _whatsappController.text,
      );
      setState(() {
        _utilisateur = updatedUser;
        _loading = false;
      });
      Helpers.showSnackBar(context, 'Profil mis à jour avec succès !');
    } catch (e) {
      Helpers.showSnackBar(context, 'Erreur de mise à jour: $e', isError: true);
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondPrincipal,
      appBar: AppBar(title: const Text(AppStrings.profil)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.bleuPrimaire))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: AppColors.grisClair,
                            backgroundImage: _utilisateur?.avatarUrl != null
                                ? NetworkImage(_utilisateur!.avatarUrl!) as ImageProvider
                                : null,
                            child: _utilisateur?.avatarUrl == null
                                ? Icon(Icons.person, size: 60, color: AppColors.blanc)
                                : null,
                          ),
                          Positioned(bottom: 0, right: 0, child: _buildEditAvatarButton()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    NymeTextField(
                      controller: _nomController,
                      label: 'Nom complet',
                      hintText: 'Votre nom',
                      validator: (val) => val!.isEmpty ? 'Le nom est requis' : null,
                    ),
                    const SizedBox(height: 16),
                    NymeTextField(
                      controller: _telephoneController,
                      label: 'Téléphone',
                      hintText: 'Votre numéro de téléphone',
                      keyboardType: TextInputType.phone,
                      validator: (val) => val!.isEmpty ? 'Le téléphone est requis' : null,
                    ),
                    const SizedBox(height: 16),
                    NymeTextField(
                      controller: _emailController,
                      label: 'Email',
                      hintText: 'Votre adresse email',
                      keyboardType: TextInputType.emailAddress,
                      readOnly: true, // L'email ne peut pas être modifié directement ici
                      // validator: (val) => Helpers.emailValide(val) ? null : 'Email invalide',
                    ),
                    const SizedBox(height: 16),
                    NymeTextField(
                      controller: _whatsappController,
                      label: 'Numéro WhatsApp (optionnel)',
                      hintText: 'Votre numéro WhatsApp',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    NymeButton(
                      label: 'Mettre à jour le profil',
                      onPressed: _mettreAJourProfil,
                      isLoading: _loading,
                    ),
                    const SizedBox(height: 16),
                    NymeButton(
                      label: 'Changer le mot de passe',
                      onPressed: () {
                        // TODO: Implémenter la navigation vers l'écran de changement de mot de passe
                        Helpers.showSnackBar(context, 'Fonctionnalité à implémenter');
                      },
                      type: ButtonType.outlined,
                    ),
                    const SizedBox(height: 16),
                    NymeButton(
                      label: 'Déconnexion',
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).deconnecter();
                        context.go(AppRoutes.connexion);
                      },
                      type: ButtonType.text,
                      textColor: AppColors.erreur,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEditAvatarButton() {
    return GestureDetector(
      onTap: () {
        // TODO: Implémenter la sélection et l'upload d'avatar
        Helpers.showSnackBar(context, 'Fonctionnalité d\'upload d\'avatar à implémenter');
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.bleuPrimaire,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.blanc, width: 2),
        ),
        child: const Icon(Icons.camera_alt, color: AppColors.blanc, size: 20),
      ),
    );
  }
}
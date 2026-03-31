import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/models.dart';
import '../../config/router.dart';
import '../widgets/common/nyme_button.dart';
import '../widgets/common/nyme_text_field.dart';
import '../widgets/common/loading_overlay.dart';

class InscriptionScreen extends ConsumerStatefulWidget {
  const InscriptionScreen({super.key});

  @override
  ConsumerState<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends ConsumerState<InscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mdpCtrl = TextEditingController();
  final _confirmMdpCtrl = TextEditingController();

  RoleUtilisateur _role = RoleUtilisateur.client;
  bool _loading = false;
  bool _mdpVisible = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    _confirmMdpCtrl.dispose();
    super.dispose();
  }

  Future<void> _inscrire() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.inscrire(
        nom: _nomCtrl.text.trim(),
        telephone: _telCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        motDePasse: _mdpCtrl.text,
        role: _role,
        whatsapp: _telCtrl.text.trim(),
      );

      if (!mounted) return;

      // Rediriger vers vérification OTP
      context.push(
        AppRoutes.verificationOtp,
        extra: {'telephone': _telCtrl.text.trim()},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.erreur,
        ),
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
        backgroundColor: AppColors.fondPrincipal,
        appBar: AppBar(
          title: const Text('Créer un compte'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Choix du rôle
                  const Text(
                    'Je suis...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.noir,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _RoleCard(
                          titre: AppStrings.jesuisClient,
                          icone: Icons.person_outline,
                          selected: _role == RoleUtilisateur.client,
                          onTap: () => setState(() => _role = RoleUtilisateur.client),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RoleCard(
                          titre: AppStrings.jesuisCoursier,
                          icone: Icons.delivery_dining,
                          selected: _role == RoleUtilisateur.coursier,
                          onTap: () => setState(() => _role = RoleUtilisateur.coursier),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Champs
                  NymeTextField(
                    controller: _nomCtrl,
                    label: AppStrings.nom,
                    hint: 'Jean Dupont',
                    prefixIcon: Icons.person_outline,
                    validator: (v) => v?.isEmpty == true ? AppStrings.champObligatoire : null,
                  ),
                  const SizedBox(height: 16),

                  NymeTextField(
                    controller: _telCtrl,
                    label: AppStrings.telephone,
                    hint: '+226 70 00 00 00',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined,
                    validator: (v) => v?.isEmpty == true ? AppStrings.champObligatoire : null,
                  ),
                  const SizedBox(height: 16),

                  NymeTextField(
                    controller: _emailCtrl,
                    label: AppStrings.email,
                    hint: 'votre@email.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (v) {
                      if (v == null || v.isEmpty) return AppStrings.champObligatoire;
                      if (!v.contains('@')) return AppStrings.emailInvalide;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  NymeTextField(
                    controller: _mdpCtrl,
                    label: AppStrings.motDePasse,
                    hint: 'Minimum 8 caractères',
                    obscureText: !_mdpVisible,
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(_mdpVisible ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _mdpVisible = !_mdpVisible),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return AppStrings.champObligatoire;
                      if (v.length < 8) return AppStrings.motDePasseTropCourt;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  NymeTextField(
                    controller: _confirmMdpCtrl,
                    label: AppStrings.confirmerMotDePasse,
                    hint: 'Répéter le mot de passe',
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (v) {
                      if (v != _mdpCtrl.text) return AppStrings.motDePasseNonCorrespondant;
                      return null;
                    },
                  ),

                  // Info coursier
                  if (_role == RoleUtilisateur.coursier) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Après inscription, vous devrez soumettre vos documents (CNI, permis, carte grise) pour être vérifié.',
                              style: TextStyle(fontSize: 13, color: AppColors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  NymeButton(
                    label: AppStrings.creerCompte,
                    onPressed: _inscrire,
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          AppStrings.dejaMembre,
                          style: TextStyle(color: AppColors.gris),
                        ),
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: const Text(
                            AppStrings.connexion,
                            style: TextStyle(
                              color: AppColors.bleuPrimaire,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String titre;
  final IconData icone;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.titre,
    required this.icone,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.bleuPrimaire : AppColors.fondInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.bleuPrimaire : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icone,
              color: selected ? Colors.white : AppColors.gris,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              titre,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.gris,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

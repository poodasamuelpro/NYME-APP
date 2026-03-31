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

class ConnexionScreen extends ConsumerStatefulWidget {
  const ConnexionScreen({super.key});

  @override
  ConsumerState<ConnexionScreen> createState() => _ConnexionScreenState();
}

class _ConnexionScreenState extends ConsumerState<ConnexionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _mdpCtrl = TextEditingController();
  bool _loading = false;
  bool _mdpVisible = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    super.dispose();
  }

  Future<void> _connecter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final auth = ref.read(authRepositoryProvider);
      final utilisateur = await auth.connecter(
        email: _emailCtrl.text.trim(),
        motDePasse: _mdpCtrl.text,
      );

      if (!mounted) return;

      // Rediriger selon le rôle
      switch (utilisateur.role) {
        case RoleUtilisateur.client:
          context.go(AppRoutes.clientHome);
          break;
        case RoleUtilisateur.coursier:
          context.go(AppRoutes.coursierHome);
          break;
        case RoleUtilisateur.admin:
          context.go(AppRoutes.adminHome);
          break;
      }
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

  Future<void> _connexionOtp() async {
    context.push(AppRoutes.verificationOtp);
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      loading: _loading,
      child: Scaffold(
        backgroundColor: AppColors.fondPrincipal,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // Logo NYME
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.bleuPrimaire,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Center(
                            child: Text(
                              'N',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'NYME',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.bleuPrimaire,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          AppStrings.slogan,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.gris,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  const Text(
                    'Bienvenue 👋',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.noir,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Connectez-vous à votre compte',
                    style: TextStyle(color: AppColors.gris),
                  ),

                  const SizedBox(height: 32),

                  // Email
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

                  // Mot de passe
                  NymeTextField(
                    controller: _mdpCtrl,
                    label: AppStrings.motDePasse,
                    hint: '••••••••',
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

                  // Mot de passe oublié
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {/* TODO: reset password */},
                      child: const Text(
                        AppStrings.motDePasseOublie,
                        style: TextStyle(color: AppColors.bleuPrimaire),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Bouton connexion
                  NymeButton(
                    label: AppStrings.connexion,
                    onPressed: _connecter,
                  ),

                  const SizedBox(height: 16),

                  // Séparateur
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'ou',
                          style: TextStyle(color: AppColors.gris),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Connexion OTP SMS
                  NymeButton(
                    label: 'Connexion par SMS',
                    onPressed: _connexionOtp,
                    outlined: true,
                    icon: Icons.sms_outlined,
                  ),

                  const SizedBox(height: 32),

                  // Lien inscription
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          AppStrings.pasMembre,
                          style: TextStyle(color: AppColors.gris),
                        ),
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.inscription),
                          child: const Text(
                            AppStrings.creerCompte,
                            style: TextStyle(
                              color: AppColors.bleuPrimaire,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

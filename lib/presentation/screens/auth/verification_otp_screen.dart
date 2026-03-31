import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/models.dart';
import '../../../config/router.dart';
import '../../widgets/common/nyme_button.dart';
import '../../widgets/common/loading_overlay.dart';

class VerificationOtpScreen extends ConsumerStatefulWidget {
  final String telephone;
  const VerificationOtpScreen({super.key, required this.telephone});

  @override
  ConsumerState<VerificationOtpScreen> createState() => _VerificationOtpScreenState();
}

class _VerificationOtpScreenState extends ConsumerState<VerificationOtpScreen> {
  String _code = '';
  bool _loading = false;

  Future<void> _verifier() async {
    if (_code.length != 6) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authRepositoryProvider);
      final user = await auth.verifierOtp(telephone: widget.telephone, token: _code);
      if (!mounted) return;
      switch (user.role) {
        case RoleUtilisateur.client:
          context.go(AppRoutes.clientHome);
          break;
        case RoleUtilisateur.coursier:
          context.go(AppRoutes.verificationCoursier);
          break;
        case RoleUtilisateur.admin:
          context.go(AppRoutes.adminHome);
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.erreur),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LoadingOverlay(
      loading: _loading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Vérification SMS')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.sms_outlined, size: 64, color: AppColors.bleuPrimaire),
              const SizedBox(height: 24),
              Text('Code envoyé au', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 4),
              Text(widget.telephone,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.noir)),
              const SizedBox(height: 32),
              Pinput(
                length: 6,
                onChanged: (v) => _code = v,
                onCompleted: (_) => _verifier(),
                defaultPinTheme: PinTheme(
                  width: 52,
                  height: 52,
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: BoxDecoration(
                    color: AppColors.fondInput,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                focusedPinTheme: PinTheme(
                  width: 52,
                  height: 52,
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: BoxDecoration(
                    color: AppColors.fondInput,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bleuPrimaire, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              NymeButton(label: 'Valider le code', onPressed: _verifier),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final auth = ref.read(authRepositoryProvider);
                  await auth.envoyerOtpSms(widget.telephone);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code renvoyé !')),
                  );
                },
                child: const Text('Renvoyer le code', style: TextStyle(color: AppColors.bleuPrimaire)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

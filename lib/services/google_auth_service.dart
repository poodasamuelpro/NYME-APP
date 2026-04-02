import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/google_auth_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/common/nyme_button.dart';

class GoogleSignInScreen extends ConsumerStatefulWidget {
  const GoogleSignInScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends ConsumerState<GoogleSignInScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final googleAuthService = ref.read(googleAuthServiceProvider);
      final response = await googleAuthService.signInWithGoogle();

      if (response.user != null) {
        // Authentification réussie, naviguer vers l'écran suivant
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentification réussie')),
          );
          // Naviguer vers le tableau de bord ou l'écran de sélection de rôle
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion avec Google'),
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_circle,
                size: 80.0,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24.0),
              Text(
                'Connectez-vous avec Google',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12.0),
              Text(
                'Utilisez votre compte Google pour accéder rapidement à NYME',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32.0),
              NymeButton(
                label: 'Continuer avec Google',
                onPressed: _isLoading ? null : _signInWithGoogle,
                isLoading: _isLoading,
                icon: Icons.login,
              ),
              const SizedBox(height: 16.0),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

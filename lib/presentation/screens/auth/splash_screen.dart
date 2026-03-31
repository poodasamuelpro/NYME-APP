import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../config/router.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/models.dart';
import '../../../services/notification_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      context.go(AppRoutes.connexion);
      return;
    }

    try {
      final auth = ref.read(authRepositoryProvider);
      final user = await auth.getProfilUtilisateur(session.user.id);

      // Sauvegarder token FCM
      await NotificationService.sauvegarderToken(user.id);

      if (!mounted) return;
      switch (user.role) {
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
    } catch (_) {
      if (!mounted) return;
      context.go(AppRoutes.connexion);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bleuPrimaire,
      body: Center(
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(
                  child: Text('N', style: TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('NYME', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 6)),
              const SizedBox(height: 8),
              Text('Livraison Rapide & Intelligente', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

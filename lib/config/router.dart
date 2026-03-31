import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../presentation/screens/auth/splash_screen.dart';
import '../presentation/screens/auth/connexion_screen.dart';
import '../presentation/screens/auth/inscription_screen.dart';
import '../presentation/screens/auth/verification_otp_screen.dart';
import '../presentation/screens/auth/verification_coursier_screen.dart';
import '../presentation/screens/client/client_shell.dart';
import '../presentation/screens/client/accueil_client_screen.dart';
import '../presentation/screens/client/nouvelle_livraison_screen.dart';
import '../presentation/screens/client/suivi_livraison_screen.dart';
import '../presentation/screens/client/detail_livraison_screen.dart';
import '../presentation/screens/client/historique_client_screen.dart';
import '../presentation/screens/client/profil_client_screen.dart';
import '../presentation/screens/client/adresses_favorites_screen.dart';
import '../presentation/screens/client/contacts_favoris_screen.dart';
import '../presentation/screens/client/tableau_bord_client_screen.dart';
import '../presentation/screens/client/propositions_prix_screen.dart';
import '../presentation/screens/coursier/coursier_shell.dart';
import '../presentation/screens/coursier/accueil_coursier_screen.dart';
import '../presentation/screens/coursier/carte_coursier_screen.dart';
import '../presentation/screens/coursier/tableau_bord_coursier_screen.dart';
import '../presentation/screens/coursier/gains_screen.dart';
import '../presentation/screens/coursier/profil_coursier_screen.dart';
import '../presentation/screens/chat/chat_screen.dart';
import '../presentation/screens/chat/liste_conversations_screen.dart';
import '../presentation/screens/admin/admin_shell.dart';
import '../presentation/screens/admin/tableau_bord_admin_screen.dart';
import '../presentation/screens/admin/verifications_screen.dart';
import '../presentation/screens/admin/utilisateurs_screen.dart';
import '../presentation/screens/admin/litiges_screen.dart';
import '../presentation/screens/shared/notifications_screen.dart';
import '../presentation/screens/shared/parametres_screen.dart';

// Routes nommées
class AppRoutes {
  static const splash = '/';
  static const connexion = '/connexion';
  static const inscription = '/inscription';
  static const verificationOtp = '/verification-otp';
  static const verificationCoursier = '/verification-coursier';

  // Client
  static const clientHome = '/client';
  static const nouvelleLivraison = '/client/nouvelle-livraison';
  static const propositionsPrix = '/client/propositions-prix/:livraisonId';
  static const suiviLivraison = '/client/suivi/:livraisonId';
  static const detailLivraison = '/client/detail/:livraisonId';
  static const historiqueClient = '/client/historique';
  static const tableauBordClient = '/client/tableau-bord';
  static const adressesFavorites = '/client/adresses';
  static const contactsFavoris = '/client/contacts';
  static const profilClient = '/client/profil';

  // Coursier
  static const coursierHome = '/coursier';
  static const carteCoursier = '/coursier/carte/:livraisonId';
  static const tableauBordCoursier = '/coursier/tableau-bord';
  static const gainsCoursier = '/coursier/gains';
  static const profilCoursier = '/coursier/profil';

  // Chat
  static const listeConversations = '/chat';
  static const chat = '/chat/:livraisonId/:interlocuteurId';

  // Admin
  static const adminHome = '/admin';
  static const verifications = '/admin/verifications';
  static const utilisateurs = '/admin/utilisateurs';
  static const litiges = '/admin/litiges';

  // Partagé
  static const notifications = '/notifications';
  static const parametres = '/parametres';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuth = session != null;
      final isOnAuth = state.matchedLocation == AppRoutes.connexion ||
          state.matchedLocation == AppRoutes.inscription ||
          state.matchedLocation == AppRoutes.splash;

      if (!isAuth && !isOnAuth) return AppRoutes.connexion;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.connexion, builder: (_, __) => const ConnexionScreen()),
      GoRoute(path: AppRoutes.inscription, builder: (_, __) => const InscriptionScreen()),
      GoRoute(path: AppRoutes.verificationOtp, builder: (_, state) =>
          VerificationOtpScreen(telephone: state.uri.queryParameters['telephone'] ?? '')),
      GoRoute(path: AppRoutes.verificationCoursier, builder: (_, __) => const VerificationCoursierScreen()),

      // Shell client (bottom navigation)
      ShellRoute(
        builder: (_, __, child) => ClientShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.clientHome, builder: (_, __) => const AccueilClientScreen()),
          GoRoute(path: AppRoutes.tableauBordClient, builder: (_, __) => const TableauBordClientScreen()),
          GoRoute(path: AppRoutes.historiqueClient, builder: (_, __) => const HistoriqueClientScreen()),
          GoRoute(path: AppRoutes.profilClient, builder: (_, __) => const ProfilClientScreen()),
        ],
      ),
      GoRoute(path: AppRoutes.nouvelleLivraison, builder: (_, __) => const NouvelleLivraisonScreen()),
      GoRoute(path: AppRoutes.propositionsPrix, builder: (_, state) =>
          PropositionsPrixScreen(livraisonId: state.pathParameters['livraisonId']!)),
      GoRoute(path: AppRoutes.suiviLivraison, builder: (_, state) =>
          SuiviLivraisonScreen(livraisonId: state.pathParameters['livraisonId']!)),
      GoRoute(path: AppRoutes.detailLivraison, builder: (_, state) =>
          DetailLivraisonScreen(livraisonId: state.pathParameters['livraisonId']!)),
      GoRoute(path: AppRoutes.adressesFavorites, builder: (_, __) => const AdressesFavoritesScreen()),
      GoRoute(path: AppRoutes.contactsFavoris, builder: (_, __) => const ContactsFavorisScreen()),

      // Shell coursier
      ShellRoute(
        builder: (_, __, child) => CoursierShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.coursierHome, builder: (_, __) => const AccueilCoursierScreen()),
          GoRoute(path: AppRoutes.tableauBordCoursier, builder: (_, __) => const TableauBordCoursierScreen()),
          GoRoute(path: AppRoutes.gainsCoursier, builder: (_, __) => const GainsScreen()),
          GoRoute(path: AppRoutes.profilCoursier, builder: (_, __) => const ProfilCoursierScreen()),
        ],
      ),
      GoRoute(path: AppRoutes.carteCoursier, builder: (_, state) =>
          CarteCoursierScreen(livraisonId: state.pathParameters['livraisonId']!)),

      // Chat
      GoRoute(path: AppRoutes.listeConversations, builder: (_, __) => const ListeConversationsScreen()),
      GoRoute(path: AppRoutes.chat, builder: (_, state) => ChatScreen(
        livraisonId: state.pathParameters['livraisonId']!,
        interlocuteurId: state.pathParameters['interlocuteurId']!,
      )),

      // Admin
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.adminHome, builder: (_, __) => const TableauBordAdminScreen()),
          GoRoute(path: AppRoutes.verifications, builder: (_, __) => const VerificationsScreen()),
          GoRoute(path: AppRoutes.utilisateurs, builder: (_, __) => const UtilisateursScreen()),
          GoRoute(path: AppRoutes.litiges, builder: (_, __) => const LitigesScreen()),
        ],
      ),

      // Partagé
      GoRoute(path: AppRoutes.notifications, builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: AppRoutes.parametres, builder: (_, __) => const ParametresScreen()),
    ],
  );
});

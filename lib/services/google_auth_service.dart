import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/app_exception.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  final SupabaseClient _supabase;

  GoogleAuthService(this._supabase);

  // Authentifier avec Google et créer une session Supabase
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // Récupérer le compte Google
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AppException('Authentification Google annulée');
      }

      // Récupérer les tokens d'authentification
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw AppException('Impossible de récupérer les tokens d\'authentification');
      }

      // Authentifier avec Supabase en utilisant les tokens Google
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Enregistrer l'ID Google dans la base de données pour référence future
      if (response.user != null) {
        await _supabase
            .from('users')
            .update({'google_id': googleUser.id})
            .eq('id', response.user!.id);
      }

      return response;
    } catch (e) {
      throw AppException('Erreur lors de l\'authentification Google: $e');
    }
  }

  // Vérifier si un utilisateur est connecté
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  // Récupérer l'utilisateur Google actuel
  GoogleSignInAccount? getCurrentUser() {
    return _googleSignIn.currentUser;
  }

  // Se déconnecter de Google et de Supabase
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();
    } catch (e) {
      throw AppException('Erreur lors de la déconnexion: $e');
    }
  }

  // Révoquer l'accès Google
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      await _supabase.auth.signOut();
    } catch (e) {
      throw AppException('Erreur lors de la révocation de l\'accès: $e');
    }
  }
}

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService(ref.read(supabaseClientProvider));
});

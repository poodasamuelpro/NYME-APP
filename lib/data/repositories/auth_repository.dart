import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../../config/supabase_config.dart';
import '../../core/errors/app_exception.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  // ── Utilisateur courant ──
  User? get currentUser => _supabase.auth.currentUser;
  String? get currentUserId => currentUser?.id;
  bool get estConnecte => currentUser != null;

  // ── Écouter les changements d'auth ──
  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // ── Inscription ──
  Future<UtilisateurModel> inscrire({
    required String nom,
    required String telephone,
    required String email,
    required String motDePasse,
    required RoleUtilisateur role,
    String? whatsapp,
  }) async {
    try {
      // 1. Créer compte Supabase Auth
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: motDePasse,
        data: {'nom': nom, 'telephone': telephone, 'role': role.name},
      );

      if (authResponse.user == null) {
        throw AppException('Erreur lors de la création du compte');
      }

      final userId = authResponse.user!.id;

      // 2. Créer profil dans la table utilisateurs
      final utilisateurData = {
        'id': userId,
        'nom': nom,
        'telephone': telephone,
        'email': email,
        'role': role.name,
        'whatsapp': whatsapp ?? telephone,
        'est_verifie': false,
        'est_actif': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from(SupabaseConfig.tableUtilisateurs).insert(utilisateurData);

      // 3. Si coursier, créer entrée dans la table coursiers
      if (role == RoleUtilisateur.coursier) {
        await _supabase.from(SupabaseConfig.tableCoursiers).insert({
          'id': userId,
          'statut': 'hors_ligne',
          'statut_verification': 'en_attente',
          'total_courses': 0,
          'total_gains': 0.0,
        });

        // Créer wallet
        await _supabase.from(SupabaseConfig.tableWallets).insert({
          'user_id': userId,
          'solde': 0.0,
        });
      }

      // 4. Envoyer OTP SMS pour vérification
      await _supabase.auth.signInWithOtp(phone: telephone);

      return UtilisateurModel.fromJson(utilisateurData);
    } on AuthException catch (e) {
      throw AppException(_mapAuthError(e.message));
    } catch (e) {
      throw AppException('Erreur inscription: $e');
    }
  }

  // ── Connexion email/mot de passe ──
  Future<UtilisateurModel> connecter({
    required String email,
    required String motDePasse,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: motDePasse,
      );

      if (response.user == null) throw AppException('Connexion échouée');

      return await getProfilUtilisateur(response.user!.id);
    } on AuthException catch (e) {
      throw AppException(_mapAuthError(e.message));
    }
  }

  // ── Connexion via OTP SMS ──
  Future<void> envoyerOtpSms(String telephone) async {
    try {
      await _supabase.auth.signInWithOtp(phone: telephone);
    } on AuthException catch (e) {
      throw AppException(_mapAuthError(e.message));
    }
  }

  Future<UtilisateurModel> verifierOtp({
    required String telephone,
    required String code,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        phone: telephone,
        token: code,
        type: OtpType.sms,
      );

      if (response.user == null) throw AppException('Code invalide');

      return await getProfilUtilisateur(response.user!.id);
    } on AuthException catch (e) {
      throw AppException(_mapAuthError(e.message));
    }
  }

  // ── Récupérer profil ──
  Future<UtilisateurModel> getProfilUtilisateur(String userId) async {
    final data = await _supabase
        .from(SupabaseConfig.tableUtilisateurs)
        .select()
        .eq('id', userId)
        .single();

    return UtilisateurModel.fromJson(data);
  }

  // ── Mettre à jour profil ──
  Future<UtilisateurModel> mettreAJourProfil({
    required String userId,
    String? nom,
    String? whatsapp,
    String? telephone,
  }) async {
    final updates = <String, dynamic>{};
    if (nom != null) updates['nom'] = nom;
    if (whatsapp != null) updates['whatsapp'] = whatsapp;
    if (telephone != null) updates['telephone'] = telephone;

    await _supabase
        .from(SupabaseConfig.tableUtilisateurs)
        .update(updates)
        .eq('id', userId);

    return await getProfilUtilisateur(userId);
  }

  // ── Upload avatar ──
  Future<String> uploadAvatar(String userId, File fichier) async {
    final extension = fichier.path.split('.').last;
    final path = 'avatars/$userId.$extension';

    await _supabase.storage
        .from(SupabaseConfig.bucketAvatars)
        .upload(path, fichier, fileOptions: const FileOptions(upsert: true));

    final url = _supabase.storage
        .from(SupabaseConfig.bucketAvatars)
        .getPublicUrl(path);

    await _supabase
        .from(SupabaseConfig.tableUtilisateurs)
        .update({'avatar_url': url})
        .eq('id', userId);

    return url;
  }

  // ── Mettre à jour FCM token ──
  Future<void> mettreAJourFcmToken(String userId, String token) async {
    await _supabase
        .from(SupabaseConfig.tableUtilisateurs)
        .update({'fcm_token': token})
        .eq('id', userId);
  }

  // ── Déconnexion ──
  Future<void> deconnecter() async {
    await _supabase.auth.signOut();
  }

  // ── Réinitialiser mot de passe ──
  Future<void> reinitialiserMotDePasse(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // ── Mapper les erreurs Auth ──
  String _mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Email ou mot de passe incorrect';
    }
    if (message.contains('Email already registered')) {
      return 'Cet email est déjà utilisé';
    }
    if (message.contains('Password should be')) {
      return 'Le mot de passe est trop faible';
    }
    if (message.contains('Token has expired')) {
      return 'Code expiré, veuillez en demander un nouveau';
    }
    if (message.contains('Invalid OTP')) {
      return 'Code incorrect';
    }
    return message;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

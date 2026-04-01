// ─────────────────────────────────────────────────────────────
// Gestion centralisée des erreurs NYME
// ─────────────────────────────────────────────────────────────

class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const AppException(this.message, {this.code, this.details});

  @override
  String toString() => message;
}

// Erreurs spécifiques
class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

class ReseauException extends AppException {
  const ReseauException([String msg = 'Pas de connexion internet'])
      : super(msg, code: 'RESEAU');
}

class PermissionException extends AppException {
  const PermissionException(super.message, {super.code});
}

class ValidationException extends AppException {
  final Map<String, String> erreurs;
  const ValidationException(super.message, {required this.erreurs});
}

// Mapper les erreurs Supabase en français
String mapperErreurSupabase(String message) {
  if (message.contains('Invalid login credentials')) {
    return 'Email ou mot de passe incorrect';
  }
  if (message.contains('Email already registered') ||
      message.contains('already been registered')) {
    return 'Cet email est déjà utilisé';
  }
  if (message.contains('Password should be')) {
    return 'Mot de passe trop faible (minimum 8 caractères)';
  }
  if (message.contains('Token has expired')) {
    return 'Code expiré, veuillez en demander un nouveau';
  }
  if (message.contains('Invalid OTP') || message.contains('otp_expired')) {
    return 'Code incorrect ou expiré';
  }
  if (message.contains('duplicate key') ||
      message.contains('unique constraint')) {
    return 'Cette information existe déjà';
  }
  if (message.contains('violates row-level security')) {
    return 'Accès non autorisé';
  }
  if (message.contains('JWT')) {
    return 'Session expirée, veuillez vous reconnecter';
  }
  if (message.contains('network') || message.contains('connection')) {
    return 'Problème de connexion internet';
  }
  return message;
}


/// Configuration Supabase pour NYME
/// Remplacer par vos vraies valeurs depuis le dashboard Supabase
class SupabaseConfig {
  SupabaseConfig._();

  // ── Projet Supabase ──
  // Dashboard → Settings → API
  static const String url = 'https://wamkyxnwtzlghewgnsxf.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndhbWt5eG53dHpsZ2hld2duc3hmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5NjYzMjQsImV4cCI6MjA5MDU0MjMyNH0.XFqPMPgxi4R35YDDcPNwuMdRnUfQBX4JM9NTRWuTdpA';

  // ── Buckets Storage ──
  static const String bucketPhotos = 'photos-colis';
  static const String bucketIdentites = 'identites-coursiers';
  static const String bucketAvatars = 'avatars';

  // ── Tables ──
  static const String tableUtilisateurs = 'utilisateurs';
  static const String tableCoursiers = 'coursiers';
  static const String tableVehicules = 'vehicules';
  static const String tableLivraisons = 'livraisons';
  static const String tablePropositionsPrix = 'propositions_prix';
  static const String tableMessages = 'messages';
  static const String tableNotifications = 'notifications';
  static const String tableAdressesFavorites = 'adresses_favorites';
  static const String tableContactsFavoris = 'contacts_favoris';
  static const String tableCoursiersFavoris = 'coursiers_favoris';
  static const String tableEvaluations = 'evaluations';
  static const String tableSignalements = 'signalements';
  static const String tableLocalisationCoursier = 'localisation_coursier';
  static const String tablePaiements = 'paiements';
  static const String tableWallets = 'wallets';
  static const String tableTransactionsWallet = 'transactions_wallet';
  static const String tableStatutsLivraison = 'statuts_livraison';
  static const String tableLogsAppels = 'logs_appels';
  static const String tableConfigTarifs = 'config_tarifs';

  // ── Realtime channels ──
  static const String channelLocalisation = 'localisation_coursier';
  static const String channelMessages = 'messages';
  static const String channelLivraisons = 'livraisons';
  static const String channelNotifications = 'notifications';
}
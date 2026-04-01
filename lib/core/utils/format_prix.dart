import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
// Formatage des prix en FCFA pour NYME
// ─────────────────────────────────────────────────────────────

class FormatPrix {
  FormatPrix._();

  static final NumberFormat _fmt = NumberFormat('#,###', 'fr_FR');

  /// 3750 → "3 750 FCFA"
  static String fcfa(double montant) =>
      '${_fmt.format(montant.round())} FCFA';

  /// 3750 → "3 750 FCFA"
  static String fcfaInt(int montant) =>
      '${_fmt.format(montant)} FCFA';

  /// 3750 → "3 750" (sans FCFA)
  static String court(double montant) =>
      _fmt.format(montant.round());

  /// 3750.0 → "+3 750 FCFA" (avec signe plus)
  static String gain(double montant) =>
      '+${fcfa(montant)}';

  /// Commission : 15% de 3750 → "562 FCFA"
  static String commission(double montant, {double taux = 0.15}) =>
      fcfa(montant * taux);

  /// Gain coursier après commission
  static double gainCoursier(double prixFinal, {double taux = 0.15}) =>
      prixFinal * (1 - taux);

  /// Calculer le prix selon distance et durée
  static double calculerPrix({
    required double distanceKm,
    required int dureeMinutes,
    double tarifKm = 500,
    double tarifMinute = 50,
    double fraisFixe = 500,
    bool estUrgent = false,
    double multiplicateurUrgent = 1.30,
  }) {
    final base = (distanceKm * tarifKm) +
        (dureeMinutes * tarifMinute) +
        fraisFixe;
    final prix = estUrgent ? base * multiplicateurUrgent : base;
    // Arrondir au multiple de 50 le plus proche
    return (prix / 50).round() * 50;
  }

  /// Résumé complet pour affichage
  static Map<String, String> resumePrix({
    required double prixFinal,
    double commissionTaux = 0.15,
  }) {
    final commission = prixFinal * commissionTaux;
    final gain = prixFinal - commission;
    return {
      'total': fcfa(prixFinal),
      'commission': fcfa(commission),
      'gain_coursier': fcfa(gain),
    };
  }
}


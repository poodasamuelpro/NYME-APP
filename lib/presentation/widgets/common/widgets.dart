// ═══════════════════════════════════════════════════
// lib/presentation/widgets/common/nyme_button.dart
// ═══════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class NymeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool loading;
  final IconData? icon;
  final Color? color;

  const NymeButton({
    super.key,
    required this.label,
    this.onPressed,
    this.outlined = false,
    this.loading = false,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.bleuPrimaire;

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : (icon != null ? Icon(icon, size: 20) : const SizedBox.shrink()),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: bg,
          side: BorderSide(color: bg),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : (icon != null ? Icon(icon, size: 20) : const SizedBox.shrink()),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// lib/presentation/widgets/common/nyme_text_field.dart
// ═══════════════════════════════════════════════════

class NymeTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool enabled;
  final void Function(String)? onChanged;

  const NymeTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.gris) : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// lib/presentation/widgets/common/loading_overlay.dart
// ═══════════════════════════════════════════════════

class LoadingOverlay extends StatelessWidget {
  final bool loading;
  final Widget child;
  const LoadingOverlay({super.key, required this.loading, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (loading)
          Container(
            color: Colors.black.withOpacity(0.35),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.bleuPrimaire),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// lib/presentation/widgets/common/statut_badge.dart
// ═══════════════════════════════════════════════════

class StatutBadge extends StatelessWidget {
  final String statut;
  const StatutBadge({super.key, required this.statut});

  static Color _couleur(String s) {
    switch (s) {
      case 'en_attente': return AppColors.statutEnAttente;
      case 'acceptee': return AppColors.statutAcceptee;
      case 'en_rout_depart':
      case 'colis_recupere':
      case 'en_route_arrivee': return AppColors.statutEnRoute;
      case 'livree': return AppColors.statutLivree;
      case 'annulee': return AppColors.statutAnnulee;
      default: return AppColors.gris;
    }
  }

  static String _label(String s) {
    switch (s) {
      case 'en_attente': return 'En attente';
      case 'acceptee': return 'Acceptée';
      case 'en_rout_depart': return 'En route (départ)';
      case 'colis_recupere': return 'Colis récupéré';
      case 'en_route_arrivee': return 'En route (arrivée)';
      case 'livree': return 'Livrée ✓';
      case 'annulee': return 'Annulée';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _couleur(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(statut),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

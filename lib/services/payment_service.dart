import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';
import '../core/errors/app_exception.dart';
import '../data/models/models.dart';

// ─────────────────────────────────────────────────────────────
// Service Paiement NYME — CinetPay (Mobile Money)
// Orange Money, Moov Money, Wave, Coris Money
// ─────────────────────────────────────────────────────────────

class PaymentService {
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

  // Clés CinetPay (à mettre dans supabase_config.dart)
  static const String _apiKey = 'VOTRE_API_KEY_CINETPAY';
  static const String _siteId = 'VOTRE_SITE_ID_CINETPAY';
  static const String _baseUrl = 'https://api-checkout.cinetpay.com/v2/payment';

  PaymentService(this._supabase);

  // ── Initier un paiement Mobile Money ──
  Future<String> initierPaiement({
    required String livraisonId,
    required double montant,
    required String clientId,
    required String description,
    ModePaiement mode = ModePaiement.mobileMoney,
  }) async {
    final transactionId = _uuid.v4().replaceAll('-', '').substring(0, 16);

    try {
      // Enregistrer le paiement en attente dans Supabase
      await _supabase.from(SupabaseConfig.tablePaiements).insert({
        'livraison_id': livraisonId,
        'montant': montant,
        'mode': mode.name,
        'reference': transactionId,
        'statut': 'en_attente',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Appeler l'Edge Function pour créer le lien CinetPay
      final result = await _supabase.functions.invoke(
        'initier-paiement',
        body: {
          'transaction_id': transactionId,
          'montant': montant.toInt(),
          'livraison_id': livraisonId,
          'client_id': clientId,
          'description': description,
          'devise': 'XOF', // FCFA
        },
      );

      final data = result.data as Map<String, dynamic>;
      if (data['code'] != '201') {
        throw AppException(data['message'] ?? 'Erreur CinetPay');
      }

      // Retourner l'URL de paiement CinetPay
      return data['data']['payment_url'];
    } catch (e) {
      throw AppException('Erreur paiement: $e');
    }
  }

  // ── Vérifier le statut d'un paiement ──
  Future<bool> verifierStatut(String reference) async {
    try {
      final result = await _supabase.functions.invoke(
        'verifier-paiement',
        body: {'reference': reference},
      );
      final data = result.data as Map<String, dynamic>;
      return data['statut'] == 'succes';
    } catch (e) {
      return false;
    }
  }

  // ── Enregistrer paiement cash (à la livraison) ──
  Future<void> enregistrerPaiementCash({
    required String livraisonId,
    required double montant,
  }) async {
    await _supabase.from(SupabaseConfig.tablePaiements).insert({
      'livraison_id': livraisonId,
      'montant': montant,
      'mode': 'cash',
      'statut': 'succes',
      'paye_le': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    await _supabase
        .from(SupabaseConfig.tableLivraisons)
        .update({'statut_paiement': 'paye', 'mode_paiement': 'cash'})
        .eq('id', livraisonId);
  }

  // ── Historique des paiements d'un utilisateur ──
  Future<List<Map<String, dynamic>>> getHistorique(String userId) async {
    final data = await _supabase
        .from(SupabaseConfig.tablePaiements)
        .select('''
          *,
          livraison:livraison_id(id, depart_adresse, arrivee_adresse, created_at)
        ''')
        .order('created_at', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(data);
  }
}

// ── Widget WebView pour le paiement CinetPay ──
class PaiementWebViewScreen extends StatefulWidget {
  final String urlPaiement;
  final String livraisonId;
  final void Function(bool succes) onResultat;

  const PaiementWebViewScreen({
    super.key,
    required this.urlPaiement,
    required this.livraisonId,
    required this.onResultat,
  });

  @override
  State<PaiementWebViewScreen> createState() => _PaiementWebViewState();
}

class _PaiementWebViewState extends State<PaiementWebViewScreen> {
  late final WebViewController _ctrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (url) {
          setState(() => _loading = false);
          // Détecter le retour CinetPay
          if (url.contains('success') || url.contains('return')) {
            widget.onResultat(true);
            Navigator.pop(context);
          } else if (url.contains('cancel') || url.contains('error')) {
            widget.onResultat(false);
            Navigator.pop(context);
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.urlPaiement));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement sécurisé'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            widget.onResultat(false);
            Navigator.pop(context);
          },
        ),
        backgroundColor: const Color(0xFF1A4FBF),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _ctrl),
          if (_loading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1A4FBF)),
                  SizedBox(height: 16),
                  Text('Chargement du paiement...'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(Supabase.instance.client);
});


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/errors/app_exception.dart';

class PaymentService {
  // Configuration des API de paiement
  static const String _cinetpayApiUrl = 'https://api.cinetpay.com/v1';
  static const String _cinetpayApiKey = 'YOUR_CINETPAY_API_KEY';
  static const String _cinetpaySecretKey = 'YOUR_CINETPAY_SECRET_KEY';

  // Initier un paiement via CinetPay (Mobile Money)
  Future<Map<String, dynamic>> initiateMobileMoneyPayment({
    required String userId,
    required double amount,
    required String phoneNumber,
    required String description,
  }) async {
    try {
      final payload = {
        'apikey': _cinetpayApiKey,
        'site_id': 'YOUR_SITE_ID',
        'amount': amount.toInt(),
        'currency': 'XOF', // Franc CFA
        'description': description,
        'customer_phone_number': phoneNumber,
        'customer_name': userId,
        'notify_url': 'https://your-domain.com/webhook/cinetpay',
        'return_url': 'https://your-domain.com/payment/success',
      };

      final response = await http.post(
        Uri.parse('$_cinetpayApiUrl/payment/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['code'] == '00',
          'transaction_id': data['transaction_id'],
          'payment_token': data['payment_token'],
          'redirect_url': data['redirect_url'],
        };
      } else {
        throw AppException('Erreur lors de l\'initiation du paiement: ${response.statusCode}');
      }
    } catch (e) {
      throw AppException('Erreur lors du paiement Mobile Money: $e');
    }
  }

  // Vérifier le statut d'un paiement CinetPay
  Future<Map<String, dynamic>> checkPaymentStatus(String transactionId) async {
    try {
      final response = await http.post(
        Uri.parse('$_cinetpayApiUrl/payment/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'apikey': _cinetpayApiKey,
          'site_id': 'YOUR_SITE_ID',
          'transaction_id': transactionId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': data['status'],
          'amount': data['amount'],
          'currency': data['currency'],
          'description': data['description'],
        };
      } else {
        throw AppException('Erreur lors de la vérification du paiement: ${response.statusCode}');
      }
    } catch (e) {
      throw AppException('Erreur lors de la vérification du paiement: $e');
    }
  }

  // Initier un paiement via Flutterwave (Carte Bancaire)
  Future<Map<String, dynamic>> initiateCardPayment({
    required String userId,
    required double amount,
    required String email,
    required String description,
  }) async {
    try {
      final payload = {
        'tx_ref': 'CARD_${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'currency': 'XOF',
        'customer': {
          'email': email,
          'name': userId,
        },
        'customizations': {
          'title': 'NYME Recharge',
          'description': description,
        },
        'redirect_url': 'https://your-domain.com/payment/success',
      };

      final response = await http.post(
        Uri.parse('https://api.flutterwave.com/v3/payments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_FLUTTERWAVE_SECRET_KEY',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['status'] == 'success',
          'link': data['data']['link'],
          'reference': data['data']['reference'],
        };
      } else {
        throw AppException('Erreur lors de l\'initiation du paiement: ${response.statusCode}');
      }
    } catch (e) {
      throw AppException('Erreur lors du paiement par carte: $e');
    }
  }

  // Vérifier le statut d'un paiement Flutterwave
  Future<Map<String, dynamic>> checkFlutterwavePaymentStatus(String reference) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.flutterwave.com/v3/transactions/$reference/verify'),
        headers: {
          'Authorization': 'Bearer YOUR_FLUTTERWAVE_SECRET_KEY',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': data['data']['status'],
          'amount': data['data']['amount'],
          'currency': data['data']['currency'],
        };
      } else {
        throw AppException('Erreur lors de la vérification du paiement: ${response.statusCode}');
      }
    } catch (e) {
      throw AppException('Erreur lors de la vérification du paiement: $e');
    }
  }

  // Traiter un retrait bancaire via Flutterwave
  Future<Map<String, dynamic>> initiateTransfer({
    required String accountNumber,
    required String bankCode,
    required double amount,
    required String narration,
  }) async {
    try {
      final payload = {
        'account_number': accountNumber,
        'amount': amount,
        'narration': narration,
        'currency': 'XOF',
        'bank_code': bankCode,
        'reference': 'TRANSFER_${DateTime.now().millisecondsSinceEpoch}',
      };

      final response = await http.post(
        Uri.parse('https://api.flutterwave.com/v3/transfers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_FLUTTERWAVE_SECRET_KEY',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['status'] == 'success',
          'transfer_id': data['data']['id'],
          'reference': data['data']['reference'],
        };
      } else {
        throw AppException('Erreur lors du virement: ${response.statusCode}');
      }
    } catch (e) {
      throw AppException('Erreur lors du virement: $e');
    }
  }

  // Vérifier le statut d'un virement
  Future<Map<String, dynamic>> checkTransferStatus(String transferId) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.flutterwave.com/v3/transfers/$transferId'),
        headers: {
          'Authorization': 'Bearer YOUR_FLUTTERWAVE_SECRET_KEY',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': data['data']['status'],
          'amount': data['data']['amount'],
          'reference': data['data']['reference'],
        };
      } else {
        throw AppException('Erreur lors de la vérification du virement: ${response.statusCode}');
      }
    } catch (e) {
      throw AppException('Erreur lors de la vérification du virement: $e');
    }
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});
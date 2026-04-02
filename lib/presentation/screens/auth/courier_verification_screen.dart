import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';
import '../../../services/payment_service.dart';
import '../../widgets/common/nyme_button.dart';

class CourierVerificationScreen extends ConsumerStatefulWidget {
  const CourierVerificationScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CourierVerificationScreen> createState() => _CourierVerificationScreenState();
}

class _CourierVerificationScreenState extends ConsumerState<CourierVerificationScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, File?> _documents = {
    'cni_recto': null,
    'cni_verso': null,
    'permis': null,
    'carte_grise': null,
  };
  bool _isSubmitting = false;

  Future<void> _pickImage(String documentType) async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _documents[documentType] = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la capture: $e')),
      );
    }
  }

  Future<void> _submitDocuments() async {
    // Vérifier que tous les documents sont fournis
    if (_documents.values.any((doc) => doc == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez fournir tous les documents')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Afficher une confirmation avant la soumission
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmer la soumission'),
          content: const Text(
            'Êtes-vous sûr que tous les documents sont corrects et lisibles? '
            'Une fois soumis, ils seront vérifiés par un administrateur.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _isSubmitting = false);
        return;
      }

      // Ici, vous devriez uploader les documents vers Supabase Storage
      // et créer des entrées dans la table courier_documents
      // Pour l'exemple, nous affichons simplement un message de succès

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documents soumis avec succès. Veuillez attendre la validation.'),
        ),
      );

      // Naviguer vers l'écran suivant ou fermer le formulaire
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la soumission: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification des Documents'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Veuillez fournir les documents suivants pour vérification:',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24.0),
            // CNI Recto
            _buildDocumentUploadCard(
              'CNI - Recto',
              'cni_recto',
              'Prenez une photo du recto de votre CNI',
            ),
            const SizedBox(height: 12.0),
            // CNI Verso
            _buildDocumentUploadCard(
              'CNI - Verso',
              'cni_verso',
              'Prenez une photo du verso de votre CNI',
            ),
            const SizedBox(height: 12.0),
            // Permis de conduire
            _buildDocumentUploadCard(
              'Permis de Conduire',
              'permis',
              'Prenez une photo de votre permis de conduire',
            ),
            const SizedBox(height: 12.0),
            // Carte Grise
            _buildDocumentUploadCard(
              'Carte Grise',
              'carte_grise',
              'Prenez une photo de votre carte grise',
            ),
            const SizedBox(height: 24.0),
            // Bouton de soumission
            NymeButton(
              label: 'Soumettre les documents',
              onPressed: _isSubmitting ? null : _submitDocuments,
              isLoading: _isSubmitting,
            ),
            const SizedBox(height: 16.0),
            // Avertissement
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: const Text(
                '⚠️ Assurez-vous que tous les documents sont clairs, lisibles et valides. '
                'Les documents flous ou invalides seront rejetés.',
                style: TextStyle(fontSize: 12.0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentUploadCard(
    String title,
    String documentType,
    String description,
  ) {
    final document = _documents[documentType];
    final isUploaded = document != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (isUploaded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: const Text(
                      '✓ Uploadé',
                      style: TextStyle(color: Colors.green, fontSize: 12.0),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12.0),
            if (isUploaded)
              Container(
                height: 150.0,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Image.file(
                  document,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 150.0,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.grey[100],
                ),
                child: const Center(
                  child: Icon(Icons.image, size: 48.0, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 12.0),
            ElevatedButton.icon(
              onPressed: () => _pickImage(documentType),
              icon: const Icon(Icons.camera_alt),
              label: isUploaded ? const Text('Reprendre une photo') : const Text('Prendre une photo'),
            ),
          ],
        ),
      ),
    );
  }
}

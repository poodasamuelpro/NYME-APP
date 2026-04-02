import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format_prix.dart';

class DashboardAdminScreen extends ConsumerStatefulWidget {
  const DashboardAdminScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends ConsumerState<DashboardAdminScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de Bord Admin'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Onglets de navigation
          Container(
            color: Colors.grey[100],
            child: Row(
              children: [
                _buildTab(0, 'Statistiques'),
                _buildTab(1, 'Coursiers'),
                _buildTab(2, 'Retraits'),
                _buildTab(3, 'Paramètres'),
              ],
            ),
          ),
          // Contenu des onglets
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 3.0,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildStatisticsTab();
      case 1:
        return _buildCouriersTab();
      case 2:
        return _buildWithdrawalsTab();
      case 3:
        return _buildSettingsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatisticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cartes de statistiques
          _buildStatCard('Clients', '1,234', Colors.blue),
          const SizedBox(height: 12.0),
          _buildStatCard('Coursiers', '567', Colors.green),
          const SizedBox(height: 12.0),
          _buildStatCard('Livraisons', '8,901', Colors.orange),
          const SizedBox(height: 12.0),
          _buildStatCard('Revenu Total', formatPrix(1234567.89), Colors.purple),
          const SizedBox(height: 24.0),
          // Graphique des revenus (exemple simplifié)
          Text(
            'Revenus par jour (derniers 7 jours)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12.0),
          Container(
            height: 200.0,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Center(
              child: Text('Graphique des revenus (à implémenter avec fl_chart)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          Text(
            value,
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouriersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filtres
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: 'pending',
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('En attente')),
                    DropdownMenuItem(value: 'approved', child: Text('Approuvés')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejetés')),
                  ],
                  onChanged: (value) {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          // Liste des coursiers
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                child: ListTile(
                  title: Text('Coursier ${index + 1}'),
                  subtitle: const Text('En attente de validation'),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Text('Voir les documents'),
                      ),
                      const PopupMenuItem(
                        value: 'approve',
                        child: Text('Approuver'),
                      ),
                      const PopupMenuItem(
                        value: 'reject',
                        child: Text('Rejeter'),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'view') {
                        _showCourierDocuments(context, index);
                      } else if (value == 'approve') {
                        _approveCourier(index);
                      } else if (value == 'reject') {
                        _rejectCourier(context, index);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filtres
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: 'pending',
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('En attente')),
                    DropdownMenuItem(value: 'completed', child: Text('Complétés')),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejetés')),
                  ],
                  onChanged: (value) {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          // Liste des demandes de retrait
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                child: ListTile(
                  title: Text('Coursier ${index + 1}'),
                  subtitle: Text('Retrait de ${formatPrix(50000.00)}'),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'approve',
                        child: Text('Approuver'),
                      ),
                      const PopupMenuItem(
                        value: 'reject',
                        child: Text('Rejeter'),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'approve') {
                        _approveWithdrawal(index);
                      } else if (value == 'reject') {
                        _rejectWithdrawal(context, index);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Configuration des tarifs et commissions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16.0),
          // Champ de taux de commission
          TextField(
            decoration: InputDecoration(
              label: const Text('Taux de commission (%)'),
              hintText: '15',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Paramètres mis à jour')),
              );
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showCourierDocuments(BuildContext context, int courierIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Documents du Coursier ${courierIndex + 1}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDocumentItem('CNI Recto', 'Approuvé'),
            _buildDocumentItem('CNI Verso', 'Approuvé'),
            _buildDocumentItem('Permis', 'En attente'),
            _buildDocumentItem('Carte Grise', 'Rejeté'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(String name, String status) {
    final statusColor = status == 'Approuvé'
        ? Colors.green
        : status == 'En attente'
            ? Colors.orange
            : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              border: Border.all(color: statusColor),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontSize: 12.0),
            ),
          ),
        ],
      ),
    );
  }

  void _approveCourier(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Coursier ${index + 1} approuvé')),
    );
  }

  void _rejectCourier(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter le coursier'),
        content: TextField(
          decoration: const InputDecoration(
            label: Text('Raison du rejet'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Coursier ${index + 1} rejeté')),
              );
            },
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }

  void _approveWithdrawal(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Retrait du coursier ${index + 1} approuvé')),
    );
  }

  void _rejectWithdrawal(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter le retrait'),
        content: TextField(
          decoration: const InputDecoration(
            label: Text('Raison du rejet'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Retrait du coursier ${index + 1} rejeté')),
              );
            },
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../services/call_service.dart';
import '../../../config/router.dart';

// ═══════════════════════════════════════════════════
// liste_conversations_screen.dart
// ═══════════════════════════════════════════════════
class ListeConversationsScreen extends ConsumerWidget {
  const ListeConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(chatRepositoryProvider).getConversations(
          'CURRENT_USER_ID', // TODO: remplacer par l'ID réel
        ),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final conversations = snap.data ?? [];
          if (conversations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.grisClair),
                  SizedBox(height: 16),
                  Text('Aucune conversation', style: TextStyle(color: AppColors.gris, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Vos échanges avec les coursiers\napparaîtront ici', textAlign: TextAlign.center, style: TextStyle(color: AppColors.grisClair)),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) {
              final conv = conversations[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.fondInput,
                  backgroundImage: conv['avatar_url'] != null ? NetworkImage(conv['avatar_url']) : null,
                  child: conv['avatar_url'] == null ? const Icon(Icons.person, color: AppColors.gris) : null,
                ),
                title: Text(conv['nom'] ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  conv['dernier_message'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: (conv['non_lus'] ?? 0) > 0 ? AppColors.noir : AppColors.gris,
                    fontWeight: (conv['non_lus'] ?? 0) > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(conv['heure'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.gris)),
                    if ((conv['non_lus'] ?? 0) > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppColors.bleuPrimaire, shape: BoxShape.circle),
                        child: Text('${conv['non_lus']}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ],
                ),
                onTap: () => context.push('/chat/${conv['livraison_id'] ?? 'sav'}/${conv['user_id']}'),
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// chat_screen.dart - messagerie temps réel
// ═══════════════════════════════════════════════════
class ChatScreen extends ConsumerStatefulWidget {
  final String livraisonId;
  final String interlocuteurId;

  const ChatScreen({
    super.key,
    required this.livraisonId,
    required this.interlocuteurId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();

  List<MessageModel> _messages = [];
  bool _loading = true;
  bool _sending = false;
  dynamic _channel; // RealtimeChannel

  String get _currentUserId => 'CURRENT_USER_ID'; // TODO

  @override
  void initState() {
    super.initState();
    _chargerMessages();
    _ecouterMessages();
  }

  Future<void> _chargerMessages() async {
    final msgs = await ref.read(chatRepositoryProvider).getMessages(
      userId1: _currentUserId,
      userId2: widget.interlocuteurId,
      livraisonId: widget.livraisonId != 'sav' ? widget.livraisonId : null,
    );
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    _scrollerEnBas();

    // Marquer comme lus
    await ref.read(chatRepositoryProvider).marquerCommeRus(
      destinataireId: _currentUserId,
      expediteurId: widget.interlocuteurId,
    );
  }

  void _ecouterMessages() {
    _channel = ref.read(chatRepositoryProvider).ecouterMessages(
      userId: _currentUserId,
      onNouveau: (msg) {
        if (msg.expediteurId == widget.interlocuteurId) {
          setState(() => _messages.add(msg));
          _scrollerEnBas();
        }
      },
    );
  }

  Future<void> _envoyer() async {
    final texte = _msgCtrl.text.trim();
    if (texte.isEmpty || _sending) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      final msg = await ref.read(chatRepositoryProvider).envoyerMessage(
        expediteurId: _currentUserId,
        destinataireId: widget.interlocuteurId,
        contenu: texte,
        livraisonId: widget.livraisonId != 'sav' ? widget.livraisonId : null,
      );
      setState(() => _messages.add(msg));
      _scrollerEnBas();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _envoyerPhoto() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xFile == null) return;

    setState(() => _sending = true);
    try {
      final msg = await ref.read(chatRepositoryProvider).envoyerMessage(
        expediteurId: _currentUserId,
        destinataireId: widget.interlocuteurId,
        contenu: '📷 Photo',
        livraisonId: widget.livraisonId != 'sav' ? widget.livraisonId : null,
        photo: File(xFile.path),
      );
      setState(() => _messages.add(msg));
      _scrollerEnBas();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollerEnBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _appeler() async {
    // TODO: récupérer le numéro de l'interlocuteur
    await ref.read(callServiceProvider).appelerTelephone(
      appelantId: _currentUserId,
      appelantRole: 'client',
      destinataireId: widget.interlocuteurId,
      numero: '+22600000000',
      livraisonId: widget.livraisonId,
    );
  }

  Future<void> _ouvrirWhatsApp() async {
    await ref.read(callServiceProvider).ouvrirWhatsApp(
      appelantId: _currentUserId,
      appelantRole: 'client',
      destinataireId: widget.interlocuteurId,
      numeroWhatsapp: '+22600000000',
      livraisonId: widget.livraisonId,
      messageInitial: 'Bonjour, je vous contacte pour la livraison NYME.',
    );
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    // TODO: unsubscribe channel
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(radius: 18, backgroundColor: AppColors.fondInput, child: Icon(Icons.person, size: 18, color: AppColors.gris)),
            const SizedBox(width: 10),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Interlocuteur', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('En ligne', style: TextStyle(fontSize: 11, color: AppColors.succes)),
              ],
            )),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.phone_outlined), onPressed: _appeler, tooltip: 'Appeler'),
          IconButton(
            icon: Image.asset('assets/icons/whatsapp.png', width: 22, errorBuilder: (_, __, ___) => const Icon(Icons.chat)),
            onPressed: _ouvrirWhatsApp,
            tooltip: 'WhatsApp',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('Commencez la conversation', style: TextStyle(color: AppColors.gris)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _BulleMessage(
                          message: _messages[i],
                          estMoi: _messages[i].expediteurId == _currentUserId,
                        ),
                      ),
          ),

          // Zone de saisie
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.image_outlined, color: AppColors.gris), onPressed: _envoyerPhoto),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Votre message...',
                        filled: true,
                        fillColor: AppColors.fondInput,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _envoyer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _envoyer,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: AppColors.bleuPrimaire, shape: BoxShape.circle),
                      child: _sending
                          ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Bulle de message
class _BulleMessage extends StatelessWidget {
  final MessageModel message;
  final bool estMoi;

  const _BulleMessage({required this.message, required this.estMoi});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: estMoi ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!estMoi) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.fondInput,
              backgroundImage: message.expediteur?.avatarUrl != null
                  ? NetworkImage(message.expediteur!.avatarUrl!)
                  : null,
              child: const Icon(Icons.person, size: 14, color: AppColors.gris),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: estMoi ? AppColors.bleuPrimaire : AppColors.fondInput,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(estMoi ? 18 : 4),
                  bottomRight: Radius.circular(estMoi ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.photoUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(message.photoUrl!, width: 180, fit: BoxFit.cover),
                    ),
                  if (message.contenu.isNotEmpty)
                    Text(
                      message.contenu,
                      style: TextStyle(color: estMoi ? Colors.white : AppColors.noir, fontSize: 14),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 10, color: estMoi ? Colors.white60 : AppColors.grisClair),
                      ),
                      if (estMoi) ...[
                        const SizedBox(width: 4),
                        Icon(message.lu ? Icons.done_all : Icons.done, size: 12, color: message.lu ? Colors.white : Colors.white60),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

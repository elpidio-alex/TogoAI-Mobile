/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Écran principal de conversation avec l'IA, gestionnaire d'état ChatController, affichage des messages, affichage des sources, sélection des modes (rag/realtime) et zone de saisie.
*/

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/togo_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/branding.dart';
import '../../../../shared/widgets/togo_widgets.dart';
import '../../../conversations/data/conversations_repository.dart';
import '../../../conversations/presentation/widgets/conversations_drawer.dart';
import '../../../settings/presentation/screens/settings_sheet.dart';
import '../../data/chat_stream_client.dart';

/// Génère un identifiant temporaire unique pour les messages locaux.
///
/// Utilisé pour l'insertion optimiste dans l'interface graphique avant
/// que l'identifiant définitif ne soit attribué par la base de données.
String _tempId() =>
    'local_${DateTime.now().microsecondsSinceEpoch}_${UniqueKey().hashCode}';

/// Contrôleur de session de messagerie instantanée (conversation nouvelle ou existante).
///
/// Orchestre le chargement de l'historique, la persistance locale/distante,
/// la communication en streaming SSE avec l'agent d'IA, et la mise à jour
/// réactive de l'état d'affichage [ChatViewState].
class ChatController extends StateNotifier<ChatViewState> {
  /// Initialise le contrôleur et déclenche le préchargement de l'historique
  /// si un [conversationId] valide est fourni.
  ChatController(this._ref, {this.conversationId})
      : super(ChatViewState(conversationId: conversationId)) {
    if (conversationId != null) {
      _loadHistory();
    }
  }

  final Ref _ref;
  String? conversationId;
  StreamSubscription<ChatStreamEvent>? _sub;
  final _client = ChatStreamClient();

  /// Accès au référentiel de conversations pour les requêtes de persistance.
  ConversationsRepository get _repo =>
      _ref.read(conversationsRepositoryProvider);

  /// Récupère la liste chronologique des messages de la conversation active.
  ///
  /// Met à jour l'indicateur de chargement [ChatViewState.loadingHistory]
  /// pour afficher un retour visuel à l'utilisateur.
  Future<void> _loadHistory() async {
    if (conversationId == null) return;
    state = state.copyWith(loadingHistory: true);
    try {
      final messages = await _repo.messages(conversationId!);
      state = state.copyWith(messages: messages, loadingHistory: false);
    } catch (_) {
      // En cas d'erreur réseau ou RLS, on bascule l'état sans bloquer l'écran
      state = state.copyWith(loadingHistory: false);
    }
  }

  /// Modifie le mode de réflexion et de recherche de l'IA ([ChatMode.rag] ou [ChatMode.realtime]).
  void setMode(ChatMode mode) {
    state = state.copyWith(mode: mode);
  }

  /// Déclenche l'envoi d'un message utilisateur vers le backend d'IA.
  Future<void> send(String text) => _send(text);

  /// Traitement complet de la soumission d'une question.
  ///
  /// 1. Validation du texte et de l'état actuel (évite les doubles envois).
  /// 2. Vérification de l'authentification active.
  /// 3. Initialisation de la conversation en base de données si premier échange.
  /// 4. Insertion optimiste dans l'UI du message utilisateur et de la bulle assistant en cours de streaming.
  /// 5. Ouverture du flux SSE et consommation incrémentale des fragments textuels et sources.
  Future<void> _send(String text) async {
    final question = text.trim();
    if (question.isEmpty || state.sending) return;

    final session = _ref.read(currentSessionProvider);
    if (session == null) return;

    // Création paresseuse de l'entité conversation lors du premier message
    if (conversationId == null) {
      final created = await _repo.create(
        userId: session.user.id,
        titre: _repo.titreDepuisQuestion(question),
      );
      conversationId = created.id;
      state = state.copyWith(conversationId: created.id);
    }

    // Préparation de l'historique contextuel pour le LLM (exclut les messages incomplets)
    final historique = state.messages
        .where((m) => !m.isStreaming && m.contenu.isNotEmpty)
        .map((m) => m.toHistorique())
        .toList();

    // Création des objets de message pour affichage immédiat (pattern Optimistic UI)
    final userMsg = ChatMessage(
      id: _tempId(),
      role: 'user',
      contenu: question,
      createdAt: DateTime.now(),
    );

    final assistantId = _tempId();
    final assistantMsg = ChatMessage(
      id: assistantId,
      role: 'assistant',
      contenu: '',
      mode: state.mode.apiValue,
      isStreaming: true,
    );

    // Injection dans l'état réactif
    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      sending: true,
      error: null,
    );

    // Tentative de persistance asynchrone du message utilisateur
    try {
      await _repo.insertMessage(
        conversationId: conversationId!,
        role: 'user',
        contenu: question,
      );
    } catch (_) {
      // Tolérance aux pannes : on poursuit le streaming même si la persistance immédiate échoue
    }

    var fullText = '';
    var collectedSources = <ChatSource>[];

    // Annulation préventive d'un flux antérieur toujours actif
    await _sub?.cancel();
    _sub = _client
        .stream(
          question: question,
          mode: state.mode,
          historique: historique,
          token: session.accessToken,
        )
        .listen(
      (event) {
        switch (event) {
          case ChatStreamSources(:final sources):
            // Réception des sources documentaires associées à la réponse
            collectedSources = sources;
            _patchAssistant(
              assistantId,
              fullText,
              collectedSources,
              streaming: true,
            );
          case ChatStreamChunk(:final text):
            // Concaténation progressive du texte généré par l'IA
            fullText += text;
            _patchAssistant(
              assistantId,
              fullText,
              collectedSources,
              streaming: true,
            );
          case ChatStreamDone():
            // Clôture normale du flux
            _finishAssistant(assistantId, fullText, collectedSources);
          case ChatStreamError(:final message):
            // Erreur signalée explicitement par le serveur
            _fail(assistantId, message);
        }
      },
      onError: (e) => _fail(assistantId, e.toString()),
      onDone: () {
        if (state.sending) {
          _finishAssistant(assistantId, fullText, collectedSources);
        }
      },
    );
  }

  /// Relance l'inférence pour la question spécifiée par [userText].
  Future<void> retry(String userText) => _send(userText);

  /// Met à jour localement le contenu et l'état du message assistant en cours d'affichage.
  void _patchAssistant(
    String id,
    String text,
    List<ChatSource> sources, {
    required bool streaming,
  }) {
    final messages = state.messages.map((m) {
      if (m.id != id) return m;
      return m.copyWith(
        contenu: text,
        sources: sources,
        isStreaming: streaming,
      );
    }).toList();
    state = state.copyWith(messages: messages);
  }

  /// Finalise la réception du message de l'IA et persiste les résultats dans Supabase.
  ///
  /// Sauvegarde le message complet, associe les sources citées, met à jour
  /// la date de dernière activité de la conversation et invalide le cache de la liste.
  Future<void> _finishAssistant(
    String id,
    String text,
    List<ChatSource> sources,
  ) async {
    _patchAssistant(id, text, sources, streaming: false);
    state = state.copyWith(sending: false);
    if (conversationId == null || text.isEmpty) return;
    try {
      final saved = await _repo.insertMessage(
        conversationId: conversationId!,
        role: 'assistant',
        contenu: text,
        mode: state.mode.apiValue,
      );
      await _repo.insertSources(saved.id, sources);
      await _repo.touchConversation(
        conversationId!,
        titre: _repo.titreDepuisQuestion(
          state.messages.firstWhere((m) => m.role == 'user').contenu,
        ),
      );
      // Notifie les observateurs de la liste des conversations du changement de titre/horodatage
      _ref.invalidate(conversationsListProvider);
    } catch (_) {
      // Échec silencieux de la persistance en cas de déconnexion réseau
    }
  }

  /// Gère les erreurs de streaming en injectant un message d'échec lisible dans la bulle.
  void _fail(String id, String message) {
    _patchAssistant(
      id,
      message.isEmpty ? 'chat.erreurEnvoi'.tr() : message,
      const [],
      streaming: false,
    );
    state = state.copyWith(sending: false, error: message);
  }

  /// Interrompt manuellement le streaming en cours à la demande de l'utilisateur.
  void stop() {
    _sub?.cancel();
    state = state.copyWith(sending: false);
    final msgs = state.messages.map((m) {
      if (m.isStreaming) return m.copyWith(isStreaming: false);
      return m;
    }).toList();
    state = state.copyWith(messages: msgs);
  }

  /// Libère les ressources du contrôleur : souscription de flux et client HTTP SSE.
  @override
  void dispose() {
    _sub?.cancel();
    _client.close();
    super.dispose();
  }
}

/// État immuable de l'écran de messagerie instantanée.
///
/// Encapsule la liste des messages affichés, le mode d'interrogation sélectionné,
/// les indicateurs de chargement ou d'envoi en cours, et l'identifiant de conversation actif.
class ChatViewState {
  /// Crée une instance immuable de l'état de chat.
  const ChatViewState({
    this.messages = const [],
    this.mode = ChatMode.rag,
    this.sending = false,
    this.loadingHistory = false,
    this.error,
    this.conversationId,
  });

  /// Liste ordonnée chronologiquement des messages (utilisateur et assistant).
  final List<ChatMessage> messages;

  /// Mode d'interrogation en vigueur (RAG documentaire ou actualité temps réel).
  final ChatMode mode;

  /// Indique si une requête d'inférence ou de streaming est en cours d'exécution.
  final bool sending;

  /// Indique si les messages de l'historique sont en cours de récupération depuis Supabase.
  final bool loadingHistory;

  /// Message d'erreur éventuel survenu lors du transport ou du traitement.
  final String? error;

  /// Identifiant UUID de la conversation en base de données, ou null si non initialisée.
  final String? conversationId;

  /// Produit une copie immuable de l'état avec certains champs substitués.
  ChatViewState copyWith({
    List<ChatMessage>? messages,
    ChatMode? mode,
    bool? sending,
    bool? loadingHistory,
    String? error,
    String? conversationId,
  }) {
    return ChatViewState(
      messages: messages ?? this.messages,
      mode: mode ?? this.mode,
      sending: sending ?? this.sending,
      loadingHistory: loadingHistory ?? this.loadingHistory,
      error: error,
      conversationId: conversationId ?? this.conversationId,
    );
  }
}

/// Fournisseur Riverpod avec cycle de vie auto-dispose indexé par identifiant de conversation.
///
/// Instancie un [ChatController] dédié à une session spécifique ou à une nouvelle discussion.
final chatControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatController, ChatViewState, String?>((ref, conversationId) {
  return ChatController(ref, conversationId: conversationId);
});

/// Écran principal de discussion avec l'intelligence artificielle TogoAI.
///
/// Affiche l'historique de discussion, le tiroir latéral des conversations antérieures,
/// le panneau d'options (renommage, suppression) et le champ de saisie multimodal.
class ChatScreen extends ConsumerStatefulWidget {
  /// Construit la vue de chat pour la conversation [conversationId] (ou 'nouvelle').
  const ChatScreen({super.key, this.conversationId});

  /// Identifiant optionnel de la conversation existante à charger.
  final String? conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Vérification asynchrone post-rendu pour rediriger si le profil est incomplet
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureOnboarding());
  }

  /// Vérifie que l'utilisateur a finalisé son tunnel d'onboarding (nom et prénom obligatoires).
  Future<void> _ensureOnboarding() async {
    final profile = await ref.read(userProfileProvider.future);
    if (!mounted) return;
    if (profile != null && !profile.hasRequiredName) {
      // Redirection immédiate vers l'écran d'enregistrement d'identité
      context.go('/onboarding/nom-prenom');
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Compose un message d'accueil dynamique tenant compte de l'heure locale et du prénom.
  String _greeting(UserProfile? profile) {
    final hour = DateTime.now().hour;
    final base =
        (hour >= 18 || hour < 5) ? 'chat.bonsoir'.tr() : 'chat.bonjour'.tr();
    final name = profile?.displayName;
    if (name == null || name.isEmpty) return base;
    return '$base, $name';
  }

  /// Déclenche l'envoi du message saisi et anime la vue jusqu'en bas de liste.
  Future<void> _send(ChatController ctrl) async {
    final text = _input.text;
    _input.clear();
    await ctrl.send(text);
    // Défilement automatique vers le nouveau message utilisateur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Affiche une boîte de dialogue pour renommer l'intitulé de la conversation active.
  Future<void> _renameActive(String activeId) async {
    final repo = ref.read(conversationsRepositoryProvider);
    final convs = await ref.read(conversationsListProvider.future);
    if (!mounted) return;
    final current = convs.where((c) => c.id == activeId).firstOrNull;
    final controller = TextEditingController(text: current?.titre ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('nav.renommer'.tr()),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('settings.fermer'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('settings.enregistrer'.tr()),
          ),
        ],
      ),
    );

    if (ok == true && controller.text.trim().isNotEmpty && mounted) {
      await repo.rename(activeId, controller.text.trim());
      ref.invalidate(conversationsListProvider);
    }
  }

  /// Affiche une alerte de confirmation puis purge la conversation courante.
  Future<void> _deleteActive(String activeId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('nav.supprimer'.tr()),
        content: Text('chat.confirmerSuppression'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('settings.fermer'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'nav.supprimer'.tr(),
              style: TextStyle(color: ctx.togo.danger),
            ),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      try {
        await ref.read(conversationsRepositoryProvider).delete(activeId);
        ref.invalidate(conversationsListProvider);
        ref.invalidate(chatControllerProvider(activeId));
        if (mounted) {
          // Bascule sur une session vierge après suppression
          context.go('/chat/nouvelle');
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('nav.erreurSuppression'.tr())),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.conversationId == 'nouvelle' ? null : widget.conversationId;
    final chat = ref.watch(chatControllerProvider(id));
    final ctrl = ref.read(chatControllerProvider(id).notifier);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final canSend = _input.text.trim().isNotEmpty || chat.sending;
    final activeConvId = chat.conversationId ?? id;

    return Scaffold(
      key: _scaffoldKey,
      drawer: ConversationsDrawer(
        currentId: activeConvId ?? widget.conversationId,
        onOpenSettings: () {
          Navigator.of(context).pop();
          showSettingsSheet(context);
        },
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const _DegressiveBarsIcon(),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const TogoLogoWordmark(size: 28),
        actions: [
          // Menu contextuel si une conversation est activement persistée
          if (activeConvId != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'nav.options'.tr(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
              onSelected: (value) async {
                if (value == 'rename') {
                  await _renameActive(activeConvId);
                } else if (value == 'delete') {
                  await _deleteActive(activeConvId);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: 10),
                      Text('nav.renommer'.tr()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: context.togo.danger),
                      const SizedBox(width: 10),
                      Text(
                        'nav.supprimer'.tr(),
                        style: TextStyle(color: context.togo.danger),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'nav.newConversation'.tr(),
            onPressed: () => context.go('/chat/nouvelle'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : chat.messages.isEmpty
                    ? _EmptyState(greeting: _greeting(profile))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: chat.messages.length,
                        itemBuilder: (context, i) {
                          final msg = chat.messages[i];
                          // Retrouve la question utilisateur précédente pour alimenter l'action de réessai
                          String? prevUserQuestion;
                          if (msg.role == 'assistant') {
                            for (var j = i - 1; j >= 0; j--) {
                              if (chat.messages[j].role == 'user') {
                                prevUserQuestion = chat.messages[j].contenu;
                                break;
                              }
                            }
                          }
                          return _MessageBubble(
                            message: msg,
                            onRetry: prevUserQuestion != null && !chat.sending
                                ? () => ctrl.retry(prevUserQuestion!)
                                : null,
                          );
                        },
                      ),
          ),
          _Composer(
            controller: _input,
            mode: chat.mode,
            sending: chat.sending,
            onMode: ctrl.setMode,
            onSend: () => _send(ctrl),
            onStop: ctrl.stop,
            onChanged: (_) => setState(() {}),
            canSend: canSend,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'chat.avertissement'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: context.togo.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// État vide accueillant l'utilisateur sur une nouvelle session sans messages.
class _EmptyState extends StatelessWidget {
  /// Crée la vue d'accueil avec une formule de bienvenue personnalisée [greeting].
  const _EmptyState({required this.greeting});
  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TogoLogoBadge(size: 48),
            const SizedBox(height: 20),
            Text(
              greeting,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'chat.accueilTexte'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.togo.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

/// Zone de composition de message avec champ de saisie, sélecteurs de mode et bouton d'action.
class _Composer extends StatelessWidget {
  /// Initialise la barre de composition avec ses gestionnaires d'actions.
  const _Composer({
    required this.controller,
    required this.mode,
    required this.sending,
    required this.onMode,
    required this.onSend,
    required this.onStop,
    required this.onChanged,
    required this.canSend,
  });

  final TextEditingController controller;
  final ChatMode mode;
  final bool sending;
  final ValueChanged<ChatMode> onMode;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final ValueChanged<String> onChanged;
  final bool canSend;

  @override
  Widget build(BuildContext context) {
    final t = context.togo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: t.bgCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: t.inputBorder),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              onChanged: onChanged,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onSubmitted: (_) {
                if (!sending && controller.text.trim().isNotEmpty) onSend();
              },
              decoration: InputDecoration(
                hintText: 'chat.ecrivezVotreQuestion'.tr(),
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: t.textSecondary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TogoChoiceChip(
                          label: 'chat.modeBaseConnaissances'.tr(),
                          selected: mode == ChatMode.rag,
                          onTap: () => onMode(ChatMode.rag),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          fontSize: 12,
                          leading: Icon(
                            Icons.menu_book_outlined,
                            size: 14,
                            color: mode == ChatMode.rag
                                ? t.accent
                                : t.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        TogoChoiceChip(
                          label: 'chat.modeActuDirecte'.tr(),
                          selected: mode == ChatMode.realtime,
                          onTap: () => onMode(ChatMode.realtime),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          fontSize: 12,
                          leading: Icon(
                            Icons.cell_tower,
                            size: 14,
                            color: mode == ChatMode.realtime
                                ? t.accent
                                : t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: sending
                      ? t.accent
                      : (controller.text.trim().isEmpty
                          ? t.sendDisabled
                          : t.accent),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: sending
                        ? onStop
                        : (controller.text.trim().isEmpty ? null : onSend),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        sending ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bulle de message affichant les questions de l'utilisateur ou les réponses rédigées par l'IA.
class _MessageBubble extends StatelessWidget {
  /// Construit la bulle d'échange avec gestion facultative du bouton de réessai.
  const _MessageBubble({required this.message, this.onRetry});
  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final t = context.togo;

    // Rendu spécifique pour les messages émis par l'utilisateur
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.userBubble,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.contenu,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    // Rendu pour les réponses générées par l'agent IA
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/logo_icon.png', width: 28, height: 28),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText(
                  message.contenu.isEmpty && message.isStreaming
                      ? '…'
                      : message.contenu,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          // Affichage des sources documentaires associées
          if (message.sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.sources
                  .map((s) => _SourceChip(source: s))
                  .toList(),
            ),
          ],
          // Barre d'actions sous le message (copie dans le presse-papier, relance)
          if (!message.isStreaming && message.contenu.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  tooltip: 'chat.copier'.tr(),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message.contenu));
                  },
                ),
                if (onRetry != null) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'chat.relancer'.tr(),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.refresh_outlined, size: 18),
                    onPressed: onRetry,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Pastille cliquable représentant une source documentaire citée par l'IA.
class _SourceChip extends StatelessWidget {
  /// Initialise la puce avec la référence documentaire [source].
  const _SourceChip({required this.source});
  final ChatSource source;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        source.source.isNotEmpty ? source.source : source.titre,
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: () async {
        final uri = Uri.tryParse(source.lien);
        if (uri != null && await canLaunchUrl(uri)) {
          // Ouverture sécurisée dans le navigateur externe de l'OS
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}

/// Icône hamburger à 3 barres de longueurs dégressives (longue, moyenne, courte),
/// alignées à gauche, pour un style moderne.
class _DegressiveBarsIcon extends StatelessWidget {
  /// Crée l'icône de navigation personnalisée.
  const _DegressiveBarsIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 18,
      child: CustomPaint(
        painter: _DegressiveBarsPainter(
          color: IconTheme.of(context).color ??
              Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Peintre personnalisé dessinant les trois barres dégressives avec angles arrondis.
class _DegressiveBarsPainter extends CustomPainter {
  /// Initialise le peintre avec la couleur d'icône [color].
  _DegressiveBarsPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;

    final barWidths = [size.width, size.width * 0.70, size.width * 0.45];
    final spacing = (size.height - paint.strokeWidth) / 2;

    for (var i = 0; i < 3; i++) {
      final y = paint.strokeWidth / 2 + i * spacing;
      canvas.drawLine(Offset(0, y), Offset(barWidths[i], y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DegressiveBarsPainter oldDelegate) =>
      color != oldDelegate.color;
}

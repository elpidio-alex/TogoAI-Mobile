/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Dépôt de données pour les conversations, messages et sources dans Supabase (CRUD, suppression en cascade et génération de titre heuristique).
*/

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/auth_provider.dart';

/// Modèle représentant une conversation utilisateur persistée dans Supabase.
class Conversation {
  /// Crée une instance immuable de [Conversation].
  const Conversation({
    required this.id,
    required this.titre,
    this.createdAt,
    this.updatedAt,
  });

  /// Identifiant UUID unique de la conversation.
  final String id;

  /// Titre affiché de la conversation.
  final String titre;

  /// Date et heure de création UTC.
  final DateTime? createdAt;

  /// Date et heure de dernière mise à jour UTC.
  final DateTime? updatedAt;

  /// Désérialise une réponse JSON/Map Supabase en instance de [Conversation].
  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      titre: (map['titre'] as String?) ?? 'Nouvelle discussion',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }
}

/// Modèle représentant une source d'information ou référence documentaire liée à un message d'assistant.
class ChatSource {
  /// Crée une source documentaire rattachée à une réponse.
  const ChatSource({
    required this.titre,
    required this.source,
    required this.lien,
  });

  /// Titre de l'article ou de la page de référence.
  final String titre;

  /// Nom de l'éditeur ou du média source (ex: 'République Togolaise', 'TogoFirst').
  final String source;

  /// URL externe vers le document source original.
  final String lien;

  /// Désérialise une map Supabase ou un événement SSE en instance de [ChatSource].
  factory ChatSource.fromMap(Map<String, dynamic> map) {
    return ChatSource(
      titre: (map['titre'] as String?) ?? '',
      source: (map['source'] as String?) ??
          (map['source_nom'] as String?) ??
          '',
      lien: (map['lien'] as String?) ?? '',
    );
  }

  /// Prépare la charge utile pour l'insertion SQL dans la table Supabase `sources`.
  Map<String, dynamic> toInsert(String messageId) => {
        'message_id': messageId,
        'titre': titre,
        'lien': lien,
        'source_nom': source,
      };
}

/// Modèle immuable représentant un message de discussion individuel.
class ChatMessage {
  /// Crée une instance de message.
  const ChatMessage({
    required this.id,
    required this.role,
    required this.contenu,
    this.mode,
    this.sources = const [],
    this.createdAt,
    this.isStreaming = false,
  });

  /// Identifiant UUID unique du message.
  final String id;

  /// Rôle de l'émetteur : `'user'` pour l'utilisateur, `'assistant'` pour le modèle IA.
  final String role;

  /// Contenu textuel markdown du message.
  final String contenu;

  /// Mode de génération utilisé (`'rag'` ou `'realtime'`).
  final String? mode;

  /// Liste des sources documentaires associées à la réponse.
  final List<ChatSource> sources;

  /// Horodatage de création du message.
  final DateTime? createdAt;

  /// Indicateur d'état actif : `true` si le texte est actuellement en cours de streaming SSE.
  final bool isStreaming;

  /// Clone l'instance en modifiant sélectivement certains champs.
  ChatMessage copyWith({
    String? contenu,
    List<ChatSource>? sources,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      contenu: contenu ?? this.contenu,
      mode: mode,
      sources: sources ?? this.sources,
      createdAt: createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  /// Désérialise un message extrait de Supabase avec ses sources imbriquées.
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final rawSources = map['sources'];
    List<ChatSource> sources = [];
    if (rawSources is List) {
      sources = rawSources
          .map((e) => ChatSource.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return ChatMessage(
      id: map['id'] as String,
      role: map['role'] as String,
      contenu: map['contenu'] as String? ?? '',
      mode: map['mode'] as String?,
      sources: sources,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  /// Formate le message pour l'historique de contexte envoyé au LLM.
  Map<String, String> toHistorique() => {
        'role': role,
        'contenu': contenu,
      };
}

/// Dépôt de données gérant les interactions CRUD avec Supabase pour les discussions.
///
/// Encapsule l'accès aux tables `conversations`, `messages` et `sources`
/// et assure l'intégrité référentielle manuelle lors des suppressions.
class ConversationsRepository {
  /// Initialise le dépôt avec l'instance active du client Supabase.
  ConversationsRepository(this._client);

  final SupabaseClient _client;

  /// Récupère la liste ordonnée des conversations d'un utilisateur par date de modification descendante.
  Future<List<Conversation>> list(String userId) async {
    final rows = await _client
        .from('conversations')
        .select('id, titre, created_at, updated_at')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((e) => Conversation.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Crée une nouvelle conversation en base de données et retourne l'enregistrement créé.
  Future<Conversation> create({
    required String userId,
    String? titre,
  }) async {
    final row = await _client
        .from('conversations')
        .insert({
          'user_id': userId,
          'titre': (titre == null || titre.trim().isEmpty)
              ? 'Nouvelle discussion'
              : titre.trim(),
        })
        .select('id, titre, created_at, updated_at')
        .single();
    return Conversation.fromMap(Map<String, dynamic>.from(row));
  }

  /// Renomme une conversation existante et met à jour son horodatage.
  Future<void> rename(String id, String titre) async {
    await _client.from('conversations').update({
      'titre': titre.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Supprime une conversation ainsi que tous ses messages et sources associés en cascade.
  Future<void> delete(String id) async {
    try {
      // 1. Récupérer les identifiants des messages rattachés
      final msgRows = await _client
          .from('messages')
          .select('id')
          .eq('conversation_id', id);

      final messageIds = (msgRows as List)
          .map((m) => m['id'] as String?)
          .whereType<String>()
          .toList();

      // 2. Supprimer les sources associées aux messages
      if (messageIds.isNotEmpty) {
        await _client
            .from('sources')
            .delete()
            .inFilter('message_id', messageIds);
      }

      // 3. Supprimer les messages de la conversation
      await _client.from('messages').delete().eq('conversation_id', id);

      // 4. Supprimer la conversation elle-même
      await _client.from('conversations').delete().eq('id', id);
    } catch (e) {
      // Fallback : tente la suppression directe si des triggers SQL CASCADE sont déjà en place
      await _client.from('conversations').delete().eq('id', id);
    }
  }

  /// Charge tous les messages d'une conversation avec leurs sources associées.
  Future<List<ChatMessage>> messages(String conversationId) async {
    final rows = await _client
        .from('messages')
        .select(
          'id, conversation_id, role, contenu, mode, created_at, sources(id, message_id, titre, lien, source_nom)',
        )
        .eq('conversation_id', conversationId)
        .order('created_at');
    return (rows as List)
        .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Enregistre un message (utilisateur ou assistant) dans la table `messages`.
  Future<ChatMessage> insertMessage({
    required String conversationId,
    required String role,
    required String contenu,
    String? mode,
  }) async {
    final row = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'role': role,
          'contenu': contenu,
          if (mode != null) 'mode': mode,
        })
        .select('id, conversation_id, role, contenu, mode, created_at')
        .single();
    return ChatMessage.fromMap(Map<String, dynamic>.from(row));
  }

  /// Insère en lot les sources documentaires rattachées à un message d'assistant.
  Future<void> insertSources(String messageId, List<ChatSource> sources) async {
    if (sources.isEmpty) return;
    await _client.from('sources').insert(
          sources.map((s) => s.toInsert(messageId)).toList(),
        );
  }

  /// Met à jour l'horodatage `updated_at` d'une conversation et optionnellement son titre.
  Future<void> touchConversation(String id, {String? titre}) async {
    await _client.from('conversations').update({
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (titre != null) 'titre': titre,
    }).eq('id', id);
  }

  /// Heuristique générant un titre concis et lisible à partir de la première question posée.
  ///
  /// Nettoie les caractères spéciaux indésirables, normalise les espaces
  /// et tronque la chaîne aux 7 premiers mots significatifs.
  String titreDepuisQuestion(String question) {
    final texte = question
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll(RegExp(r'[^\w\s\-àâäéèêëïîôùûüçÀÂÄÉÈÊËÏÎÔÙÛÜÇ]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (texte.isEmpty) return 'Nouvelle discussion';
    final mots = texte.split(' ').where((m) => m.isNotEmpty).take(7);
    final titre = mots.join(' ');
    return titre.isEmpty ? 'Nouvelle discussion' : titre;
  }
}

/// Provider Riverpod instanciant le [ConversationsRepository] avec le client Supabase actif.
final conversationsRepositoryProvider = Provider<ConversationsRepository>((ref) {
  return ConversationsRepository(ref.watch(supabaseProvider));
});

/// FutureProvider auto-disposable chargeant les conversations de l'utilisateur connecté.
final conversationsListProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return [];
  return ref.watch(conversationsRepositoryProvider).list(session.user.id);
});

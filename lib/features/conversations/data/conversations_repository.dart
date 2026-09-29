import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/auth_provider.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.titre,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String titre;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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

class ChatSource {
  const ChatSource({
    required this.titre,
    required this.source,
    required this.lien,
  });

  final String titre;
  final String source;
  final String lien;

  factory ChatSource.fromMap(Map<String, dynamic> map) {
    return ChatSource(
      titre: (map['titre'] as String?) ?? '',
      source: (map['source'] as String?) ??
          (map['source_nom'] as String?) ??
          '',
      lien: (map['lien'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toInsert(String messageId) => {
        'message_id': messageId,
        'titre': titre,
        'lien': lien,
        'source_nom': source,
      };
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.contenu,
    this.mode,
    this.sources = const [],
    this.createdAt,
    this.isStreaming = false,
  });

  final String id;
  final String role; // user | assistant
  final String contenu;
  final String? mode;
  final List<ChatSource> sources;
  final DateTime? createdAt;
  final bool isStreaming;

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

  Map<String, String> toHistorique() => {
        'role': role,
        'contenu': contenu,
      };
}

class ConversationsRepository {
  ConversationsRepository(this._client);

  final SupabaseClient _client;

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

  Future<void> rename(String id, String titre) async {
    await _client.from('conversations').update({
      'titre': titre.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

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

      // 4. Supprimer la conversation
      await _client.from('conversations').delete().eq('id', id);
    } catch (e) {
      // En cas d'échec ou si cascade déjà configurée en base, tenter la suppression directe
      await _client.from('conversations').delete().eq('id', id);
    }
  }

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

  Future<void> insertSources(String messageId, List<ChatSource> sources) async {
    if (sources.isEmpty) return;
    await _client.from('sources').insert(
          sources.map((s) => s.toInsert(messageId)).toList(),
        );
  }

  Future<void> touchConversation(String id, {String? titre}) async {
    await _client.from('conversations').update({
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (titre != null) 'titre': titre,
    }).eq('id', id);
  }

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

final conversationsRepositoryProvider = Provider<ConversationsRepository>((ref) {
  return ConversationsRepository(ref.watch(supabaseProvider));
});

final conversationsListProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return [];
  return ref.watch(conversationsRepositoryProvider).list(session.user.id);
});

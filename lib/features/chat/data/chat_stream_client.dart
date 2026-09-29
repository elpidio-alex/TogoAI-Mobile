/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Client HTTP pour le streaming SSE (Server-Sent Events) vers l'endpoint FastAPI /chat/stream, avec parsing des événements de sources, morceaux de texte et statut de complétion.
*/

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../conversations/data/conversations_repository.dart';

/// Modes de génération du modèle d'IA TogoAI alignés sur l'API backend FastAPI.
enum ChatMode {
  /// Mode RAG (Retrieval-Augmented Generation) : recherche sémantique vectorielle dans la base de connaissances documentaire du Togo.
  rag,

  /// Mode temps réel : interrogation directe avec accès aux flux d'actualités et données récentes.
  realtime;

  /// Valeur de chaîne sérialisée transmise dans la charge utile JSON de l'API.
  String get apiValue => name;
}

/// Classe scellée racine pour tous les événements émis par le flux SSE de discussion.
sealed class ChatStreamEvent {
  /// Constructeur constant pour les sous-classes d'événements.
  const ChatStreamEvent();
}

/// Événement émis en début de réponse listant les sources documentaires / articles consultés par le modèle.
class ChatStreamSources extends ChatStreamEvent {
  /// Crée un événement contenant la liste des sources [ChatSource].
  const ChatStreamSources(this.sources);

  /// Liste des références et documents sources.
  final List<ChatSource> sources;
}

/// Morceau de texte brut (token / chunk) streamé incrémentalement par le LLM.
class ChatStreamChunk extends ChatStreamEvent {
  /// Crée un morceau de texte partiel.
  const ChatStreamChunk(this.text);

  /// Fragment textuel généré.
  final String text;
}

/// Événement signalant la fin de la génération et de la transmission du message.
class ChatStreamDone extends ChatStreamEvent {
  /// Crée un événement de complétion de stream.
  const ChatStreamDone();
}

/// Événement émis lorsqu'une erreur survient côté backend ou lors du transport réseau.
class ChatStreamError extends ChatStreamEvent {
  /// Crée un événement d'erreur avec un message explicatif.
  const ChatStreamError(this.message);

  /// Description de l'erreur survenue.
  final String message;
}

/// Client HTTP optimisé pour la consommation d'événements SSE (Server-Sent Events) via `POST /chat/stream`.
///
/// Gère la reconstruction des fragments TCP/HTTP, le parsing des lignes `data:`,
/// et la transformation en flux typé asynchrone [ChatStreamEvent].
class ChatStreamClient {
  /// Crée une instance du client de stream en injectant optionnellement un [http.Client] pour les tests.
  ChatStreamClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Client HTTP sous-jacent.
  final http.Client _http;

  /// Établit la connexion SSE et renvoie un flux d'événements typés en temps réel.
  ///
  /// Paramètres :
  /// - [question] : Question ou prompt textuel saisi par l'utilisateur.
  /// - [mode] : Mode de réponse sélectionné ([ChatMode.rag] ou [ChatMode.realtime]).
  /// - [historique] : Contexte conversationnel sous forme de liste de couples rôle/contenu `[{ "role": "user", "content": "..." }]`.
  /// - [token] : Jeton d'authentification JWT Supabase optionnel.
  Stream<ChatStreamEvent> stream({
    required String question,
    required ChatMode mode,
    List<Map<String, String>> historique = const [],
    String? token,
  }) async* {
    final uri = Uri.parse('${AppConfig.resolvedBackendUrl}/chat/stream');
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        if (AppConfig.internalApiKey.isNotEmpty)
          'X-Internal-API-Key': AppConfig.internalApiKey,
        if (AppConfig.sendJwtToBackend && token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      })
      ..body = jsonEncode({
        'question': question,
        'mode': mode.apiValue,
        'historique': historique,
      });

    // Envoi de la requête en mode streaming pour lire le corps de réponse au fil de l'eau
    final response = await _http.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      yield ChatStreamError(
        'HTTP ${response.statusCode}: ${body.isEmpty ? 'erreur réseau' : body}',
      );
      return;
    }

    // Tampon mémoire pour accumuler les fragments de flux et découper sur les délimiteurs SSE standards (\n\n)
    final buffer = StringBuffer();
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      final raw = buffer.toString();
      final parts = raw.split('\n\n');

      // Préserve le dernier fragment s'il est incomplet (non terminé par \n\n)
      buffer
        ..clear()
        ..write(parts.isNotEmpty && !raw.endsWith('\n\n') ? parts.last : '');

      // Détermine les blocs d'événements entièrement reçus
      final complete = raw.endsWith('\n\n')
          ? parts
          : parts.sublist(0, parts.length - 1);

      for (final part in complete) {
        final event = _parseSse(part);
        if (event != null) yield event;
        // Arrêt immédiat de la lecture du flux dès complétion ou erreur
        if (event is ChatStreamDone || event is ChatStreamError) return;
      }
    }

    // Traite un éventuel reste de tampon à la clôture de la connexion
    final leftover = buffer.toString();
    if (leftover.trim().isNotEmpty) {
      final event = _parseSse(leftover);
      if (event != null) yield event;
    }
  }

  /// Analyse et désérialise un bloc textuel d'événement SSE.
  ///
  /// Extrait les lignes préfixées par `data:`, concatène la charge JSON,
  /// et retourne l'instance d'événement correspondante.
  ChatStreamEvent? _parseSse(String block) {
    final lines = block.split('\n');
    final dataLines = <String>[];
    for (final line in lines) {
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
    if (dataLines.isEmpty) return null;
    final payload = dataLines.join('\n');
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final type = json['type'] as String?;
      switch (type) {
        case 'sources':
          final data = json['data'] as List? ?? [];
          return ChatStreamSources(
            data
                .map((e) =>
                    ChatSource.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList(),
          );
        case 'chunk':
          return ChatStreamChunk('${json['data'] ?? ''}');
        case 'done':
          return const ChatStreamDone();
        case 'error':
          return ChatStreamError('${json['data'] ?? 'Erreur inconnue'}');
        default:
          return null;
      }
    } catch (_) {
      // Ignorer les blocs SSE non-JSON ou malformés
      return null;
    }
  }

  /// Ferme les connexions persistantes du client HTTP.
  void close() => _http.close();
}

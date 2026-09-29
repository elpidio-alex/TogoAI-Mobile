import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../conversations/data/conversations_repository.dart';

/// Mode chat aligné sur FastAPI / Next.js : rag | realtime
enum ChatMode {
  rag,
  realtime;

  String get apiValue => name;
}

sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

class ChatStreamSources extends ChatStreamEvent {
  const ChatStreamSources(this.sources);
  final List<ChatSource> sources;
}

class ChatStreamChunk extends ChatStreamEvent {
  const ChatStreamChunk(this.text);
  final String text;
}

class ChatStreamDone extends ChatStreamEvent {
  const ChatStreamDone();
}

class ChatStreamError extends ChatStreamEvent {
  const ChatStreamError(this.message);
  final String message;
}

/// Client SSE natif pour `POST /chat/stream`.
///
/// **Sécurité :** FastAPI protège via `X-Internal-API-Key`. Cette clé ne doit
/// PAS être dans l'app store. En attendant un gateway JWT rétrocompatible,
/// le header n'est envoyé que si `INTERNAL_API_KEY` est passé en
/// `--dart-define` (debug).
class ChatStreamClient {
  ChatStreamClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

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

    final response = await _http.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      yield ChatStreamError(
        'HTTP ${response.statusCode}: ${body.isEmpty ? 'erreur réseau' : body}',
      );
      return;
    }

    final buffer = StringBuffer();
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      final raw = buffer.toString();
      final parts = raw.split('\n\n');
      // Keep incomplete trailing fragment
      buffer
        ..clear()
        ..write(parts.isNotEmpty && !raw.endsWith('\n\n') ? parts.last : '');

      final complete = raw.endsWith('\n\n')
          ? parts
          : parts.sublist(0, parts.length - 1);

      for (final part in complete) {
        final event = _parseSse(part);
        if (event != null) yield event;
        if (event is ChatStreamDone || event is ChatStreamError) return;
      }
    }

    // Flush remaining
    final leftover = buffer.toString();
    if (leftover.trim().isNotEmpty) {
      final event = _parseSse(leftover);
      if (event != null) yield event;
    }
  }

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
      return null;
    }
  }

  void close() => _http.close();
}

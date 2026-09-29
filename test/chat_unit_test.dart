import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:togoai_mobile/features/conversations/data/conversations_repository.dart';

void main() {
  group('ConversationsRepository title extraction', () {
    test('titreDepuisQuestion produces clean truncated titles', () {
      final repo = ConversationsRepository(FakeSupabaseClient());

      expect(
        repo.titreDepuisQuestion('Quelle est la météo à Lomé aujourd\'hui ?'),
        'Quelle est la météo à Lomé aujourdhui',
      );

      expect(
        repo.titreDepuisQuestion(''),
        'Nouvelle discussion',
      );
    });
  });

  group('ChatMessage & ChatSource models', () {
    test('serialization and copyWith', () {
      const source = ChatSource(
        titre: 'Article Togo',
        source: 'republicoftogo.com',
        lien: 'https://example.com',
      );

      final insertMap = source.toInsert('msg_123');
      expect(insertMap['message_id'], 'msg_123');
      expect(insertMap['source_nom'], 'republicoftogo.com');

      const msg = ChatMessage(
        id: 'msg_1',
        role: 'user',
        contenu: 'Bonjour',
        sources: [source],
      );

      final copied = msg.copyWith(contenu: 'Bonjour modifié');
      expect(copied.contenu, 'Bonjour modifié');
      expect(copied.sources.length, 1);
      expect(copied.toHistorique(), {'role': 'user', 'contenu': 'Bonjour modifié'});
    });
  });
}

class FakeSupabaseClient extends Fake implements SupabaseClient {}

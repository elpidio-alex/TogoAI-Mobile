/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Tests unitaires pour le dépôt de conversations (extraction de titre) et les modèles de données ChatMessage et ChatSource (sérialisation, copyWith).
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:togoai_mobile/features/conversations/data/conversations_repository.dart';

/// Point d'entrée de la suite de tests unitaires pour la logique métier du chat.
void main() {
  group('ConversationsRepository title extraction', () {
    /// Valide l'algorithme d'épuration et de troncature du titre généré depuis la première question.
    test('titreDepuisQuestion produces clean truncated titles', () {
      final repo = ConversationsRepository(FakeSupabaseClient());

      // Vérifie le nettoyage des caractères spéciaux et de la ponctuation
      expect(
        repo.titreDepuisQuestion('Quelle est la météo à Lomé aujourd\'hui ?'),
        'Quelle est la météo à Lomé aujourdhui',
      );

      // Vérifie la valeur de secours en cas de chaîne vide
      expect(
        repo.titreDepuisQuestion(''),
        'Nouvelle discussion',
      );
    });
  });

  group('ChatMessage & ChatSource models', () {
    /// Valide la transformation des sources documentaires et l'immuabilité du modèle de message.
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

      // Validation du pattern de copie immuable
      final copied = msg.copyWith(contenu: 'Bonjour modifié');
      expect(copied.contenu, 'Bonjour modifié');
      expect(copied.sources.length, 1);
      expect(copied.toHistorique(), {'role': 'user', 'contenu': 'Bonjour modifié'});
    });
  });
}

/// Doublure de test simulant le client Supabase pour isoler la logique métier sans appel réseau.
class FakeSupabaseClient extends Fake implements SupabaseClient {}

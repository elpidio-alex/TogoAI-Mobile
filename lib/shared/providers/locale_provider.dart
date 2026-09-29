/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Gestion de la locale (fr/en/ewe), persistance du choix de langue dans EasyLocalization et synchronisation avec la table users Supabase.
*/

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Liste des locales prises en charge par l'application.
///
/// Alignées sur les langues disponibles côté backend web :
/// - `fr` : Français (locale par défaut)
/// - `en` : Anglais
/// - `ewe` : Éwé (langue locale togolaise)
///
/// Ces locales correspondent aux fichiers JSON de traduction
/// situés dans `assets/translations/`.
const supportedLocales = [
  Locale('fr'),
  Locale('en'),
  Locale('ewe'),
];

/// Provider Riverpod stockant le code langue actif (ex. `'fr'`).
///
/// Utilisé comme source de vérité pour l'UI (sélection dans les
/// paramètres) et synchronisé avec EasyLocalization et Supabase
/// via [persistLocale].
final localeCodeProvider = StateProvider<String>((ref) => 'fr');

/// Persiste le choix de langue à trois niveaux : Riverpod, EasyLocalization et Supabase.
///
/// Cette fonction orchestre la synchronisation complète du changement de langue :
/// 1. Met à jour le [localeCodeProvider] pour réactivité immédiate dans l'UI.
/// 2. Appelle [context.setLocale] pour qu'EasyLocalization recharge les traductions.
/// 3. Si un utilisateur est authentifié, met à jour la colonne `language` de son
///    profil dans la table `users` Supabase pour persistance inter-sessions.
///
/// Le paramètre [code] doit correspondre à l'un des codes définis dans
/// [supportedLocales] (ex. `'fr'`, `'en'`, `'ewe'`).
Future<void> persistLocale(WidgetRef ref, BuildContext context, String code) async {
  // Étape 1 : mise à jour immédiate de l'état Riverpod
  ref.read(localeCodeProvider.notifier).state = code;

  // Étape 2 : synchronisation avec le moteur de localisation
  await context.setLocale(Locale(code));

  // Étape 3 : persistance distante si l'utilisateur est connecté
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    await Supabase.instance.client
        .from('users')
        .update({'language': code}).eq('id', user.id);
  }
}

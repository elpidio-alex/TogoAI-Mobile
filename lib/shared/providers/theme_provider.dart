/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Gestion du thème d'affichage (systeme/clair/sombre) avec persistance locale via SharedPreferences et synchronisation avec le profil Supabase.
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Énumération des modes de thème de l'application.
///
/// Les valeurs sont alignées sur la nomenclature du backend web
/// (systeme | clair | sombre) pour garantir la cohérence inter-plateformes
/// lors de la synchronisation du profil utilisateur.
enum AppThemeMode {
  systeme,
  clair,
  sombre;

  /// Retourne la représentation textuelle destinée à la persistance
  /// (SharedPreferences et colonne `theme` de la table `users` Supabase).
  String get dbValue => name;

  /// Désérialise une valeur stockée en base ou en préférences locales.
  ///
  /// Retourne [AppThemeMode.systeme] par défaut si la valeur est nulle
  /// ou ne correspond à aucune entrée connue, afin d'assurer un fallback
  /// sûr au premier lancement.
  static AppThemeMode fromDb(String? value) {
    return AppThemeMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppThemeMode.systeme,
    );
  }

  /// Convertit le mode applicatif vers le [ThemeMode] Flutter natif
  /// consommé par [MaterialApp.themeMode].
  ThemeMode get flutterMode => switch (this) {
        AppThemeMode.systeme => ThemeMode.system,
        AppThemeMode.clair => ThemeMode.light,
        AppThemeMode.sombre => ThemeMode.dark,
      };
}

/// Gestionnaire d'état du thème avec double persistance.
///
/// Charge la préférence de thème depuis [SharedPreferences] au démarrage
/// et la sauvegarde à chaque changement. Prend également en charge la
/// synchronisation unidirectionnelle depuis le profil Supabase (via
/// [syncFromProfile]) pour aligner le thème mobile sur le choix web.
class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  /// Initialise le notifier en lisant la valeur persistée.
  ///
  /// Si aucune valeur n'est trouvée sous [_key], le fallback
  /// [AppThemeMode.systeme] est utilisé.
  ThemeModeNotifier(this._prefs)
      : super(
          AppThemeMode.fromDb(_prefs.getString(_key)),
        );

  /// Clé de stockage SharedPreferences – préfixée `togoai-` pour
  /// éviter les collisions avec d'autres plugins.
  static const _key = 'togoai-theme';

  /// Instance SharedPreferences injectée via Riverpod.
  final SharedPreferences _prefs;

  /// Met à jour le thème actif et persiste le choix localement.
  ///
  /// L'écriture asynchrone dans SharedPreferences est fire-and-forget :
  /// l'état UI est mis à jour immédiatement pour garantir une
  /// réactivité instantanée.
  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    await _prefs.setString(_key, mode.dbValue);
  }

  /// Synchronise le thème depuis le profil Supabase distant.
  ///
  /// Appelée après le chargement du profil utilisateur pour aligner
  /// le thème mobile sur la préférence enregistrée côté serveur.
  /// Ignore silencieusement les valeurs nulles (profil incomplet).
  void syncFromProfile(String? theme) {
    if (theme == null) return;
    state = AppThemeMode.fromDb(theme);
  }
}

/// Fournisseur de l'instance [SharedPreferences].
///
/// Déclaré comme non-implémenté car il doit être surchargé (override)
/// dans [main()] avec l'instance réelle obtenue de manière asynchrone
/// avant le lancement de l'application. Ce pattern permet d'injecter
/// une dépendance asynchrone dans l'arbre Riverpod synchrone.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main()');
});

/// Provider Riverpod exposant le [ThemeModeNotifier] et l'état [AppThemeMode].
///
/// Dépend de [sharedPreferencesProvider] pour la persistance locale.
/// Les widgets consommateurs surveillent ce provider pour reconstruire
/// l'interface quand le thème change.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(sharedPreferencesProvider));
});

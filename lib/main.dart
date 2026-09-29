/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Point d'entrée principal de l'application TogoAI Mobile, initialisation des dépendances (EasyLocalization, SharedPreferences, Supabase) et configuration globale du widget racine avec MaterialApp.router.
*/

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/locale_provider.dart';
import 'shared/providers/theme_provider.dart';

/// Point d'entrée principal de l'application TogoAI Mobile.
///
/// Exécute la séquence d'amorçage asynchrone :
/// 1. Initialisation des bindings du moteur graphique Flutter (`WidgetsFlutterBinding`).
/// 2. Configuration du routage URL sans hash `#` pour le Web (`usePathUrlStrategy`).
/// 3. Initialisation du moteur de traduction internationalisation (`EasyLocalization`).
/// 4. Chargement persistant des préférences utilisateur via `SharedPreferences`.
/// 5. Connexion conditionnelle au client Supabase si les clés `--dart-define` sont fournies.
/// 6. Lancement du widget racine enveloppé dans `ProviderScope` (Riverpod) et `EasyLocalization`.
Future<void> main() async {
  // Garantit que le moteur Flutter est prêt avant d'effectuer des appels asynchrones natifs
  WidgetsFlutterBinding.ensureInitialized();

  // Élimine le dièse (#) dans les URLs de navigation sur le Web pour des URLs propres
  usePathUrlStrategy();

  // Charge les dictionnaires de localisation depuis assets/translations/
  await EasyLocalization.ensureInitialized();

  // Pré-chargement asynchrone des préférences partagées pour injection synchrone dans Riverpod
  final prefs = await SharedPreferences.getInstance();

  debugPrint('BACKEND_URL → ${AppConfig.resolvedBackendUrl}');

  // Initialisation sécurisée de Supabase avec dégradation gracieuse si non configuré
  if (!AppConfig.hasSupabase) {
    debugPrint(
      'SUPABASE_URL / SUPABASE_ANON_KEY manquants '
      '(--dart-define). Auth désactivée.',
    );
  } else {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  // Montage de l'arbre de widgets avec injection des dépendances Riverpod au sommet
  runApp(
    ProviderScope(
      overrides: [
        // Injecte l'instance SharedPreferences déjà résolue pour éviter tout FutureBuilder ultérieur
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: EasyLocalization(
        supportedLocales: supportedLocales,
        path: 'assets/translations',
        fallbackLocale: const Locale('fr'),
        startLocale: Locale(prefs.getString('locale') ?? 'fr'),
        child: const TogoAiApp(),
      ),
    ),
  );
}

/// Widget racine de l'application TogoAI Mobile.
///
/// Consomme les providers Riverpod globaux ([routerProvider] et [themeModeProvider])
/// pour configurer le `MaterialApp.router` avec réactivité dynamique au thème,
/// à la langue et aux routes de navigation.
class TogoAiApp extends ConsumerWidget {
  /// Crée une instance du widget racine [TogoAiApp].
  const TogoAiApp({super.key});

  /// Construit la structure globale `MaterialApp.router`.
  ///
  /// Écoute les changements de routeur et de thème, et applique les délégués
  /// de localisation avec gestion de secours (fallback) pour les langues locales (Éwé).
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'TogoAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode.flutterMode,
      routerConfig: router,
      localizationsDelegates: [
        // Délégués de secours pour éviter les plantages sur les langues non natives du SDK Flutter (ex: Éwé)
        const _FallbackMaterialLocalizationsDelegate(),
        const _FallbackCupertinoLocalizationsDelegate(),
        ...context.localizationDelegates,
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}

/// Délégué de localisation Material de secours.
///
/// Intercepte la résolution des composants Material pour les locales personnalisées
/// comme l'Éwé ('ee'/'ewe') non supportées d'origine par le SDK Flutter,
/// et bascule de manière transparente sur le français ('fr').
class _FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  /// Crée une instance constante du délégué de secours Material.
  const _FallbackMaterialLocalizationsDelegate();

  /// Indique que toutes les locales sont acceptées par ce délégué de secours.
  @override
  bool isSupported(Locale locale) => true;

  /// Charge les traductions Material pour la locale demandée ou bascule sur le français.
  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final target = GlobalMaterialLocalizations.delegate.isSupported(locale)
        ? locale
        : const Locale('fr');
    return GlobalMaterialLocalizations.delegate.load(target);
  }

  /// Indique si le délégué doit être rechargé lors d'un rebuild (aucun état dynamique interne).
  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) =>
      false;
}

/// Délégué de localisation Cupertino de secours.
///
/// Assure que les widgets de style iOS (dialogues, sélecteurs Cupertino)
/// disposent de traductions valides même lorsque la langue active n'est pas
/// fournie par le package standard `GlobalCupertinoLocalizations`.
class _FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  /// Crée une instance constante du délégué de secours Cupertino.
  const _FallbackCupertinoLocalizationsDelegate();

  /// Indique que toutes les locales sont acceptées par ce délégué de secours.
  @override
  bool isSupported(Locale locale) => true;

  /// Charge les traductions Cupertino pour la locale demandée ou bascule sur le français.
  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    final target = GlobalCupertinoLocalizations.delegate.isSupported(locale)
        ? locale
        : const Locale('fr');
    return GlobalCupertinoLocalizations.delegate.load(target);
  }

  /// Indique si le délégué doit être rechargé lors d'un rebuild.
  @override
  bool shouldReload(covariant LocalizationsDelegate<CupertinoLocalizations> old) =>
      false;
}

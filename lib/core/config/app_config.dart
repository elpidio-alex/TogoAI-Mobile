/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Définition des variables de configuration d'environnement (--dart-define), résolution des URL backend (FastAPI, loopback émulateur Android 10.0.2.2), clés Supabase et liens légaux.
*/

import 'package:flutter/foundation.dart';

/// Gestionnaire centralisé de la configuration d'exécution de l'application TogoAI.
///
/// Cette classe encapsule l'accès aux variables injectées à la compilation
/// via `--dart-define` (secrets, URLs de service, drapeaux fonctionnels)
/// et assure la résolution dynamique des URLs selon l'environnement (Web, émulateur Android, appareils réels).
class AppConfig {
  /// Constructeur privé pour empêcher l'instanciation de cette classe utilitaire statique.
  AppConfig._();

  /// URL de l'instance du projet Supabase.
  ///
  /// Peut être surchargée via `--dart-define=SUPABASE_URL=...`.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rmrskgankgezjttoiwud.supabase.co',
  );

  /// Clé publique anonyme (anon key) pour les requêtes client Supabase.
  ///
  /// Peut être surchargée via `--dart-define=SUPABASE_ANON_KEY=...`.
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJtcnNrZ2Fua2dlemp0dG9pd3VkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYzNTYwODEsImV4cCI6MjEwMTkzMjA4MX0.XglWmCrrM1FyHx9dXvUDBQ7gYMq7z2ROlgEFY7W055k',
  );

  /// URL de base brute du backend FastAPI pour les échanges de chat streaming (SSE).
  ///
  /// Valeur par défaut pointant sur le cluster de production Render (`https://togoai.onrender.com`).
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://togoai.onrender.com',
  );

  /// Résout l'URL backend opérationnelle selon la plateforme d'exécution.
  ///
  /// Sur l'émulateur officiel Android, `localhost` ou `127.0.0.1` fait référence
  /// à la machine virtuelle de l'émulateur elle-même. Cette méthode substitue
  /// automatiquement cette boucle locale par `10.0.2.2` afin d'accéder au serveur hôte du développeur.
  static String get resolvedBackendUrl {
    var url = backendUrl;
    // Détection de l'émulateur Android ciblant une adresse de boucle locale
    final useEmulatorLoopback = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        (url.contains('://localhost') || url.contains('://127.0.0.1'));
    if (useEmulatorLoopback) {
      url = url
          .replaceFirst('://localhost', '://10.0.2.2')
          .replaceFirst('://127.0.0.1', '://10.0.2.2');
    }
    return url;
  }

  /// Clé d'API interne facultative pour sécuriser les appels au backend en environnement restreint.
  ///
  /// Attention : ne doit pas être embarquée en production sur les stores publics.
  static const internalApiKey = String.fromEnvironment(
    'INTERNAL_API_KEY',
    defaultValue: '',
  );

  /// Drapeau déterminant si le jeton JWT Supabase doit être transmis en entête d'autorisation (`Authorization: Bearer <token>`).
  ///
  /// Désactivé par défaut si le backend FastAPI gère le passthrough anonyme.
  static const sendJwtToBackend = bool.fromEnvironment(
    'SEND_JWT_TO_BACKEND',
    defaultValue: false,
  );

  /// URL de redirection OAuth par défaut pour les applications mobiles natives (deep link).
  static const oauthRedirectUrl = String.fromEnvironment(
    'OAUTH_REDIRECT_URL',
    defaultValue: 'io.togoai.app://login-callback/',
  );

  /// Résout dynamiquement l'URL de redirection OAuth en fonction du runtime.
  ///
  /// - En mode Web : extrait l'origine active du navigateur (`window.location.origin`)
  ///   pour cibler la route `/auth/callback`.
  /// - En mode Mobile natif : retourne le schéma deep link custom ([oauthRedirectUrl]).
  static String get resolvedOauthRedirectUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      final normalized = origin.replaceFirst('://127.0.0.1', '://localhost');
      return '$normalized/auth/callback';
    }
    return oauthRedirectUrl;
  }

  /// Lien externe vers la page de présentation "À propos" de la plateforme TogoAI.
  static const aboutUrl = 'https://togoai.site/a-propos';

  /// Lien externe vers les conditions générales d'utilisation du service.
  static const termsUrl = 'https://togoai.site/conditions-utilisation';

  /// Lien externe vers la politique de confidentialité des données personnelles.
  static const privacyUrl = 'https://togoai.site/politique-confidentialite';

  /// Alias désignant le document juridique principal (conditions d'utilisation).
  static const legalUrl = termsUrl;

  /// Vérifie si les identifiants Supabase sont configurés et non vides.
  ///
  /// Permet d'activer conditionnellement l'authentification et la persistance des discussions.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

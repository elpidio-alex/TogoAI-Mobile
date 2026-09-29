import 'package:flutter/foundation.dart';

/// Configuration runtime (via --dart-define, jamais de secrets en dur).
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rmrskgankgezjttoiwud.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJtcnNrZ2Fua2dlemp0dG9pd3VkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYzNTYwODEsImV4cCI6MjEwMTkzMjA4MX0.XglWmCrrM1FyHx9dXvUDBQ7gYMq7z2ROlgEFY7W055k',
  );

  /// Base FastAPI. Prod web référence : https://togoai.onrender.com
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://togoai.onrender.com',
  );

  /// Sur l'émulateur Android, `localhost` est l'émulateur lui-même.
  /// `10.0.2.2` redirige vers le PC hôte (backend :8000).
  static String get resolvedBackendUrl {
    var url = backendUrl;
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

  /// Uniquement pour debug local si INTERNAL_API_KEY est actif côté backend.
  /// Ne jamais shipper en store.
  static const internalApiKey = String.fromEnvironment(
    'INTERNAL_API_KEY',
    defaultValue: '',
  );

  /// Indique si l'app mobile doit envoyer le header `Authorization: Bearer <JWT>`
  /// au backend FastAPI. Désactivé par défaut car le backend Render utilise
  /// le passthrough sans clé.
  static const sendJwtToBackend = bool.fromEnvironment(
    'SEND_JWT_TO_BACKEND',
    defaultValue: false,
  );


  static const oauthRedirectUrl = String.fromEnvironment(
    'OAUTH_REDIRECT_URL',
    defaultValue: 'io.togoai.app://login-callback/',
  );

  /// Chrome : origine de l'app Flutter (pas le Next.js :3000).
  /// Mobile : deep link.
  static String get resolvedOauthRedirectUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      final normalized = origin.replaceFirst('://127.0.0.1', '://localhost');
      return '$normalized/auth/callback';
    }
    return oauthRedirectUrl;
  }

  static const aboutUrl = 'https://togoai.site/a-propos';
  static const termsUrl = 'https://togoai.site/conditions-utilisation';
  static const privacyUrl = 'https://togoai.site/politique-confidentialite';
  static const legalUrl = termsUrl;

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

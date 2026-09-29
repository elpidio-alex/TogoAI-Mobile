/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Configuration du routage avec GoRouter, gestion des redirections d'authentification en temps réel et déclaration des routes de l'application.
*/

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/auth_screens.dart';
import '../../features/auth/presentation/screens/onboarding_screens.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../core/config/app_config.dart';

/// Clé de navigation racine globale utilisée par GoRouter.
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Adaptateur permettant de convertir un [Stream] asynchrone en [Listenable] pour GoRouter.
///
/// Utilisé pour écouter le flux des événements d'authentification Supabase ([onAuthStateChange])
/// et notifier GoRouter afin de recalculer automatiquement les gardes de redirection (`redirect`).
class GoRouterRefreshStream extends ChangeNotifier {
  /// Crée un adaptateur et souscrit au flux spécifié.
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  /// Abonnement interne au flux.
  late final StreamSubscription<dynamic> _sub;

  /// Libère l'abonnement lors de la destruction du routeur pour éviter les fuites mémoire.
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Détermine si l'emplacement ciblé correspond à l'écran de connexion ou d'inscription.
bool _isLoginSignup(String loc) => loc == '/login' || loc == '/signup';

/// Vérifie si l'URL courante correspond à un retour de callback OAuth (Web ou deep link mobile).
bool _isOAuthCallback(String loc) =>
    loc == '/auth/callback' ||
    loc == '/login-callback' ||
    loc.startsWith('/login-callback');

/// Provider Riverpod fournissant l'instance singleton de configuration [GoRouter].
///
/// Met en place :
/// - La souscription temps réel aux changements de session Supabase.
/// - La garde d'accès (redirection vers `/login` pour les routes privées non authentifiées).
/// - La redirection automatique d'un utilisateur connecté vers `/chat/nouvelle` lorsqu'il visite `/login` ou `/signup`.
/// - La déclaration arborescente de toutes les routes de l'application.
final routerProvider = Provider<GoRouter>((ref) {
  Listenable? refresh;
  // Si Supabase est initialisé, on connecte le flux de session au rafraîchissement du routeur
  if (AppConfig.hasSupabase && Supabase.instance.isInitialized) {
    final r = GoRouterRefreshStream(
      Supabase.instance.client.auth.onAuthStateChange,
    );
    ref.onDispose(r.dispose);
    refresh = r;
  }

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Mode dégradé sans Supabase : maintien sur les écrans d'authentification ou accès restreint
      if (!AppConfig.hasSupabase || !Supabase.instance.isInitialized) {
        return _isLoginSignup(loc) ? null : '/login';
      }

      final session = Supabase.instance.client.auth.currentSession;
      // Utilisateur non connecté : autorise uniquement la connexion/inscription et les retours OAuth
      if (session == null) {
        return (_isLoginSignup(loc) || _isOAuthCallback(loc)) ? null : '/login';
      }

      // Utilisateur déjà authentifié tentant d'accéder aux pages de login/signup
      if (_isLoginSignup(loc)) {
        return '/chat/nouvelle';
      }

      // Accès autorisé sans redirection
      return null;
    },
    routes: [
      // Écran de connexion (Email + Mot de passe + OAuth Google)
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      // Écran de création de compte
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      // Callback d'authentification OAuth pour la plateforme Web
      GoRoute(
        path: '/auth/callback',
        builder: (_, state) => AuthCallbackScreen(uri: state.uri),
      ),
      // Callback d'authentification OAuth pour les deep links mobiles
      GoRoute(
        path: '/login-callback',
        builder: (_, state) => AuthCallbackScreen(uri: state.uri),
      ),
      // Étape 1 d'onboarding : saisie des nom et prénom
      GoRoute(
        path: '/onboarding/nom-prenom',
        builder: (_, __) => const OnboardingNomPrenomScreen(),
      ),
      // Étape 2 d'onboarding : nom d'usage / pseudonyme
      GoRoute(
        path: '/onboarding/nom-appel',
        builder: (_, __) => const OnboardingNomAppelScreen(),
      ),
      // Étape 3 d'onboarding : date de naissance
      GoRoute(
        path: '/onboarding/date-naissance',
        builder: (_, __) => const OnboardingDateNaissanceScreen(),
      ),
      // Interface principale de chat (discussion active ou nouvelle discussion avec ':id')
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => ChatScreen(
          conversationId: state.pathParameters['id'],
        ),
      ),
    ],
  );
});

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/auth_screens.dart';
import '../../features/auth/presentation/screens/onboarding_screens.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../core/config/app_config.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

bool _isLoginSignup(String loc) => loc == '/login' || loc == '/signup';

bool _isOAuthCallback(String loc) =>
    loc == '/auth/callback' ||
    loc == '/login-callback' ||
    loc.startsWith('/login-callback');

final routerProvider = Provider<GoRouter>((ref) {
  Listenable? refresh;
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

      if (!AppConfig.hasSupabase || !Supabase.instance.isInitialized) {
        return _isLoginSignup(loc) ? null : '/login';
      }

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        return (_isLoginSignup(loc) || _isOAuthCallback(loc)) ? null : '/login';
      }

      if (_isLoginSignup(loc)) {
        return '/chat/nouvelle';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: '/auth/callback',
        builder: (_, state) => AuthCallbackScreen(uri: state.uri),
      ),
      GoRoute(
        path: '/login-callback',
        builder: (_, state) => AuthCallbackScreen(uri: state.uri),
      ),
      GoRoute(
        path: '/onboarding/nom-prenom',
        builder: (_, __) => const OnboardingNomPrenomScreen(),
      ),
      GoRoute(
        path: '/onboarding/nom-appel',
        builder: (_, __) => const OnboardingNomAppelScreen(),
      ),
      GoRoute(
        path: '/onboarding/date-naissance',
        builder: (_, __) => const OnboardingDateNaissanceScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => ChatScreen(
          conversationId: state.pathParameters['id'],
        ),
      ),
    ],
  );
});

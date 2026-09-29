import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/auth_provider.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseProvider));
});

/// Après login / OAuth : upsert profil puis route vers onboarding ou chat.
Future<void> navigateAfterAuth(WidgetRef ref, BuildContext context) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    if (context.mounted) context.go('/login');
    return;
  }

  try {
    await ref.read(authRepositoryProvider).upsertProfileFromMetadata(user);
  } catch (e) {
    debugPrint('Erreur upsertProfileFromMetadata: $e');
  }
  ref.invalidate(userProfileProvider);

  UserProfile? profile;
  try {
    profile = await ref
        .read(userProfileProvider.future)
        .timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('Erreur récupération userProfile: $e');
  }

  if (!context.mounted) return;

  if (profile == null || !profile.hasRequiredName) {
    context.go('/onboarding/nom-prenom');
  } else {
    context.go('/chat/nouvelle');
  }
}

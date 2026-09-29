/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Logique de redirection post-authentification, synchronisation du profil utilisateur Supabase et orientation vers le tunnel d'onboarding ou le chat.
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/providers/auth_provider.dart';
import '../data/auth_repository.dart';

/// Provider exposant le repository d'authentification.
///
/// Injecte automatiquement le client Supabase via [supabaseProvider]
/// pour que le repository puisse effectuer les opérations de profil
/// (upsert, soft-delete, etc.).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseProvider));
});

/// Orchestre la navigation post-authentification (login email ou OAuth).
///
/// Cette fonction gère le flux critique après une connexion réussie :
///
/// 1. **Vérification de session** : Contrôle qu'un utilisateur est bien
///    authentifié. Redirige vers `/login` si la session est invalide.
///
/// 2. **Upsert du profil** : Appelle [AuthRepository.upsertProfileFromMetadata]
///    pour créer ou mettre à jour le profil dans la table `users` à partir
///    des métadonnées Supabase Auth (nom, email, avatar). Cette étape est
///    encapsulée dans un try-catch car un échec réseau ne doit pas bloquer
///    la navigation.
///
/// 3. **Décision de routage** :
///    - Si le profil est absent ou incomplet (nom/prénom manquants),
///      redirige vers le tunnel d'onboarding (`/onboarding/nom-prenom`).
///    - Sinon, redirige vers l'écran de chat (`/chat/nouvelle`).
///
/// Le timeout de 4 secondes sur la récupération du profil protège contre
/// les latences réseau excessives – en cas de timeout, l'utilisateur est
/// orienté vers l'onboarding par sécurité.
Future<void> navigateAfterAuth(WidgetRef ref, BuildContext context) async {
  // Étape 1 : Vérification de la session active
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    if (context.mounted) context.go('/login');
    return;
  }

  // Étape 2 : Upsert du profil – fire-and-forget en cas d'échec
  try {
    await ref.read(authRepositoryProvider).upsertProfileFromMetadata(user);
  } catch (e) {
    debugPrint('Erreur upsertProfileFromMetadata: $e');
  }

  // Invalide le cache du profil pour forcer un rechargement frais
  ref.invalidate(userProfileProvider);

  // Étape 3 : Récupération du profil avec timeout de protection
  UserProfile? profile;
  try {
    profile = await ref
        .read(userProfileProvider.future)
        .timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('Erreur récupération userProfile: $e');
  }

  // Garde de sécurité : le widget peut avoir été démonté pendant l'attente
  if (!context.mounted) return;

  // Routage conditionnel basé sur la complétude du profil
  if (profile == null || !profile.hasRequiredName) {
    context.go('/onboarding/nom-prenom');
  } else {
    context.go('/chat/nouvelle');
  }
}

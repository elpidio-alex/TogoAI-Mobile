/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Dépôt gérant les opérations d'authentification Supabase (email/mot de passe, Google OAuth, déconnexion), gestion du profil utilisateur et logique de suppression de compte (soft-delete).
*/

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

/// Exception métier levée lors d'anomalies de validation ou de flux d'authentification.
class AuthException implements Exception {
  /// Crée une exception avec un code d'erreur ou message explicatif.
  AuthException(this.message);

  /// Code textuel de l'erreur (ex: `'compte_supprime'`, `'mot_de_passe_incorrect'`).
  final String message;

  @override
  String toString() => message;
}

/// Dépôt de données et contrôleur métier pour toutes les opérations d'authentification Supabase.
///
/// Prend en charge :
/// - La connexion email/mot de passe avec contrôle de désactivation (soft-delete).
/// - L'inscription avec consentement aux politiques de confidentialité.
/// - L'authentification fédérée via Google OAuth.
/// - La synchronisation des profils dans la table publique `users`.
/// - La suppression sécurisée de compte avec ré-authentification obligatoire.
class AuthRepository {
  /// Initialise le dépôt avec le client Supabase actif.
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Authentifie un utilisateur par son adresse email et mot de passe.
  ///
  /// Effectue une vérification post-connexion sur la table `users` : si le compte
  /// fait l'objet d'une suppression logique (`deleted_at != null`), la session est
  /// immédiatement révoquée et une [AuthException] avec le code `'compte_supprime'` est levée.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = res.user;
    if (user != null) {
      // Contrôle de sécurité : vérification si le compte a été supprimé (soft-delete)
      final row = await _client
          .from('users')
          .select('deleted_at')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null && row['deleted_at'] != null) {
        await _client.auth.signOut();
        throw AuthException('compte_supprime');
      }
    }
    return res;
  }

  /// Crée un nouveau compte utilisateur avec email, mot de passe et métadonnées d'identité.
  ///
  /// Enregistre automatiquement l'horodatage d'acceptation des conditions d'utilisation (`policy_version`).
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String nom,
    required String prenom,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'nom': nom.trim(),
        'prenom': prenom.trim(),
        'policy_version': 'v1',
        'policy_accepted_at': DateTime.now().toUtc().toIso8601String(),
      },
      emailRedirectTo: AppConfig.resolvedOauthRedirectUrl,
    );
  }

  /// Déclenche le flux d'authentification externe Google OAuth.
  ///
  /// Redirige vers le navigateur ou custom tab avec l'URL de retour [AppConfig.resolvedOauthRedirectUrl].
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.resolvedOauthRedirectUrl,
    );
  }

  /// Déconnecte l'utilisateur et détruit la session active localement et sur le serveur.
  Future<void> signOut() => _client.auth.signOut();

  /// Synchronise les métadonnées de l'utilisateur (fournies par Google OAuth) dans la table publique `users`.
  ///
  /// Extrait intelligemment le prénom et le nom de famille à partir de `family_name`, `given_name`
  /// ou par découpage de `full_name`.
  Future<void> upsertProfileFromMetadata(User user) async {
    final meta = user.userMetadata ?? {};
    String? nom = meta['nom'] as String?;
    String? prenom = meta['prenom'] as String?;

    // Extraction des attributs standards renvoyés par les fournisseurs OAuth
    if ((nom == null || nom.isEmpty) && meta['family_name'] != null) {
      nom = meta['family_name'] as String?;
    }
    if ((prenom == null || prenom.isEmpty) && meta['given_name'] != null) {
      prenom = meta['given_name'] as String?;
    }
    // Découpage heuristique en cas de chaîne unique "full_name"
    if ((nom == null || nom.isEmpty) &&
        (prenom == null || prenom.isEmpty) &&
        meta['full_name'] != null) {
      final parts = (meta['full_name'] as String).split(' ');
      prenom = parts.isNotEmpty ? parts.first : null;
      nom = parts.length > 1 ? parts.sublist(1).join(' ') : null;
    }

    final data = <String, dynamic>{
      'id': user.id,
      if (user.email != null) 'email': user.email,
      if (nom != null && nom.isNotEmpty) 'nom': nom,
      if (prenom != null && prenom.isNotEmpty) 'prenom': prenom,
    };

    try {
      await _client.from('users').upsert(data);
    } catch (_) {
      try {
        // Fallback update en cas de politique RLS interdisant l'insertion directe si la ligne existe
        await _client.from('users').update({
          if (nom != null && nom.isNotEmpty) 'nom': nom,
          if (prenom != null && prenom.isNotEmpty) 'prenom': prenom,
        }).eq('id', user.id);
      } catch (_) {
        // Ignorer si la ligne est déjà gérée par un trigger Supabase SQL
      }
    }
  }

  /// Met à jour les informations du profil utilisateur dans la base de données.
  Future<void> updateProfile({
    required String userId,
    String? nom,
    String? prenom,
    String? nomAppel,
    String? theme,
    String? language,
  }) {
    return _client.from('users').update({
      if (nom != null) 'nom': nom,
      if (prenom != null) 'prenom': prenom,
      if (nomAppel != null) 'nom_appel': nomAppel.isEmpty ? null : nomAppel,
      if (theme != null) 'theme': theme,
      if (language != null) 'language': language,
    }).eq('id', userId);
  }

  /// Enregistre la date de naissance de l'utilisateur au format standard ISO `YYYY-MM-DD`.
  Future<void> updateDateNaissance({
    required String userId,
    DateTime? dateNaissance,
  }) {
    return _client.from('users').update({
      'date_naissance': dateNaissance == null
          ? null
          : '${dateNaissance.year.toString().padLeft(4, '0')}-'
              '${dateNaissance.month.toString().padLeft(2, '0')}-'
              '${dateNaissance.day.toString().padLeft(2, '0')}',
    }).eq('id', userId);
  }

  /// Procède à la suppression logique (soft-delete) du compte utilisateur.
  ///
  /// Exige une confirmation explicite textuelle (`confirmation == 'SUPPRIMER'`)
  /// ainsi qu'une ré-authentification obligatoire pour prévenir toute suppression frauduleuse :
  /// - Pour les comptes Google : vérifie que la dernière connexion date de moins de 5 minutes.
  /// - Pour les comptes Email : re-vérifie le mot de passe actuel.
  /// Marque ensuite la colonne `deleted_at` et déconnecte l'utilisateur.
  Future<void> softDeleteAccount({
    required String password,
    required String confirmation,
  }) async {
    if (confirmation != 'SUPPRIMER') {
      throw AuthException('confirmation_invalide');
    }

    final user = _client.auth.currentUser;
    if (user == null || user.email == null) {
      throw AuthException('non_authentifie');
    }

    final isGoogle = user.appMetadata['provider'] == 'google' ||
        (user.identities?.any((i) => i.provider == 'google') ?? false);

    if (isGoogle) {
      // Exige une session Google récente (< 5 min)
      final last = user.lastSignInAt != null
          ? DateTime.tryParse(user.lastSignInAt!)
          : null;
      if (last == null ||
          DateTime.now().toUtc().difference(last.toUtc()) >
              const Duration(minutes: 5)) {
        throw AuthException('reauth_google_requise');
      }
    } else {
      // Re-vérification du mot de passe pour les comptes traditionnels
      try {
        await _client.auth.signInWithPassword(
          email: user.email!,
          password: password,
        );
      } catch (_) {
        throw AuthException('mot_de_passe_incorrect');
      }
    }

    // Horodatage de suppression douce (soft-delete)
    await _client.from('users').update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', user.id);

    await _client.auth.signOut();
  }
}

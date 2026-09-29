import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

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

  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.resolvedOauthRedirectUrl,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> upsertProfileFromMetadata(User user) async {
    final meta = user.userMetadata ?? {};
    String? nom = meta['nom'] as String?;
    String? prenom = meta['prenom'] as String?;

    if ((nom == null || nom.isEmpty) && meta['family_name'] != null) {
      nom = meta['family_name'] as String?;
    }
    if ((prenom == null || prenom.isEmpty) && meta['given_name'] != null) {
      prenom = meta['given_name'] as String?;
    }
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
        await _client.from('users').update({
          if (nom != null && nom.isNotEmpty) 'nom': nom,
          if (prenom != null && prenom.isNotEmpty) 'prenom': prenom,
        }).eq('id', user.id);
      } catch (_) {
        // Ignorer si la ligne est déjà gérée par un trigger Supabase
      }
    }
  }

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

  /// Soft-delete : `deleted_at` + signOut.
  /// Le ban admin (service role) n'est pas faisable côté client ;
  /// le login refuse déjà les comptes avec `deleted_at`.
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
      final last = user.lastSignInAt != null
          ? DateTime.tryParse(user.lastSignInAt!)
          : null;
      if (last == null ||
          DateTime.now().toUtc().difference(last.toUtc()) >
              const Duration(minutes: 5)) {
        throw AuthException('reauth_google_requise');
      }
    } else {
      try {
        await _client.auth.signInWithPassword(
          email: user.email!,
          password: password,
        );
      } catch (_) {
        throw AuthException('mot_de_passe_incorrect');
      }
    }

    await _client.from('users').update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', user.id);

    await _client.auth.signOut();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  if (!Supabase.instance.isInitialized) {
    throw StateError(
      'Supabase non initialisé. Passez SUPABASE_URL et SUPABASE_ANON_KEY '
      'via --dart-define.',
    );
  }
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

final currentSessionProvider = Provider<Session?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.session ??
      ref.watch(supabaseProvider).auth.currentSession;
});

/// Profil `public.users` aligné sur le schéma web.
class UserProfile {
  const UserProfile({
    required this.id,
    this.email,
    this.nom,
    this.prenom,
    this.nomAppel,
    this.theme,
    this.language,
    this.deletedAt,
  });

  final String id;
  final String? email;
  final String? nom;
  final String? prenom;
  final String? nomAppel;
  final String? theme;
  final String? language;
  final DateTime? deletedAt;

  String get displayName {
    final appel = nomAppel?.trim();
    if (appel != null && appel.isNotEmpty) return appel;
    final p = prenom?.trim();
    if (p != null && p.isNotEmpty) return p;
    return email?.split('@').first ?? 'Utilisateur';
  }

  String get initial {
    final n = displayName;
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  bool get hasRequiredName =>
      (nom?.trim().isNotEmpty ?? false) && (prenom?.trim().isNotEmpty ?? false);

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String?,
      nom: map['nom'] as String?,
      prenom: map['prenom'] as String?,
      nomAppel: map['nom_appel'] as String?,
      theme: map['theme'] as String?,
      language: map['language'] as String?,
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'] as String)
          : null,
    );
  }

  UserProfile copyWith({
    String? nom,
    String? prenom,
    String? nomAppel,
    String? theme,
    String? language,
  }) {
    return UserProfile(
      id: id,
      email: email,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      nomAppel: nomAppel ?? this.nomAppel,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      deletedAt: deletedAt,
    );
  }
}

final userProfileProvider = FutureProvider.autoDispose<UserProfile?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  final client = ref.watch(supabaseProvider);
  final row = await client
      .from('users')
      .select()
      .eq('id', session.user.id)
      .maybeSingle();
  if (row == null) return null;
  return UserProfile.fromMap(Map<String, dynamic>.from(row));
});

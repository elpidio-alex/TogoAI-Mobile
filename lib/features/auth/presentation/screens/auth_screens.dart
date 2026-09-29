/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Écrans d'authentification de l'application : connexion (LoginScreen), inscription (SignupScreen) et gestion du retour OAuth (AuthCallbackScreen).
*/

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/togo_colors.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../../shared/widgets/branding.dart';
import '../../../../shared/widgets/togo_widgets.dart';
import '../../data/auth_repository.dart';
import '../auth_flow.dart';

/// Écran de connexion de l'utilisateur par adresse e-mail ou via Google OAuth.
///
/// Intègre la validation des identifiants, la détection des comptes marqués comme
/// supprimés (soft-delete), et la bascule de thème clair/sombre dans l'en-tête.
class LoginScreen extends ConsumerStatefulWidget {
  /// Initialise l'écran de connexion.
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Valide et soumet les identifiants de connexion au service d'authentification Supabase.
  ///
  /// Intercepte spécifiquement les exceptions de soft-delete (`compte_supprime`),
  /// d'identifiants erronés ou d'adresse email non confirmée pour afficher un retour adapté.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(authRepositoryProvider).signInWithEmail(
            email: _email.text,
            password: _password.text,
          );
      if (res.user != null && mounted) {
        // Redirection conditionnelle selon l'état de complétion du profil
        await navigateAfterAuth(ref, context);
      }
    } on AuthException catch (e) {
      setState(() {
        _error = e.message == 'compte_supprime'
            ? 'auth.erreurCompteSupprime'.tr()
            : e.message;
      });
    } catch (e) {
      // Diagnostic des erreurs standard renvoyées par Supabase GoTrue
      final msg = e.toString().toLowerCase();
      setState(() {
        if (msg.contains('invalid') || msg.contains('credentials')) {
          _error = 'auth.erreurIdentifiants'.tr();
        } else if (msg.contains('email not confirmed') ||
            msg.contains('not confirmed')) {
          _error = 'auth.erreurEmailNonConfirme'.tr();
        } else {
          _error = 'auth.erreurIdentifiants'.tr();
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Déclenche le flux d'authentification fédérée Google OAuth.
  Future<void> _google() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (e) {
      debugPrint('Erreur Google sign-in: $e');
      if (mounted) {
        setState(() => _error = 'auth.erreurCallback'.tr());
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == AppThemeMode.sombre ||
        (themeMode == AppThemeMode.systeme &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    AuthHeader(
                      tagline: 'auth.accrochePanneau'.tr(),
                      isDark: isDark,
                      onToggleTheme: () {
                        ref.read(themeModeProvider.notifier).setMode(
                              isDark ? AppThemeMode.clair : AppThemeMode.sombre,
                            );
                      },
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                          child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'auth.login'.tr(),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0C3C24),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'auth.sousTitreLogin'.tr(),
                        style: TextStyle(color: context.togo.textSecondary),
                      ),
                      const SizedBox(height: 28),
                      TogoTextField(
                        label: 'auth.email'.tr(),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'auth.erreurEmailRequis'.tr()
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TogoTextField(
                        label: 'auth.password'.tr(),
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onToggleObscure: () =>
                            setState(() => _obscure = !_obscure),
                        validator: (v) =>
                            (v == null || v.isEmpty)
                                ? 'auth.erreurMotDePasseRequis'.tr()
                                : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: TextStyle(color: context.togo.danger),
                        ),
                      ],
                      const SizedBox(height: 24),
                      TogoPrimaryButton(
                        label: 'auth.seConnecter'.tr(),
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 20),
                      OrDivider(label: 'auth.ou'.tr()),
                      const SizedBox(height: 20),
                      TogoSecondaryButton(
                        label: 'auth.continuerAvecGoogle'.tr(),
                        loading: _googleLoading,
                        onPressed: _google,
                        leading: const _GoogleG(),
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'auth.pasDeCompte'.tr(),
                              style: TextStyle(color: context.togo.textSecondary),
                            ),
                            TextButton(
                              onPressed: () => context.go('/signup'),
                              child: Text(
                                'auth.creerUnCompte'.tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: context.togo.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
        },
      ),
    );
  }
}

/// Écran d'inscription d'un nouvel utilisateur (nom, prénom, e-mail, mot de passe fort).
///
/// Soumet les données de création de compte à Supabase et présente
/// un écran de confirmation par e-mail en cas de succès.
class SignupScreen extends ConsumerStatefulWidget {
  /// Initialise l'écran d'inscription.
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _accepted = false;
  bool _loading = false;
  bool _googleLoading = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Valide la robustesse cryptographique du mot de passe saisi.
  ///
  /// Exige une longueur minimale de 8 caractères, au moins une majuscule,
  /// une minuscule, un chiffre et un caractère spécial.
  String? _validatePassword(String? v) {
    if (v == null || v.length < 8) return 'auth.erreurMdpLongueur'.tr();
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'auth.erreurMdpMajuscule'.tr();
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'auth.erreurMdpMinuscule'.tr();
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'auth.erreurMdpChiffre'.tr();
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
      return 'auth.erreurMdpSpecial'.tr();
    }
    return null;
  }

  /// Valide l'ensemble des contraintes du formulaire et transmet la requête de création de compte.
  ///
  /// Vérifie l'acceptation explicite des CGU/politique et la correspondance des deux mots de passe.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = 'auth.erreurPolitiqueNonAcceptee'.tr());
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'auth.erreurMdpNeCorrespondentPas'.tr());
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
            nom: _nom.text,
            prenom: _prenom.text,
          );
      // Bascule vers l'état d'information sur la confirmation par courriel
      if (mounted) setState(() => _success = true);
    } catch (_) {
      setState(() => _error = 'auth.erreurCallback'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Déclenche l'inscription accélérée via l'identité Google OAuth.
  Future<void> _google() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (e) {
      debugPrint('Erreur Google sign-in: $e');
      if (mounted) setState(() => _error = 'auth.erreurCallback'.tr());
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  /// Lance le navigateur externe pour consulter les conditions générales d'utilisation.
  Future<void> _openLegal() async {
    final uri = Uri.parse(AppConfig.termsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == AppThemeMode.sombre ||
        (themeMode == AppThemeMode.systeme &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    if (_success) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_email_read_outlined,
                    size: 64, color: context.togo.accent),
                const SizedBox(height: 20),
                Text(
                  'auth.verifierEmail'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'auth.messageConfirmationEmail'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.togo.textSecondary),
                ),
                const SizedBox(height: 28),
                TogoPrimaryButton(
                  label: 'auth.seConnecter'.tr(),
                  onPressed: () => context.go('/login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    AuthHeader(
                      tagline: 'auth.accrochePanneau'.tr(),
                      isDark: isDark,
                      onToggleTheme: () {
                        ref.read(themeModeProvider.notifier).setMode(
                              isDark ? AppThemeMode.clair : AppThemeMode.sombre,
                            );
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'auth.creerUnCompte'.tr(),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0C3C24),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'auth.sousTitreSignup'.tr(),
                      style: TextStyle(color: context.togo.textSecondary),
                    ),
                    const SizedBox(height: 22),
                    TogoTextField(
                      label: 'auth.nom'.tr(),
                      controller: _nom,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'auth.erreurNomPrenomRequis'.tr()
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TogoTextField(
                      label: 'auth.prenom'.tr(),
                      controller: _prenom,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'auth.erreurNomPrenomRequis'.tr()
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TogoTextField(
                      label: 'auth.email'.tr(),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'auth.erreurEmailRequis'.tr()
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TogoTextField(
                      label: 'auth.password'.tr(),
                      controller: _password,
                      obscureText: _obscure,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 14),
                    TogoTextField(
                      label: 'auth.confirmerMotDePasse'.tr(),
                      controller: _confirm,
                      obscureText: _obscureConfirm,
                      onToggleObscure: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (v) => v != _password.text
                          ? 'auth.erreurMdpNeCorrespondentPas'.tr()
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _accepted,
                          onChanged: (v) =>
                              setState(() => _accepted = v ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              children: [
                                Text('${'auth.jAcceptePrefix'.tr()} '),
                                GestureDetector(
                                  onTap: _openLegal,
                                  child: Text(
                                    'auth.conditionsUtilisation'.tr(),
                                    style: TextStyle(
                                      color: context.togo.accent,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                Text(' ${'auth.et'.tr()} '),
                                GestureDetector(
                                  onTap: _openLegal,
                                  child: Text(
                                    'auth.politiqueConfidentialite'.tr(),
                                    style: TextStyle(
                                      color: context.togo.accent,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: TextStyle(color: context.togo.danger)),
                    ],
                    const SizedBox(height: 20),
                    TogoPrimaryButton(
                      label: 'auth.creerMonCompte'.tr(),
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 18),
                    OrDivider(label: 'auth.ou'.tr()),
                    const SizedBox(height: 18),
                    TogoSecondaryButton(
                      label: 'auth.continuerAvecGoogle'.tr(),
                      loading: _googleLoading,
                      onPressed: _google,
                      leading: const _GoogleG(),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'auth.dejaUnCompte'.tr(),
                            style:
                                TextStyle(color: context.togo.textSecondary),
                          ),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: Text(
                              'auth.login'.tr(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.togo.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
        },
      ),
    );
  }
}

/// Icône vectorielle SVG officielle du logo Google « G » aux quatre couleurs.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  static const _svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.79l7.97-6.2z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
<path fill="none" d="M0 0h48v48H0z"/>
</svg>''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg,
      width: 20,
      height: 20,
    );
  }
}

/// Écran intermédiaire de capture et d'échange du jeton de retour OAuth (Deep Link).
///
/// Réceptionne les paramètres d'URL (ou fragments de hachage) issus de la redirection
/// du fournisseur d'identité, finalise la session via Supabase PKCE et achemine
/// l'utilisateur vers son parcours post-authentification.
class AuthCallbackScreen extends ConsumerStatefulWidget {
  /// Initialise la capture avec l'URI de redirection [uri].
  const AuthCallbackScreen({super.key, required this.uri});

  final Uri uri;

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Exécution différée après le premier frame pour garantir un contexte monté
    WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
  }

  /// Analyse les fragments d'URL, extrait les jetons OAuth et synchronise la session client.
  Future<void> _complete() async {
    if (!AppConfig.hasSupabase) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      // Normalisation de l'URI (prise en compte des fragments #access_token)
      final uri = (widget.uri.queryParameters.isNotEmpty ||
              widget.uri.fragment.isNotEmpty)
          ? widget.uri
          : Uri.base;
      final fragmentParams = Uri.splitQueryString(uri.fragment);

      // Détection des erreurs signalées par le fournisseur OAuth
      final errorDesc = uri.queryParameters['error_description'] ??
          fragmentParams['error_description'] ??
          uri.queryParameters['error'] ??
          fragmentParams['error'];

      if (errorDesc != null && errorDesc.isNotEmpty) {
        debugPrint('OAuth error received: $errorDesc');
        if (mounted) {
          setState(() => _errorMessage = errorDesc);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go('/login');
        }
        return;
      }

      // Échange du code d'autorisation contre un jeu de jetons d'accès
      final hasCode = uri.queryParameters.containsKey('code') ||
          fragmentParams.containsKey('code');
      final hasToken = uri.queryParameters.containsKey('access_token') ||
          fragmentParams.containsKey('access_token');

      if (hasCode || hasToken) {
        try {
          await Supabase.instance.client.auth.getSessionFromUrl(uri);
        } catch (e) {
          debugPrint('getSessionFromUrl notice: $e');
        }
      }
    } catch (e) {
      debugPrint('AuthCallback parse error: $e');
    }

    // Boucle d'attente active de propagation de la session (max 4 secondes)
    if (Supabase.instance.client.auth.currentSession == null) {
      for (int i = 0; i < 8; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (Supabase.instance.client.auth.currentSession != null) break;
      }
    }

    if (!mounted) return;
    if (Supabase.instance.client.auth.currentSession != null) {
      await navigateAfterAuth(ref, context);
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage != null) ...[
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ] else ...[
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

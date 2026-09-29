import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/togo_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/locale_provider.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../../shared/widgets/togo_widgets.dart';
import '../../../auth/presentation/auth_flow.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SettingsSheet(),
  );
}

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _nomAppel = TextEditingController();
  AppThemeMode _theme = AppThemeMode.systeme;
  String _lang = 'fr';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final profile = await ref.read(userProfileProvider.future);
    if (!mounted) return;
    setState(() {
      _nom.text = profile?.nom ?? '';
      _prenom.text = profile?.prenom ?? '';
      _nomAppel.text = profile?.nomAppel ?? '';
      _theme = AppThemeMode.fromDb(profile?.theme) ;
      if (profile?.theme == null) {
        _theme = ref.read(themeModeProvider);
      }
      _lang = profile?.language ??
          context.locale.languageCode;
      _loading = false;
    });
    // Appliquer thème immédiatement comme le web
    ref.read(themeModeProvider.notifier).setMode(_theme);
  }

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    _nomAppel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            userId: session.user.id,
            nom: _nom.text.trim(),
            prenom: _prenom.text.trim(),
            nomAppel: _nomAppel.text.trim(),
            theme: _theme.dbValue,
          );
      await ref.read(themeModeProvider.notifier).setMode(_theme);
      if (!mounted) return;
      await persistLocale(ref, context, _lang);
      ref.invalidate(userProfileProvider);
      if (!mounted) return;
      setState(() => _success = 'settings.enregistre'.tr());
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'settings.erreurEnregistrement'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    Navigator.of(context).pop();
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // Ignorer si la session est déjà invalide ou expirée
    }
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.togo;
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return Material(
      color: t.bgApp,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'settings.title'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      // ─── PROFIL (card) ───
                      _SectionLabel('settings.profil'.tr()),
                      const SizedBox(height: 10),
                      _SettingsCard(
                        children: [
                          TogoTextField(
                            label: 'settings.nom'.tr(),
                            controller: _nom,
                          ),
                          const SizedBox(height: 12),
                          TogoTextField(
                            label: 'settings.prenom'.tr(),
                            controller: _prenom,
                          ),
                          const SizedBox(height: 12),
                          TogoTextField(
                            label: 'settings.commentVousAppeler'.tr(),
                            controller: _nomAppel,
                            hintText: 'settings.exempleNomAppel'.tr(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ─── APPARENCE (card) ───
                      _SectionLabel('settings.apparence'.tr()),
                      const SizedBox(height: 10),
                      _SettingsCard(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TogoChoiceChip(
                                label: 'settings.themeSysteme'.tr(),
                                selected: _theme == AppThemeMode.systeme,
                                onTap: () {
                                  setState(() => _theme = AppThemeMode.systeme);
                                  ref
                                      .read(themeModeProvider.notifier)
                                      .setMode(AppThemeMode.systeme);
                                },
                                leading: Icon(
                                  Icons.desktop_windows_outlined,
                                  size: 16,
                                  color: _theme == AppThemeMode.systeme
                                      ? t.accent
                                      : t.textSecondary,
                                ),
                              ),
                              TogoChoiceChip(
                                label: 'settings.themeClair'.tr(),
                                selected: _theme == AppThemeMode.clair,
                                onTap: () {
                                  setState(() => _theme = AppThemeMode.clair);
                                  ref
                                      .read(themeModeProvider.notifier)
                                      .setMode(AppThemeMode.clair);
                                },
                                leading: Icon(
                                  Icons.wb_sunny_outlined,
                                  size: 16,
                                  color: _theme == AppThemeMode.clair
                                      ? t.accent
                                      : t.textSecondary,
                                ),
                              ),
                              TogoChoiceChip(
                                label: 'settings.themeSombre'.tr(),
                                selected: _theme == AppThemeMode.sombre,
                                onTap: () {
                                  setState(() => _theme = AppThemeMode.sombre);
                                  ref
                                      .read(themeModeProvider.notifier)
                                      .setMode(AppThemeMode.sombre);
                                },
                                leading: Icon(
                                  Icons.dark_mode_outlined,
                                  size: 16,
                                  color: _theme == AppThemeMode.sombre
                                      ? t.accent
                                      : t.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ─── LANGUE (card) ───
                      _SectionLabel('settings.language'.tr()),
                      const SizedBox(height: 10),
                      _SettingsCard(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TogoChoiceChip(
                                label: '🇫🇷 ${"settings.languageOptions.fr".tr()}',
                                selected: _lang == 'fr',
                                onTap: () async {
                                  setState(() => _lang = 'fr');
                                  await persistLocale(ref, context, 'fr');
                                },
                              ),
                              TogoChoiceChip(
                                label: '🇬🇧 ${"settings.languageOptions.en".tr()}',
                                selected: _lang == 'en',
                                onTap: () async {
                                  setState(() => _lang = 'en');
                                  await persistLocale(ref, context, 'en');
                                },
                              ),
                              TogoChoiceChip(
                                label: '🇹🇬 ${"settings.languageOptions.ewe".tr()}',
                                selected: _lang == 'ewe',
                                onTap: () async {
                                  setState(() => _lang = 'ewe');
                                  await persistLocale(ref, context, 'ewe');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      TogoPrimaryButton(
                        label: 'settings.enregistrer'.tr(),
                        loading: _saving,
                        onPressed: _save,
                      ),
                      if (_success != null) ...[
                        const SizedBox(height: 10),
                        Text(_success!,
                            style: TextStyle(color: t.accent),
                            textAlign: TextAlign.center),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!,
                            style: TextStyle(color: t.danger),
                            textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 28),
                      Divider(color: t.border),
                      const SizedBox(height: 12),

                      // ─── COMPTE (card) ───
                      _SectionLabel('settings.compte'.tr()),
                      const SizedBox(height: 8),
                      _SettingsCard(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.lock_outline, color: t.textSecondary),
                            title: Text(
                              'settings.modifierMotDePasse'.tr(),
                              style: TextStyle(color: t.textSecondary),
                            ),
                            enabled: false,
                          ),
                          Divider(color: t.border, height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.logout),
                            title: Text('settings.seDeconnecter'.tr()),
                            onTap: _logout,
                          ),
                          Divider(color: t.border, height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline, color: t.danger),
                            title: Text(
                              'settings.supprimerCompte'.tr(),
                              style: TextStyle(color: t.danger),
                            ),
                            onTap: _confirmDeleteAccount,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ─── INFORMATIONS (card) ───
                      _SectionLabel('settings.informations'.tr()),
                      const SizedBox(height: 8),
                      _SettingsCard(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.info_outline, color: t.accent),
                            title: Text('menu.aPropos'.tr()),
                            trailing: Icon(Icons.chevron_right, color: t.textTertiary),
                            onTap: () async {
                              final uri = Uri.parse(AppConfig.aboutUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                          Divider(color: t.border, height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.shield_outlined, color: t.accent),
                            title: Text('menu.politiqueConfidentialite'.tr()),
                            trailing: Icon(Icons.chevron_right, color: t.textTertiary),
                            onTap: () async {
                              final uri = Uri.parse(AppConfig.privacyUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                          Divider(color: t.border, height: 1),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.description_outlined, color: t.accent),
                            title: Text('menu.conditionsUtilisation'.tr()),
                            trailing: Icon(Icons.chevron_right, color: t.textTertiary),
                            onTap: () async {
                              final uri = Uri.parse(AppConfig.termsUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final isGoogle = () {
      final user = ref.read(supabaseProvider).auth.currentUser;
      return user?.appMetadata['provider'] == 'google' ||
          (user?.identities?.any((i) => i.provider == 'google') ?? false);
    }();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settings.supprimerCompte'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isGoogle
                  ? 'Reconnectez-vous avec Google (session < 5 min), puis tapez SUPPRIMER.'
                  : 'Entrez votre mot de passe et tapez SUPPRIMER pour confirmer.',
            ),
            if (!isGoogle) ...[
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'auth.password'.tr()),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              decoration: const InputDecoration(
                labelText: 'Confirmation',
                hintText: 'SUPPRIMER',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('settings.fermer'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'settings.supprimerCompte'.tr(),
              style: TextStyle(color: context.togo.danger),
            ),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await ref.read(authRepositoryProvider).softDeleteAccount(
            password: passwordCtrl.text,
            confirmation: confirmCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        context.go('/login');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = switch (e.message) {
        'mot_de_passe_incorrect' => 'auth.erreurIdentifiants'.tr(),
        'reauth_google_requise' =>
          'Reconnectez-vous avec Google avant de supprimer le compte.',
        'confirmation_invalide' => 'Confirmation invalide (tapez SUPPRIMER).',
        _ => e.message,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: context.togo.textSecondary,
      ),
    );
  }
}

/// Carte arrondie pour regrouper les éléments de paramètres.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.togo;
    return Container(
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border, width: 0.8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

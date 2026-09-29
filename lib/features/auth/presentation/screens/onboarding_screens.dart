import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth_flow.dart';
import '../../../../core/theme/togo_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../../shared/widgets/branding.dart';
import '../../../../shared/widgets/togo_widgets.dart';

/// Layout commun onboarding (logo + titre + formulaire).
class _OnboardingShell extends ConsumerWidget {
  const _OnboardingShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == AppThemeMode.sombre ||
        (themeMode == AppThemeMode.systeme &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  onPressed: () {
                    ref.read(themeModeProvider.notifier).setMode(
                          isDark ? AppThemeMode.clair : AppThemeMode.sombre,
                        );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: context.togo.bgCard,
                    side: BorderSide(color: context.togo.border),
                  ),
                  icon: Icon(
                    isDark
                        ? Icons.wb_sunny_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: TogoLogoWordmark(size: 32)),
                      const SizedBox(height: 28),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.togo.textSecondary),
                      ),
                      const SizedBox(height: 28),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingNomPrenomScreen extends ConsumerStatefulWidget {
  const OnboardingNomPrenomScreen({super.key});

  @override
  ConsumerState<OnboardingNomPrenomScreen> createState() =>
      _OnboardingNomPrenomScreenState();
}

class _OnboardingNomPrenomScreenState
    extends ConsumerState<OnboardingNomPrenomScreen> {
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final profile = await ref.read(userProfileProvider.future);
    final user = ref.read(supabaseProvider).auth.currentUser;
    final meta = user?.userMetadata ?? {};

    String nom = profile?.nom ??
        (meta['nom'] as String?) ??
        (meta['family_name'] as String?) ??
        '';
    String prenom = profile?.prenom ??
        (meta['prenom'] as String?) ??
        (meta['given_name'] as String?) ??
        '';

    if (nom.isEmpty && prenom.isEmpty) {
      final full = ((meta['full_name'] ?? meta['name']) as String?)?.trim();
      if (full != null && full.isNotEmpty) {
        final parts = full.split(' ');
        prenom = parts.first;
        nom = parts.length > 1 ? parts.sublist(1).join(' ') : parts.first;
      }
    }

    if (!mounted) return;
    setState(() {
      _nom.text = nom;
      _prenom.text = prenom;
    });
  }

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nom.text.trim().isEmpty || _prenom.text.trim().isEmpty) {
      setState(() => _error = 'auth.erreurNomPrenomRequis'.tr());
      return;
    }
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      setState(() => _error = 'common.sessionExpiree'.tr());
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            userId: session.user.id,
            nom: _nom.text.trim(),
            prenom: _prenom.text.trim(),
          );
      ref.invalidate(userProfileProvider);
      if (mounted) context.go('/onboarding/nom-appel');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingShell(
      title: 'auth.completezVotreProfil'.tr(),
      subtitle: 'auth.sousTitreNomPrenom'.tr(),
      child: Column(
        children: [
          TogoTextField(
            label: 'auth.nom'.tr(),
            controller: _nom,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          TogoTextField(
            label: 'auth.prenom'.tr(),
            controller: _prenom,
            textInputAction: TextInputAction.done,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.togo.danger)),
          ],
          const SizedBox(height: 24),
          TogoPrimaryButton(
            label: _loading
                ? 'auth.enregistrementEnCours'.tr()
                : 'auth.continuer'.tr(),
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class OnboardingNomAppelScreen extends ConsumerStatefulWidget {
  const OnboardingNomAppelScreen({super.key});

  @override
  ConsumerState<OnboardingNomAppelScreen> createState() =>
      _OnboardingNomAppelScreenState();
}

class _OnboardingNomAppelScreenState
    extends ConsumerState<OnboardingNomAppelScreen> {
  final _nomAppel = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(userProfileProvider.future).then((p) {
      if (p?.nomAppel != null && mounted) {
        _nomAppel.text = p!.nomAppel!;
      }
    });
  }

  @override
  void dispose() {
    _nomAppel.dispose();
    super.dispose();
  }

  Future<void> _save(String? value) async {
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      setState(() => _error = 'common.sessionExpiree'.tr());
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            userId: session.user.id,
            nomAppel: value ?? '',
          );
      ref.invalidate(userProfileProvider);
      if (mounted) context.go('/onboarding/date-naissance');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingShell(
      title: 'auth.titreNomAppel'.tr(),
      subtitle: 'auth.sousTitreNomAppel'.tr(),
      child: Column(
        children: [
          TogoTextField(
            label: 'auth.nomAppel'.tr(),
            controller: _nomAppel,
            hintText: 'auth.exempleNomAppel'.tr(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.togo.danger)),
          ],
          const SizedBox(height: 24),
          TogoPrimaryButton(
            label: _loading
                ? 'auth.enregistrementEnCours'.tr()
                : 'auth.continuer'.tr(),
            loading: _loading,
            onPressed: () => _save(_nomAppel.text.trim()),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading ? null : () => _save(null),
            child: Text('auth.passer'.tr()),
          ),
        ],
      ),
    );
  }
}

class OnboardingDateNaissanceScreen extends ConsumerStatefulWidget {
  const OnboardingDateNaissanceScreen({super.key});

  @override
  ConsumerState<OnboardingDateNaissanceScreen> createState() =>
      _OnboardingDateNaissanceScreenState();
}

class _OnboardingDateNaissanceScreenState
    extends ConsumerState<OnboardingDateNaissanceScreen> {
  DateTime? _date;
  bool _loading = false;
  String? _error;

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(DateTime? value) async {
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      setState(() => _error = 'common.sessionExpiree'.tr());
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateDateNaissance(
            userId: session.user.id,
            dateNaissance: value,
          );
      ref.invalidate(userProfileProvider);
      if (mounted) context.go('/chat/nouvelle');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _date == null
        ? 'auth.dateNaissance'.tr()
        : '${_date!.day.toString().padLeft(2, '0')}/'
            '${_date!.month.toString().padLeft(2, '0')}/'
            '${_date!.year}';

    return _OnboardingShell(
      title: 'auth.titreDateNaissance'.tr(),
      subtitle: 'auth.sousTitreDateNaissance'.tr(),
      child: Column(
        children: [
          OutlinedButton(
            onPressed: _pick,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 10),
                Text(label),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.togo.danger)),
          ],
          const SizedBox(height: 24),
          TogoPrimaryButton(
            label: _loading
                ? 'auth.enregistrementEnCours'.tr()
                : 'auth.terminer'.tr(),
            loading: _loading,
            onPressed: () {
              if (_date == null) {
                setState(() => _error = 'auth.erreurDateRequise'.tr());
                return;
              }
              _save(_date);
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading ? null : () => _save(null),
            child: Text('auth.passer'.tr()),
          ),
        ],
      ),
    );
  }
}

/*
Date : 29/09/2026
Auteurs : Elpidio Alexis AMOUSSOU
          Eli Yannick HOVI
Emails : amoussouelpidioalexis@gmail.com
         yannickeli2007@gmail.com
But : Tiroir latéral (drawer) listant l'historique des discussions avec barre de recherche, options de renommage/suppression et raccourci vers les paramètres.
*/

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/togo_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/branding.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../data/conversations_repository.dart';

/// Tiroir latéral (drawer) affichant l'historique des conversations.
///
/// Ce widget est le panneau de navigation principal de l'application,
/// accessible via un swipe ou le bouton hamburger. Il propose :
///
/// - **En-tête** : Logo wordmark + bouton fermer.
/// - **Nouvelle conversation** : Bouton outlined pour démarrer un nouveau chat.
/// - **Barre de recherche** : Filtre les conversations en temps réel par titre.
/// - **Liste des conversations** : Affiche toutes les discussions avec
///   indicateur visuel de la conversation active (bordure gauche accent).
/// - **Actions contextuelles** : Menu popup par conversation (renommer, supprimer).
/// - **Footer** : Avatar + nom de l'utilisateur + accès aux paramètres.
///
/// Utilise [ConsumerStatefulWidget] car il gère un état local (la requête
/// de recherche [_query]) tout en observant les providers Riverpod.
class ConversationsDrawer extends ConsumerStatefulWidget {
  const ConversationsDrawer({
    super.key,
    required this.currentId,
    required this.onOpenSettings,
  });

  /// Identifiant de la conversation actuellement affichée dans le chat.
  /// Utilisé pour mettre en surbrillance l'élément correspondant dans la liste.
  /// Peut être null si l'utilisateur est sur un nouveau chat non persisté.
  final String? currentId;

  /// Callback déclenché quand l'utilisateur tape sur la zone profil/paramètres.
  final VoidCallback onOpenSettings;

  @override
  ConsumerState<ConversationsDrawer> createState() =>
      _ConversationsDrawerState();
}

class _ConversationsDrawerState extends ConsumerState<ConversationsDrawer> {
  /// Requête de recherche locale – filtre les conversations par titre (lowercase).
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.togo;
    // Observation réactive de la liste des conversations depuis Supabase
    final asyncList = ref.watch(conversationsListProvider);
    // Profil utilisateur pour afficher le nom et l'initiale dans le footer
    final profile = ref.watch(userProfileProvider).valueOrNull;

    return Drawer(
      backgroundColor: t.bgSidebar,
      width: 300,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── En-tête : Logo + bouton fermer ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(child: TogoLogoWordmark(size: 30)),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // ─── Bouton nouvelle conversation ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/chat/nouvelle');
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text('nav.newConversation'.tr()),
              ),
            ),
            const SizedBox(height: 12),
            // ─── Barre de recherche avec filtre temps réel ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'nav.rechercherConversation'.tr(),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: t.bgCard,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: t.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: t.border),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ─── Liste des conversations (scrollable) ───
            Expanded(
              child: asyncList.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text('nav.aucuneDiscussion'.tr())),
                data: (list) {
                  // Filtrage côté client par titre – case-insensitive
                  final filtered = _query.isEmpty
                      ? list
                      : list
                          .where((c) => c.titre.toLowerCase().contains(_query))
                          .toList();

                  // Message d'état vide adaptatif (pas de conversations vs aucun résultat)
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isEmpty
                            ? 'nav.aucuneDiscussion'.tr()
                            : 'nav.aucunResultat'.tr(),
                        style: TextStyle(color: t.textSecondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      final active = c.id == widget.currentId;
                      return Material(
                        // Fond teinté pour la conversation active
                        color: active ? t.bgActive : Colors.transparent,
                        child: ListTile(
                          selected: active,
                          title: Text(
                            c.titre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Bordure gauche accent pour indiquer la sélection
                          shape: Border(
                            left: BorderSide(
                              color: active ? t.accent : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go('/chat/${c.id}');
                          },
                          // Menu contextuel : renommer / supprimer
                          trailing: PopupMenuButton<String>(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 8,
                            onSelected: (value) async {
                              if (value == 'rename') {
                                await _rename(c);
                              } else if (value == 'delete') {
                                await _delete(c);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18, color: Theme.of(context).colorScheme.onSurface),
                                    const SizedBox(width: 10),
                                    Text('nav.renommer'.tr()),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 18, color: t.danger),
                                    const SizedBox(width: 10),
                                    Text(
                                      'nav.supprimer'.tr(),
                                      style: TextStyle(color: t.danger),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // ─── Footer : profil utilisateur + accès paramètres ───
            InkWell(
              onTap: widget.onOpenSettings,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    // Avatar avec initiale – couleur accent pour cohérence visuelle
                    CircleAvatar(
                      backgroundColor: t.accent,
                      child: Text(
                        profile?.initial ?? '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.displayName ?? 'menu.utilisateur'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'menu.connecte'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.settings_outlined, color: t.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Affiche un dialogue de renommage pour la conversation [c].
  ///
  /// Pré-remplit le champ avec le titre actuel. Si l'utilisateur confirme
  /// et que le nouveau titre n'est pas vide, met à jour via le repository
  /// puis invalide le cache de la liste pour forcer un rafraîchissement.
  Future<void> _rename(Conversation c) async {
    final controller = TextEditingController(text: c.titre);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('nav.renommer'.tr()),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('settings.fermer'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('settings.enregistrer'.tr()),
          ),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      await ref.read(conversationsRepositoryProvider).rename(
            c.id,
            controller.text,
          );
      // Invalide le cache pour refléter le nouveau titre dans la liste
      ref.invalidate(conversationsListProvider);
    }
  }

  /// Affiche un dialogue de confirmation avant suppression de la conversation [c].
  ///
  /// En cas de confirmation :
  /// 1. Supprime la conversation via le repository (DELETE Supabase).
  /// 2. Invalide les caches de la liste et du contrôleur de chat associé.
  /// 3. Si la conversation supprimée est celle actuellement affichée,
  ///    ferme le drawer et redirige vers un nouveau chat.
  ///
  /// En cas d'erreur réseau, affiche un [SnackBar] d'erreur sans crasher.
  Future<void> _delete(Conversation c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('nav.supprimer'.tr()),
        content: Text('chat.confirmerSuppression'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('settings.fermer'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'nav.supprimer'.tr(),
              style: TextStyle(color: context.togo.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(conversationsRepositoryProvider).delete(c.id);
        // Nettoyage des caches associés à la conversation supprimée
        ref.invalidate(conversationsListProvider);
        ref.invalidate(chatControllerProvider(c.id));
        // Redirection si la conversation active vient d'être supprimée
        if (c.id == widget.currentId && mounted) {
          Navigator.of(context).pop();
          context.go('/chat/nouvelle');
        }
      } catch (_) {
        // Affiche un feedback utilisateur en cas d'échec réseau
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('nav.erreurSuppression'.tr())),
          );
        }
      }
    }
  }
}

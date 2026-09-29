import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/togo_colors.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/widgets/branding.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../data/conversations_repository.dart';

class ConversationsDrawer extends ConsumerStatefulWidget {
  const ConversationsDrawer({
    super.key,
    required this.currentId,
    required this.onOpenSettings,
  });

  final String? currentId;
  final VoidCallback onOpenSettings;

  @override
  ConsumerState<ConversationsDrawer> createState() =>
      _ConversationsDrawerState();
}

class _ConversationsDrawerState extends ConsumerState<ConversationsDrawer> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.togo;
    final asyncList = ref.watch(conversationsListProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;

    return Drawer(
      backgroundColor: t.bgSidebar,
      width: 300,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            Expanded(
              child: asyncList.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text('nav.aucuneDiscussion'.tr())),
                data: (list) {
                  final filtered = _query.isEmpty
                      ? list
                      : list
                          .where((c) => c.titre.toLowerCase().contains(_query))
                          .toList();
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
                        color: active ? t.bgActive : Colors.transparent,
                        child: ListTile(
                          selected: active,
                          title: Text(
                            c.titre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
            InkWell(
              onTap: widget.onOpenSettings,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
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
      ref.invalidate(conversationsListProvider);
    }
  }

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
        ref.invalidate(conversationsListProvider);
        ref.invalidate(chatControllerProvider(c.id));
        if (c.id == widget.currentId && mounted) {
          Navigator.of(context).pop();
          context.go('/chat/nouvelle');
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('nav.erreurSuppression'.tr())),
          );
        }
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/guild_events.dart';
import '../../state/recruitment.dart';
import '../../state/settings.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/responsive.dart';

/// who the leader of a guild has allowed to open and edit its recruitment page: any member, by the account they play. it is not the officer's permission, and it goes with the membership. only the leader
/// changes it; the database says so, and the screen is only opened for the leader
class RecruitersScreen extends ConsumerWidget {
  const RecruitersScreen({super.key, required this.guild});

  final MyRecruitGuild guild;

  Future<void> _change(BuildContext context, WidgetRef ref, Future<void> Function() change) async {
    final s = ref.read(stringsProvider);
    try {
      await change();
      ref.invalidate(recruitersProvider(guild.guildId));
    } catch (e) {
      if (context.mounted) showToast(context, s.t(recruitErrorKey(e)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final recruiters = ref.watch(recruitersProvider(guild.guildId));
    return Scaffold(
      appBar: AppBar(title: Text('${s.t('rec_rec_title')} · ${guild.title}', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ContentFrame(
        maxWidth: readingMaxWidth,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(s.t('rec_rec_intro'), style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSoft)),
            const SizedBox(height: 16),
            AsyncView<List<RecruiterEntry>>(
              value: recruiters,
              onRetry: () => ref.invalidate(recruitersProvider(guild.guildId)),
              builder: (list) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(s.t('rec_rec_none'), style: const TextStyle(color: AppColors.muted)),
                    ),
                  for (final r in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(r.accountName),
                      trailing: TextButton(
                        onPressed: () => _change(context, ref, () => ref.read(recruitBackendProvider).revoke(guild.guildId, r.userId)),
                        child: Text(s.t('rec_rec_remove')),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _pick(context, ref, {for (final r in list) r.userId}),
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(s.t('rec_rec_add')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// the members the leader may allow: those of the guild who are not its leader and are not allowed already
  Future<void> _pick(BuildContext context, WidgetRef ref, Set<String> already) async {
    final s = ref.read(stringsProvider);
    final roster = await ref.read(guildRosterProvider(guild.guildId).future);
    if (!context.mounted) return;
    final candidates = [
      for (final m in roster)
        if (m.role != 'leader' && !already.contains(m.userId)) m,
    ];
    final chosen = await showDialog<RosterMember>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(s.t('rec_rec_pick')),
        children: [
          if (candidates.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(s.t('rec_rec_none'), style: const TextStyle(color: AppColors.muted))),
          for (final m in candidates)
            SimpleDialogOption(onPressed: () => Navigator.of(context).pop(m), child: Text(m.accountName)),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    await _change(context, ref, () => ref.read(recruitBackendProvider).grant(guild.guildId, chosen.userId));
  }
}

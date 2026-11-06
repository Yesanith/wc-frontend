part of '../guilds_screen.dart';

/// one guild rank with how many hold it and what it may do
class _RankCard extends ConsumerStatefulWidget {
  const _RankCard({required this.rank, required this.members});

  final Json rank;
  final int members;

  @override
  ConsumerState<_RankCard> createState() => _RankCardState();
}

class _RankCardState extends ConsumerState<_RankCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final catalog = ref.watch(guildPermissionsProvider).valueOrNull ?? const <String, Json>{};
    final permissions = [for (final p in (widget.rank['permissions'] as List?) ?? const []) '$p'];
    final icon = widget.rank['icon'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: permissions.isEmpty ? null : () => setState(() => _open = !_open),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: icon == null ? null : CachedIcon(url: icon, fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${widget.rank['id'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                Text(s.t('n_members', {'n': widget.members}), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                if (permissions.isNotEmpty)
                  Icon(_open ? Icons.expand_less : Icons.expand_more, color: AppColors.chevron),
              ],
            ),
            if (!_open && permissions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  s.t('n_permissions', {'n': permissions.length}),
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            if (_open)
              for (final p in permissions)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${catalog[p]?['name'] ?? p.replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => ' ${m[1]}')}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      if ('${catalog[p]?['description'] ?? ''}'.isNotEmpty)
                        Text(
                          '${catalog[p]!['description']}',
                          style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// what the guild's leader shares of it: level, message of the day, member
/// count, and the members who use the app with the rank the game gives them
class _SharedGuild extends ConsumerWidget {
  const _SharedGuild({required this.gw2Id});

  final String gw2Id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    Widget note(String key) => Panel(
      child: Text(s.t(key), style: TextStyle(color: AppColors.muted, height: 1.5)),
    );

    return ref
        .watch(tyriaGuildIdProvider(gw2Id))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => ListView(padding: const EdgeInsets.all(20), children: [note('guild_rank_needed')]),
          data: (guildId) {
            // no account linked in this guild yet, so nothing is shared with the player
            if (guildId == null) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [note('gshared_not_linked'), const SizedBox(height: 12), note('guild_rank_needed')],
              );
            }
            final roster = ref.watch(guildRosterProvider(guildId));
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                GuildInfoCard(guildId: guildId, leading: false),
                const SizedBox(height: 16),
                Text(s.t('gshared_note'), style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted)),
                const SizedBox(height: 10),
                roster.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => ErrorBox(error: e, onRetry: () => ref.invalidate(guildRosterProvider(guildId))),
                  data: (members) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(title: s.t('members'), trailing: '${members.length}'),
                      const SizedBox(height: 6),
                      for (final m in members)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                m.role == 'leader'
                                    ? Icons.workspace_premium
                                    : m.role == 'officer'
                                    ? Icons.military_tech_outlined
                                    : Icons.person_outline,
                                size: 18,
                                color: m.role == 'member' ? AppColors.muted : AppColors.gold,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  m.accountName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                m.gw2Rank ?? s.t('guild_role_${m.role}'),
                                style: TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/community.dart';
import '../state/guild_events.dart';
import '../state/link_refresh.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'guild_events_screen.dart' show eventWhen;

/// a guild's tyria companion members with their roles. the leader appoints
/// officers here, who may then create and manage events
class GuildRosterScreen extends ConsumerStatefulWidget {
  const GuildRosterScreen({super.key, required this.guild});

  final MyGuild guild;

  @override
  ConsumerState<GuildRosterScreen> createState() => _GuildRosterScreenState();
}

class _GuildRosterScreenState extends ConsumerState<GuildRosterScreen> {
  /// the leader's app brings what the game tells only the leader, and says how it went
  Future<void> _bringFromGame() async {
    final s = ref.read(stringsProvider);
    try {
      final outcome = await refreshLink(ref, force: true);
      if (mounted) showToast(context, guildSyncMessage(s, outcome), duration: const Duration(seconds: 6));
    } catch (e) {
      if (mounted) showToast(context, '${s.t('community_failed')} ($e)', duration: const Duration(seconds: 6));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final me = ref.watch(sessionProvider).valueOrNull?.user.id;
    final g = widget.guild;
    final leading = g.role == 'leader';

    return Scaffold(
      appBar: AppBar(title: Text(g.tag.isEmpty ? g.name : '${g.name} [${g.tag}]')),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          // a leader's app brings what the game tells only the leader, and says how it went
          if (leading) await _bringFromGame();
          ref.invalidate(guildRosterProvider(g.id));
          ref.invalidate(guildDetailsProvider(g.id));
          await ref.read(guildRosterProvider(g.id).future);
        },
        child: AsyncView<List<RosterMember>>(
          value: ref.watch(guildRosterProvider(g.id)),
          onRetry: () => ref.invalidate(guildRosterProvider(g.id)),
          builder: (members) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              GuildInfoCard(guildId: g.id, leading: leading),
              const SizedBox(height: 12),
              if (leading) ...[GuildSharingPanel(guildId: g.id), const SizedBox(height: 12)],
              Text(
                s.t('roster_note_game'),
                style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    for (final m in members)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              m.role == 'leader'
                                  ? Icons.workspace_premium
                                  : m.role == 'officer'
                                      ? Icons.military_tech_outlined
                                      : Icons.person_outline,
                              size: 20,
                              color: m.role == 'member' ? AppColors.muted : AppColors.gold,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.accountName,
                                    style: TextStyle(fontWeight: m.userId == me ? FontWeight.w800 : FontWeight.w600),
                                  ),
                                  Text(rankLabel(s, m.role, m.gw2Rank),
                                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(s.t('roster_missing'), style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.hint)),
            ],
          ),
        ),
      ),
    );
  }
}

/// the level, message of the day and member count the game gives the guild,
/// or why they are not here yet. [guildId] is the community guild's id
class GuildInfoCard extends ConsumerWidget {
  const GuildInfoCard({super.key, required this.guildId, required this.leading});

  final String guildId;
  final bool leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final d = ref.watch(guildDetailsProvider(guildId)).valueOrNull;
    if (d == null || !d.known) {
      return Text(
        s.t(leading ? 'ginfo_pending_leader' : 'ginfo_pending'),
        style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.hint),
      );
    }

    Widget fact(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        );

    final count = d.memberCount;
    final capacity = d.memberCapacity;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              if (d.level != null) fact(s.t('ginfo_level'), '${d.level}'),
              if (count != null) fact(s.t('ginfo_members'), capacity == null ? '$count' : '$count / $capacity'),
            ],
          ),
          if (d.motd.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(d.motd, style: const TextStyle(fontSize: 13, height: 1.4, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 8),
          Text(
            s.t('ginfo_updated', {'when': eventWhen(s, d.syncedAt!.toLocal())}),
            style: const TextStyle(fontSize: 11, color: AppColors.hint),
          ),
        ],
      ),
    );
  }
}

/// the parts of a guild the leader may hide from the members, with the text
/// each is called in the guild's tabs
const _sharedParts = <String, String>{
  'members': 'members',
  'ranks': 'ranks',
  'treasury': 'treasury',
  'stash': 'stash',
  'upgrades': 'built_upgrades',
  'storage': 'hall_storage',
  'teams': 'pvp_teams',
  'log': 'log',
};

/// what the guild's leader lets the members see of everything the leader's app
/// brings, one switch for each part. [guildId] is the community guild's id
class GuildSharingPanel extends ConsumerStatefulWidget {
  const GuildSharingPanel({super.key, required this.guildId});

  final String guildId;

  @override
  ConsumerState<GuildSharingPanel> createState() => _GuildSharingPanelState();
}

class _GuildSharingPanelState extends ConsumerState<GuildSharingPanel> {
  bool _busy = false;

  Future<void> _set(String part, bool shared) async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      await setGuildPartShared(widget.guildId, part, shared);
      ref.invalidate(guildDetailsProvider(widget.guildId));
      await ref.read(guildDetailsProvider(widget.guildId).future);
    } catch (e) {
      if (mounted) showToast(context, '${s.t('community_failed')} ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final details = ref.watch(guildDetailsProvider(widget.guildId));
    final d = details.valueOrNull;
    if (d == null) {
      // never vanish quietly: the switches are the only way to choose
      return details.isLoading
          ? const LinearProgressIndicator(minHeight: 2, color: AppColors.gold)
          : Text(s.t('community_failed'), style: const TextStyle(fontSize: 12, color: AppColors.hint));
    }

    Widget row(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: value,
          onChanged: _busy ? null : onChanged,
          title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(
            s.t(value ? 'gshare_on' : 'gshare_off'),
            style: TextStyle(fontSize: 11, color: value ? AppColors.gold : AppColors.hint),
          ),
        );

    return Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('gshare_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(s.t('gshare_note'), style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
          for (final part in _sharedParts.entries) row(s.t(part.value), d.shares(part.key), (v) => _set(part.key, v)),
        ],
      ),
    );
  }
}

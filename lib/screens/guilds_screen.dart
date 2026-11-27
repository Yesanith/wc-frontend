import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../api/gw2_api.dart';
import '../services/icon_cache.dart';
import '../state/clock.dart';
import '../state/community.dart';
import '../state/guild_events.dart' show EventSummary, guildRosterProvider, upcomingEventsProvider;
import '../state/guilds.dart';
import '../state/reference.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/guild_emblem.dart';
import 'guild_roster_screen.dart' show GuildInfoCard, GuildSharingPanel;
import 'item_sheet.dart';

part 'guilds/rank.dart';
part 'guilds/tabs.dart';
part 'guilds/site.dart';

class GuildsScreen extends ConsumerWidget {
  const GuildsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final ids = ref.watch(guildIdsProvider);

    // on a site the guilds are a row of them over the tabs of the one chosen
    if (SiteScope.of(context)) {
      return AsyncView<List<String>>(
        value: ids,
        onRetry: () => ref.invalidate(guildIdsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Panel(child: Text(s.t('no_guilds'), style: TextStyle(color: AppColors.muted))),
            );
          }
          return _GuildsSite(ids: list);
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(s.t('guilds_note'), style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
        const SizedBox(height: 12),
        AsyncView<List<String>>(
          value: ids,
          onRetry: () => ref.invalidate(guildIdsProvider),
          builder: (list) {
            if (list.isEmpty) {
              return Panel(child: Text(s.t('no_guilds'), style: TextStyle(color: AppColors.muted)));
            }
            return CardWrap(minWidth: 400, children: [for (final id in list) _GuildCard(id: id)]);
          },
        ),
      ],
    );
  }
}

class _GuildCard extends ConsumerWidget {
  const _GuildCard({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guild = ref.watch(guildProvider(id)).valueOrNull;
    final name = (guild?['name'] as String?) ?? '...';
    final tag = (guild?['tag'] as String?) ?? '';

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => GuildDetailScreen(id: id)),
      ),
      padding: const EdgeInsets.all(16),
      radius: AppRadius.card,
      child: Row(
        children: [
          GuildEmblem(emblem: _emblemOf(guild), size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: display(18)),
                if (tag.isNotEmpty) Text('[$tag]', style: TextStyle(fontSize: 13, color: AppColors.gold)),
              ],
            ),
          ),
          if (asInt(guild?['level']) > 0)
            Text('${asInt(guild?['level'])}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: AppColors.chevron),
        ],
      ),
    );
  }
}

class GuildDetailScreen extends ConsumerWidget {
  const GuildDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final guild = ref.watch(guildProvider(id)).valueOrNull;
    final name = (guild?['name'] as String?) ?? s.t('guild');

    // the leader chooses here what the members see of the treasury, the stash and the log
    final tyriaId = ref.watch(tyriaGuildIdProvider(id)).valueOrNull;
    final leads = tyriaId != null &&
        (ref.watch(myGuildsProvider).valueOrNull ?? const <MyGuild>[])
            .any((g) => g.id == tyriaId && g.role == 'leader');

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        // the guild's own dark header, as the mockup of the phone has it: its emblem, tag and level over the name
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: AppColors.header,
          foregroundColor: AppColors.onHeader,
          iconTheme: IconThemeData(color: AppColors.onHeader),
          toolbarHeight: 72,
          titleSpacing: 0,
          title: Row(
            children: [
              GuildEmblem(emblem: _emblemOf(guild), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (guild != null)
                      Text(
                        [
                          if ('${guild['tag'] ?? ''}'.isNotEmpty) '[${guild['tag']}]',
                          if (guild['level'] != null) s.t('guild_level_n', {'n': guild['level']}),
                        ].join(' · ').caps,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.accent),
                      ),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: display(22, color: const Color(0xFFFFF8E6))),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (leads)
              IconButton(
                tooltip: s.t('gshare_title'),
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  backgroundColor: AppColors.surface,
                  // as tall as its switches, scrolling when the screen is short
                  builder: (_) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: GuildSharingPanel(guildId: tyriaId),
                  ),
                ),
              ),
          ],
          bottom: _LightTabs(
            AppTabBar(
              scrollable: true,
              labels: [s.t('treasury'), s.t('stash'), s.t('members'), s.t('upgrades_guild'), s.t('log')],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _TreasuryTab(id: id),
            _StashTab(id: id),
            _MembersTab(id: id),
            _UpgradesTab(id: id),
            _LogTab(id: id),
          ],
        ),
      ),
    );
  }
}

/// the tabs under a dark header, on a strip of the page's own colour so they read as they do everywhere else
class _LightTabs extends StatelessWidget implements PreferredSizeWidget {
  const _LightTabs(this.tabs);

  final PreferredSizeWidget tabs;

  @override
  Size get preferredSize => tabs.preferredSize;

  @override
  Widget build(BuildContext context) => ColoredBox(color: AppColors.navBg, child: tabs);
}

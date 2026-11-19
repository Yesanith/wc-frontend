part of '../guilds_screen.dart';

/// the guilds on a site: the player's guilds side by side, the chosen one under its tabs, the first of which says what is going on in it
class _GuildsSite extends ConsumerStatefulWidget {
  const _GuildsSite({required this.ids});

  final List<String> ids;

  @override
  ConsumerState<_GuildsSite> createState() => _GuildsSiteState();
}

class _GuildsSiteState extends ConsumerState<_GuildsSite> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final ids = widget.ids;
    final index = _selected < ids.length ? _selected : 0;
    final id = ids[index];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // the guilds side by side, each as wide as its name needs, and sideways to scroll when there are more than fit
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: ids.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) => SizedBox(
                  width: 280,
                  child: _GuildSwitch(id: ids[i], on: i == index, onTap: () => setState(() => _selected = i))),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: DefaultTabController(
              key: ValueKey(id),
              length: 6,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AppTabBar(
                      scrollable: true,
                      labels: [
                        s.t('overview'),
                        s.t('treasury'),
                        s.t('stash'),
                        s.t('members'),
                        s.t('upgrades_guild'),
                        s.t('log'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _OverviewTab(id: id),
                        _TreasuryTab(id: id),
                        _StashTab(id: id),
                        _MembersTab(id: id),
                        _UpgradesTab(id: id),
                        _LogTab(id: id),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// one guild of the row at the top: its emblem, name and level, with a gold edge while it is the one shown
class _GuildSwitch extends ConsumerWidget {
  const _GuildSwitch({required this.id, required this.on, required this.onTap});

  final String id;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final guild = ref.watch(guildProvider(id)).valueOrNull;
    final tag = (guild?['tag'] as String?) ?? '';
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: on ? AppColors.gold : AppColors.line, width: on ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GuildEmblem(emblem: _emblemOf(guild), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: (guild?['name'] as String?) ?? '...', style: display(17)),
                        if (tag.isNotEmpty)
                          TextSpan(
                              text: '  [$tag]',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (asInt(guild?['level']) > 0)
                      Text(s.t('guild_level_n', {'n': asInt(guild?['level'])}),
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// what is going on in a guild: how big it is and what it holds, the message of the day, the next events of it and the last of its log
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final guild = ref.watch(guildProvider(id)).valueOrNull;
    final tyriaId = ref.watch(tyriaGuildIdProvider(id)).valueOrNull;
    final events = [
      for (final e in ref.watch(upcomingEventsProvider).valueOrNull ?? const <EventSummary>[])
        if (tyriaId != null && e.event.guildId == tyriaId) e,
    ].take(4).toList();
    final log = ref.watch(guildLogProvider(id));
    final motd = '${guild?['motd'] ?? ''}'.trim();

    Widget stat(String label, String value, String note) => Expanded(
          child: Panel(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.caps,
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(value, style: display(28)),
                const SizedBox(height: 2),
                Text(note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        );
    String n(String key) => guild?[key] == null ? '–' : fmtInt(asInt(guild?[key]));

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (motd.isNotEmpty) ...[
          Panel(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(s.t('guild_motd').caps),
                const SizedBox(height: 8),
                _Expandable(text: motd),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Panel(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('guild_events'), style: display(18)),
              const SizedBox(height: 8),
              if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(s.t('events_none'), style: TextStyle(fontSize: 13, color: AppColors.muted)),
                )
              else
                for (final e in events)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Column(
                            children: [
                              Text(s.t('wd_${e.event.startAt.toLocal().weekday}').caps,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      color: AppColors.gold)),
                              Text('${e.event.startAt.toLocal().day}', style: display(22)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                              Text(
                                  '${pad2(e.event.startAt.toLocal().hour)}:${pad2(e.event.startAt.toLocal().minute)} · ${titleCase(e.event.activity)}',
                                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        Pill(e.event.maxParticipants == null
                            ? s.t('n_going', {'n': e.going})
                            : '${e.going} / ${e.event.maxParticipants}'),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );

    final right = Panel(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('log'), style: display(18)),
          const SizedBox(height: 8),
          AsyncView<List<Json>>(
            permission: 'guilds',
            restricted: s.t('guild_rank_needed'),
            value: log,
            onRetry: () => ref.invalidate(guildLogProvider(id)),
            builder: (entries) {
              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(s.t('nothing_here'), style: TextStyle(fontSize: 13, color: AppColors.muted)),
                );
              }
              return Column(
                children: [
                  for (final entry in entries.take(6))
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text(_logLine(entry),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4))),
                          const SizedBox(width: 10),
                          Text('${entry['time'] ?? ''}'.length >= 10 ? '${entry['time']}'.substring(0, 10) : '',
                              style: TextStyle(fontSize: 11, color: AppColors.hint)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            stat(s.t('members'), '${n('member_count')} / ${n('member_capacity')}', ''),
            const SizedBox(width: 14),
            stat(s.t('level'), n('level'), '${s.t('guild_influence')} ${n('influence')}'),
            const SizedBox(width: 14),
            stat(s.t('guild_favor'), n('favor'), ''),
            const SizedBox(width: 14),
            stat(s.t('guild_aetherium'), n('aetherium'), '${s.t('guild_resonance')} ${n('resonance')}'),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          if (box.maxWidth < 900) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 16), right]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 13, child: left),
              const SizedBox(width: 16),
              Expanded(flex: 10, child: right),
            ],
          );
        }),
      ],
    );
  }
}

/// a long text cut to a few lines, with a line to read all of it
class _Expandable extends ConsumerStatefulWidget {
  const _Expandable({required this.text});

  final String text;

  @override
  ConsumerState<_Expandable> createState() => _ExpandableState();
}

class _ExpandableState extends ConsumerState<_Expandable> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    // a long message of the day has its lines counted, not its words
    final long = '\n'.allMatches(widget.text).length >= 6 || widget.text.length > 420;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.text,
            maxLines: _open || !long ? null : 6,
            overflow: _open || !long ? TextOverflow.clip : TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, height: 1.55)),
        if (long)
          TextButton(
            onPressed: () => setState(() => _open = !_open),
            child: Text(s.t(_open ? 'show_less' : 'show_more')),
          ),
      ],
    );
  }
}

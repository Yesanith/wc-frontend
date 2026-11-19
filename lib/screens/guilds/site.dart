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
          // the guilds three to a row, one row under another
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 600 ? 2 : 1);
              const gap = 14.0;
              final width = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < ids.length; i++)
                    SizedBox(
                      width: width,
                      child: _GuildSwitch(id: ids[i], on: i == index, onTap: () => setState(() => _selected = i)),
                    ),
                ],
              );
            }),
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

// -------------------------------------------------------------------------
// the other tabs of a guild on a site

String _logDay(Json entry) {
  final time = '${entry['time'] ?? ''}';
  return time.length >= 10 ? time.substring(0, 10) : '';
}

/// the treasury: what is stored against what the upgrades still ask for, in cards, with a search and what to look at
class _TreasurySite extends ConsumerStatefulWidget {
  const _TreasurySite({required this.rows});

  final List<TreasuryRow> rows;

  @override
  ConsumerState<_TreasurySite> createState() => _TreasurySiteState();
}

class _TreasurySiteState extends ConsumerState<_TreasurySite> {
  var _query = '';
  // 0 all, 1 still needed, 2 almost done, 3 done
  var _filter = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    bool done(TreasuryRow r) => r.needed > 0 && r.count >= r.needed;
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final r in widget.rows)
        if ((q.isEmpty || r.name.toLowerCase().contains(q)) &&
            switch (_filter) {
              1 => r.needed > 0 && !done(r),
              2 => r.needed > 0 && !done(r) && r.ratio >= 0.75,
              3 => done(r),
              _ => true,
            })
          r,
    ];
    final open = widget.rows.where((r) => r.needed > 0 && !done(r)).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: fieldDecoration(s.t('search'), prefixIcon: Icon(Icons.search, color: AppColors.muted)),
              ),
            ),
            for (final (i, label) in [
              (0, s.t('all')),
              (1, s.t('treasury_needed')),
              (2, s.t('almost_done')),
              (3, s.t('treasury_done')),
            ])
              ChoiceChip(label: Text(label), selected: _filter == i, onSelected: (_) => setState(() => _filter = i)),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child:
                  Text(s.t('treasury_open_n', {'n': open}), style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        CardWrap(
          minWidth: 300,
          gap: 12,
          children: [
            for (final row in shown)
              Panel(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ItemIcon(url: row.item?['icon'] as String?, rarity: row.item?['rarity'] as String?, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                              Text(
                                  row.needed > 0
                                      ? s.t('treasury_of', {'c': fmtInt(row.count), 'n': fmtInt(row.needed)})
                                      : fmtInt(row.count),
                                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        if (row.needed > 0) Pill('${(row.ratio.clamp(0, 1) * 100).round()}%'),
                      ],
                    ),
                    if (row.needed > 0) ...[
                      const SizedBox(height: 10),
                      Bar(value: row.ratio.clamp(0, 1).toDouble(), color: done(row) ? AppColors.green : AppColors.gold),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// the stash: its tabs at the left, the chosen one as a grid of slots, and what it holds in coins and in words at the right
class _StashSite extends ConsumerStatefulWidget {
  const _StashSite({required this.tabs});

  final List<GuildStashSlot> tabs;

  @override
  ConsumerState<_StashSite> createState() => _StashSiteState();
}

class _StashSiteState extends ConsumerState<_StashSite> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final tabs = widget.tabs;
    final tab = tabs[_selected < tabs.length ? _selected : 0];
    final used = tab.slots.where((e) => e.id != 0).length;
    // what there is most of, in a line each
    final most = [...tab.slots.where((e) => e.id != 0)]..sort((a, b) => b.count.compareTo(a.count));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 250,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 14, bottom: 8),
                  child: Kicker(s.t('stash_tabs').caps),
                ),
                for (var i = 0; i < tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Material(
                      color: tabs[i] == tab ? AppColors.text : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => setState(() => _selected = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(tabs[i].tabName.isEmpty ? '#${i + 1}' : tabs[i].tabName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: tabs[i] == tab ? AppColors.bg : AppColors.text)),
                              ),
                              Text('${tabs[i].slots.where((e) => e.id != 0).length} / ${tabs[i].slots.length}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: tabs[i] == tab ? AppColors.bg.withValues(alpha: 0.7) : AppColors.muted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Panel(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(tab.tabName.isEmpty ? '#${_selected + 1}' : tab.tabName, style: display(22))),
                          Text(s.t('stash_slots_used', {'a': used, 'b': tab.slots.length}),
                              style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView(
                        gridDelegate: const AdaptiveGridDelegate(
                            minColumns: 8, maxTile: 60, mainAxisSpacing: 8, crossAxisSpacing: 8),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final slot in tab.slots)
                            if (slot.id == 0)
                              const ItemIcon(empty: true)
                            else
                              GestureDetector(
                                onTap: () => showItemSheet(
                                  context,
                                  id: slot.id,
                                  name: slot.name,
                                  icon: slot.icon,
                                  rarity: slot.rarity,
                                  type: slot.type,
                                  count: slot.count,
                                ),
                                child: ItemIcon(url: slot.icon, rarity: slot.rarity, count: slot.count),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 290,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (tab.coins > 0) ...[
                  Panel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Kicker(s.t('stash_coins').caps),
                        const SizedBox(height: 8),
                        CoinText(tab.coins, size: 22),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (most.isNotEmpty) ...[
                  Panel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Kicker(s.t('stash_most').caps),
                        const SizedBox(height: 8),
                        for (final e in most.take(3))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${e.name} · ${fmtInt(e.count)}', style: const TextStyle(fontSize: 13.5)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (tab.note.trim().isNotEmpty)
                  Panel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Kicker(s.t('stash_note').caps),
                        const SizedBox(height: 8),
                        Text(tab.note, style: const TextStyle(fontSize: 13.5, height: 1.5)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// the members as a table with a search and the ranks to look at, and the pvp teams under it
class _MembersSite extends ConsumerStatefulWidget {
  const _MembersSite({required this.members, required this.ranks, required this.teams});

  final List<Json> members;
  final List<Json> ranks;
  final List<Json> teams;

  @override
  ConsumerState<_MembersSite> createState() => _MembersSiteState();
}

class _MembersSiteState extends ConsumerState<_MembersSite> {
  var _query = '';
  String? _rank;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final icons = {for (final r in widget.ranks) '${r['id']}': r['icon'] as String?};
    final order = {for (final r in widget.ranks) '${r['id']}': asInt(r['order'])};
    final rankNames = [
      for (final r in [...widget.ranks]..sort((a, b) => asInt(a['order']).compareTo(asInt(b['order'])))) '${r['id']}',
    ];
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final m in widget.members)
        if ((_rank == null || '${m['rank']}' == _rank) && (q.isEmpty || '${m['name']}'.toLowerCase().contains(q))) m,
    ]..sort((a, b) {
        final byRank = (order['${a['rank']}'] ?? 99).compareTo(order['${b['rank']}'] ?? 99);
        return byRank != 0 ? byRank : '${a['name']}'.toLowerCase().compareTo('${b['name']}'.toLowerCase());
      });
    String joined(Json m) {
      final j = '${m['joined'] ?? ''}';
      return j.length >= 10 ? j.substring(0, 10) : '';
    }

    Widget head(String label) => Align(
          alignment: Alignment.centerLeft,
          child: Text(label.caps,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.muted)),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: fieldDecoration(s.t('members_search', {'n': widget.members.length}),
                    prefixIcon: Icon(Icons.search, color: AppColors.muted)),
              ),
            ),
            ChoiceChip(
                label: Text(s.t('all')), selected: _rank == null, onSelected: (_) => setState(() => _rank = null)),
            for (final r in rankNames)
              ChoiceChip(label: Text(r), selected: _rank == r, onSelected: (_) => setState(() => _rank = r)),
          ],
        ),
        const SizedBox(height: 12),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                color: Color.alphaBlend(AppColors.track.withValues(alpha: 0.5), AppColors.surface),
                child: Row(
                  children: [
                    Expanded(child: head(s.t('member'))),
                    SizedBox(width: 200, child: head(s.t('rank'))),
                    SizedBox(width: 130, child: head(s.t('joined'))),
                  ],
                ),
              ),
              for (final m in shown)
                Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: icons['${m['rank']}'] == null
                                  ? Icon(Icons.person_outline, size: 18, color: AppColors.muted)
                                  : CachedIcon(url: icons['${m['rank']}']!, fit: BoxFit.contain),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('${m['name'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                          width: 200,
                          child: Text('${m['rank'] ?? ''}', style: TextStyle(fontSize: 13, color: AppColors.muted))),
                      SizedBox(
                          width: 130, child: Text(joined(m), style: TextStyle(fontSize: 13, color: AppColors.muted))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (widget.teams.isNotEmpty) ...[
          const SizedBox(height: 22),
          SectionHeader(title: s.t('pvp_teams'), trailing: '${widget.teams.length}'),
          const SizedBox(height: 10),
          CardWrap(
            minWidth: 300,
            gap: 12,
            children: [
              for (final t in widget.teams)
                Panel(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(child: Text('${t['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text(
                        s.t('wins_losses', {
                          'w': asInt((t['aggregate'] as Map?)?['wins']),
                          'l': asInt((t['aggregate'] as Map?)?['losses']),
                        }),
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// what the guild hall has built and what sits in its storage, side by side
class _UpgradesSite extends ConsumerWidget {
  const _UpgradesSite({required this.built, required this.storage});

  final List<GuildUpgradeRow> built;
  final List<GuildUpgradeRow> storage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    Widget stat(String label, String value) => Expanded(
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
              ],
            ),
          ),
        );
    final byType = <String, List<GuildUpgradeRow>>{};
    for (final u in built) {
      byType.putIfAbsent(u.type, () => []).add(u);
    }
    final built0 = Panel(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('built_upgrades'), style: display(18)),
          for (final e in byType.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Kicker(titleCase(e.key.isEmpty ? '-' : e.key).caps),
            ),
            for (final u in e.value)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
                child: Row(
                  children: [
                    ItemIcon(url: u.icon, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(u.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    Pill(s.t('upgrade_built')),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
    final storage0 = Panel(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.t('hall_storage'), style: display(18))),
              Text('${storage.length}', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 6),
          if (storage.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(s.t('nothing_here'), style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
          for (final u in storage)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
              child: Row(
                children: [
                  ItemIcon(url: u.icon, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(u.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
                  Text(fmtInt(u.count), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            stat(s.t('built_upgrades'), '${built.length}'),
            const SizedBox(width: 14),
            stat(s.t('hall_storage'), fmtInt(storage.fold<int>(0, (n, u) => n + u.count))),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          if (box.maxWidth < 800) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [built0, const SizedBox(height: 16), storage0]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(flex: 6, child: built0), const SizedBox(width: 16), Expanded(flex: 5, child: storage0)],
          );
        }),
      ],
    );
  }
}

/// the log grouped by day, with the kinds of entry to look at
class _LogSite extends ConsumerStatefulWidget {
  const _LogSite({required this.entries});

  final List<Json> entries;

  @override
  ConsumerState<_LogSite> createState() => _LogSiteState();
}

class _LogSiteState extends ConsumerState<_LogSite> {
  String? _type;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final types = {for (final e in widget.entries) '${e['type'] ?? ''}'}.where((t) => t.isNotEmpty).toList()..sort();
    final shown = [
      for (final e in widget.entries)
        if (_type == null || '${e['type']}' == _type) e
    ];
    final days = <String, List<Json>>{};
    for (final e in shown) {
      days.putIfAbsent(_logDay(e), () => []).add(e);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
                label: Text(s.t('all')), selected: _type == null, onSelected: (_) => setState(() => _type = null)),
            for (final t in types)
              ChoiceChip(label: Text(titleCase(t)), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
            Text(s.t('log_last_n', {'n': widget.entries.length}),
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ),
        for (final d in days.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 18, 2, 6),
            child: Kicker(d.key.caps),
          ),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < d.value.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: i == 0 ? null : BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(_logLine(d.value[i]),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
                        ),
                        Text(
                            '${d.value[i]['time'] ?? ''}'.length >= 16 ? '${d.value[i]['time']}'.substring(11, 16) : '',
                            style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

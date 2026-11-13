part of '../progression_screen.dart';

/// where the account sits in the current league, when it played one
class _SeasonStanding extends ConsumerWidget {
  const _SeasonStanding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final standing = ref.watch(pvpStandingProvider).valueOrNull;
    if (standing == null) return const SizedBox.shrink();

    final title = standing.divisionName.isEmpty
        ? standing.seasonName
        : '${standing.divisionName} · ${s.t('tier_n', {'n': standing.tier})}';
    if (title.trim().isEmpty) return const SizedBox.shrink();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(s.t('league').caps),
          const SizedBox(height: 6),
          Text(title, style: display(16)),
          if (standing.seasonName.isNotEmpty && standing.divisionName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(standing.seasonName, style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (standing.rating > 0) Expanded(child: StatTile(label: s.t('rating'), value: fmtInt(standing.rating))),
              Expanded(child: StatTile(label: s.t('pips'), value: fmtInt(standing.points))),
            ],
          ),
        ],
      ),
    );
  }
}

class _PvpLink extends StatelessWidget {
  const _PvpLink({required this.icon, required this.label, required this.page});

  final IconData icon;
  final String label;
  final Widget Function() page;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page())),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _PvpTab extends ConsumerWidget {
  const _PvpTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final stats = ref.watch(pvpStatsProvider);
    final account = ref.watch(accountProvider).valueOrNull;
    final wvw = account?['wvw'];
    final wvwRank = wvw is Map ? asInt(wvw['rank']) : asInt(account?['wvw_rank']);

    String ratio(Json? agg) {
      final wins = asInt(agg?['wins']);
      final losses = asInt(agg?['losses']);
      final total = wins + losses;
      if (total == 0) return '-';
      return '${(wins / total * 100).round()}%';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        AsyncView<Json>(
          permission: 'pvp',
          value: stats,
          onRetry: () => ref.invalidate(pvpStatsProvider),
          builder: (data) {
            final aggregate =
                data['aggregate'] is Map ? Map<String, dynamic>.from(data['aggregate'] as Map) : <String, dynamic>{};
            final professions = data['professions'] is Map
                ? Map<String, dynamic>.from(data['professions'] as Map)
                : <String, dynamic>{};
            final tier = rankTierFor(
              ref.watch(pvpRanksProvider).valueOrNull ?? const [],
              asInt(data['pvp_rank']),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Panel(
                  child: Column(
                    children: [
                      if (tier != null) ...[
                        Row(
                          children: [
                            ItemIcon(url: tier.icon, rarity: 'Exotic', size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tier.name, style: display(18)),
                                  Text(s.t('rank_n', {'n': asInt(data['pvp_rank'])}),
                                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          Expanded(child: StatTile(label: s.t('pvp_rank'), value: '${asInt(data['pvp_rank'])}')),
                          Expanded(child: StatTile(label: s.t('win_rate'), value: ratio(aggregate))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                              child: StatTile(
                                  label: s.t('pvp_rank_points'), value: fmtInt(asInt(data['pvp_rank_points'])))),
                          // rollovers only mean something once there has been one
                          Expanded(
                            child: asInt(data['pvp_rank_rollovers']) > 0
                                ? StatTile(
                                    label: s.t('pvp_rollovers'),
                                    value: fmtInt(asInt(data['pvp_rank_rollovers'])),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: StatTile(label: s.t('wins'), value: fmtInt(asInt(aggregate['wins'])))),
                          Expanded(
                            child: StatTile(label: s.t('losses'), value: fmtInt(asInt(aggregate['losses']))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Ladders(data, ratio: ratio),
                const _SeasonStanding(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PvpLink(
                        icon: Icons.history,
                        label: s.t('match_history'),
                        page: () => const PvpMatchesScreen(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PvpLink(
                        icon: Icons.shield_moon_outlined,
                        label: s.t('amulets'),
                        page: () => const PvpAmuletsScreen(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _PvpLink(
                  icon: Icons.leaderboard_outlined,
                  label: s.t('leaderboard'),
                  page: () => const PvpLadderScreen(),
                ),
                const SizedBox(height: 22),
                SectionHeader(title: s.t('per_profession')),
                const SizedBox(height: 10),
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      for (final entry in professions.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: professionColor(titleCase(entry.key)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(titleCase(entry.key),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              ),
                              if (entry.value is Map)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Text(
                                    '${fmtInt(asInt((entry.value as Map)['wins']))} – ${fmtInt(asInt((entry.value as Map)['losses']))}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                        fontFeatures: const [FontFeature.tabularFigures()]),
                                  ),
                                ),
                              Text(
                                ratio(entry.value is Map ? Map<String, dynamic>.from(entry.value as Map) : null),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold),
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
        ),
        const SizedBox(height: 22),
        SectionHeader(title: s.t('wvw')),
        const SizedBox(height: 10),
        Panel(
          child: Row(
            children: [
              Expanded(
                child: Text(s.t('wvw_rank'), style: TextStyle(fontSize: 14, color: AppColors.textSoft)),
              ),
              Text(wvwRank > 0 ? fmtInt(wvwRank) : '-',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
            ],
          ),
        ),
      ],
    );
  }
}

/// the ranked and the unranked ladder apart, and the matches left early or without an opponent, which the totals hide
class _Ladders extends ConsumerWidget {
  const _Ladders(this.data, {required this.ratio});

  final Json data;
  final String Function(Json?) ratio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final ladders = data['ladders'] is Map ? Map<String, dynamic>.from(data['ladders'] as Map) : <String, dynamic>{};
    final aggregate =
        data['aggregate'] is Map ? Map<String, dynamic>.from(data['aggregate'] as Map) : <String, dynamic>{};
    Json? ladder(String key) => ladders[key] is Map ? Map<String, dynamic>.from(ladders[key] as Map) : null;
    final rows = [('ladder_ranked', ladder('ranked')), ('ladder_unranked', ladder('unranked'))];
    final left = [
      ('pvp_desertions', asInt(aggregate['desertions'])),
      ('pvp_forfeits', asInt(aggregate['forfeits'])),
      ('pvp_byes', asInt(aggregate['byes'])),
    ].where((e) => e.$2 > 0).toList();
    if (ladders.isEmpty && left.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker(s.t('pvp_ladders').caps),
            const SizedBox(height: 8),
            for (final (key, l) in rows)
              if (l != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(s.t(key), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                      Text('${fmtInt(asInt(l['wins']))} – ${fmtInt(asInt(l['losses']))}',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                              fontFeatures: const [FontFeature.tabularFigures()])),
                      SizedBox(
                        width: 54,
                        child: Text(ratio(l),
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold)),
                      ),
                    ],
                  ),
                ),
            if (left.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                children: [
                  for (final (key, n) in left)
                    Text('${s.t(key)} $n', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

part of '../character_progress.dart';

class _HeroPoints extends ConsumerWidget {
  const _HeroPoints({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AsyncView<dynamic>(
      value: ref.watch(characterPartProvider('$name|heropoints')),
      permission: 'progression',
      onRetry: () => ref.invalidate(characterPartProvider('$name|heropoints')),
      builder: (raw) {
        final count = raw is List ? raw.length : 0;
        // the game's api has returned an empty list for every character since End of Dragons:
        // a zero would read as a character with no hero challenges done
        if (count == 0) {
          return Panel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.stars_outlined, color: AppColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s.t('progress_hero_unavailable'),
                      style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted)),
                ),
              ],
            ),
          );
        }
        return Panel(
          child: Row(
            children: [
              Icon(Icons.stars_outlined, color: AppColors.gold),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(s.t('hero_challenges'), style: TextStyle(fontSize: 14, color: AppColors.textSoft))),
              Text(fmtInt(count),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
            ],
          ),
        );
      },
    );
  }
}

class _Training extends ConsumerWidget {
  const _Training({required this.name, required this.profession});

  final String name;
  final String profession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final trees = <String, String>{};
    final prof = ref.watch(professionProvider(profession)).valueOrNull;
    for (final t in (prof?['training'] as List?) ?? const []) {
      if (t is Map) trees['${t['id']}'] = '${t['name'] ?? ''}';
    }
    return AsyncView<dynamic>(
      value: ref.watch(characterPartProvider('$name|training')),
      permission: 'builds',
      onRetry: () => ref.invalidate(characterPartProvider('$name|training')),
      builder: (raw) {
        final rows = [
          for (final t in ((raw is Map ? raw['training'] : raw) as List?) ?? const [])
            if (t is Map) Map<String, dynamic>.from(t),
        ]..sort((a, b) => (a['done'] == true ? 1 : 0).compareTo(b['done'] == true ? 1 : 0));
        // the game's api returns nothing for the training of characters, which is not a character without any
        if (rows.isEmpty) {
          return Panel(
            child: Text(s.t('progress_training_unavailable'),
                style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted)),
          );
        }
        final done = rows.where((r) => r['done'] == true).length;
        return Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('trees_done', {'n': done, 'm': rows.length}),
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(r['done'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 16, color: r['done'] == true ? AppColors.green : AppColors.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(trees['${r['id']}'] ?? '#${r['id']}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Text('${asInt(r['spent'])}', style: TextStyle(fontSize: 12, color: AppColors.gold)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// one story of the story journal, with how many of its quests the character has done
typedef StoryRow = ({String name, int done, int total});

/// the stories of one season, in the order the game lists them. a story with no quest
/// in the game's quest list has a total of nought: the game never gave one to compare with
List<StoryRow> seasonStories(
    String seasonId, Map<String, Json> quests, Map<String, Json> stories, Set<String> completed) {
  final mine = [
    for (final e in stories.entries)
      if ('${e.value['season']}' == seasonId) e,
  ]..sort((a, b) {
      final byOrder = asInt(a.value['order']).compareTo(asInt(b.value['order']));
      return byOrder != 0 ? byOrder : asInt(a.key).compareTo(asInt(b.key));
    });
  return [
    for (final e in mine)
      (
        name: '${e.value['name'] ?? '#${e.key}'}',
        done: quests.values.where((q) => '${q['story']}' == e.key && completed.contains('${q['id']}')).length,
        total: quests.values.where((q) => '${q['story']}' == e.key).length,
      ),
  ];
}

/// the quests the game recorded for the character that are not in its list of story quests,
/// so there is nothing to count them against
int unmatchedQuests(Map<String, Json> quests, Set<String> completed) =>
    completed.where((id) => !quests.containsKey(id)).length;

/// completed story quests, counted per season of the story journal
class _Story extends ConsumerWidget {
  const _Story({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final quests = ref.watch(questsProvider).valueOrNull;
    final stories = ref.watch(storiesProvider).valueOrNull;
    final seasons = ref.watch(storySeasonsProvider).valueOrNull;
    return AsyncView<dynamic>(
      value: ref.watch(characterPartProvider('$name|quests')),
      permission: 'progression',
      onRetry: () => ref.invalidate(characterPartProvider('$name|quests')),
      builder: (raw) {
        if (quests == null || stories == null || seasons == null) {
          return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
        }
        final completed = {for (final q in (raw as List?) ?? const []) '$q'};
        // season id -> (done, total)
        final perSeason = <String, (int, int)>{};
        for (final q in quests.values) {
          final season = '${stories['${q['story']}']?['season'] ?? ''}';
          if (season.isEmpty) continue;
          final (done, total) = perSeason[season] ?? (0, 0);
          perSeason[season] = (done + (completed.contains('${q['id']}') ? 1 : 0), total + 1);
        }
        return Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (final season in seasons)
                if (perSeason['${season['id']}'] != null)
                  InkWell(
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      backgroundColor: AppColors.surface,
                      builder: (_) => _SeasonSheet(
                        title: '${season['name'] ?? ''}',
                        rows: seasonStories('${season['id']}', quests, stories, completed),
                        unmatched: unmatchedQuests(quests, completed),
                        s: s,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Builder(builder: (_) {
                        final (done, total) = perSeason['${season['id']}']!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text('${season['name'] ?? ''}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                ),
                                Text('$done/$total', style: TextStyle(fontSize: 12, color: AppColors.gold)),
                                Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Bar(
                                value: total == 0 ? 0 : done / total,
                                color: done >= total ? AppColors.green : AppColors.gold),
                          ],
                        );
                      }),
                    ),
                  ),
              if (perSeason.isEmpty) EmptyNote(s.t('nothing_here'), center: false),
            ],
          ),
        );
      },
    );
  }
}

class _Sab extends ConsumerWidget {
  const _Sab({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AsyncView<dynamic>(
      value: ref.watch(characterPartProvider('$name|sab')),
      permission: 'progression',
      onRetry: () => ref.invalidate(characterPartProvider('$name|sab')),
      builder: (raw) {
        final data = raw is Map ? raw : const {};
        final zones = ((data['zones'] as List?) ?? const []).whereType<Map>().toList();
        List<String> names(String key) => [
              for (final u in (data[key] as List?) ?? const [])
                if (u is Map) titleCase('${u['name'] ?? u['id']}'.replaceAll('_', ' ')),
            ];
        final unlocks = names('unlocks');
        final songs = names('songs');
        final modes = <String, int>{};
        for (final z in zones) {
          final mode = '${z['mode'] ?? ''}';
          modes[mode] = (modes[mode] ?? 0) + 1;
        }
        if (zones.isEmpty && unlocks.isEmpty && songs.isEmpty) {
          return EmptyNote(s.t('nothing_here'), center: false);
        }
        return Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('sab_zones', {'n': zones.length}),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in modes.entries) Pill('${titleCase(e.key)} · ${e.value}'),
              ]),
              if (unlocks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Kicker(s.t('sab_unlocks').toUpperCase()),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final u in unlocks) Pill(u)]),
              ],
              if (songs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Kicker(s.t('sab_songs').toUpperCase()),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final u in songs) Pill(u)]),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// the biography answers picked at character creation
class _Backstory extends ConsumerWidget {
  const _Backstory({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final answers = ref.watch(backstoryAnswersProvider).valueOrNull;
    final questions = ref.watch(backstoryQuestionsProvider).valueOrNull;
    return AsyncView<dynamic>(
      value: ref.watch(characterPartProvider('$name|backstory')),
      permission: 'characters',
      onRetry: () => ref.invalidate(characterPartProvider('$name|backstory')),
      builder: (raw) {
        final ids = [for (final a in ((raw is Map ? raw['backstory'] : raw) as List?) ?? const []) '$a'];
        if (ids.isEmpty || answers == null || questions == null) {
          return EmptyNote(s.t('nothing_here'), center: false);
        }
        return Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final id in ids)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${questions['${answers[id]?['question']}']?['title'] ?? ''}',
                          style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      const SizedBox(height: 2),
                      Text('${answers[id]?['title'] ?? id}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

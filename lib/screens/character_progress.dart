import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/characters.dart';
import '../state/reference.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

/// hero points, training, story journal, super adventure box and backstory
/// of one character, each section loads on its own
class CharacterProgressTab extends ConsumerWidget {
  const CharacterProgressTab({super.key, required this.name, required this.profession});

  final String name;
  final String profession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _HeroPoints(name: name),
        const SizedBox(height: 22),
        SectionHeader(title: s.t('training')),
        const SizedBox(height: 10),
        _Training(name: name, profession: profession),
        const SizedBox(height: 22),
        SectionHeader(title: s.t('story_journal')),
        const SizedBox(height: 10),
        _Story(name: name),
        const SizedBox(height: 22),
        SectionHeader(title: s.t('super_adventure_box')),
        const SizedBox(height: 10),
        _Sab(name: name),
        const SizedBox(height: 22),
        SectionHeader(title: s.t('backstory')),
        const SizedBox(height: 10),
        _Backstory(name: name),
      ],
    );
  }
}

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
      builder: (raw) => Panel(
        child: Row(
          children: [
            const Icon(Icons.stars_outlined, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(child: Text(s.t('hero_challenges'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft))),
            Text(fmtInt(raw is List ? raw.length : 0),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
          ],
        ),
      ),
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
        if (rows.isEmpty) return Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted));
        final done = rows.where((r) => r['done'] == true).length;
        return Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('trees_done', {'n': done, 'm': rows.length}),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
                      Text('${asInt(r['spent'])}', style: const TextStyle(fontSize: 12, color: AppColors.gold)),
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
                  Padding(
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
                              Text('$done/$total', style: const TextStyle(fontSize: 12, color: AppColors.gold)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Bar(value: total == 0 ? 0 : done / total, color: done >= total ? AppColors.green : AppColors.gold),
                        ],
                      );
                    }),
                  ),
              if (perSeason.isEmpty) Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted)),
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
          return Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted));
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
          return Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted));
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
                          style: const TextStyle(fontSize: 11, color: AppColors.muted)),
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

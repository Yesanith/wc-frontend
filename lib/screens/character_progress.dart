import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/characters.dart';
import '../state/reference.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

part 'character_progress/sections.dart';

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
        const SizedBox(height: 6),
        Text(s.t('story_note'), style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.hint)),
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

/// the stories of one season of the journal, each with how many of its quests are done,
/// to compare with what the game shows
class _SeasonSheet extends StatelessWidget {
  const _SeasonSheet({required this.title, required this.rows, required this.unmatched, required this.s});

  final String title;
  final List<StoryRow> rows;
  final int unmatched;
  final S s;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(
                        r.total > 0 && r.done >= r.total
                            ? Icons.check_circle
                            : r.done > 0
                                ? Icons.timelapse
                                : Icons.radio_button_unchecked,
                        size: 16,
                        color: r.total > 0 && r.done >= r.total
                            ? AppColors.green
                            : r.done > 0
                                ? AppColors.gold
                                : AppColors.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r.name, style: const TextStyle(fontSize: 13))),
                      Text(r.total == 0 ? '–' : '${r.done}/${r.total}',
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (unmatched > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Text(s.t('story_unmatched', {'n': unmatched}),
                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.hint)),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/pvp.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

/// the matches the api still remembers, which is only the most recent handful
class PvpMatchesScreen extends ConsumerWidget {
  const PvpMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final games = ref.watch(pvpGamesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('match_history'), style: display(20)),
      ),
      body: AsyncView<List<PvpGame>>(
        permission: 'pvp',
        value: games,
        onRetry: () => ref.invalidate(pvpGamesProvider),
        builder: (list) {
          if (list.isEmpty) {
            return Center(child: Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted)));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(s.t('match_history_note'),
                  style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
              const SizedBox(height: 14),
              for (final game in list) ...[
                _MatchCard(game),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard(this.game);

  final PvpGame game;

  @override
  Widget build(BuildContext context) {
    final colour = game.won ? AppColors.green : AppColors.red;
    final rating = game.ratingChange;

    return Panel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 40,
            decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game.mapName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  [
                    game.profession,
                    if (game.ratingType.isNotEmpty) game.ratingType,
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: professionColor(game.profession)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${game.ownScore} – ${game.otherScore}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colour)),
              if (rating != 0)
                Text(rating > 0 ? '+$rating' : '$rating',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// the fixed attribute spreads pvp builds pick from
class PvpAmuletsScreen extends ConsumerWidget {
  const PvpAmuletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final amulets = ref.watch(pvpAmuletsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('amulets'), style: display(20)),
      ),
      body: AsyncView<List<PvpAmulet>>(
        value: amulets,
        onRetry: () => ref.invalidate(pvpAmuletsProvider),
        builder: (list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final a = list[i];
            return Panel(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ItemIcon(url: a.icon, rarity: 'Exotic', size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in a.attributes.entries) Pill('${e.key} +${fmtInt(e.value)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
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
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('match_history')),
      ),
      body: AsyncView<List<PvpGame>>(
        permission: 'pvp',
        value: games,
        onRetry: () => ref.invalidate(pvpGamesProvider),
        builder: (list) {
          if (list.isEmpty) {
            return EmptyNote(s.t('nothing_here'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(s.t('match_history_note'), style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
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
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('amulets')),
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

/// every board of every league season: the ladder, and the legendary and
/// guild boards older seasons kept, per region
class PvpLadderScreen extends ConsumerStatefulWidget {
  const PvpLadderScreen({super.key});

  @override
  ConsumerState<PvpLadderScreen> createState() => _PvpLadderScreenState();
}

class _PvpLadderScreenState extends ConsumerState<PvpLadderScreen> {
  String _region = 'eu';
  String? _season;
  String? _board;

  String _boardLabel(S s, String board) => switch (board) {
        'ladder' => s.t('board_ladder'),
        'legendary' => s.t('board_legendary'),
        'guild' => s.t('board_guild'),
        _ => titleCase(board),
      };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final standing = ref.watch(pvpStandingProvider).valueOrNull;
    final seasons = ref.watch(pvpSeasonsProvider);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('leaderboard')),
      ),
      body: AsyncView<List<Json>>(
        value: seasons,
        onRetry: () => ref.invalidate(pvpSeasonsProvider),
        builder: (all) {
          if (all.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(s.t('no_season'), style: TextStyle(color: AppColors.muted)),
            );
          }
          // the season the account played last, else the newest one
          final ids = [for (final season in all) '${season['id']}'];
          final seasonId = _season != null && ids.contains(_season)
              ? _season!
              : (standing != null && ids.contains(standing.seasonId) ? standing.seasonId : ids.first);
          final boards = ref.watch(pvpBoardsProvider(seasonId));
          final boardList = boards.valueOrNull ?? const <String>[];
          final board = _board != null && boardList.contains(_board) ? _board! : boardList.firstOrNull;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: InputDecorator(
                  decoration: fieldDecoration(s.t('season')),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: seasonId,
                      isExpanded: true,
                      isDense: true,
                      dropdownColor: AppColors.surface,
                      items: [
                        for (final season in all)
                          DropdownMenuItem(
                            value: '${season['id']}',
                            child: Text('${season['name'] ?? season['id']}', overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _season = v;
                        _board = null;
                      }),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                  children: [
                    for (final r in const ['eu', 'na']) ...[
                      ChoiceChip(
                        label: Text(r.toUpperCase()),
                        selected: _region == r,
                        onSelected: (_) => setState(() => _region = r),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (boardList.length > 1) ...[
                      const SizedBox(width: 8),
                      for (final b in boardList) ...[
                        ChoiceChip(
                          label: Text(_boardLabel(s, b)),
                          selected: board == b,
                          onSelected: (_) => setState(() => _board = b),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ],
                ),
              ),
              Expanded(
                child: boards.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : board == null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(s.t('no_leaderboard'), style: TextStyle(color: AppColors.muted)),
                          )
                        : _BoardList(key: ValueKey('$seasonId|$board|$_region'), boardKey: '$seasonId|$board|$_region'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BoardList extends ConsumerWidget {
  const _BoardList({super.key, required this.boardKey});

  final String boardKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AsyncView<List<BoardRow>>(
      value: ref.watch(pvpLeaderboardProvider(boardKey)),
      onRetry: () => ref.invalidate(pvpLeaderboardProvider(boardKey)),
      builder: (rows) {
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyNote(s.t('no_leaderboard')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: rows.length,
          separatorBuilder: (_, __) => Divider(color: AppColors.track, height: 1),
          itemBuilder: (context, i) {
            final r = rows[i];
            final main = r.scores.isEmpty ? null : r.scores.first;
            final rest = r.scores.skip(1).where((sc) => sc.$1.isNotEmpty).toList();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text('${r.rank}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.gold)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        if (rest.isNotEmpty)
                          Text(
                            rest.map((sc) => '${sc.$1} ${fmtInt(sc.$2)}').join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                      ],
                    ),
                  ),
                  if (main != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(fmtInt(main.$2), style: TextStyle(fontSize: 13, color: AppColors.textSoft)),
                        if (main.$1.isNotEmpty) Text(main.$1, style: TextStyle(fontSize: 10, color: AppColors.muted)),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

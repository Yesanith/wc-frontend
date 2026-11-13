import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cache.dart';
import '../util.dart';
import 'api.dart';
import 'period_refresh.dart';
import 'settings.dart';

part 'progression/achievements.dart';
part 'progression/instances.dart';
part 'progression/masteries.dart';

/// world bosses, daily crafts and map chests already done today.
/// needs the progression permission, empty when it is missing
final doneTodayProvider = FutureProvider.autoDispose.family<Set<String>, String>((ref, path) async {
  ref.watch(periodRefreshProvider);
  final api = accountApi(ref);
  try {
    return (await api.get('/account/$path') as List).map((e) => '$e').toSet();
  } catch (_) {
    return <String>{};
  }
});

final pvpStatsProvider = FutureProvider<Json>((ref) => accountApi(ref).pvpStats());

// -------------------------------------------------------------------------
// pinned achievements

/// achievements picked to keep an eye on, in the order they were pinned
class PinnedAchievementsNotifier extends Notifier<List<int>> {
  static const _key = 'pinned_achievements';

  @override
  List<int> build() {
    final raw = ref.read(prefsProvider).getStringList(_key) ?? const [];
    return [
      for (final e in raw)
        if ((int.tryParse(e) ?? 0) > 0) int.parse(e),
    ];
  }

  bool contains(int id) => state.contains(id);

  Future<void> toggle(int id) => replaceAll(state.contains(id) ? state.where((e) => e != id).toList() : [...state, id]);

  Future<void> replaceAll(List<int> ids) async {
    state = ids;
    await ref.read(prefsProvider).setStringList(_key, ids.map((e) => '$e').toList());
  }
}

final pinnedAchievementsProvider =
    NotifierProvider<PinnedAchievementsNotifier, List<int>>(PinnedAchievementsNotifier.new);

/// the highest count among an achievement's tiers, which is its goal when
/// the account has not started it yet
int topTierCount(Json? detail) {
  var top = 0;
  for (final t in (detail?['tiers'] as List?) ?? const []) {
    if (t is Map && asInt(t['count']) > top) top = asInt(t['count']);
  }
  return top;
}

/// one achievement's row from its details and the account's progress, which
/// is null when the account has not started it
AchievementRow achievementRowFor(int id, Json? detail, Json? progress) => AchievementRow(
      id,
      detail,
      asInt(progress?['current']),
      progress?['max'] != null ? asInt(progress?['max']) : topTierCount(detail),
      progress?['done'] == true,
      bitsDone: intList(progress?['bits']),
    );

/// the pinned achievements with their progress, in pin order
final pinnedAchievementRowsProvider = FutureProvider<List<AchievementRow>>((ref) async {
  final ids = ref.watch(pinnedAchievementsProvider);
  if (ids.isEmpty) return const [];
  final api = accountApi(ref);
  final details = await api.achievements(ids);
  var progress = const <int, Json>{};
  try {
    progress = {for (final r in await api.accountAchievements()) asInt(r['id']): r};
  } catch (_) {
    // without the progression permission the pins still show, at zero
  }
  return [for (final id in ids) achievementRowFor(id, details[id], progress[id])];
});

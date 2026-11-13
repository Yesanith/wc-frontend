part of '../progression.dart';

class AchievementRow {
  const AchievementRow(this.id, this.detail, this.current, this.max, this.done, {this.bitsDone = const []});
  final int id;

  /// which of the achievement's pieces (the items, minis or skins of a collection) the account has, by their place in the
  /// achievement's list of bits
  final List<int> bitsDone;
  final Json? detail;
  final int current;
  final int max;
  final bool done;

  String get name => (detail?['name'] as String?) ?? 'Achievement #$id';

  /// only repeatable achievements carry a point_cap, everything else adds up
  /// the points of its tiers
  int get points {
    final cap = asInt(detail?['point_cap']);
    if (cap > 0) return cap;
    var sum = 0;
    for (final t in (detail?['tiers'] as List?) ?? const []) {
      if (t is Map) sum += asInt(t['points']);
    }
    return sum;
  }

  double get ratio => max == 0 ? 0 : current / max;
}

/// achievements the account has started but not finished, most complete first
final achievementsProvider = FutureProvider<List<AchievementRow>>((ref) async {
  final api = accountApi(ref);
  final rows = await api.accountAchievements();
  final started = [
    for (final r in rows)
      if (r['done'] != true && asInt(r['current']) > 0) r,
  ];
  started.sort((a, b) {
    final ra = asInt(a['max']) == 0 ? 0.0 : asInt(a['current']) / asInt(a['max']);
    final rb = asInt(b['max']) == 0 ? 0.0 : asInt(b['current']) / asInt(b['max']);
    return rb.compareTo(ra);
  });
  final top = started.take(150).toList();
  final details = await api.achievements(top.map((r) => asInt(r['id'])));
  return [
    for (final r in top)
      AchievementRow(
        asInt(r['id']),
        details[asInt(r['id'])],
        asInt(r['current']),
        asInt(r['max']),
        r['done'] == true,
        bitsDone: intList(r['bits']),
      ),
  ];
});

class AchievementSummary {
  const AchievementSummary(this.done, this.inProgress);

  final int done;

  /// started but not finished. the in progress list is capped for display,
  /// this is the real count
  final int inProgress;
}

/// both counts off the one account call the tab already makes
final achievementSummaryProvider = FutureProvider<AchievementSummary>((ref) async {
  final rows = await accountApi(ref).accountAchievements();
  var done = 0;
  var started = 0;
  for (final r in rows) {
    if (r['done'] == true) {
      done++;
    } else if (asInt(r['current']) > 0) {
      started++;
    }
  }
  return AchievementSummary(done, started);
});

class AchievementCategory {
  const AchievementCategory(this.id, this.name, this.icon, this.achievementIds);
  final int id;
  final String name;
  final String? icon;
  final List<int> achievementIds;
}

class AchievementGroup {
  const AchievementGroup(this.id, this.name, this.categories);
  final String id;
  final String name;
  final List<AchievementCategory> categories;

  int get achievementCount => categories.fold<int>(0, (n, c) => n + c.achievementIds.length);
}

/// the whole achievement catalogue, groups in game order with their
/// categories. static data, so it lives on disk for a month
final achievementCatalogueProvider = FutureProvider<List<AchievementGroup>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final lang = ref.watch(langProvider);

  final groupRows = await cachedList(
    cache,
    'ach_groups_${lang.apiLang}',
    'rows',
    () async => api.details('/achievements/groups', await api.idList('/achievements/groups')),
  );
  final categoryRows = await cachedList(
    cache,
    'ach_categories_${lang.apiLang}',
    'rows',
    () async => api.details('/achievements/categories', await api.idList('/achievements/categories')),
  );

  final byId = <int, AchievementCategory>{};
  for (final raw in categoryRows.whereType<Map>()) {
    final c = Map<String, dynamic>.from(raw);
    final id = asInt(c['id']);
    byId[id] = AchievementCategory(
      id,
      '${c['name'] ?? ''}',
      c['icon'] as String?,
      // entries are {"id": n} objects, not bare ids
      [
        for (final a in (c['achievements'] as List?) ?? const []) asInt(a is Map ? a['id'] : a),
      ],
    );
  }

  final groups = <AchievementGroup>[];
  for (final raw in groupRows.whereType<Map>()) {
    final g = Map<String, dynamic>.from(raw);
    final categories = [
      for (final cid in (g['categories'] as List?) ?? const [])
        if (byId[asInt(cid)] != null) byId[asInt(cid)]!,
    ];
    if (categories.isEmpty) continue;
    groups.add(AchievementGroup('${g['id']}', '${g['name'] ?? ''}', categories));
  }
  groups.sort((a, b) => a.name.compareTo(b.name));
  return groups;
});

/// one category's achievements with this account's progress on each
final categoryAchievementsProvider = FutureProvider.family<List<AchievementRow>, int>((ref, categoryId) async {
  final api = accountApi(ref);
  final groups = await ref.watch(achievementCatalogueProvider.future);

  var ids = const <int>[];
  for (final g in groups) {
    for (final c in g.categories) {
      if (c.id == categoryId) ids = c.achievementIds;
    }
  }
  if (ids.isEmpty) return const [];

  final details = await api.achievements(ids);
  var progress = const <int, Json>{};
  try {
    progress = {for (final r in await api.accountAchievements()) asInt(r['id']): r};
  } catch (_) {
    // no progression permission: the catalogue still reads fine without it
  }

  return [
    for (final id in ids)
      AchievementRow(
        id,
        details[id],
        asInt(progress[id]?['current']),
        // without account progress the target is the last tier's count
        progress[id]?['max'] != null ? asInt(progress[id]?['max']) : _topTier(details[id]),
        progress[id]?['done'] == true,
        bitsDone: intList(progress[id]?['bits']),
      ),
  ];
});

/// the count the final tier asks for, which is what finishing it takes
int _topTier(Json? detail) {
  var top = 0;
  for (final t in (detail?['tiers'] as List?) ?? const []) {
    if (t is Map && asInt(t['count']) > top) top = asInt(t['count']);
  }
  return top;
}

/// how many achievements the game has, so the completed count has something
/// to sit against. the id list only changes with a patch
final achievementTotalProvider = FutureProvider<int>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final ids = await cachedList(cache, 'achievement_ids', 'ids', () => api.idList('/achievements'));
  return ids.length;
});

/// one piece of an achievement that is a collection: an item, a mini, a skin, or a line of text
class AchievementBit {
  const AchievementBit(this.kind, this.name, this.icon);

  final String kind;
  final String name;
  final String? icon;
}

/// one reward of an achievement: coins, an item, a title or a mastery point
class AchievementReward {
  const AchievementReward(this.kind, this.label, {this.icon, this.copper = 0});

  final String kind;
  final String label;
  final String? icon;
  final int copper;
}

class AchievementExtras {
  const AchievementExtras(this.bits, this.rewards);

  final List<AchievementBit> bits;
  final List<AchievementReward> rewards;
}

/// the pieces and the rewards of an achievement with their names, which the achievement itself only has as ids
final achievementExtrasProvider = FutureProvider.autoDispose.family<AchievementExtras, int>((ref, id) async {
  final api = accountApi(ref);
  final detail = (await api.achievements([id]))[id];
  final bits = [
    for (final b in (detail?['bits'] as List?) ?? const [])
      if (b is Map) Map<String, dynamic>.from(b)
  ];
  final rewards = [
    for (final r in (detail?['rewards'] as List?) ?? const [])
      if (r is Map) Map<String, dynamic>.from(r)
  ];

  List<int> idsOf(List<Json> rows, String type) => [
        for (final r in rows)
          if ('${r['type']}' == type && r['id'] != null) asInt(r['id']),
      ];
  final itemIds = {...idsOf(bits, 'Item'), ...idsOf(rewards, 'Item')};
  final miniIds = idsOf(bits, 'Minipet');
  final skinIds = idsOf(bits, 'Skin');
  final titleIds = idsOf(rewards, 'Title');

  Future<Map<int, Json>> byId(String path, List<int> ids) async {
    if (ids.isEmpty) return const {};
    try {
      return {
        for (final r in await api.details(path, [for (final i in ids) '$i'])) asInt(r['id']): r
      };
    } catch (_) {
      return const {};
    }
  }

  final results = await Future.wait([
    itemIds.isEmpty ? Future.value(<int, Json>{}) : api.items(itemIds),
    byId('/minis', miniIds),
    byId('/skins', skinIds),
    byId('/titles', titleIds),
  ]);
  final items = results[0], minis = results[1], skins = results[2], titles = results[3];

  return AchievementExtras([
    for (final b in bits)
      switch ('${b['type']}') {
        'Item' => AchievementBit(
            'Item', '${items[asInt(b['id'])]?['name'] ?? '#${b['id']}'}', items[asInt(b['id'])]?['icon'] as String?),
        'Minipet' => AchievementBit(
            'Minipet', '${minis[asInt(b['id'])]?['name'] ?? '#${b['id']}'}', minis[asInt(b['id'])]?['icon'] as String?),
        'Skin' => AchievementBit(
            'Skin', '${skins[asInt(b['id'])]?['name'] ?? '#${b['id']}'}', skins[asInt(b['id'])]?['icon'] as String?),
        _ => AchievementBit('Text', '${b['text'] ?? ''}', null),
      },
  ], [
    for (final r in rewards)
      switch ('${r['type']}') {
        'Coins' => AchievementReward('Coins', '', copper: asInt(r['count'])),
        'Item' => AchievementReward(
            'Item',
            [
              if (asInt(r['count']) > 1) '${asInt(r['count'])} × ',
              '${items[asInt(r['id'])]?['name'] ?? '#${r['id']}'}',
            ].join(),
            icon: items[asInt(r['id'])]?['icon'] as String?),
        'Title' => AchievementReward('Title', '${titles[asInt(r['id'])]?['name'] ?? '#${r['id']}'}'),
        'Mastery' => AchievementReward('Mastery', '${r['region'] ?? ''}'),
        _ => AchievementReward('Other', '${r['type']}'),
      },
  ]);
});

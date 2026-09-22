/// world boss rotation in utc, minutes after midnight.
/// taken from the wiki's event timer tables, double check there if something
/// looks off after a patch
/// which release a boss or meta belongs to. the names are proper nouns, so
/// they read the same in every language the app supports
enum Expansion {
  core('Core Tyria'),
  hot('Heart of Thorns'),
  pof('Path of Fire'),
  ibs('Icebrood Saga'),
  eod('End of Dragons'),
  soto('Secrets of the Obscure'),
  jw('Janthir Wilds');

  const Expansion(this.label);

  final String label;
}

class WorldBoss {
  const WorldBoss(
    this.id,
    this.name,
    this.map,
    this.times, {
    this.hardcore = false,
    this.expansion = Expansion.core,
  });

  final String id;
  final String name;
  final String map;
  final List<int> times;
  final bool hardcore;
  final Expansion expansion;
}

/// the releases that actually have an entry, so the filter never shows a
/// chip that would come back empty
List<Expansion> get expansionsWithBosses =>
    [for (final e in Expansion.values) if (worldBosses.any((b) => b.expansion == e)) e];

List<int> _every(int start, int period) => [for (var m = start; m < 1440; m += period) m];

int _t(int h, int m) => h * 60 + m;

final worldBosses = <WorldBoss>[
  WorldBoss('svanir', 'Svanir Shaman Chief', 'Wayfarer Foothills', _every(15, 120)),
  WorldBoss('fire_elemental', 'Fire Elemental', 'Metrica Province', _every(45, 120)),
  WorldBoss('jungle_wurm', 'Great Jungle Wurm', 'Caledon Forest', _every(75, 120)),
  WorldBoss('behemoth', 'Shadow Behemoth', 'Queensdale', _every(105, 120)),
  WorldBoss('taidha', 'Admiral Taidha Covington', 'Bloodtide Coast', _every(0, 180)),
  WorldBoss('megadestroyer', 'Megadestroyer', 'Mount Maelstrom', _every(30, 180)),
  WorldBoss('shatterer', 'The Shatterer', 'Blazeridge Steppes', _every(60, 180)),
  WorldBoss('ulgoth', 'Modniir Ulgoth', 'Harathi Hinterlands', _every(90, 180)),
  WorldBoss('golem', 'Inquest Golem Mark II', 'Mount Maelstrom', _every(120, 180)),
  WorldBoss('jormag', 'Claw of Jormag', 'Frostgorge Sound', _every(150, 180)),
  WorldBoss('tequatl', 'Tequatl the Sunless', 'Sparkfly Fen',
      [_t(0, 0), _t(3, 0), _t(7, 0), _t(11, 30), _t(16, 0), _t(19, 0)],
      hardcore: true),
  WorldBoss('triple_trouble', 'Triple Trouble', 'Bloodtide Coast',
      [_t(1, 0), _t(4, 0), _t(8, 0), _t(12, 30), _t(17, 0), _t(20, 0)],
      hardcore: true),
  WorldBoss('karka_queen', 'Karka Queen', 'Southsun Cove',
      [_t(2, 0), _t(6, 0), _t(10, 30), _t(15, 0), _t(18, 0), _t(23, 0)],
      hardcore: true),
  // the anomaly moves between three maps, every six hours on each
  WorldBoss('ley_line_timberline', 'Ley-Line Anomaly', 'Timberline Falls', _every(_t(0, 20), 360)),
  WorldBoss('ley_line_iron', 'Ley-Line Anomaly', 'Iron Marches', _every(_t(2, 20), 360)),
  WorldBoss('ley_line_gendarran', 'Ley-Line Anomaly', 'Gendarran Fields', _every(_t(4, 20), 360)),

  // expansion metas go here, grouped by release, for example:
  //   WorldBoss('octovine', 'Octovine', 'Auric Basin', [...], expansion: Expansion.hot),
];

/// roughly how long a boss is worth running to after it spawns
const bossWindow = Duration(minutes: 15);

class BossSpawn {
  const BossSpawn(this.boss, this.start);

  final WorldBoss boss;
  final DateTime start;

  bool isActive(DateTime now) => !start.isAfter(now) && now.isBefore(start.add(bossWindow));
}

List<BossSpawn> upcomingSpawns(DateTime now, {Duration ahead = const Duration(hours: 24)}) {
  final utc = now.toUtc();
  final today = DateTime.utc(utc.year, utc.month, utc.day);
  final limit = utc.add(ahead);
  final out = <BossSpawn>[];
  for (final boss in worldBosses) {
    for (final day in const [-1, 0, 1]) {
      for (final minute in boss.times) {
        final start = today.add(Duration(days: day, minutes: minute));
        if (start.add(bossWindow).isAfter(utc) && start.isBefore(limit)) {
          out.add(BossSpawn(boss, start));
        }
      }
    }
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

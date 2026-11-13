/// the fixed schedule of world bosses and map metas, in utc minutes after
/// midnight. everything repeats daily, most of it every two hours. the facts
/// come from the wiki's event timer tables; durations are rough, they only
/// set how long a block looks on the timeline
library;

/// which release a map belongs to. the names are proper nouns, so they read
/// the same in every language the app supports
enum Expansion {
  core('Core Tyria'),
  lws('Living World'),
  hot('Heart of Thorns'),
  pof('Path of Fire'),
  ibs('Icebrood Saga'),
  eod('End of Dragons'),
  soto('Secrets of the Obscure'),
  jw('Janthir Wilds'),
  voe('Visions of Eternity');

  const Expansion(this.label);

  final String label;
}

enum MetaKind { boss, hardBoss, meta }

/// the event of the incursions of the fractals in the open world, whose maps are only where it is held
const fractalIncursionPage = 'Defeat the enemy spawned by the fractal incursion';

class MetaEvent {
  const MetaEvent(this.name, this.times, {this.minutes = 15, this.kind = MetaKind.meta, this.bossId, this.wiki});

  final String name;

  /// the wiki page to open when it is not the one of the event's own name
  final String? wiki;

  /// start times in minutes after midnight utc
  final List<int> times;
  final int minutes;
  final MetaKind kind;

  /// the id /v2/account/worldbosses reports once it was looted today
  final String? bossId;
}

/// what a pin remembers: the boss id where there is one, else map and name
String eventKey(MetaMap map, MetaEvent event) => event.bossId ?? '${map.id}/${event.name}';

class MetaMap {
  const MetaMap(this.id, this.name, this.release, this.events);

  final String id;
  final String name;
  final Expansion release;
  final List<MetaEvent> events;
}

List<int> _every(int start, int period) => [for (var m = start % period; m < 1440; m += period) m];

int _t(int h, int m) => h * 60 + m;

MetaEvent _boss(String name, List<int> times, String id, {bool hard = false, int minutes = 15}) =>
    MetaEvent(name, times, minutes: minutes, kind: hard ? MetaKind.hardBoss : MetaKind.boss, bossId: id);

final metaMaps = <MetaMap>[
  // core world bosses, one row per map
  MetaMap('queensdale', 'Queensdale', Expansion.core, [_boss('Shadow Behemoth', _every(105, 120), 'shadow_behemoth')]),
  MetaMap('wayfarer', 'Wayfarer Foothills', Expansion.core,
      [_boss('Svanir Shaman Chief', _every(15, 120), 'svanir_shaman_chief')]),
  MetaMap('metrica', 'Metrica Province', Expansion.core, [_boss('Fire Elemental', _every(45, 120), 'fire_elemental')]),
  MetaMap(
      'caledon', 'Caledon Forest', Expansion.core, [_boss('Great Jungle Wurm', _every(75, 120), 'great_jungle_wurm')]),
  MetaMap('bloodtide', 'Bloodtide Coast', Expansion.core, [
    _boss('Admiral Taidha Covington', _every(0, 180), 'admiral_taidha_covington'),
    _boss('Triple Trouble', [_t(1, 0), _t(4, 0), _t(8, 0), _t(12, 30), _t(17, 0), _t(20, 0)], 'triple_trouble_wurm',
        hard: true, minutes: 20),
  ]),
  MetaMap('maelstrom', 'Mount Maelstrom', Expansion.core, [
    _boss('Megadestroyer', _every(30, 180), 'megadestroyer'),
    _boss('Inquest Golem Mark II', _every(120, 180), 'inquest_golem_mark_ii'),
  ]),
  MetaMap(
      'blazeridge', 'Blazeridge Steppes', Expansion.core, [_boss('The Shatterer', _every(60, 180), 'the_shatterer')]),
  MetaMap(
      'harathi', 'Harathi Hinterlands', Expansion.core, [_boss('Modniir Ulgoth', _every(90, 180), 'modniir_ulgoth')]),
  MetaMap(
      'frostgorge', 'Frostgorge Sound', Expansion.core, [_boss('Claw of Jormag', _every(150, 180), 'claw_of_jormag')]),
  MetaMap('sparkfly', 'Sparkfly Fen', Expansion.core, [
    _boss(
        'Tequatl the Sunless', [_t(0, 0), _t(3, 0), _t(7, 0), _t(11, 30), _t(16, 0), _t(19, 0)], 'tequatl_the_sunless',
        hard: true),
  ]),
  MetaMap('southsun', 'Southsun Cove', Expansion.core, [
    _boss('Karka Queen', [_t(2, 0), _t(6, 0), _t(10, 30), _t(15, 0), _t(18, 0), _t(23, 0)], 'karka_queen', hard: true),
  ]),
  // the anomaly rotates between three maps, six hours apart on each
  MetaMap('leyline', 'Ley-Line Anomaly', Expansion.core, [
    MetaEvent('Timberline Falls', _every(_t(0, 20), 360), minutes: 20),
    MetaEvent('Iron Marches', _every(_t(2, 20), 360), minutes: 20),
    MetaEvent('Gendarran Fields', _every(_t(4, 20), 360), minutes: 20),
  ]),
  // an incursion from the fractals every hour, in turn on four maps, the wiki's timer has it from midnight
  MetaMap('incursion', 'Fractal Incursion', Expansion.core, [
    MetaEvent('Kessex Hills', _every(0, 240), wiki: fractalIncursionPage),
    MetaEvent('Diessa Plateau', _every(60, 240), wiki: fractalIncursionPage),
    MetaEvent('Brisban Wildlands', _every(120, 240), wiki: fractalIncursionPage),
    MetaEvent('Snowden Drifts', _every(180, 240), wiki: fractalIncursionPage),
  ]),

  // living world
  MetaMap('drytop', 'Dry Top', Expansion.lws, [
    MetaEvent('Crash Site', _every(0, 60), minutes: 40),
    MetaEvent('Sandstorm', _every(40, 60), minutes: 20),
  ]),
  MetaMap('lakedoric', 'Lake Doric', Expansion.lws, [
    MetaEvent("Noran's Homestead", _every(30, 120), minutes: 30),
    MetaEvent("Saidra's Haven", _every(60, 120), minutes: 45),
    MetaEvent('New Loamhurst', _every(105, 120), minutes: 45),
  ]),
  MetaMap('istan', 'Domain of Istan', Expansion.lws, [MetaEvent('Palawadan', _every(105, 120), minutes: 30)]),
  MetaMap('jahai', 'Jahai Bluffs', Expansion.lws, [
    MetaEvent('Escorts', _every(60, 120)),
    MetaEvent('Death-Branded Shatterer', _every(75, 120)),
  ]),
  MetaMap('thunderhead', 'Thunderhead Peaks', Expansion.lws, [
    MetaEvent('The Oil Floes', _every(45, 120)),
    MetaEvent('Thunderhead Keep', _every(105, 120), minutes: 20),
  ]),
  MetaMap('eotn', 'Eye of the North', Expansion.lws, [
    MetaEvent('Twisted Marionette', _every(0, 120), minutes: 20),
    MetaEvent("Battle for Lion's Arch", _every(30, 120), minutes: 20),
    MetaEvent('Dragonstorm', _every(60, 120), minutes: 20),
    MetaEvent('Tower of Nightmares', _every(90, 120), minutes: 20),
  ]),

  // heart of thorns
  MetaMap('verdant', 'Verdant Brink', Expansion.hot, [
    MetaEvent('Night Bosses', _every(10, 120), minutes: 20),
    MetaEvent('Securing Verdant Brink', _every(30, 120), minutes: 75),
    MetaEvent('Night and the Enemy', _every(105, 120), minutes: 25),
  ]),
  MetaMap('auric', 'Auric Basin', Expansion.hot, [
    MetaEvent('Challenges', _every(45, 120)),
    MetaEvent('Octovine', _every(60, 120), minutes: 20),
    MetaEvent('Pylons', _every(90, 120), minutes: 30),
  ]),
  MetaMap('tangled', 'Tangled Depths', Expansion.hot, [
    MetaEvent('Chak Gerent', _every(30, 120), minutes: 20),
    MetaEvent('Outposts', _every(50, 120), minutes: 70),
  ]),
  MetaMap('dragonsstand', "Dragon's Stand", Expansion.hot,
      [MetaEvent('Advancing on the Blighting Towers', _every(90, 120), minutes: 90)]),

  // path of fire
  MetaMap('oasis', 'Crystal Oasis', Expansion.pof, [MetaEvent('Casino Blitz', _every(5, 120), minutes: 16)]),
  MetaMap('highlands', 'Desert Highlands', Expansion.pof, [MetaEvent('Buried Treasure', _every(60, 120), minutes: 20)]),
  MetaMap('riverlands', 'Elon Riverlands', Expansion.pof, [
    MetaEvent('Augury Rock', _every(90, 120), minutes: 25),
    MetaEvent('Doppelganger', _every(115, 120)),
  ]),
  MetaMap('desolation', 'The Desolation', Expansion.pof, [
    MetaEvent('Junundu Rising', _every(30, 60), minutes: 20),
    MetaEvent('Maws of Torment', _every(60, 120), minutes: 20),
  ]),
  MetaMap('vabbi', 'Domain of Vabbi', Expansion.pof, [
    MetaEvent('Forged with Fire', _every(0, 60)),
    MetaEvent("Serpents' Ire", _every(30, 120), minutes: 30),
  ]),

  // icebrood saga
  MetaMap('grothmar', 'Grothmar Valley', Expansion.ibs, [
    MetaEvent('Effigy', _every(10, 120)),
    MetaEvent('Doomlore Shrine', _every(38, 120), minutes: 22),
    MetaEvent('Ooze Pits', _every(65, 120), minutes: 20),
    MetaEvent('Metal Concert', _every(100, 120)),
  ]),
  MetaMap('bjora', 'Bjora Marches', Expansion.ibs, [
    MetaEvent('Shards and Construct', _every(0, 120), minutes: 5),
    MetaEvent('Icebrood Champions', _every(5, 120), minutes: 60),
    _boss('Drakkar', _every(65, 120), 'drakkar', minutes: 35),
    MetaEvent("Defend Jora's Keep", _every(105, 120)),
  ]),

  // end of dragons
  MetaMap(
      'seitung', 'Seitung Province', Expansion.eod, [MetaEvent('Aetherblade Assault', _every(90, 120), minutes: 30)]),
  MetaMap('kaineng', 'New Kaineng City', Expansion.eod, [MetaEvent('Kaineng Blackout', _every(0, 120), minutes: 40)]),
  MetaMap('echovald', 'The Echovald Wilds', Expansion.eod, [
    MetaEvent('Gang War', _every(30, 120), minutes: 35),
    MetaEvent('Aspenwood', _every(100, 120), minutes: 20),
  ]),
  MetaMap('dragonsend', "Dragon's End", Expansion.eod, [
    MetaEvent('Jade Maw', [..._every(5, 120), ..._every(45, 120)]..sort(), minutes: 8),
    MetaEvent('Battle for the Jade Sea', _every(60, 120), minutes: 60),
  ]),

  // secrets of the obscure
  MetaMap('skywatch', 'Skywatch Archipelago', Expansion.soto,
      [MetaEvent("Unlocking the Wizard's Tower", _every(60, 120), minutes: 25)]),
  MetaMap('wizardstower', "Wizard's Tower", Expansion.soto, [
    MetaEvent('Target Practice', _every(60, 120)),
    MetaEvent('Fly by Night', _every(115, 120), minutes: 20),
  ]),
  MetaMap('amnytas', 'Amnytas', Expansion.soto, [MetaEvent('Defense of Amnytas', _every(0, 120), minutes: 25)]),
  MetaMap('nayos', 'Outer Nayos', Expansion.soto, [MetaEvent('Convergence', _every(90, 180), minutes: 20)]),

  // janthir wilds
  MetaMap('syntri', 'Janthir Syntri', Expansion.jw, [
    _boss('Of Mists and Monsters', _every(30, 120), 'mists_and_monsters_titans', minutes: 25),
  ]),
  MetaMap('bava', 'Bava Nisos', Expansion.jw, [MetaEvent('A Titanic Voyage', _every(80, 120), minutes: 25)]),
  MetaMap('balrior', 'Mount Balrior', Expansion.jw, [MetaEvent('Convergence', _every(0, 180), minutes: 20)]),

  // visions of eternity
  MetaMap(
      'shipwreck', 'Shipwreck Strand', Expansion.voe, [MetaEvent('Hammerhart Rumble!', _every(40, 120), minutes: 20)]),
  MetaMap('weald', 'Starlit Weald', Expansion.voe, [MetaEvent('Secrets of the Weald', _every(100, 120), minutes: 20)]),
  MetaMap('garden', "Eternity's Garden", Expansion.voe,
      [MetaEvent('Shackles of the Ancients', _every(75, 120), minutes: 20)]),
  MetaMap(
      'leyspring', 'Leyspring Hollows', Expansion.voe, [MetaEvent('Depths of Cruelty', _every(120, 180), minutes: 20)]),
  MetaMap('nexus', 'Nexus of Eternity', Expansion.voe, [MetaEvent('Convergence', _every(60, 180), minutes: 20)]),
];

/// one concrete run of an event
class Occurrence {
  const Occurrence(this.map, this.event, this.start);

  final MetaMap map;
  final MetaEvent event;
  final DateTime start;

  DateTime get end => start.add(Duration(minutes: event.minutes));

  bool activeAt(DateTime now) => !start.isAfter(now) && end.isAfter(now);

  @override
  bool operator ==(Object other) =>
      other is Occurrence && other.event == event && other.map == map && other.start == start;

  @override
  int get hashCode => Object.hash(map.id, event.name, start);
}

/// every run that overlaps [from, to), sorted by start
List<Occurrence> occurrences(DateTime from, DateTime to, {Iterable<MetaMap>? maps}) {
  final f = from.toUtc();
  final t = to.toUtc();
  final day0 = DateTime.utc(f.year, f.month, f.day);
  final days = t.difference(day0).inDays + 1;
  final out = <Occurrence>[];
  for (final map in maps ?? metaMaps) {
    for (final event in map.events) {
      for (var d = -1; d <= days; d++) {
        for (final minute in event.times) {
          final start = day0.add(Duration(days: d, minutes: minute));
          final o = Occurrence(map, event, start);
          if (o.end.isAfter(f) && start.isBefore(t)) out.add(o);
        }
      }
    }
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// what is on now, then what comes next, for a short list
List<Occurrence> upNext(DateTime now, {int count = 5, bool Function(Occurrence)? where}) {
  final all = occurrences(now, now.add(const Duration(hours: 4)));
  final picked = where == null ? all : all.where(where).toList();
  return picked.take(count).toList();
}

/// world boss rotation in utc, minutes after midnight.
/// taken from the wiki's event timer tables, double check there if something
/// looks off after a patch
/// which release a boss or meta belongs to. the names are proper nouns, so
/// they read the same in every language the app supports
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
List<Expansion> get expansionsWithBosses => [
      for (final e in Expansion.values)
        if (worldBosses.any((b) => b.expansion == e)) e
    ];

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
  WorldBoss('triple_trouble_wurm', 'Triple Trouble', 'Bloodtide Coast',
      [_t(1, 0), _t(4, 0), _t(8, 0), _t(12, 30), _t(17, 0), _t(20, 0)],
      hardcore: true),
  WorldBoss(
      'karka_queen', 'Karka Queen', 'Southsun Cove', [_t(2, 0), _t(6, 0), _t(10, 30), _t(15, 0), _t(18, 0), _t(23, 0)],
      hardcore: true),
  // the anomaly moves between three maps, every six hours on each
  WorldBoss('ley_line_timberline', 'Ley-Line Anomaly', 'Timberline Falls', _every(_t(0, 20), 360)),
  WorldBoss('ley_line_iron', 'Ley-Line Anomaly', 'Iron Marches', _every(_t(2, 20), 360)),
  WorldBoss('ley_line_gendarran', 'Ley-Line Anomaly', 'Gendarran Fields', _every(_t(4, 20), 360)),

  // Heart of Thorns
  WorldBoss(
      'verdant_brink_night_night_and_the_enemy', "Night: Night and the Enemy", "Verdant Brink", _every(_t(1, 45), 120),
      expansion: Expansion.hot),
  WorldBoss('verdant_brink_night_bosses', "Night Bosses", "Verdant Brink", _every(_t(0, 10), 120),
      expansion: Expansion.hot),
  WorldBoss('verdant_brink_day_securing_verdant_brink', "Day: Securing Verdant Brink", "Verdant Brink",
      _every(_t(0, 30), 120),
      expansion: Expansion.hot),
  WorldBoss('auric_basin_defending_tarir_pylons', "Defending Tarir (Pylons)", "Auric Basin", _every(_t(1, 30), 120),
      expansion: Expansion.hot),
  WorldBoss('auric_basin_challenges', "Challenges", "Auric Basin", _every(_t(0, 45), 120), expansion: Expansion.hot),
  WorldBoss('auric_basin_battle_in_tarir_octovine', "Battle in Tarir (Octovine)", "Auric Basin", _every(_t(1, 0), 120),
      expansion: Expansion.hot),
  WorldBoss('tangled_depths_advancing_across_tangled_root', "Advancing Across Tangled Roots (Outposts)",
      "Tangled Depths", _every(_t(0, 50), 120),
      expansion: Expansion.hot),
  WorldBoss('tangled_depths_king_of_the_jungle_chak_geren', "King of the Jungle (Chak Gerent)", "Tangled Depths",
      _every(_t(0, 30), 120),
      expansion: Expansion.hot),
  WorldBoss('dragon_s_stand_start_advancing_on_the_blight', "Start advancing on the Blighting Towers", "Dragon's Stand",
      _every(_t(1, 30), 120),
      expansion: Expansion.hot),

  // Path of Fire
  WorldBoss('crystal_oasis_rounds_1_to_3', "Rounds 1 to 3", "Crystal Oasis", _every(_t(0, 5), 120),
      expansion: Expansion.pof),
  WorldBoss('desert_highlands_buried_treasure', "Buried Treasure", "Desert Highlands", _every(_t(1, 0), 120),
      expansion: Expansion.pof),
  WorldBoss('elon_riverlands_doppelganger', "Doppelganger", "Elon Riverlands", _every(_t(1, 55), 120),
      expansion: Expansion.pof),
  WorldBoss('elon_riverlands_the_path_to_ascension_augury', "The Path to Ascension: Augury Rock", "Elon Riverlands",
      _every(_t(1, 30), 120),
      expansion: Expansion.pof),
  WorldBoss('the_desolation_junundu_rising', "Junundu Rising", "The Desolation", _every(_t(0, 30), 60),
      expansion: Expansion.pof),
  WorldBoss('the_desolation_maws_of_torment', "Maws of Torment", "The Desolation", _every(_t(1, 0), 120),
      expansion: Expansion.pof),
  WorldBoss('domain_of_vabbi_forged_with_fire', "Forged with Fire", "Domain of Vabbi", _every(_t(0, 0), 60),
      expansion: Expansion.pof),
  WorldBoss('domain_of_vabbi_serpents_ire', "Serpents' Ire", "Domain of Vabbi", _every(_t(0, 30), 120),
      expansion: Expansion.pof),

  // Living World
  WorldBoss('dry_top_crash_site', "Crash Site", "Dry Top", _every(_t(0, 0), 60), expansion: Expansion.lws),
  WorldBoss('dry_top_sandstorm', "Sandstorm", "Dry Top", _every(_t(0, 40), 60), expansion: Expansion.lws),
  WorldBoss('lake_doric_new_loamhurst', "New Loamhurst", "Lake Doric", _every(_t(1, 45), 120),
      expansion: Expansion.lws),
  WorldBoss('lake_doric_noran_s_homestead', "Noran's Homestead", "Lake Doric", _every(_t(0, 30), 120),
      expansion: Expansion.lws),
  WorldBoss('lake_doric_saidra_s_haven', "Saidra's Haven", "Lake Doric", _every(_t(1, 0), 120),
      expansion: Expansion.lws),
  WorldBoss('domain_of_istan_palawadan', "Palawadan", "Domain of Istan", _every(_t(1, 45), 120),
      expansion: Expansion.lws),
  WorldBoss('jahai_bluffs_escorts', "Escorts", "Jahai Bluffs", _every(_t(1, 0), 120), expansion: Expansion.lws),
  WorldBoss('jahai_bluffs_death_branded_shatterer', "Death-Branded Shatterer", "Jahai Bluffs", _every(_t(1, 15), 120),
      expansion: Expansion.lws),
  WorldBoss('thunderhead_peaks_thunderhead_keep', "Thunderhead Keep", "Thunderhead Peaks", _every(_t(1, 45), 120),
      expansion: Expansion.lws),
  WorldBoss('thunderhead_peaks_the_oil_floes', "The Oil Floes", "Thunderhead Peaks", _every(_t(0, 45), 120),
      expansion: Expansion.lws),
  WorldBoss('eye_of_the_north_twisted_marionette', "Twisted Marionette", "Eye of the North", _every(_t(0, 0), 120),
      expansion: Expansion.lws),
  WorldBoss(
      'eye_of_the_north_battle_for_lion_s_arch', "Battle For Lion's Arch", "Eye of the North", _every(_t(0, 30), 120),
      expansion: Expansion.lws),
  WorldBoss('eye_of_the_north_tower_of_nightmares', "Tower of Nightmares", "Eye of the North", _every(_t(1, 30), 120),
      expansion: Expansion.lws),

  // Icebrood Saga
  WorldBoss('grothmar_valley_effigy', "Effigy", "Grothmar Valley", _every(_t(0, 10), 120), expansion: Expansion.ibs),
  WorldBoss('grothmar_valley_doomlore_shrine', "Doomlore Shrine", "Grothmar Valley", _every(_t(0, 38), 120),
      expansion: Expansion.ibs),
  WorldBoss('grothmar_valley_ooze_pits', "Ooze Pits", "Grothmar Valley", _every(_t(1, 5), 120),
      expansion: Expansion.ibs),
  WorldBoss('grothmar_valley_metal_concert', "Metal Concert", "Grothmar Valley", _every(_t(1, 40), 120),
      expansion: Expansion.ibs),
  WorldBoss('bjora_marches_shards_and_construct', "Shards and Construct", "Bjora Marches", _every(_t(0, 0), 120),
      expansion: Expansion.ibs),
  WorldBoss('bjora_marches_icebrood_champions', "Icebrood Champions", "Bjora Marches", _every(_t(0, 5), 120),
      expansion: Expansion.ibs),
  WorldBoss('drakkar', "Drakkar and Spirits of the Wild", "Bjora Marches", _every(_t(1, 5), 120),
      expansion: Expansion.ibs),
  WorldBoss('bjora_marches_defend_jora_s_keep', "Defend Jora's Keep", "Bjora Marches", _every(_t(1, 45), 120),
      expansion: Expansion.ibs),
  WorldBoss('eye_of_the_north_dragonstorm', "Dragonstorm", "Eye of the North", _every(_t(1, 0), 120),
      expansion: Expansion.ibs),

  // End of Dragons
  WorldBoss('seitung_province_aetherblade_assault', "Aetherblade Assault", "Seitung Province", _every(_t(1, 30), 120),
      expansion: Expansion.eod),
  WorldBoss('new_kaineng_city_kaineng_blackout', "Kaineng Blackout", "New Kaineng City", _every(_t(0, 0), 120),
      expansion: Expansion.eod),
  WorldBoss('the_echovald_wilds_gang_war', "Gang War", "The Echovald Wilds", _every(_t(0, 30), 120),
      expansion: Expansion.eod),
  WorldBoss('the_echovald_wilds_aspenwood', "Aspenwood", "The Echovald Wilds", _every(_t(1, 40), 120),
      expansion: Expansion.eod),
  WorldBoss(
      'dragon_s_end_jade_maw',
      "Jade Maw",
      "Dragon's End",
      [
        _t(0, 5),
        _t(0, 45),
        _t(2, 5),
        _t(2, 45),
        _t(4, 5),
        _t(4, 45),
        _t(6, 5),
        _t(6, 45),
        _t(8, 5),
        _t(8, 45),
        _t(10, 5),
        _t(10, 45),
        _t(12, 5),
        _t(12, 45),
        _t(14, 5),
        _t(14, 45),
        _t(16, 5),
        _t(16, 45),
        _t(18, 5),
        _t(18, 45),
        _t(20, 5),
        _t(20, 45),
        _t(22, 5),
        _t(22, 45)
      ],
      expansion: Expansion.eod),
  WorldBoss(
      'dragon_s_end_the_battle_for_the_jade_sea', "The Battle for the Jade Sea", "Dragon's End", _every(_t(1, 0), 120),
      expansion: Expansion.eod),

  // Secrets of the Obscure
  WorldBoss('skywatch_archipelago_unlocking_the_wizard_s_', "Unlocking the Wizard's Tower", "Skywatch Archipelago",
      _every(_t(1, 0), 120),
      expansion: Expansion.soto),
  WorldBoss('wizard_s_tower_fly_by_night', "Fly by Night", "Wizard's Tower", _every(_t(1, 55), 120),
      expansion: Expansion.soto),
  WorldBoss('wizard_s_tower_target_practice', "Target Practice", "Wizard's Tower", _every(_t(1, 0), 120),
      expansion: Expansion.soto),
  WorldBoss('wizard_s_tower_target_practice_fly_by_night', "Target Practice & Fly by Night", "Wizard's Tower",
      _every(_t(1, 40), 120),
      expansion: Expansion.soto),
  WorldBoss('amnytas_defense_of_amnytas', "Defense of Amnytas", "Amnytas", _every(_t(0, 0), 120),
      expansion: Expansion.soto),
  WorldBoss('convergence_outer_nayos', "Convergence: Outer Nayos", "Outer Nayos", _every(_t(1, 30), 180),
      expansion: Expansion.soto),

  // Janthir Wilds
  WorldBoss('mists_and_monsters_titans', "Of Mists and Monsters", "Janthir Syntri", _every(_t(0, 30), 120),
      expansion: Expansion.jw),
  WorldBoss('bava_nisos_a_titanic_voyage', "A Titanic Voyage", "Bava Nisos", _every(_t(1, 20), 120),
      expansion: Expansion.jw),
  WorldBoss('convergence_mount_balrior', "Convergence: Mount Balrior", "Mount Balrior", _every(_t(0, 0), 180),
      expansion: Expansion.jw),

  // Visions of Eternity
  WorldBoss('shipwreck_strand_hammerhart_rumble', "Hammerhart Rumble!", "Shipwreck Strand", _every(_t(0, 40), 120),
      expansion: Expansion.voe),
  WorldBoss('starlit_weald_secrets_of_the_weald', "Secrets of the Weald", "Starlit Weald", _every(_t(1, 40), 120),
      expansion: Expansion.voe),
  WorldBoss('eternity_s_garden_shackles_of_the_ancients', "Shackles of the Ancients", "Eternity's Garden",
      _every(_t(1, 15), 120),
      expansion: Expansion.voe),
  WorldBoss('leyspring_hollows_depths_of_cruelty', "Depths of Cruelty", "Leyspring Hollows", _every(_t(2, 0), 180),
      expansion: Expansion.voe),
  WorldBoss(
      'convergence_nexus_of_eternity', "Convergence: Nexus of Eternity", "Nexus of Eternity", _every(_t(1, 0), 180),
      expansion: Expansion.voe),
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

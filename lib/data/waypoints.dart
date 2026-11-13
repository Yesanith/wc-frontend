import 'metas.dart';

/// a waypoint of the game: its name and the chat code that turns into a link to it when pasted in the game's chat
class Waypoint {
  const Waypoint(this.name, this.code);

  final String name;

  /// the chat code, like [&BN0AAAA=]
  final String code;
}

const _swamplost = Waypoint('Swamplost Haven Waypoint', '[&BPcAAAA=]');
const _krennak = Waypoint("Krennak's Homestead Waypoint", '[&BMIDAAA=]');
const _muridian = Waypoint('Muridian Waypoint', '[&BEcAAAA=]');
const _twilight = Waypoint('Twilight Arbor Waypoint', '[&BEEFAAA=]');
const _laughingGull = Waypoint('Laughing Gull Waypoint', '[&BKgBAAA=]');
const _firthside = Waypoint('Firthside Vigil Waypoint', '[&BKoBAAA=]');
const _maelstrom = Waypoint("Maelstrom's Waypoint", '[&BM0CAAA=]');
const _oldSledge = Waypoint('Old Sledge Site Waypoint', '[&BNQCAAA=]');
const _lowlandBurns = Waypoint('Lowland Burns Waypoint', '[&BE4DAAA=]');
const _junction = Waypoint('Junction Camp Waypoint', '[&BLAAAAA=]');
const _earthshake = Waypoint('Earthshake Waypoint', '[&BHoCAAA=]');
const _splintered = Waypoint('Splintered Coast Waypoint', '[&BNABAAA=]');
const _pearlIslet = Waypoint('Pearl Islet Waypoint', '[&BNUGAAA=]');
const _valance = Waypoint('Valance Tutory Waypoint', '[&BEwCAAA=]');
const _scalecatch = Waypoint('Village of Scalecatch Waypoint', '[&BOcBAAA=]');
const _provern = Waypoint('Provern Shore Waypoint', '[&BOQAAAA=]');
const _cereboth = Waypoint('Cereboth Waypoint', '[&BBIAAAA=]');
const _nageling = Waypoint('Nageling Waypoint', '[&BN0AAAA=]');
const _mrotBoru = Waypoint('Mrot Boru Waypoint', '[&BHUAAAA=]');
const _lornars = Waypoint("Lornar's Waypoint", '[&BLQAAAA=]');
const _dryTopEntry = Waypoint('Dry Top Entry Waypoint', '[&BIAHAAA=]');
const _redLeaf = Waypoint('Red Leaf Retreat Waypoint', '[&BK8JAAA=]');
const _doricsLanding = Waypoint("Doric's Landing Waypoint", '[&BK0JAAA=]');
const _lakesideBazaar = Waypoint('Lakeside Bazaar Waypoint', '[&BLQJAAA=]');
const _chalonDocks = Waypoint('Chalon Docks Waypoint', '[&BAkLAAA=]');
const _soulsVendetta = Waypoint("Soul's Vendetta Waypoint", '[&BIMLAAA=]');
const _ventaPass = Waypoint('Venta Pass Waypoint', '[&BJMLAAA=]');
const _revolutionsHeart = Waypoint("Revolution's Heart Waypoint", '[&BKYLAAA=]');
const _historysEnd = Waypoint("History's End Waypoint", '[&BLsLAAA=]');
const _eyeOfTheNorth = Waypoint('Eye of the North Waypoint', '[&BAkMAAA=]');
const _pactEncampment = Waypoint('Pact Encampment Waypoint', '[&BAgIAAA=]');
const _eastwatch = Waypoint('Eastwatch Waypoint', '[&BGwIAAA=]');
const _southwatch = Waypoint('Southwatch Waypoint', '[&BAIIAAA=]');
const _northwatch = Waypoint('Northwatch Waypoint', '[&BN0HAAA=]');
const _leyLineConfluence = Waypoint('Ley-Line Confluence Waypoint', '[&BPUHAAA=]');
const _pactBaseCamp = Waypoint('Pact Base Camp Waypoint', '[&BBAIAAA=]');
const _amnoon = Waypoint('Amnoon Waypoint', '[&BLsKAAA=]');
const _makali = Waypoint('Makali Outpost Waypoint', '[&BGsKAAA=]');
const _auguryShadow = Waypoint("Augury's Shadow Waypoint", '[&BFMKAAA=]');
const _lairForgotten = Waypoint('Lair of the Forgotten Waypoint', '[&BMEKAAA=]');
const _darklands = Waypoint('The Darklands Waypoint', '[&BKMKAAA=]');
const _vehjin = Waypoint('Vehjin Palace Waypoint', '[&BO0KAAA=]');
const _marketRuins = Waypoint('Market Ruins Waypoint', '[&BHQKAAA=]');
const _dalada = Waypoint('Dalada Forest Waypoint', '[&BA4MAAA=]');
const _wardowns = Waypoint('Wardowns Waypoint', '[&BPgLAAA=]');
const _stillWaters = Waypoint('Still Waters Speaking Waypoint', '[&BDkMAAA=]');
const _joraKeep = Waypoint("Jora's Keep Waypoint", '[&BCcMAAA=]');
const _daigo = Waypoint('Daigo Ward Waypoint', '[&BGUNAAA=]');
const _ministry = Waypoint('Ministry Ward Waypoint', '[&BBkNAAA=]');
const _kropa = Waypoint('Kropa Waypoint', '[&BMwMAAA=]');
const _jadeGate = Waypoint('Jade Gate Waypoint', '[&BPkMAAA=]');
const _jadeQuarry = Waypoint('Jade Quarry Waypoint', '[&BKIMAAA=]');
const _droknars = Waypoint("Droknar's Light Waypoint", '[&BL4NAAA=]');
const _towerCourtyard = Waypoint('Tower Courtyard Waypoint', '[&BB8OAAA=]');
const _bastion = Waypoint('Bastion of the Natural Waypoint', '[&BDQOAAA=]');
const _strickenPlains = Waypoint('Stricken Plains Waypoint', '[&BCoPAAA=]');
const _mantlesArrival = Waypoint("Mantle's Arrival Waypoint", '[&BGEPAAA=]');
const _harvestDen = Waypoint('Harvest Den Waypoint', '[&BK4OAAA=]');
const _pubCanach = Waypoint('Pub Canach Waypoint', '[&BJEPAAA=]');
const _priory = Waypoint('Priory Expedition Waypoint', '[&BJ4PAAA=]');
const _pilgrimsRest = Waypoint("Pilgrim's Rest Waypoint", '[&BPwPAAA=]');
const _hallAssemblage = Waypoint('Hall of Assemblage Waypoint', '[&BDYQAAA=]');
const _doyensAdytum = Waypoint("Doyen's Adytum Waypoint", '[&BB8QAAA=]');

/// the waypoint the wiki's event timer gives for each event, by map id and event name. where the wiki names none for an
/// event (the first half of a map's rotation, the quiet parts of it) it is the one of the other events of that map, which
/// is where a player goes for that map anyway. the convergences are in instances: the waypoint is the one they are
/// entered from
const _waypoints = <String, Waypoint>{
  'queensdale/Shadow Behemoth': _swamplost,
  'wayfarer/Svanir Shaman Chief': _krennak,
  'metrica/Fire Elemental': _muridian,
  'caledon/Great Jungle Wurm': _twilight,
  'bloodtide/Admiral Taidha Covington': _laughingGull,
  'bloodtide/Triple Trouble': _firthside,
  'maelstrom/Megadestroyer': _maelstrom,
  'maelstrom/Inquest Golem Mark II': _oldSledge,
  'blazeridge/The Shatterer': _lowlandBurns,
  'harathi/Modniir Ulgoth': _junction,
  'frostgorge/Claw of Jormag': _earthshake,
  'sparkfly/Tequatl the Sunless': _splintered,
  'southsun/Karka Queen': _pearlIslet,
  'leyline/Timberline Falls': _valance,
  'leyline/Iron Marches': _scalecatch,
  'leyline/Gendarran Fields': _provern,
  'incursion/Kessex Hills': _cereboth,
  'incursion/Diessa Plateau': _nageling,
  'incursion/Brisban Wildlands': _mrotBoru,
  'incursion/Snowden Drifts': _lornars,
  'drytop/Crash Site': _dryTopEntry,
  'drytop/Sandstorm': _dryTopEntry,
  'lakedoric/Noran\'s Homestead': _redLeaf,
  'lakedoric/Saidra\'s Haven': _doricsLanding,
  'lakedoric/New Loamhurst': _lakesideBazaar,
  'istan/Palawadan': _chalonDocks,
  'jahai/Escorts': _soulsVendetta,
  'jahai/Death-Branded Shatterer': _ventaPass,
  'thunderhead/The Oil Floes': _revolutionsHeart,
  'thunderhead/Thunderhead Keep': _historysEnd,
  'eotn/Twisted Marionette': _eyeOfTheNorth,
  'eotn/Battle for Lion\'s Arch': _eyeOfTheNorth,
  'eotn/Dragonstorm': _eyeOfTheNorth,
  'eotn/Tower of Nightmares': _eyeOfTheNorth,
  'verdant/Night Bosses': _pactEncampment,
  'verdant/Securing Verdant Brink': _pactEncampment,
  'verdant/Night and the Enemy': _pactEncampment,
  'auric/Challenges': _eastwatch,
  'auric/Octovine': _southwatch,
  'auric/Pylons': _northwatch,
  'tangled/Chak Gerent': _leyLineConfluence,
  'tangled/Outposts': _leyLineConfluence,
  'dragonsstand/Advancing on the Blighting Towers': _pactBaseCamp,
  'oasis/Casino Blitz': _amnoon,
  'highlands/Buried Treasure': _makali,
  'riverlands/Augury Rock': _auguryShadow,
  'riverlands/Doppelganger': _auguryShadow,
  'desolation/Junundu Rising': _lairForgotten,
  'desolation/Maws of Torment': _darklands,
  'vabbi/Forged with Fire': _vehjin,
  'vabbi/Serpents\' Ire': _marketRuins,
  'grothmar/Effigy': _dalada,
  'grothmar/Doomlore Shrine': _dalada,
  'grothmar/Ooze Pits': _wardowns,
  'grothmar/Metal Concert': _wardowns,
  'bjora/Shards and Construct': _joraKeep,
  'bjora/Icebrood Champions': _joraKeep,
  'bjora/Drakkar': _stillWaters,
  'bjora/Defend Jora\'s Keep': _joraKeep,
  'seitung/Aetherblade Assault': _daigo,
  'kaineng/Kaineng Blackout': _ministry,
  'echovald/Gang War': _kropa,
  'echovald/Aspenwood': _jadeGate,
  'dragonsend/Jade Maw': _jadeQuarry,
  'dragonsend/Battle for the Jade Sea': _jadeQuarry,
  'skywatch/Unlocking the Wizard\'s Tower': _droknars,
  'wizardstower/Target Practice': _towerCourtyard,
  'wizardstower/Fly by Night': _towerCourtyard,
  'amnytas/Defense of Amnytas': _bastion,
  'nayos/Convergence': _towerCourtyard,
  'syntri/Of Mists and Monsters': _strickenPlains,
  'bava/A Titanic Voyage': _mantlesArrival,
  'balrior/Convergence': _harvestDen,
  'shipwreck/Hammerhart Rumble!': _pubCanach,
  'weald/Secrets of the Weald': _priory,
  'garden/Shackles of the Ancients': _pilgrimsRest,
  'leyspring/Depths of Cruelty': _hallAssemblage,
  'nexus/Convergence': _doyensAdytum,
};

/// the waypoint to go to for an event, or null for one that is not known
Waypoint? waypointFor(MetaMap map, MetaEvent event) => _waypoints['${map.id}/${event.name}'];

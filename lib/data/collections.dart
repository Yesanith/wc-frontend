/// unlock collections that the api exposes as "all ids" + "ids this account has"
class CollectionKind {
  const CollectionKind(
    this.key,
    this.accountPath,
    this.staticPath, {
    this.hasDetails = true,
  });

  /// also the strings key for the display name
  final String key;
  final String accountPath;
  final String staticPath;

  /// false for wardrobe skins, there are far too many to list one by one
  final bool hasDetails;
}

const collectionKinds = <CollectionKind>[
  CollectionKind('mounts', '/account/mounts/types', '/mounts/types'),
  CollectionKind('mount_skins', '/account/mounts/skins', '/mounts/skins'),
  CollectionKind('gliders', '/account/gliders', '/gliders'),
  CollectionKind('minis', '/account/minis', '/minis'),
  CollectionKind('dyes', '/account/dyes', '/colors'),
  CollectionKind('outfits', '/account/outfits', '/outfits'),
  CollectionKind('novelties', '/account/novelties', '/novelties'),
  CollectionKind('finishers', '/account/finishers', '/finishers'),
  CollectionKind('mail_carriers', '/account/mailcarriers', '/mailcarriers'),
  CollectionKind('titles', '/account/titles', '/titles'),
  CollectionKind('emotes', '/account/emotes', '/emotes'),
  CollectionKind('wardrobe', '/account/skins', '/skins', hasDetails: false),
  CollectionKind('home_cats', '/account/home/cats', '/home/cats'),
  CollectionKind('home_nodes', '/account/home/nodes', '/home/nodes', hasDetails: false),
  CollectionKind('homestead_decorations', '/account/homestead/decorations', '/homestead/decorations'),
  CollectionKind('homestead_glyphs', '/account/homestead/glyphs', '/homestead/glyphs'),
  CollectionKind('jadebots', '/account/jadebots', '/jadebots'),
  CollectionKind('skiffs', '/account/skiffs', '/skiffs'),
  // the account endpoint lists hero skins, so the entries are skins, not heroes
  CollectionKind('pvp_heroes', '/account/pvp/heroes', '/pvp/heroes'),
];

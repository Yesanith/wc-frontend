import 'package:flutter_riverpod/flutter_riverpod.dart';

/// top level sections shown in the side drawer.
/// the order is the menu's: the day first, then the account, the economy,
/// the world, reference pages and finally the app itself
enum AppSection {
  home,
  bosses,
  daily,
  weekly,
  characters,
  account,
  progression,
  collections,
  guilds,
  guildEvents,
  trading,
  recipes,
  maps,
  wvw,
  professions,
  wiki,
  news,
  settings,
  about
}

final sectionProvider = StateProvider<AppSection>((ref) => AppSection.home);

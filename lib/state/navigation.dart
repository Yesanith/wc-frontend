import 'package:flutter_riverpod/flutter_riverpod.dart';

/// top level sections shown in the side drawer
enum AppSection {
  home,
  daily,
  weekly,
  characters,
  collections,
  progression,
  wvw,
  account,
  inventory,
  guilds,
  trading,
  bosses,
  maps,
  recipes,
  professions,
  wiki,
  settings,
  about
}

final sectionProvider = StateProvider<AppSection>((ref) => AppSection.home);

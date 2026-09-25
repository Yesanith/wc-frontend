import 'package:flutter_riverpod/flutter_riverpod.dart';

/// top level sections shown in the side drawer
enum AppSection { home, characters, collections, progression, wvw, account, guilds, trading, bosses, maps, recipes, wiki, settings }

final sectionProvider = StateProvider<AppSection>((ref) => AppSection.home);

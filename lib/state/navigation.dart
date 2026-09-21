import 'package:flutter_riverpod/flutter_riverpod.dart';

/// top level sections shown in the side drawer
enum AppSection { home, characters, collections, progression, account, guilds, trading, crafting, bosses, goals, recipes, wiki, settings }

final sectionProvider = StateProvider<AppSection>((ref) => AppSection.home);

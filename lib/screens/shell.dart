import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/navigation.dart';
import '../state/settings.dart';
import '../theme.dart';
import 'account_screen.dart';
import 'characters_screen.dart';
import 'collections_screen.dart';
import 'crafting_screen.dart';
import 'events_screen.dart';
import 'goals_screen.dart';
import 'guilds_screen.dart';
import 'home_screen.dart';
import 'maps_screen.dart';
import 'progression_screen.dart';
import 'recipes_screen.dart';
import 'settings_screen.dart';
import 'trading_screen.dart';
import 'wiki_screen.dart';

const _titleKeys = {
  AppSection.home: 'nav_home',
  AppSection.characters: 'nav_characters',
  AppSection.collections: 'collections',
  AppSection.progression: 'progression',
  AppSection.account: 'nav_account',
  AppSection.guilds: 'guilds',
  AppSection.trading: 'trading_post',
  AppSection.crafting: 'crafting',
  AppSection.bosses: 'world_bosses',
  AppSection.maps: 'maps',
  AppSection.goals: 'goals',
  AppSection.recipes: 'recipes',
  AppSection.wiki: 'nav_wiki',
  AppSection.settings: 'nav_settings',
};

const _icons = {
  AppSection.home: (Icons.home_outlined, Icons.home),
  AppSection.characters: (Icons.shield_outlined, Icons.shield),
  AppSection.collections: (Icons.auto_awesome_outlined, Icons.auto_awesome),
  AppSection.progression: (Icons.emoji_events_outlined, Icons.emoji_events),
  AppSection.account: (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
  AppSection.guilds: (Icons.groups_outlined, Icons.groups),
  AppSection.trading: (Icons.storefront_outlined, Icons.storefront),
  AppSection.crafting: (Icons.handyman_outlined, Icons.handyman),
  AppSection.bosses: (Icons.schedule_outlined, Icons.schedule),
  AppSection.maps: (Icons.map_outlined, Icons.map),
  AppSection.goals: (Icons.flag_outlined, Icons.flag),
  AppSection.recipes: (Icons.account_tree_outlined, Icons.account_tree),
  AppSection.wiki: (Icons.menu_book_outlined, Icons.menu_book),
  AppSection.settings: (Icons.settings_outlined, Icons.settings),
};

Widget _page(AppSection section) => switch (section) {
      AppSection.home => const HomeScreen(),
      AppSection.characters => const CharactersScreen(),
      AppSection.collections => const CollectionsScreen(),
      AppSection.progression => const ProgressionScreen(),
      AppSection.account => const AccountScreen(),
      AppSection.guilds => const GuildsScreen(),
      AppSection.trading => const TradingHubScreen(),
      AppSection.crafting => const CraftingScreen(),
      AppSection.bosses => const EventsScreen(embedded: true),
      AppSection.maps => const MapsScreen(),
      AppSection.goals => const GoalsScreen(embedded: true),
      AppSection.recipes => const RecipesScreen(),
      AppSection.wiki => const WikiScreen(),
      AppSection.settings => const SettingsScreen(),
    };

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // sections are only built once they're opened, so the app doesn't hit
  // every endpoint on startup. after that they stay alive in the stack
  final _opened = <AppSection>{AppSection.home};

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final section = ref.watch(sectionProvider);
    final accountName = ref.watch(accountProvider).valueOrNull?['name'] as String?;
    _opened.add(section);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t(_titleKeys[section]!), style: display(20)),
      ),
      drawer: NavigationDrawer(
        backgroundColor: AppColors.navBg,
        indicatorColor: const Color(0x2EE3B55B),
        selectedIndex: section.index,
        onDestinationSelected: (i) {
          ref.read(sectionProvider.notifier).state = AppSection.values[i];
          _scaffoldKey.currentState?.closeDrawer();
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tyria Codex', style: display(24, color: AppColors.gold)),
                if (accountName != null)
                  Text(accountName, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
          for (final sec in AppSection.values) ...[
            if (sec == AppSection.wiki || sec == AppSection.settings)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 6),
                child: Divider(color: AppColors.track, height: 1),
              ),
            NavigationDrawerDestination(
              icon: Icon(_icons[sec]!.$1),
              selectedIcon: Icon(_icons[sec]!.$2, color: AppColors.gold),
              label: Text(s.t(_titleKeys[sec]!)),
            ),
          ],
        ],
      ),
      body: IndexedStack(
        index: section.index,
        children: [
          for (final sec in AppSection.values) _opened.contains(sec) ? _page(sec) : const SizedBox.shrink(),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/navigation.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import 'account_screen.dart';
import 'characters_screen.dart';
import 'events_screen.dart';
import 'goals_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'trading_screen.dart';
import 'wiki_screen.dart';

const _titleKeys = {
  AppSection.home: 'nav_home',
  AppSection.characters: 'nav_characters',
  AppSection.account: 'nav_account',
  AppSection.trading: 'trading_post',
  AppSection.bosses: 'world_bosses',
  AppSection.goals: 'goals',
  AppSection.wiki: 'nav_wiki',
  AppSection.settings: 'nav_settings',
};

const _icons = {
  AppSection.home: (Icons.home_outlined, Icons.home),
  AppSection.characters: (Icons.shield_outlined, Icons.shield),
  AppSection.account: (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
  AppSection.trading: (Icons.storefront_outlined, Icons.storefront),
  AppSection.bosses: (Icons.schedule_outlined, Icons.schedule),
  AppSection.goals: (Icons.flag_outlined, Icons.flag),
  AppSection.wiki: (Icons.menu_book_outlined, Icons.menu_book),
  AppSection.settings: (Icons.settings_outlined, Icons.settings),
};

Widget _page(AppSection section) => switch (section) {
      AppSection.home => const HomeScreen(),
      AppSection.characters => const CharactersScreen(),
      AppSection.account => const AccountScreen(),
      AppSection.trading => const TradingHubScreen(),
      AppSection.bosses => const EventsScreen(embedded: true),
      AppSection.goals => const GoalsScreen(embedded: true),
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

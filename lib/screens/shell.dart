import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync.dart';
import '../state/account.dart';
import '../state/api.dart';
import '../state/navigation.dart';
import '../state/reference.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../state/wealth.dart';
import '../util.dart';
import 'account_screen.dart';
import 'characters_screen.dart';
import 'collections_screen.dart';
import 'events_screen.dart';
import 'guilds_screen.dart';
import 'home_screen.dart';
import 'maps_screen.dart';
import 'progression_screen.dart';
import 'recipes_screen.dart';
import 'settings_screen.dart';
import 'trading_screen.dart';
import 'wiki_screen.dart';
import 'wvw_screen.dart';
import 'daily_screen.dart';
import 'weekly_screen.dart';

const _titleKeys = {
  AppSection.home: 'nav_home',
  AppSection.daily: 'daily',
  AppSection.weekly: 'weekly',
  AppSection.characters: 'nav_characters',
  AppSection.collections: 'collections',
  AppSection.progression: 'progression',
  AppSection.wvw: 'wvw',
  AppSection.account: 'nav_account',
  AppSection.guilds: 'guilds',
  AppSection.trading: 'trading_post',
  AppSection.bosses: 'world_bosses',
  AppSection.maps: 'maps',
  AppSection.recipes: 'recipes',
  AppSection.wiki: 'nav_wiki',
  AppSection.settings: 'nav_settings',
};

const _icons = {
  AppSection.home: (Icons.home_outlined, Icons.home),
  AppSection.daily: (Icons.today_outlined, Icons.today),
  AppSection.weekly: (Icons.date_range_outlined, Icons.date_range),
  AppSection.characters: (Icons.shield_outlined, Icons.shield),
  AppSection.collections: (Icons.auto_awesome_outlined, Icons.auto_awesome),
  AppSection.progression: (Icons.emoji_events_outlined, Icons.emoji_events),
  AppSection.wvw: (Icons.fort_outlined, Icons.fort),
  AppSection.account: (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
  AppSection.guilds: (Icons.groups_outlined, Icons.groups),
  AppSection.trading: (Icons.storefront_outlined, Icons.storefront),
  AppSection.bosses: (Icons.schedule_outlined, Icons.schedule),
  AppSection.maps: (Icons.map_outlined, Icons.map),
  AppSection.recipes: (Icons.account_tree_outlined, Icons.account_tree),
  AppSection.wiki: (Icons.menu_book_outlined, Icons.menu_book),
  AppSection.settings: (Icons.settings_outlined, Icons.settings),
};

Widget _page(AppSection section) => switch (section) {
      AppSection.home => const HomeScreen(),
      AppSection.daily => const DailyScreen(),
      AppSection.weekly => const WeeklyScreen(),
      AppSection.characters => const CharactersScreen(),
      AppSection.collections => const CollectionsScreen(),
      AppSection.progression => const ProgressionScreen(),
      AppSection.wvw => const WvwScreen(),
      AppSection.account => const AccountScreen(),
      AppSection.guilds => const GuildsScreen(),
      AppSection.trading => const TradingHubScreen(),
      AppSection.bosses => const EventsScreen(embedded: true),
      AppSection.maps => const MapsScreen(),
      AppSection.recipes => const RecipesScreen(),
      AppSection.wiki => const WikiScreen(),
      AppSection.settings => const SettingsScreen(),
    };

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // sections are only built once they're opened, so the app doesn't hit
  // every endpoint on startup. after that they stay alive in the stack
  final _opened = <AppSection>{AppSection.home};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // after a game patch the static data cache is cleared once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(patchCheckProvider.future).catchError((_) => false);
    });
    // pull the whole account to disk once on launch, so opening a section
    // reads from the cache instead of waiting on the api
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncProvider.notifier).run();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// the system back button on the root screen. this observer is registered
  /// after the app's own, so it is asked first. returning false hands the
  /// event on to the navigator as usual
  @override
  Future<bool> didPopRoute() async {
    // a pushed page, dialog or sheet is on top: let it close normally
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return false;
    return _rootBack();
  }

  /// set while a section is picked from the menu, so that closing the menu
  /// for navigation is not mistaken for a back press
  bool _selecting = false;

  /// after the menu was dismissed, a back press within this window exits
  DateTime? _exitArmedUntil;

  void _select(AppSection next) {
    _selecting = true;
    ref.read(sectionProvider.notifier).state = next;
    _scaffoldKey.currentState?.closeDrawer();
  }

  /// when the menu was last dismissed by something other than picking a
  /// section. on some flutter versions the navigator closes the menu on back
  /// before we hear about it, this lets us still treat that as our back press
  DateTime? _dismissedAt;

  void _drawerChanged(bool open) {
    if (open) return;
    if (_selecting) {
      _selecting = false;
      return;
    }
    _dismissedAt = DateTime.now();
  }

  bool _within(DateTime? at, Duration window) => at != null && DateTime.now().difference(at) < window;

  void _armExit() {
    _exitArmedUntil = DateTime.now().add(const Duration(seconds: 2));
    showToast(context, ref.read(stringsProvider).t('back_again_to_exit'),
        duration: const Duration(seconds: 2));
  }

  /// back on the first page of any section, never switching sections:
  /// the first press opens the menu, the second press with the menu open
  /// shows the exit hint and keeps the menu, and a third press within two
  /// seconds of that hint leaves the app
  bool _rootBack() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold == null) return false;
    final armed = _exitArmedUntil;
    if (armed != null && DateTime.now().isBefore(armed)) {
      SystemNavigator.pop();
      return true;
    }
    if (scaffold.isDrawerOpen) {
      _armExit();
      return true;
    }
    // the navigator already closed the menu for this press: reopen it and
    // treat the press as the second one
    if (_within(_dismissedAt, const Duration(milliseconds: 1500))) {
      _dismissedAt = null;
      scaffold.openDrawer();
      _armExit();
      return true;
    }
    scaffold.openDrawer();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final section = ref.watch(sectionProvider);
    // one wallet snapshot per day and account feeds the wealth history
    ref.listen<AsyncValue<List<WalletEntry>>>(walletProvider, (_, next) {
      final wallet = next.valueOrNull;
      final name = ref.read(accountProvider).valueOrNull?['name'];
      if (wallet != null && name != null) ref.read(wealthProvider.notifier).record('$name', wallet);
    });
    final sync = ref.watch(syncProvider);
    final refreshing = ref.watch(backgroundRefreshProvider);
    // a different account has its own cache, so fill it too
    ref.listen(apiKeyProvider, (previous, next) {
      if (previous?.valueOrNull != next.valueOrNull) {
        ref.read(syncProvider.notifier).run();
      }
    });
    final accountName = ref.watch(accountProvider).valueOrNull?['name'] as String?;
    _opened.add(section);

    // canPop false makes the framework claim the back gesture, otherwise
    // android's predictive back would quit before _rootBack gets a say
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _rootBack();
      },
      child: Scaffold(
      key: _scaffoldKey,
      onDrawerChanged: _drawerChanged,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t(_titleKeys[section]!), style: display(20)),
        // a full sync shows real progress, a background refresh only says
        // that something is updating
        bottom: !sync.running && refreshing == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: sync.running ? sync.ratio : null,
                  minHeight: 2,
                  backgroundColor: AppColors.track,
                  color: AppColors.gold,
                ),
              ),
      ),
      drawer: NavigationDrawer(
        backgroundColor: AppColors.navBg,
        indicatorColor: const Color(0x2EE3B55B),
        selectedIndex: section.index,
        onDestinationSelected: (i) => _select(AppSection.values[i]),
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
          for (final sec in AppSection.values)
            // hidden sections keep their state but stop their tickers and timers
            TickerMode(
              enabled: sec == section,
              child: _opened.contains(sec) ? _page(sec) : const SizedBox.shrink(),
            ),
        ],
      ),
    ),
    );
  }
}

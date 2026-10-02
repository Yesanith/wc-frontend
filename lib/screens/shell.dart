import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync.dart';
import '../state/app_open.dart';
import '../state/account.dart';
import '../state/api.dart';
import '../state/navigation.dart';
import '../state/reference.dart';
import '../state/settings.dart';
import '../state/trading.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/site_header.dart';
import '../widgets/swipe_open.dart';
import '../state/wealth.dart';
import '../state/period_refresh.dart';
import '../util.dart';
import '../services/update_check.dart';
import '../services/push.dart';
import '../state/community.dart';
import '../state/link_refresh.dart';
import '../services/boss_alerts.dart';
import '../state/boss_alerts.dart';
import 'about_screen.dart';
import 'account_screen.dart';
import 'characters_screen.dart';
import 'collections_screen.dart';
import 'events_screen.dart';
import 'guild_roster_screen.dart' show SharingReviewScreen;
import 'guilds_screen.dart';
import 'home_screen.dart';
import 'professions_screen.dart';
import 'progression_screen.dart';
import 'recipes_screen.dart';
import 'settings_screen.dart';
import 'trading_screen.dart';
import 'wiki_screen.dart';
import 'wvw_screen.dart';
import 'daily_screen.dart';
import 'weekly_screen.dart';
import 'world_map_screen.dart';
import 'news_screen.dart';
import 'guild_events_screen.dart';
import 'open_events_screen.dart';

/// pages that are one long list: a row across a whole screen of a computer is hard to read
const _readingSections = {
  AppSection.news,
  AppSection.recipes,
  AppSection.progression,
  AppSection.bosses,
  AppSection.weekly,
  AppSection.guilds,
  AppSection.wvw,
  AppSection.about,
  AppSection.settings,
};

const _titleKeys = {
  AppSection.home: 'nav_home',
  AppSection.daily: 'nav_daily',
  AppSection.weekly: 'nav_weekly',
  AppSection.characters: 'nav_characters',
  AppSection.collections: 'collections',
  AppSection.progression: 'progression',
  AppSection.wvw: 'wvw',
  AppSection.account: 'nav_account',
  AppSection.guilds: 'guilds',
  AppSection.guildEvents: 'guild_events',
  AppSection.publicEvents: 'public_events',
  AppSection.trading: 'trading_post',
  AppSection.bosses: 'world_bosses',
  AppSection.maps: 'maps',
  AppSection.recipes: 'recipes',
  AppSection.professions: 'professions',
  AppSection.wiki: 'nav_wiki',
  AppSection.news: 'news',
  AppSection.settings: 'nav_settings',
  AppSection.about: 'about',
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
  AppSection.guildEvents: (Icons.event_note_outlined, Icons.event_note),
  AppSection.publicEvents: (Icons.public_outlined, Icons.public),
  AppSection.trading: (Icons.storefront_outlined, Icons.storefront),
  AppSection.bosses: (Icons.schedule_outlined, Icons.schedule),
  AppSection.maps: (Icons.map_outlined, Icons.map),
  AppSection.recipes: (Icons.account_tree_outlined, Icons.account_tree),
  AppSection.professions: (Icons.school_outlined, Icons.school),
  AppSection.wiki: (Icons.menu_book_outlined, Icons.menu_book),
  AppSection.news: (Icons.newspaper_outlined, Icons.newspaper),
  AppSection.settings: (Icons.settings_outlined, Icons.settings),
  AppSection.about: (Icons.info_outline, Icons.info),
};

/// where a group of the menu begins, and its heading. settings and about
/// get a divider without a heading
const _groupStarts = <AppSection, String?>{
  AppSection.characters: 'nav_group_account',
  AppSection.trading: 'nav_group_economy',
  AppSection.maps: 'nav_group_world',
  AppSection.professions: 'nav_group_reference',
  AppSection.settings: null,
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
      AppSection.guildEvents => const GuildEventsScreen(),
      AppSection.publicEvents => const OpenEventsScreen(),
      AppSection.trading => const TradingHubScreen(),
      AppSection.bosses => const EventsScreen(embedded: true),
      AppSection.maps => const WorldMapScreen(),
      AppSection.recipes => const RecipesScreen(),
      AppSection.professions => const ProfessionsScreen(),
      AppSection.wiki => const WikiScreen(),
      AppSection.news => const NewsScreen(),
      AppSection.settings => const SettingsScreen(),
      AppSection.about => const AboutScreen(),
    };

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// the window is wide enough for a menu that stays open, set on every build
  bool _wide = false;

  /// the guilds whose leader was already asked in this run, so it happens once
  static final _reviewAsked = <String>{};

  /// refreshes the link, which brings a leader's guild from the game, and when
  /// there is a guild whose leader has not yet chosen what the members see, asks
  Future<void> _refreshAndReview() async {
    // which version is in use, counted for the dashboard, not waited for
    unawaited(recordAppOpen(ref));
    await refreshLink(ref);
    if (!mounted) return;
    try {
      final guilds = await ref.read(myGuildsProvider.future);
      for (final g in guilds) {
        if (g.role != 'leader' || _reviewAsked.contains(g.id)) continue;
        final details = await ref.read(guildDetailsProvider(g.id).future);
        // nothing to choose about before the guild has been read
        if (details == null || !details.known || details.reviewed) continue;
        _reviewAsked.add(g.id);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => SharingReviewScreen(guildId: g.id, guildName: g.name)),
        );
        // one guild at a time
        return;
      }
    } catch (_) {
      // the question is asked again the next time the app opens
    }
  }

  // sections are only built once they're opened, so the app doesn't hit
  // every endpoint on startup. after that they stay alive in the stack
  final _opened = <AppSection>{AppSection.home};

  @override
  void initState() {
    super.initState();
    // this device takes the player's event notifications once they are
    // signed in, unless switched off in settings
    ref.listenManual(sessionProvider, (previous, next) {
      if (previous?.valueOrNull == null && next.valueOrNull != null) {
        _startPush();
        // the link with the community account is refreshed quietly, and a
        // guild leader's app brings the guild's details each time it is opened
        WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAndReview());
      }
    }, fireImmediately: true);
    // a tap on a world event alert opens the events, also when it started the app
    _alertTaps = bossAlertTaps.stream.listen(_openFromAlert);
    if (bossAlertLaunchPayload != null) {
      final payload = bossAlertLaunchPayload;
      bossAlertLaunchPayload = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFromAlert(payload));
    }
    _pushWhileOpen = pushWhileOpen.stream.listen((message) {
      final n = message.notification;
      if (n == null || !mounted) return;
      showToast(context, n.body == null ? '${n.title}' : '${n.title} · ${n.body}',
          duration: const Duration(seconds: 6));
    });
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
    // the watchlist's prices once per launch, so the price history gains a
    // point every day the app is opened, not only when the tp is
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(watchlistPricesProvider.future).catchError((_) => const <WatchedItem>[]);
    });
  }

  @override
  void dispose() {
    _pushWhileOpen?.cancel();
    _alertTaps?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime? _backgroundSince;
  StreamSubscription<Object?>? _pushWhileOpen;
  StreamSubscription<String?>? _alertTaps;

  void _openFromAlert(String? payload) {
    if (!isBossAlertPayload(payload) || !mounted) return;
    ref.read(sectionProvider.notifier).state = AppSection.bosses;
  }

  void _startPush() {
    if (!pushReady || ref.read(prefsProvider).getBool(pushPref) == false) return;
    enablePush(ref.read(langProvider).code).catchError((_) => false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundSince ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // a permission may have been given in the phone's settings meanwhile
      ref.read(bossAlertsRecheckProvider.notifier).bump();
      final away = _backgroundSince == null ? Duration.zero : DateTime.now().difference(_backgroundSince!);
      _backgroundSince = null;
      // a short switch away is not worth a refresh, a few minutes is
      if (away > const Duration(minutes: 3)) {
        ref.read(periodRefreshProvider.notifier).resumed();
        _refreshAndReview();
      }
    }
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
    // a menu that is always there has no closing to be mistaken for a back press
    if (!_wide) _selecting = true;
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
    showToast(context, ref.read(stringsProvider).t('back_again_to_exit'), duration: const Duration(seconds: 2));
  }

  /// back on the first page of any section, never switching sections:
  /// the first press opens the menu, the second press with the menu open
  /// shows the exit hint and keeps the menu, and a third press within two
  /// seconds of that hint leaves the app
  bool _rootBack() {
    if (_wide) {
      // the menu is always there, back has none to open. a browser keeps its own history
      if (kIsWeb) return false;
      final until = _exitArmedUntil;
      if (until != null && DateTime.now().isBefore(until)) {
        SystemNavigator.pop();
        return true;
      }
      _armExit();
      return true;
    }
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

  /// stores today's wallet once the wallet and the account both settled.
  /// while either reloads after a key switch it still holds the previous
  /// account's value, and the two would mix
  void _recordWealth() {
    final wallet = ref.read(walletProvider);
    final account = ref.read(accountProvider);
    if (wallet.isLoading || account.isLoading) return;
    final entries = wallet.valueOrNull;
    final name = account.valueOrNull?['name'];
    if (entries != null && name != null) ref.read(wealthProvider.notifier).record('$name', entries);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final section = ref.watch(sectionProvider);
    // one wallet snapshot per day and account feeds the wealth history
    ref.listen<AsyncValue<List<WalletEntry>>>(walletProvider, (_, __) => _recordWealth());
    ref.listen<AsyncValue<Json>>(accountProvider, (_, __) => _recordWealth());
    final sync = ref.watch(syncProvider);
    // keeps the phone's alarms for pinned world events in line, see boss_alerts
    ref.watch(bossAlertsSyncProvider);
    final refreshing = ref.watch(backgroundRefreshProvider);
    // a different account has its own cache, so fill it too
    ref.listen(apiKeyProvider, (previous, next) {
      if (previous?.valueOrNull != next.valueOrNull) {
        ref.read(syncProvider.notifier).run();
      }
    });
    final hasKey = ref.watch(hasKeyProvider);
    final String? accountName;
    if (hasKey) {
      accountName = ref.watch(accountProvider).valueOrNull?['name'] as String?;
    } else {
      accountName = s.t('guest');
    }
    _opened.add(section);

    // a computer or a tablet held sideways keeps the menu open beside the page. in a browser the menu is a bar along the top and a
    // footer under the page, as a site has, not a panel beside it as an app has
    final wide = useSideMenu(MediaQuery.sizeOf(context));
    _wide = wide;
    final site = kIsWeb && wide;
    final lang = ref.watch(langProvider);
    final menu = NavigationDrawer(
      selectedIndex: section.index,
      onDestinationSelected: (i) => _select(AppSection.values[i]),
      children: [
        // the plugin's header bar: the emblem, the name and the version
        // in a pill, with the account underneath
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 16, 14),
          child: Row(
            children: [
              const DiamondEmblem(size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text('Tyria Codex', style: display(18), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        const VersionPill(appVersion == 'dev' ? 'dev' : 'v$appVersion'),
                      ],
                    ),
                    if (accountName != null)
                      Text(accountName, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Divider(),
        ),
        for (final sec in AppSection.values) ...[
          if (_groupStarts.containsKey(sec)) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 6),
              child: Divider(),
            ),
            if (_groupStarts[sec] case final key?)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
                child: Kicker(s.t(key).toUpperCase(), color: AppColors.hint),
              ),
          ],
          NavigationDrawerDestination(
            icon: Icon(_icons[sec]!.$1),
            selectedIcon: Icon(_icons[sec]!.$2),
            label: Text(s.t(_titleKeys[sec]!)),
          ),
        ],
      ],
    );

    // the same scaffold either way, under its key, so a window resized past the limit
    // does not start the sections over
    final scaffold = Scaffold(
      key: _scaffoldKey,
      onDrawerChanged: _drawerChanged,
      appBar: site
          ? SiteHeader(
              current: section,
              onSelect: _select,
              labels: {for (final sec in AppSection.values) sec: s.t(_titleKeys[sec]!)},
              icons: {for (final sec in AppSection.values) sec: _icons[sec]!.$1},
              groupLabels: [for (final group in siteNavGroups) s.t(group.$1)],
              account: accountName,
              busy: sync.running || refreshing != 0,
              progress: sync.running ? sync.ratio : null,
            )
          : AppBar(
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
      bottomNavigationBar: site
          ? SiteFooter(
              note: s.t('site_footer_note'),
              links: [
                (
                  label: s.t('site_privacy'),
                  onTap: () => openUrl(context, sitePageUrl(lang, 'privacy'), failMessage: s.t('open_failed'))
                ),
                (
                  label: s.t('site_terms'),
                  onTap: () => openUrl(context, sitePageUrl(lang, 'terms'), failMessage: s.t('open_failed'))
                ),
                (
                  label: s.t('site_source'),
                  onTap: () => openUrl(context, repositoryUrl, failMessage: s.t('open_failed'))
                ),
              ],
            )
          : null,
      drawer: wide ? null : menu,
      body: SwipeToOpen(
        // the map pans sideways, the menu stays on the button and back there
        enabled: section != AppSection.maps && !wide,
        onOpen: () => _scaffoldKey.currentState?.openDrawer(),
        child: IndexedStack(
          index: section.index,
          children: [
            for (final sec in AppSection.values)
              // hidden sections keep their state but stop their tickers and timers
              TickerMode(
                enabled: sec == section,
                // the map takes the whole window, a list keeps to a width it can be read in and a page laid
                // out in columns to a wider one, both in the middle
                child: ContentFrame(
                  maxWidth: sec == AppSection.maps
                      ? double.infinity
                      : _readingSections.contains(sec)
                          ? readingMaxWidth
                          : contentMaxWidth,
                  child: !_opened.contains(sec)
                      ? const SizedBox.shrink()
                      : (!hasKey && sectionNeedsKey(sec))
                          ? const NeedsKeyView()
                          : site && sec != AppSection.maps && sec != AppSection.home
                              // a page of a site has its name at the top of it, the bar of an app is where an app has it
                              ? Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(s.t(_titleKeys[sec]!), style: display(30)),
                                      ),
                                    ),
                                    Expanded(child: _page(sec)),
                                  ],
                                )
                              : _page(sec),
                ),
              ),
          ],
        ),
      ),
    );

    // canPop false makes the framework claim the back gesture, otherwise
    // android's predictive back would quit before _rootBack gets a say
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _rootBack();
      },
      child: wide && !site
          ? Row(
              children: [
                SizedBox(
                  width: sideMenuWidth,
                  // the menu of the drawer, as a panel: flat, square, the width of the panel
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      drawerTheme: Theme.of(context).drawerTheme.copyWith(
                            elevation: 0,
                            shape: const RoundedRectangleBorder(),
                            width: sideMenuWidth,
                          ),
                    ),
                    child: menu,
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: AppColors.hairline),
                Expanded(child: scaffold),
              ],
            )
          : scaffold,
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/boss_alerts.dart';
import '../services/push.dart';
import '../services/sync.dart';
import '../services/trade_check.dart';
import '../services/update_check.dart';
import '../state/account.dart';
import '../state/api.dart';
import '../state/app_open.dart';
import '../state/boss_alerts.dart';
import '../state/community.dart';
import '../state/link_refresh.dart';
import '../state/navigation.dart';
import '../state/period_refresh.dart';
import '../state/reference.dart';
import '../state/server_price_alerts.dart';
import '../state/settings.dart';
import '../state/trade_notify.dart';
import '../state/trading.dart';
import '../state/wealth.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/account_badge.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/site_header.dart';
import '../widgets/site_search.dart';
import '../widgets/swipe_open.dart';
import 'about_screen.dart';
import 'account_screen.dart';
import 'characters_screen.dart';
import 'collections_screen.dart';
import 'daily_screen.dart';
import 'events_screen.dart';
import 'guild_events_screen.dart';
import 'guild_roster_screen.dart' show SharingReviewScreen;
import 'guilds_screen.dart';
import 'home_screen.dart';
import 'item_detail_screen.dart' show showItemDetails;
import 'news_screen.dart';
import 'open_events_screen.dart';
import 'open_link.dart';
import 'professions_screen.dart';
import 'progression_screen.dart';
import 'recipes_screen.dart';
import 'recruitment_screen.dart';
import 'settings_screen.dart';
import 'trading_screen.dart';
import 'weekly_screen.dart';
import 'wiki_screen.dart';
import 'world_map_screen.dart';
import 'wvw_screen.dart';

part 'shell/sections.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// the window is wide enough for a menu that stays open, set on every build
  bool _wide = false;

  /// what the tab of the browser says now, set when it changes
  String? _pageTitle;

  /// what was chosen in the search of the site: the page, the item, or the wiki asked for what was typed
  void _openHit(SearchHit hit) {
    switch (hit.kind) {
      case SearchKind.section:
        _select(hit.section!);
      case SearchKind.item:
        showItemDetails(context, hit.itemId!);
      case SearchKind.wiki:
        ref.read(wikiSearchRequestProvider.notifier).state = hit.query;
        _select(AppSection.wiki);
    }
  }

  /// the search of the site, as the bar and the window that opens from its button both have it
  SiteSearch _search({required double width, required ValueChanged<SearchHit> onSelect, bool autofocus = false}) {
    final s = ref.read(stringsProvider);
    return SiteSearch(
      width: width,
      autofocus: autofocus,
      labels: {for (final sec in AppSection.values) sec: s.t(_titleKeys[sec]!)},
      placeholder: s.t('search_placeholder'),
      wikiLabel: s.t('search_in_wiki'),
      pageLabel: s.t('search_page'),
      itemLabel: s.t('search_item'),
      onSelect: onSelect,
    );
  }

  /// the search in a window of its own, for a bar with no room for the box
  void _showSearch() {
    showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.only(top: 80, left: 24, right: 24),
        backgroundColor: AppColors.navBg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 440,
            child: _search(
              width: 440,
              autofocus: true,
              onSelect: (hit) {
                Navigator.of(dialog).pop();
                _openHit(hit);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _setPageTitle(String title) {
    if (_pageTitle == title) return;
    _pageTitle = title;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setApplicationSwitcherDescription(
          ApplicationSwitcherDescription(label: title, primaryColor: 0xFF0D0B09));
    });
  }

  /// the guilds whose leader was already asked in this run, so it happens once
  static final _reviewAsked = <String>{};

  /// refreshes the link, which brings a leader's guild from the game, and when
  /// there is a guild whose leader has not yet chosen what the members see, asks
  Future<void> _refreshAndReview() async {
    // which version is in use, counted for the dashboard, not waited for
    unawaited(recordAppOpen(ref));
    await refreshLink(ProviderScope.containerOf(context, listen: false));
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
    WidgetsBinding.instance.addObserver(this);
    _listenForSession();
    _listenForTaps();
    _listenForPushWhileOpen();
    _startBackgroundWork();
  }

  /// this device takes the player's event notifications once they are signed in, unless switched off in settings; the link with the community
  /// account is refreshed quietly, and a guild leader's app brings the guild's details each time it is opened
  void _listenForSession() {
    ref.listenManual(sessionProvider, (previous, next) {
      if (previous?.valueOrNull == null && next.valueOrNull != null) {
        _startPush();
        WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAndReview());
      }
    }, fireImmediately: true);
  }

  /// a tap on a world event alert or on a notification opens what it is about, also when it started the app; and so does a link the app was
  /// opened with
  void _listenForTaps() {
    _alertTaps = bossAlertTaps.stream.listen(_openFromAlert);
    if (bossAlertLaunchPayload != null) {
      final payload = bossAlertLaunchPayload;
      bossAlertLaunchPayload = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFromAlert(payload));
    }
    _pushTaps = pushTapped.stream.listen(_openFromPush);
    final started = linkFromPushData(initialPushData);
    initialPushData = null;
    if (started != null) ref.read(pendingLinkProvider.notifier).state = started;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPending());
  }

  void _listenForPushWhileOpen() {
    _pushWhileOpen = pushWhileOpen.stream.listen((message) {
      final n = message.notification;
      if (n == null || !mounted) return;
      showToast(context, n.body == null ? '${n.title}' : '${n.title} · ${n.body}',
          duration: const Duration(seconds: 6));
    });
  }

  /// what is done once the first frame is up
  void _startBackgroundWork() {
    // what the trading post did for the player is looked at every few minutes while the app is open, and once now. while it is closed Android
    // does it every quarter of an hour
    if (!kIsWeb) {
      _tradeTimer = Timer.periodic(const Duration(minutes: 5), (_) => _checkTrades());
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkTrades());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // after a game patch the static data cache is cleared once
      ref.read(patchCheckProvider.future).catchError((_) => false);
      // pull the whole account to disk once on launch, so opening a section reads from the cache instead of waiting on the api
      ref.read(syncProvider.notifier).run();
      // the watchlist's prices once per launch, so the price history gains a point every day the app is opened, not only when the tp is
      ref.read(watchlistPricesProvider.future).catchError((_) => const <WatchedItem>[]);
    });
  }

  @override
  void dispose() {
    _pushWhileOpen?.cancel();
    _pushTaps?.cancel();
    _tradeTimer?.cancel();
    _alertTaps?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime? _backgroundSince;
  StreamSubscription<Object?>? _pushWhileOpen;
  StreamSubscription<Map<String, dynamic>>? _pushTaps;
  Timer? _tradeTimer;
  bool _checkingTrades = false;
  StreamSubscription<String?>? _alertTaps;

  /// the item or the public event a link asked for, opened over the page now that there is one
  void _openPending() {
    final link = ref.read(pendingLinkProvider);
    if (link == null || !mounted) return;
    ref.read(pendingLinkProvider.notifier).state = null;
    // the browser already has its address
    openLinkNow(context, link, announce: false);
  }

  void _openFromPush(Map<String, dynamic> data) {
    final link = linkFromPushData(data);
    if (link == null || !mounted) return;
    openLinkNow(context, link);
  }

  void _openFromAlert(String? payload) {
    if (!mounted) return;
    if (isTradePayload(payload)) {
      ref.read(sectionProvider.notifier).state = AppSection.trading;
    } else if (isBossAlertPayload(payload)) {
      ref.read(sectionProvider.notifier).state = AppSection.bosses;
    }
  }

  /// a look at what the trading post did for the player since the last, when they asked to be told. one at a time, and a failure is only a look that did not happen
  Future<void> _checkTrades() async {
    if (_checkingTrades || !bossAlertsReady || !ref.read(tradeNotifyProvider)) return;
    final keys = ref.read(keysProvider).valueOrNull ?? const <StoredKey>[];
    if (keys.isEmpty) return;
    _checkingTrades = true;
    try {
      await checkTradingPost(keys: keys, prefs: ref.read(prefsProvider), lang: ref.read(langProvider));
    } catch (_) {
      // at the next look
    } finally {
      _checkingTrades = false;
    }
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
      if (!kIsWeb) _checkTrades();
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
    // the price alerts of the device are told to the server, so that they arrive when the app is shut
    ref.watch(priceAlertSyncProvider);
    // a page is an address in the browser, so that its back button, a link to it and a refresh all lead to it
    ref.listen<AppSection>(sectionProvider, (_, next) {
      if (kIsWeb) announceSection(next);
    });
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
    final site = kIsWeb && wide && MediaQuery.sizeOf(context).width >= siteMinWidth;
    // the tab of the browser says which page it is, as the tab of a site does
    if (kIsWeb) _setPageTitle(sitePageTitle(section, s.t(_titleKeys[section]!)));
    final lang = ref.watch(langProvider);
    final menu = NavigationDrawer(
      selectedIndex: section.index,
      onDestinationSelected: (i) => _select(AppSection.values[i]),
      children: [
        // who is signed in, first of all: a button to sign in with Discord, or the Discord name with the game accounts
        if (communityReady)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AccountBadge(onOpen: () => _select(AppSection.settings)),
          ),
        // the plugin's header bar: the emblem, the name and the version
        // in a pill, with the account of the api key underneath
        Padding(
          padding: EdgeInsets.fromLTRB(24, communityReady ? 16 : 22, 16, 14),
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
                        Flexible(child: Text('Wondrous Compass', style: display(18), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        const VersionPill(appVersion == 'dev' ? 'dev' : 'v$appVersion'),
                      ],
                    ),
                    if (accountName != null) Text(accountName, style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
              // the room of the bar decides what is in it: the account and a wide search, a narrower search, or a button that opens the
              // search in a window, so that the sections are always all there
              account: siteBarLayout(MediaQuery.sizeOf(context).width).account ? accountName : null,
              // with the community backend the bar says who is signed in, or offers to sign in, at every width
              accountBadge:
                  communityReady
                      ? AccountBadge(
                          compact: true,
                          showName: siteBarLayout(MediaQuery.sizeOf(context).width).account,
                          onOpen: () => _select(AppSection.settings),
                        )
                      : null,
              search: switch (siteBarLayout(MediaQuery.sizeOf(context).width).searchWidth) {
                final width? => _search(width: width, onSelect: _openHit),
                null => IconButton(
                    tooltip: s.t('search_placeholder'),
                    onPressed: _showSearch,
                    icon: Icon(Icons.search, color: AppColors.muted),
                  ),
              },
              busy: sync.running || refreshing != 0,
              progress: sync.running ? sync.ratio : null,
            )
          : AppBar(
              surfaceTintColor: Colors.transparent,
              title: Text(s.t(_titleKeys[section]!), style: display(20, color: AppColors.accent)),
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
                                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: SitePageHeading(
                                          title: s.t(_titleKeys[sec]!),
                                          kicker: siteGroupIndex(sec) == null
                                              ? null
                                              : s.t(siteNavGroups[siteGroupIndex(sec)!].$1),
                                        ),
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
                VerticalDivider(width: 1, thickness: 1, color: AppColors.hairline),
                Expanded(child: scaffold),
              ],
            )
          : scaffold,
    );
  }
}

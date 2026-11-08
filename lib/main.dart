import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/strings.dart';
import 'screens/landing_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/open_link.dart';
import 'screens/shell.dart';
import 'services/trade_background.dart';
import 'state/trade_alerts.dart' show tradeNotifyPref;
import 'services/cache.dart';
import 'services/boss_alerts.dart';
import 'services/icon_cache.dart';
import 'services/push.dart';
import 'state/community.dart';
import 'state/kept_keys.dart';
import 'state/api.dart';
import 'state/navigation.dart';
import 'state/settings.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets/ui_zoom.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // the page a link opened is read now, before the app has begun: the navigator tells the browser its own address ("/") as it begins, and what is read after is that
  final startLink = initialLink();
  final startSection = initialSection();
  final prefs = await SharedPreferences.getInstance();
  // a browser has no disk to keep them on, everything then comes from the network
  final cache = kIsWeb ? null : await DiskCache.open();
  final icons = kIsWeb ? null : await IconCache.open();
  // the community account is optional, a failure here never blocks the app
  await initCommunity();
  // push notifications need the community account, and are off without firebase values. a browser has them through
  // the page's bridge (web_push.js) when the site was built with the Firebase web app
  await initPush();
  if (!kIsWeb) {
    // alerts before pinned world events, from the phone's own alarms
    await initBossAlerts();
    // the look at the trading post while the app is closed, asked for again each time in case an update of the app lost it
    await initTradeBackground();
    if (prefs.getBool(tradeNotifyPref) == true) await setTradeBackground(true);
  }
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        sectionProvider.overrideWith((ref) => startSection),
        // a link to an item or to an event is opened by the page once there is one: the player may have to choose to go on first
        pendingLinkProvider.overrideWith((ref) => startLink is SectionLink ? null : startLink),
        diskCacheProvider.overrideWithValue(cache),
        iconCacheProvider.overrideWithValue(icons),
      ],
      child: const WondrousCompassApp(),
    ),
  );
}

class WondrousCompassApp extends ConsumerStatefulWidget {
  const WondrousCompassApp({super.key});

  @override
  ConsumerState<WondrousCompassApp> createState() => _WondrousCompassAppState();
}

class _WondrousCompassAppState extends ConsumerState<WondrousCompassApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  late final _brightness = _BrightnessWatcher(() {
    if (mounted) setState(() {});
  });
  late final _urlRestorer = UrlRestorer(_restoreUrl);

  /// the back button goes between the pages only with a history of more than one place. it is asked for after the first frame: the navigator, as it begins, chooses a history of
  /// one place, which would undo it if it were asked for before
  void _startHistory() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await keepHistoryOfPages();
      if (mounted) restoreAddress(_address());
    });
  }

  /// what the address in the browser is now: what is open over the page, a link not opened yet, or the page
  String _address() => currentAddress(
        section: ref.read(sectionProvider),
        open: ref.read(openLinkProvider),
        pending: ref.read(pendingLinkProvider),
      );

  /// puts the address of the page back in the browser once the frame is made, which is when the navigator has told it its own, and again a moment later
  /// in case it does so later
  void _restoreUrl() {
    if (!kIsWeb) return;
    void put() {
      if (mounted) restoreAddress(_address());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => put());
    Future<void>.delayed(const Duration(milliseconds: 500), put);
    // and once more, when the history has been changed over
    Future<void>.delayed(const Duration(milliseconds: 1500), put);
  }

  // the observer is put in before the app's own, which would take an address it does not know for a page to push, and so is asked first
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_brightness);
    if (kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
      _startHistory();
      // a link to a page opens it: its address is what the browser has to say, not the "/" of the navigator
      _restoreUrl();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_brightness);
    if (kIsWeb) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// the back and forward buttons of the browser and a link to a page: the page is shown, and what was open over the last one is closed
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    return followBrowser(
      routeInformation.uri,
      ref.read(sectionProvider),
      (section) {
        _closeOver();
        ref.read(sectionProvider.notifier).state = section;
      },
      open: _openFollowed,
      linkIsOpen: ref.read(openLinkProvider) != null,
      close: _closeOver,
    );
  }

  /// what is open over the page is closed. the link that was open is forgotten first: the browser is where it should be, and has nothing to be put back
  void _closeOver() {
    ref.read(openLinkProvider.notifier).state = null;
    _navigator.currentState?.popUntil((route) => route.isFirst);
  }

  /// the browser went to a link to an item or an event: what was open is closed and the link is opened, without a new place in the history
  void _openFollowed(AppLink link) {
    _closeOver();
    final context = _navigator.currentContext;
    if (context != null) openLinkNow(context, link, announce: false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    groupSeparator = switch (lang) {
      AppLang.en || AppLang.ja || AppLang.zh => ',',
      AppLang.fr => '\u202F',
      AppLang.ru => '\u00A0',
      _ => '.',
    };
    final key = ref.watch(apiKeyProvider);
    final guest = ref.watch(guestModeProvider);
    final chosenScale = ref.watch(uiScaleProvider);
    // the palette is chosen here and read by every widget as it is built. the whole tree is made again
    // when it changes (the key), since widgets made once as constants would keep the old colours
    final palette = paletteFor(ref.watch(lookProvider), WidgetsBinding.instance.platformDispatcher.platformBrightness);
    AppColors.use(palette);
    return KeyedSubtree(
      key: ValueKey(palette.dark),
      child: _app(key, guest, chosenScale),
    );
  }

  Widget _home(String? key, bool guest) {
    final signedIn = ref.watch(sessionProvider).valueOrNull != null;
    final noKey = key == null || key.isEmpty;
    return homeFor(
      key: key,
      guest: guest,
      signedIn: signedIn,
      // signed in on a device with no key: the keys the account keeps are brought first
      restoring: signedIn && noKey && ref.watch(restoredKeysProvider).isLoading,
      // read only while it decides something: a player with a key never waits for it
      linked: signedIn && noKey ? ref.watch(linkedAccountsProvider) : const AsyncData(<LinkedAccount>[]),
      landing: kIsWeb && !ref.watch(landingDismissedProvider),
    );
  }

  Widget _app(AsyncValue<String?> key, bool guest, double? chosenScale) {
    return MaterialApp(
      navigatorKey: _navigator,
      navigatorObservers: [_urlRestorer],
      // the address in the browser is the page, which the shell reads, not a route of the navigator
      initialRoute: '/',
      title: 'Wondrous Compass',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // on the web a wide screen shows everything larger, so a 2K monitor is not a phone's layout in the middle of it
      builder: (context, child) => UiZoom(
        scale: kIsWeb ? uiZoomFor(MediaQuery.sizeOf(context).width, chosenScale) : 1.0,
        child: child ?? const SizedBox.shrink(),
      ),
      home: key.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) => const OnboardingScreen(),
        // a visitor of the site is shown what the app is first, then asked to sign in. the app on a phone goes straight to signing in
        data: (k) => _home(k, guest),
      ),
    );
  }
}

/// what the app opens on: with a key the app. signed in with Discord and no key, a wait while the keys the account keeps
/// are brought ([restoring]), then the app when a game account is linked to the Discord account, the screen that asks
/// for a key to link when none is. otherwise the way in, or the app as a guest
Widget homeFor({
  required String? key,
  required bool guest,
  required bool signedIn,
  required AsyncValue<List<LinkedAccount>> linked,
  required bool landing,
  bool restoring = false,
}) {
  if (key != null && key.isNotEmpty) return const AppShell();
  if (signedIn) {
    if (restoring) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return linked.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      // not knowing is no reason to keep the player out
      error: (_, __) => const AppShell(),
      data: (accounts) => accounts.isEmpty ? const OnboardingScreen(linking: true) : const AppShell(),
    );
  }
  if (guest) return const AppShell();
  return landing ? const LandingScreen() : const OnboardingScreen();
}

/// tells the app when the phone changes between light and dark
class _BrightnessWatcher with WidgetsBindingObserver {
  _BrightnessWatcher(this.onChange);

  final VoidCallback onChange;

  @override
  void didChangePlatformBrightness() => onChange();
}

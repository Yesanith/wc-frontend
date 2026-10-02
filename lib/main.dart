import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/strings.dart';
import 'screens/landing_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';
import 'services/cache.dart';
import 'services/boss_alerts.dart';
import 'services/icon_cache.dart';
import 'services/push.dart';
import 'state/community.dart';
import 'state/api.dart';
import 'state/navigation.dart';
import 'state/settings.dart';
import 'theme.dart';
import 'util.dart';
import 'widgets/ui_zoom.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // a browser has no disk to keep them on, everything then comes from the network
  final cache = kIsWeb ? null : await DiskCache.open();
  final icons = kIsWeb ? null : await IconCache.open();
  // the community account is optional, a failure here never blocks the app
  await initCommunity();
  // push notifications need the community account, and are off without firebase values
  // in a browser there are neither, the settings hide them
  if (!kIsWeb) {
    await initPush();
    // alerts before pinned world events, from the phone's own alarms
    await initBossAlerts();
  }
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        diskCacheProvider.overrideWithValue(cache),
        iconCacheProvider.overrideWithValue(icons),
      ],
      child: const TyriaCodexApp(),
    ),
  );
}

class TyriaCodexApp extends ConsumerStatefulWidget {
  const TyriaCodexApp({super.key});

  @override
  ConsumerState<TyriaCodexApp> createState() => _TyriaCodexAppState();
}

class _TyriaCodexAppState extends ConsumerState<TyriaCodexApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();

  // the observer is put in before the app's own, which would take an address it does not know for a page to push, and so is asked first
  @override
  void initState() {
    super.initState();
    if (kIsWeb) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    if (kIsWeb) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// the back and forward buttons of the browser and a link to a page: the page is shown, and what was open over the last one is closed
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    return followBrowser(routeInformation.uri, ref.read(sectionProvider), (section) {
      _navigator.currentState?.popUntil((route) => route.isFirst);
      ref.read(sectionProvider.notifier).state = section;
    });
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
    return MaterialApp(
      navigatorKey: _navigator,
      // the address in the browser is the page, which the shell reads, not a route of the navigator
      initialRoute: '/',
      title: 'Tyria Codex',
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
        data: (k) => (k == null || k.isEmpty) && !guest
            ? (kIsWeb && !ref.watch(landingDismissedProvider) ? const LandingScreen() : const OnboardingScreen())
            : const AppShell(),
      ),
    );
  }
}

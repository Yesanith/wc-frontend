import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/strings.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';
import 'services/cache.dart';
import 'services/boss_alerts.dart';
import 'services/icon_cache.dart';
import 'services/push.dart';
import 'state/community.dart';
import 'state/api.dart';
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

class TyriaCodexApp extends ConsumerWidget {
  const TyriaCodexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        data: (k) => (k == null || k.isEmpty) && !guest ? const OnboardingScreen() : const AppShell(),
      ),
    );
  }
}

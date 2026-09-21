import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/strings.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';
import 'services/cache.dart';
import 'state/api.dart';
import 'state/settings.dart';
import 'theme.dart';
import 'util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final cache = await DiskCache.open();
  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        diskCacheProvider.overrideWithValue(cache),
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
      AppLang.en => ',',
      AppLang.fr => '\u202F',
      _ => '.',
    };
    final key = ref.watch(apiKeyProvider);
    return MaterialApp(
      title: 'Tyria Codex',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: key.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) => const OnboardingScreen(),
        data: (k) => (k == null || k.isEmpty) ? const OnboardingScreen() : const AppShell(),
      ),
    );
  }
}

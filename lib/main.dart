import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';
import 'state/providers.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: TyriaCodexApp()));
}

class TyriaCodexApp extends ConsumerWidget {
  const TyriaCodexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/main.dart';
import 'package:wondrous_compass/screens/landing_screen.dart';
import 'package:wondrous_compass/screens/onboarding_screen.dart';
import 'package:wondrous_compass/screens/shell.dart';
import 'package:wondrous_compass/state/community.dart';

void main() {
  const none = AsyncData(<LinkedAccount>[]);
  const one = AsyncData([LinkedAccount('a1', 'Leo.1234', null)]);

  group('what the app opens on', () {
    test('a key opens the app, whatever else', () {
      expect(homeFor(key: 'k', guest: false, signedIn: false, linked: none, landing: true), isA<AppShell>());
      expect(homeFor(key: 'k', guest: false, signedIn: true, linked: none, landing: false), isA<AppShell>());
    });

    test('signed in with Discord and no game account linked asks for a key to link', () {
      final w = homeFor(key: null, guest: false, signedIn: true, linked: none, landing: true);
      expect(w, isA<OnboardingScreen>().having((o) => o.linking, 'linking', isTrue));
      // a guest who signs in is asked too
      expect(homeFor(key: '', guest: true, signedIn: true, linked: none, landing: false),
          isA<OnboardingScreen>().having((o) => o.linking, 'linking', isTrue));
    });

    test('signed in with a game account linked opens the app without a key', () {
      expect(homeFor(key: null, guest: false, signedIn: true, linked: one, landing: false), isA<AppShell>());
      // not knowing keeps nobody out
      expect(
        homeFor(key: null, guest: false, signedIn: true, linked: AsyncError('x', StackTrace.empty), landing: false),
        isA<AppShell>(),
      );
    });

    test('nobody signed in and no key: the way in, the app for a guest', () {
      expect(homeFor(key: null, guest: false, signedIn: false, linked: none, landing: false),
          isA<OnboardingScreen>().having((o) => o.linking, 'linking', isFalse));
      expect(homeFor(key: null, guest: false, signedIn: false, linked: none, landing: true), isA<LandingScreen>());
      expect(homeFor(key: null, guest: true, signedIn: false, linked: none, landing: true), isA<AppShell>());
    });
  });
}

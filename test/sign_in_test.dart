import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/main.dart';
import 'package:wondrous_compass/screens/landing_screen.dart';
import 'package:wondrous_compass/screens/onboarding_screen.dart';
import 'package:wondrous_compass/screens/shell.dart';
import 'package:wondrous_compass/state/community.dart';
import 'package:wondrous_compass/state/kept_keys.dart';

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

    test('signed in on a device with no key waits while the kept keys are brought', () {
      expect(homeFor(key: null, guest: false, signedIn: true, linked: one, landing: false, restoring: true),
          isNot(isA<AppShell>()));
      expect(homeFor(key: null, guest: false, signedIn: true, linked: one, landing: false, restoring: true),
          isNot(isA<OnboardingScreen>()));
      // a key already here: nothing to wait for
      expect(homeFor(key: 'k', guest: false, signedIn: true, linked: none, landing: false, restoring: true),
          isA<AppShell>());
    });

    test('signed in with a game account linked opens the app without a key', () {
      expect(homeFor(key: null, guest: false, signedIn: true, linked: one, landing: false), isA<AppShell>());
      // not knowing keeps nobody out
      expect(
        homeFor(key: null, guest: false, signedIn: true, linked: const AsyncError('x', StackTrace.empty), landing: false),
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

  group('keys kept in the account', () {
    test('the keys are read from the server\'s answer, anything else is none', () {
      final keys = parseKeptKeys({
        'keys': [
          {'account_name': 'Leo.1234', 'key': 'K1'},
          {'account_name': 'Mia.5678', 'key': ''},
          'nonsense',
        ],
      });
      expect(keys.map((k) => '${k.accountName}=${k.key}'), ['Leo.1234=K1']);
      expect(parseKeptKeys(null), isEmpty);
      expect(parseKeptKeys({'keys': 'x'}), isEmpty);
    });

    test('why a key could not be kept is said', () {
      expect(keptKeyFailure('keys_off'), 'keep_keys_off');
      expect(keptKeyFailure('rate_limited'), 'err_rate_limited');
      expect(keptKeyFailure('invalid_token'), 'gw2_link_key');
    });
  });
}

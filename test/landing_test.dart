import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wondrous_compass/l10n/strings.dart';
import 'package:wondrous_compass/screens/landing_screen.dart';
import 'package:wondrous_compass/state/settings.dart';
import 'package:wondrous_compass/theme.dart';

void main() {
  group('the features the page shows', () {
    test('are eight, each with its own icon, its page of the app and its line', () {
      expect(landingFeatures.length, 8);
      expect(landingFeatures.map((f) => f.$1).toSet().length, 8, reason: 'no two with the same icon');
      expect(landingFeatures.map((f) => f.$2).toSet().length, 8);
      expect(landingFeatures.map((f) => f.$3).toSet().length, 8);
    });

    test('have words in every language: the name of the page and the line under it', () {
      for (final lang in AppLang.values) {
        final s = S(lang);
        for (final f in landingFeatures) {
          expect(s.t(f.$2), isNot(f.$2), reason: '${f.$2} in ${lang.code}');
          expect(s.t(f.$3), isNot(f.$3), reason: '${f.$3} in ${lang.code}');
        }
        for (final key in ['landing_title', 'landing_sub', 'landing_start', 'landing_guest', 'privacy_note']) {
          expect(s.t(key), isNot(key), reason: '$key in ${lang.code}');
        }
      }
    });

    test('and so does the search of the site', () {
      for (final lang in AppLang.values) {
        final s = S(lang);
        for (final key in ['search_placeholder', 'search_in_wiki', 'search_item', 'search_page']) {
          expect(s.t(key), isNot(key), reason: '$key in ${lang.code}');
        }
        expect(s.t('search_in_wiki').contains('{q}'), isTrue,
            reason: 'it has a place for what was typed in ${lang.code}');
      }
    });
  });

  group('how many cards go side by side', () {
    test('four on a wide page, two on a middle one and one on a phone', () {
      expect(landingColumns(1400), 4);
      expect(landingColumns(1000), 4);
      expect(landingColumns(999), 2);
      expect(landingColumns(640), 2);
      expect(landingColumns(639), 1);
      expect(landingColumns(360), 1);
    });
  });

  group('the page', () {
    Future<ProviderContainer> show(WidgetTester tester, {Size size = const Size(1400, 3200)}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(theme: buildTheme(), home: const LandingScreen()),
      ));
      await tester.pump();
      return ProviderScope.containerOf(tester.element(find.byType(LandingScreen)));
    }

    const s = S(AppLang.en);

    testWidgets('says what the app is, with what it has, and how to begin', (tester) async {
      await show(tester);
      expect(find.text(s.t('landing_title')), findsNWidgets(2), reason: 'above, and again at the foot');
      expect(find.text(s.t('landing_sub')), findsOneWidget);
      for (final f in landingFeatures) {
        expect(find.text(s.t(f.$2)), findsOneWidget, reason: f.$2);
        expect(find.text(s.t(f.$3)), findsOneWidget, reason: f.$3);
      }
      expect(find.text(s.t('landing_start')), findsNWidgets(2));
      expect(find.text(s.t('landing_guest')), findsNWidgets(2));
      expect(find.text(s.t('privacy_note')), findsOneWidget, reason: 'what the key can do, before it is asked for');
    });

    testWidgets('has the links of a site at its foot', (tester) async {
      await show(tester);
      expect(find.text(s.t('site_privacy')), findsOneWidget);
      expect(find.text(s.t('site_terms')), findsOneWidget);
      expect(find.text(s.t('site_source')), findsOneWidget);
    });

    testWidgets('goes on to sign in when started, from the top and from the foot', (tester) async {
      final container = await show(tester);
      expect(container.read(landingDismissedProvider), isFalse);
      await tester.tap(find.text(s.t('landing_start')).first);
      expect(container.read(landingDismissedProvider), isTrue);
      container.read(landingDismissedProvider.notifier).state = false;
      await tester.tap(find.text(s.t('landing_start')).last);
      expect(container.read(landingDismissedProvider), isTrue);
    });

    testWidgets('looks around as a guest, without a key', (tester) async {
      final container = await show(tester);
      expect(container.read(guestModeProvider), isFalse);
      await tester.tap(find.text(s.t('landing_guest')).first);
      await tester.pump();
      expect(container.read(guestModeProvider), isTrue);
      expect(container.read(landingDismissedProvider), isFalse,
          reason: 'the guest goes to the app, not to the sign in');
    });

    testWidgets('changes its words with the language, and keeps all of its cards', (tester) async {
      final container = await show(tester);
      await container.read(langProvider.notifier).set(AppLang.tr);
      await tester.pump();
      const tr = S(AppLang.tr);
      expect(find.text(tr.t('landing_title')), findsNWidgets(2));
      expect(find.text(tr.t('landing_f_trading')), findsOneWidget);
      expect(find.text(s.t('landing_title')), findsNothing);
    });

    testWidgets('does not overflow on a phone, with its cards one under another', (tester) async {
      await show(tester, size: const Size(390, 6000));
      expect(tester.takeException(), isNull);
      expect(find.text(s.t('landing_f_public')), findsOneWidget);
    });
  });
}

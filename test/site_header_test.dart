import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/l10n/strings.dart';
import 'package:tyria_codex/state/navigation.dart';
import 'package:tyria_codex/theme.dart';
import 'package:tyria_codex/widgets/site_header.dart';

void main() {
  group('the bar of the site', () {
    test('has every section somewhere, and none in two places, or one could not be reached', () {
      final inBar = [
        ...siteNavSingles,
        for (final group in siteNavGroups) ...group.$2,
        // at the end of the bar, apart
        AppSection.settings,
        AppSection.about,
      ];
      expect(inBar.toSet(), AppSection.values.toSet(), reason: 'every section has its place');
      expect(inBar.length, AppSection.values.length, reason: 'and only one');
    });

    test('has the groups the menu of the app has', () {
      expect(siteNavGroups.map((g) => g.$1), ['nav_group_account', 'nav_group_economy', 'nav_group_world', 'nav_group_reference']);
    });
  });

  group('the address of a page of the static site', () {
    test('is at the root in English and in a folder of its own in the other languages', () {
      expect(sitePageUrl(AppLang.en, 'privacy'), 'https://yesanith.github.io/tyria-companion/privacy.html');
      expect(sitePageUrl(AppLang.tr, 'privacy'), 'https://yesanith.github.io/tyria-companion/tr/privacy.html');
      expect(sitePageUrl(AppLang.de, 'terms'), 'https://yesanith.github.io/tyria-companion/de/terms.html');
    });

    test('is one for every language the app has, so no page is left without', () {
      for (final lang in AppLang.values) {
        final url = sitePageUrl(lang, 'privacy');
        expect(url.startsWith(siteBase), isTrue, reason: lang.code);
        expect(url.endsWith('privacy.html'), isTrue, reason: lang.code);
      }
    });
  });

  group('the header as a widget', () {
    Future<void> show(
      WidgetTester tester, {
      required AppSection current,
      required void Function(AppSection) onSelect,
      Size size = const Size(1400, 900),
      bool busy = false,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          appBar: SiteHeader(
            current: current,
            onSelect: onSelect,
            labels: {for (final sec in AppSection.values) sec: 'S-${sec.name}'},
            icons: {for (final sec in AppSection.values) sec: Icons.circle},
            groupLabels: const ['Account', 'Economy', 'World', 'Reference'],
            account: 'Leo.1234',
            busy: busy,
            progress: 0.5,
          ),
          body: const SizedBox.expand(),
        ),
      ));
    }

    testWidgets('has the name, the sections that stand alone, the groups, the account and the settings', (tester) async {
      await show(tester, current: AppSection.home, onSelect: (_) {});
      expect(find.text('Tyria Codex'), findsOneWidget);
      for (final sec in siteNavSingles) {
        expect(find.text('S-${sec.name}'), findsOneWidget, reason: sec.name);
      }
      for (final label in ['Account', 'Economy', 'World', 'Reference']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Leo.1234'), findsOneWidget);
      expect(find.byTooltip('S-settings'), findsOneWidget);
      expect(find.byTooltip('S-about'), findsOneWidget);
      expect(find.text('S-trading'), findsNothing, reason: 'the sections of a group are under its heading, shut');
    });

    testWidgets('goes to a section that stands alone, to the settings and to the home page by its name', (tester) async {
      final chosen = <AppSection>[];
      await show(tester, current: AppSection.home, onSelect: chosen.add);
      await tester.tap(find.text('S-daily'));
      await tester.tap(find.byTooltip('S-settings'));
      await tester.tap(find.byTooltip('S-about'));
      await tester.tap(find.text('Tyria Codex'));
      expect(chosen, [AppSection.daily, AppSection.settings, AppSection.about, AppSection.home]);
    });

    testWidgets('opens a group under its heading, and what is chosen in it is gone to and the menu shut', (tester) async {
      final chosen = <AppSection>[];
      await show(tester, current: AppSection.home, onSelect: chosen.add);
      await tester.tap(find.text('Economy'));
      await tester.pumpAndSettle();
      expect(find.text('S-trading'), findsOneWidget);
      expect(find.text('S-recipes'), findsOneWidget);
      expect(find.text('S-maps'), findsNothing, reason: 'another group is not in it');
      await tester.tap(find.text('S-recipes'));
      await tester.pumpAndSettle();
      expect(chosen, [AppSection.recipes]);
      expect(find.text('S-recipes'), findsNothing, reason: 'the menu is shut');
    });

    testWidgets('shows which page it is: the section, or the group the section is in', (tester) async {
      await show(tester, current: AppSection.daily, onSelect: (_) {});
      bool selected(String label) => tester.widget<SiteNavButton>(find.widgetWithText(SiteNavButton, label)).selected;
      expect(selected('S-daily'), isTrue);
      expect(selected('S-home'), isFalse);
      expect(selected('Economy'), isFalse);
      await show(tester, current: AppSection.trading, onSelect: (_) {});
      expect(selected('Economy'), isTrue, reason: 'the trading post is in the economy');
      expect(selected('World'), isFalse);
      expect(selected('S-daily'), isFalse);
    });

    testWidgets('does not overflow in a window just wide enough for it, and has the progress bar only while something is updating', (tester) async {
      await show(tester, current: AppSection.home, onSelect: (_) {}, size: const Size(1100, 800));
      expect(tester.takeException(), isNull);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await show(tester, current: AppSection.home, onSelect: (_) {}, size: const Size(1100, 800), busy: true);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('the footer', () {
    testWidgets('has the note and the links, which are followed', (tester) async {
      final followed = <String>[];
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          bottomNavigationBar: SiteFooter(
            note: 'An unofficial companion',
            links: [
              (label: 'Privacy', onTap: () => followed.add('privacy')),
              (label: 'Source code', onTap: () => followed.add('source')),
            ],
          ),
        ),
      ));
      expect(find.text('An unofficial companion'), findsOneWidget);
      await tester.tap(find.text('Privacy'));
      await tester.tap(find.text('Source code'));
      expect(followed, ['privacy', 'source']);
    });
  });
}

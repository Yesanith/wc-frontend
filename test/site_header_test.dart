import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/l10n/strings.dart';
import 'package:wondrous_compass/state/navigation.dart';
import 'package:wondrous_compass/theme.dart';
import 'package:wondrous_compass/widgets/site_header.dart';

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
      expect(siteNavGroups.map((g) => g.$1), [
        'nav_group_account',
        'nav_group_economy',
        'nav_group_world',
        'nav_group_reference',
      ]);
    });
  });

  group('what the bar has room for', () {
    test(
      'is a site from a width that has room for the whole bar, with the search as a button where the box does not fit',
      () {
        expect(siteMinWidth, 1280);
        expect(siteMinWidth < 1500, isTrue, reason: 'where the box would not fit the search is a button');
        expect(siteBarLayout(siteMinWidth).searchWidth, isNull);
      },
    );

    test('is a search that is a button on a window that is not wide, a narrower box on a wider one, and a wide one with the account on the widest', () {
      expect(siteBarLayout(1000).searchWidth, isNull);
      expect(siteBarLayout(1499).searchWidth, isNull);
      expect(siteBarLayout(1500).searchWidth, 200);
      expect(siteBarLayout(1699).searchWidth, 200);
      expect(siteBarLayout(1700).searchWidth, 260);
      expect(siteBarLayout(3840).searchWidth, 260);
    });

    test('has the account only where the bar is widest, and never takes it when the search is a button', () {
      expect(siteBarLayout(1000).account, isFalse);
      expect(siteBarLayout(1699).account, isFalse);
      expect(siteBarLayout(1700).account, isTrue);
      for (var w = 800.0; w <= 3000; w += 50) {
        final layout = siteBarLayout(w);
        if (layout.searchWidth == null) expect(layout.account, isFalse, reason: '$w');
      }
    });

    test('only gets wider with the window: a window wider than another has at least as much of the bar', () {
      var previous = siteBarLayout(800);
      for (var w = 850.0; w <= 3000; w += 50) {
        final now = siteBarLayout(w);
        expect((now.searchWidth ?? 0) >= (previous.searchWidth ?? 0), isTrue, reason: '$w');
        expect(now.account || !previous.account, isTrue, reason: '$w');
        previous = now;
      }
    });
  });

  group('the heading and the title of a page', () {
    test('a page in a group says the group, and one that stands alone none', () {
      expect(siteGroupIndex(AppSection.trading), 1);
      expect(siteNavGroups[siteGroupIndex(AppSection.trading)!].$1, 'nav_group_economy');
      expect(siteGroupIndex(AppSection.wiki), 3);
      expect(siteGroupIndex(AppSection.home), isNull);
      expect(siteGroupIndex(AppSection.daily), isNull);
      expect(siteGroupIndex(AppSection.settings), isNull);
    });

    test('every section of a group has its group, and the others have none', () {
      for (final sec in AppSection.values) {
        final inGroup = siteNavGroups.any((g) => g.$2.contains(sec));
        expect(siteGroupIndex(sec) != null, inGroup, reason: sec.name);
      }
    });

    test('the tab says the page and the site, the site alone for the home page', () {
      expect(sitePageTitle(AppSection.home, 'Home'), 'Wondrous Compass');
      expect(sitePageTitle(AppSection.trading, 'Trading post'), 'Trading post · Wondrous Compass');
    });

    testWidgets('the heading has the group above the name, and none above a page that stands alone', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(
            body: Column(
              children: [
                SitePageHeading(title: 'Trading post', kicker: 'Economy'),
                SitePageHeading(title: 'Daily'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('ECONOMY'), findsOneWidget, reason: 'in capitals, small');
      expect(find.text('Trading post'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('DAILY'), findsNothing);
    });
  });

  group('the address of a page of the static site', () {
    test('is at the root in English and in a folder of its own in the other languages', () {
      expect(sitePageUrl(AppLang.en, 'privacy'), 'https://yesanith.github.io/wc-frontend/privacy.html');
      expect(sitePageUrl(AppLang.tr, 'privacy'), 'https://yesanith.github.io/wc-frontend/tr/privacy.html');
      expect(sitePageUrl(AppLang.de, 'terms'), 'https://yesanith.github.io/wc-frontend/de/terms.html');
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
      Size size = const Size(1800, 900),
      bool busy = false,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );
    }

    testWidgets('has the name, the sections that stand alone, the groups, the account and the settings', (
      tester,
    ) async {
      await show(tester, current: AppSection.home, onSelect: (_) {});
      expect(find.text('Wondrous Compass'), findsOneWidget);
      for (final sec in siteNavSingles) {
        expect(find.text('S-${sec.name}'), findsOneWidget, reason: sec.name);
      }
      for (final label in ['Account', 'Economy', 'World', 'Reference']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Leo.1234'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget, reason: 'the account is a badge');
      expect(find.byTooltip('S-settings'), findsOneWidget);
      expect(find.byTooltip('S-about'), findsOneWidget);
      expect(find.text('S-trading'), findsNothing, reason: 'the sections of a group are under its heading, shut');
    });

    testWidgets(
      'has every section within reach at every width the page gives it, with the search the bar has room for in it',
      (tester) async {
        addTearDown(tester.view.reset);
        for (final width in [siteMinWidth, 1300.0, 1499.0, 1500.0, 1699.0, 1700.0, 1900.0, 2560.0]) {
          final layout = siteBarLayout(width);
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(),
              // the font of a test has every letter as wide as it is tall, a real one a little over half of that
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.6)),
                child: child!,
              ),
              home: Scaffold(
                appBar: SiteHeader(
                  current: AppSection.home,
                  onSelect: (_) {},
                  labels: {for (final sec in AppSection.values) sec: 'S-${sec.name}'},
                  icons: {for (final sec in AppSection.values) sec: Icons.circle},
                  groupLabels: const ['Account', 'Economy', 'World', 'Reference'],
                  account: layout.account ? 'Leo.1234' : null,
                  search: SizedBox(width: layout.searchWidth ?? 48, child: const Text('SEARCH')),
                ),
                body: const SizedBox.expand(),
              ),
            ),
          );
          for (final label in [
            'S-home',
            'S-bosses',
            'S-daily',
            'S-weekly',
            'Account',
            'Economy',
            'World',
            'Reference',
          ]) {
            expect(find.text(label).hitTestable(), findsOneWidget, reason: '$label at $width');
          }
          expect(tester.takeException(), isNull, reason: 'at $width');
        }
      },
    );

    testWidgets('has the search between the sections and the account when it is given one, and none when it is not', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget header({Widget? search}) => MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          appBar: SiteHeader(
            current: AppSection.home,
            onSelect: (_) {},
            labels: {for (final sec in AppSection.values) sec: 'S-${sec.name}'},
            icons: {for (final sec in AppSection.values) sec: Icons.circle},
            groupLabels: const ['Account', 'Economy', 'World', 'Reference'],
            account: 'Leo.1234',
            search: search,
          ),
          body: const SizedBox.expand(),
        ),
      );
      await tester.pumpWidget(header());
      expect(find.text('SEARCH BOX'), findsNothing);
      await tester.pumpWidget(header(search: const SizedBox(width: 260, child: Text('SEARCH BOX'))));
      expect(find.text('SEARCH BOX'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final box = tester.getCenter(find.text('SEARCH BOX')).dx;
      expect(box < tester.getCenter(find.text('Leo.1234')).dx, isTrue, reason: 'before the account');
      expect(box > tester.getCenter(find.text('S-weekly')).dx, isTrue, reason: 'after the sections');
    });

    testWidgets('goes to a section that stands alone, to the settings and to the home page by its name', (
      tester,
    ) async {
      final chosen = <AppSection>[];
      await show(tester, current: AppSection.home, onSelect: chosen.add);
      await tester.tap(find.text('S-daily'));
      await tester.tap(find.byTooltip('S-settings'));
      await tester.tap(find.byTooltip('S-about'));
      await tester.tap(find.text('Wondrous Compass'));
      expect(chosen, [AppSection.daily, AppSection.settings, AppSection.about, AppSection.home]);
    });

    testWidgets('opens a group under its heading, and what is chosen in it is gone to and the menu shut', (
      tester,
    ) async {
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

    testWidgets(
      'does not overflow in a window just wide enough for it, and has the progress bar only while something is updating',
      (tester) async {
        await show(tester, current: AppSection.home, onSelect: (_) {}, size: const Size(1100, 800));
        expect(tester.takeException(), isNull);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await show(tester, current: AppSection.home, onSelect: (_) {}, size: const Size(1100, 800), busy: true);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );
  });

  group('the footer', () {
    testWidgets('is one thin line where there is room for it, and does not fill the window', (tester) async {
      tester.view.physicalSize = const Size(1800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            bottomNavigationBar: SiteFooter(
              note: 'An unofficial companion',
              links: [(label: 'Privacy', onTap: () {})],
              year: 2026,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(SiteFooter)).height,
        SiteFooter.height + 1,
        reason: 'a line, and the rule above it',
      );
      final owner = tester.getTopLeft(find.text('© 2026 Wondrous Compass')).dy;
      final link = tester.getTopLeft(find.text('Privacy')).dy;
      expect((owner - link).abs() < 12, isTrue, reason: 'on one line');
    });

    testWidgets('puts its parts one under another where there is no room for a line, and does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            bottomNavigationBar: SiteFooter(
              note: 'An unofficial Guild Wars 2 companion. Not affiliated with ArenaNet or NCSOFT.',
              links: [
                (label: 'Privacy', onTap: () {}),
                (label: 'Terms', onTap: () {}),
                (label: 'Source code', onTap: () {}),
              ],
              year: 2026,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('© 2026 Wondrous Compass'), findsOneWidget);
      expect(find.text('Source code'), findsOneWidget);
      final owner = tester.getTopLeft(find.text('© 2026 Wondrous Compass')).dy;
      final note = tester.getTopLeft(find.textContaining('An unofficial')).dy;
      final link = tester.getTopLeft(find.text('Privacy')).dy;
      expect(owner < note && note < link, isTrue, reason: 'one under another');
    });

    testWidgets('says whose it is and the year, the year of the day when none is given', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(
            bottomNavigationBar: SiteFooter(note: 'note', links: [], year: 2031),
          ),
        ),
      );
      expect(find.text('© 2031 Wondrous Compass'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(
            bottomNavigationBar: SiteFooter(note: 'note', links: []),
          ),
        ),
      );
      expect(find.text('© ${DateTime.now().year} Wondrous Compass'), findsOneWidget);
    });

    testWidgets('has the note and the links, which are followed', (tester) async {
      final followed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
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
        ),
      );
      expect(find.text('An unofficial companion'), findsOneWidget);
      await tester.tap(find.text('Privacy'));
      await tester.tap(find.text('Source code'));
      expect(followed, ['privacy', 'source']);
    });
  });
}

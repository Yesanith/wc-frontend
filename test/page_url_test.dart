import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/state/navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the address of a page', () {
    test('is its own for every page, so that no two pages are the same address', () {
      expect(sectionPaths.keys.toSet(), AppSection.values.toSet(), reason: 'every page has one');
      expect(sectionPaths.values.toSet().length, AppSection.values.length, reason: 'and not one of another');
      for (final path in sectionPaths.values) {
        expect(path.startsWith('/'), isTrue, reason: path);
        expect(path, path.toLowerCase(), reason: 'in small letters, as an address is');
        expect(path.contains(' '), isFalse, reason: path);
      }
    });

    test('is found again as the page it is, for every page', () {
      for (final section in AppSection.values) {
        expect(sectionFromPath(sectionPath(section)), section, reason: section.name);
      }
    });

    test('is the home page at the root, and the pages are where people expect them', () {
      expect(sectionPath(AppSection.home), '/');
      expect(sectionPath(AppSection.trading), '/trading');
      expect(sectionPath(AppSection.maps), '/map');
      expect(sectionPath(AppSection.guildEvents), '/guild-events');
      expect(sectionPath(AppSection.publicEvents), '/events');
    });

    test('is the page whatever the slash, the query or the case, and the home page when there is none', () {
      expect(sectionFromPath('/trading/'), AppSection.trading);
      expect(sectionFromPath('/Trading'), AppSection.trading);
      expect(sectionFromPath('trading'), AppSection.trading);
      expect(sectionFromPath('/trading?item=19721'), AppSection.trading);
      expect(sectionFromPath('/trading#top'), AppSection.trading);
      expect(sectionFromPath(''), AppSection.home);
      expect(sectionFromPath(null), AppSection.home);
      expect(sectionFromPath('/'), AppSection.home);
    });

    test('is none when it is none of the pages: an address of a login, a page that is not there', () {
      expect(sectionFromPath('/nonsense'), isNull);
      expect(sectionFromPath('/trading/extra'), isNull);
      expect(sectionFromPath('/access_token=abc&type=bearer'), isNull);
      expect(sectionFromPath('/code=abc123'), isNull);
    });
  });

  group('the page the app opens at', () {
    test('is the one in the address that was given, and the home page when it is none', () {
      expect(initialSection(route: '/wiki'), AppSection.wiki);
      expect(initialSection(route: '/nonsense'), AppSection.home);
      expect(initialSection(route: '/'), AppSection.home);
      expect(initialSection(), AppSection.home, reason: 'outside a browser it is the home page');
    });
  });

  group('the back and forward buttons of the browser', () {
    tearDown(() => sectionFromBrowser = null);

    test('show the page the address is, once, and say it is dealt with', () {
      final shown = <AppSection>[];
      expect(followBrowser(Uri.parse('/trading'), AppSection.home, shown.add), isTrue);
      expect(shown, [AppSection.trading]);
      expect(sectionFromBrowser, AppSection.trading, reason: 'so that it is not put in the history again');
    });

    test('change nothing for the page that is shown already, and still say it is dealt with', () {
      final shown = <AppSection>[];
      expect(followBrowser(Uri.parse('/trading'), AppSection.trading, shown.add), isTrue);
      expect(shown, isEmpty);
      expect(sectionFromBrowser, isNull);
    });

    test(
        'say it is dealt with for an address that is no page, so that it is not taken for a page of the navigator to push',
        () {
      final shown = <AppSection>[];
      expect(followBrowser(Uri.parse('/access_token=abc'), AppSection.home, shown.add), isTrue);
      expect(shown, isEmpty);
    });
  });

  group('a page that is a new address', () {
    final calls = <Map<dynamic, dynamic>>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, (call) async {
        if (call.method == 'routeInformationUpdated') calls.add(call.arguments as Map);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, null);
      sectionFromBrowser = null;
    });

    test('is told to the browser as its address, a new place in its history', () {
      announceSection(AppSection.trading);
      expect(calls.single['uri'], '/trading');
      expect(calls.single['replace'], false);
      announceSection(AppSection.home);
      expect(calls.last['uri'], '/');
    });

    test('is not told when the browser itself went there, and the next one is', () {
      sectionFromBrowser = AppSection.wiki;
      announceSection(AppSection.wiki);
      expect(calls, isEmpty, reason: 'it is in the history already');
      expect(sectionFromBrowser, isNull);
      announceSection(AppSection.news);
      expect(calls.single['uri'], '/news');
    });

    test('is told when it is another page than the one the browser went to', () {
      sectionFromBrowser = AppSection.wiki;
      announceSection(AppSection.news);
      expect(calls.single['uri'], '/news');
      expect(sectionFromBrowser, isNull);
    });
  });

  group('the address put back', () {
    final calls = <Map<dynamic, dynamic>>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, (call) async {
        if (call.method == 'routeInformationUpdated') calls.add(call.arguments as Map);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, null);
    });

    test('is the page the app is at, in place of what is there and with no new place in the history', () {
      restoreSectionUrl(AppSection.wiki);
      expect(calls.single['uri'], '/wiki');
      expect(calls.single['replace'], true);
      restoreSectionUrl(AppSection.home);
      expect(calls.last['uri'], '/');
      expect(calls.last['replace'], true);
    });

    test('is asked for whenever a route is pushed, taken off, removed or replaced, by the observer of the navigator',
        () {
      var asked = 0;
      final observer = UrlRestorer(() => asked++);
      final a = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      final b = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      observer.didPush(a, null);
      observer.didPop(a, null);
      observer.didRemove(a, b);
      observer.didReplace(newRoute: b, oldRoute: a);
      expect(asked, 4);
    });
  });
}

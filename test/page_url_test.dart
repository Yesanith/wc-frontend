import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/navigation.dart';
import 'package:wondrous_compass/widgets/site_header.dart' show siteGroupIndex;

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

    test('has a history of the pages, which the back and forward buttons go between', () async {
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, (call) async {
        methods.add(call.method);
        return null;
      });
      await keepHistoryOfPages();
      expect(methods, ['selectMultiEntryHistory']);
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

  const eventId = '3f2a9c1e-5b7d-4e8a-9c6b-0d1e2f3a4b5c';

  group('the address of an item or an event', () {
    test('is /item/ and the number of the item, or /event/ and the number of the event, and a page is as it was', () {
      expect(linkFromPath('/item/19721'), const ItemLink(19721));
      expect(linkFromPath('/event/$eventId'), const EventLink(eventId));
      expect(linkFromPath('/trading'), const SectionLink(AppSection.trading));
      expect(linkFromPath('/'), const SectionLink(AppSection.home));
      expect(linkFromPath(''), const SectionLink(AppSection.home));
      expect(linkFromPath(null), const SectionLink(AppSection.home));
    });

    test('is found whatever the case, a slash at the end, a query or a fragment', () {
      expect(linkFromPath('/ITEM/19721/'), const ItemLink(19721));
      expect(linkFromPath('item/19721'), const ItemLink(19721), reason: 'the slash at the front is not needed');
      expect(linkFromPath('/item/19721?lang=de'), const ItemLink(19721));
      expect(linkFromPath('/item/19721#top'), const ItemLink(19721));
      expect(linkFromPath('/event/${eventId.toUpperCase()}'), const EventLink(eventId),
          reason: 'a number is kept in small letters');
    });

    test('is none when it is not an item or an event, so that nothing is made up of what is not one', () {
      for (final path in [
        '/item',
        '/item/',
        '/item/0',
        '/item/-5',
        '/item/abc',
        '/item/12.5',
        '/item/1234567890',
        '/item/19721/extra',
        '/event',
        '/event/',
        '/event/abc',
        '/event/${eventId.substring(1)}',
        '/event/${eventId}0',
        '/event/${eventId.replaceAll('-', '')}',
        '/event/zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz',
        '/events/$eventId',
        '/items/19721',
        '/nothing',
        '/access_token=abc',
      ]) {
        expect(linkFromPath(path), isNull, reason: path);
      }
    });

    test('is written as it is read, for an item, an event and every page', () {
      expect(linkPath(const ItemLink(19721)), '/item/19721');
      expect(linkPath(const EventLink(eventId)), '/event/$eventId');
      expect(linkPath(EventLink(eventId.toUpperCase())), '/event/$eventId', reason: 'in small letters');
      for (final section in AppSection.values) {
        expect(linkFromPath(linkPath(SectionLink(section))), SectionLink(section), reason: '$section');
      }
      expect(linkFromPath(linkPath(const ItemLink(5))), const ItemLink(5));
      expect(linkFromPath(linkPath(const EventLink(eventId))), const EventLink(eventId));
    });

    test('is a whole address when it is shared, which opens the app at it', () {
      expect(linkUrl(const ItemLink(19721)), 'https://yesanith.github.io/wc-frontend/app/#/item/19721');
      expect(linkUrl(const EventLink(eventId)), 'https://yesanith.github.io/wc-frontend/app/#/event/$eventId');
      expect(linkUrl(const SectionLink(AppSection.trading)), 'https://yesanith.github.io/wc-frontend/app/#/trading');
      expect(linkUrl(const SectionLink(AppSection.home)), 'https://yesanith.github.io/wc-frontend/app/#/');
      expect(appBase.endsWith('/app/'), isTrue);
    });

    test('has links that are equal when they are of the same thing and not otherwise', () {
      expect(const ItemLink(1), const ItemLink(1));
      expect(const ItemLink(1), isNot(const ItemLink(2)));
      expect(const EventLink(eventId), const EventLink(eventId));
      expect(const SectionLink(AppSection.bosses), const SectionLink(AppSection.bosses));
      expect(const SectionLink(AppSection.bosses), isNot(const SectionLink(AppSection.daily)));
      expect(const ItemLink(1), isNot(const SectionLink(AppSection.home)));
      final set = <AppLink>{};
      set
        ..add(const ItemLink(1))
        ..add(const ItemLink(1))
        ..add(const EventLink(eventId));
      expect(set.length, 2, reason: 'and in a set');
    });

    test('tells a number that is an event\'s', () {
      expect(isEventId(eventId), isTrue);
      expect(isEventId(eventId.toUpperCase()), isTrue);
      for (final bad in [null, '', 'abc', '123', '${eventId}x', ' $eventId']) {
        expect(isEventId(bad), isFalse, reason: '$bad');
      }
    });
  });

  group('what a link is behind', () {
    test('is the page itself, the trading post for an item, the public events for an event', () {
      expect(sectionForLink(const SectionLink(AppSection.wiki)), AppSection.wiki);
      expect(sectionForLink(const ItemLink(5)), AppSection.trading);
      expect(sectionForLink(const EventLink(eventId)), AppSection.publicEvents);
    });

    test('is what the app begins at: the page behind the link, and the link itself', () {
      expect(initialLink(route: '/item/5'), const ItemLink(5));
      expect(initialSection(route: '/item/5'), AppSection.trading);
      expect(initialLink(route: '/event/$eventId'), const EventLink(eventId));
      expect(initialSection(route: '/event/$eventId'), AppSection.publicEvents);
      expect(initialLink(route: '/wiki'), const SectionLink(AppSection.wiki));
      expect(initialSection(route: '/wiki'), AppSection.wiki);
      expect(initialLink(route: '/nothing'), isNull);
      expect(initialSection(route: '/nothing'), AppSection.home, reason: 'not a page is the home page');
      expect(initialSection(route: '/item/0'), AppSection.home, reason: 'nor is an item that is none');
      expect(initialLink(), isNull, reason: 'outside a browser the app begins at no link');
    });
  });

  group('what a notification opens', () {
    test('is the public event it is about, or the item', () {
      expect(linkFromPushData({'open_event_id': eventId, 'kind': 'open_reminder'}), const EventLink(eventId));
      expect(linkFromPushData({'open_event_id': eventId.toUpperCase(), 'kind': 'open_cancelled'}),
          const EventLink(eventId));
      expect(linkFromPushData({'item_id': '19721', 'kind': 'price'}), const ItemLink(19721),
          reason: 'a notification carries text only');
      expect(linkFromPushData({'item_id': 19721}), const ItemLink(19721));
    });

    test('is the event when it carries both, and nothing when it carries neither', () {
      expect(linkFromPushData({'open_event_id': eventId, 'item_id': '5'}), const EventLink(eventId));
      expect(linkFromPushData({'event_id': eventId, 'kind': 'reminder'}), isNull,
          reason: 'a guild\'s event is not a public one');
      expect(linkFromPushData({'kind': 'promoted'}), isNull);
      expect(linkFromPushData({}), isNull);
      expect(linkFromPushData(null), isNull);
    });

    test('is nothing for a number that is none, so that a bad notification opens nothing', () {
      expect(linkFromPushData({'open_event_id': 'abc'}), isNull);
      expect(linkFromPushData({'open_event_id': ''}), isNull);
      expect(linkFromPushData({'open_event_id': 5}), isNull);
      expect(linkFromPushData({'item_id': '0'}), isNull);
      expect(linkFromPushData({'item_id': '-3'}), isNull);
      expect(linkFromPushData({'item_id': 'x'}), isNull);
      expect(linkFromPushData({'open_event_id': 'abc', 'item_id': '7'}), const ItemLink(7),
          reason: 'what is good is used');
    });
  });

  group('the address in the browser', () {
    const home = AppSection.home;

    test('is what is open over the page, or else a link not opened yet, or else the page', () {
      expect(currentAddress(section: AppSection.wiki), '/wiki');
      expect(currentAddress(section: AppSection.wiki, pending: const ItemLink(5)), '/item/5');
      expect(currentAddress(section: AppSection.wiki, open: const EventLink(eventId)), '/event/$eventId');
      expect(currentAddress(section: AppSection.wiki, open: const ItemLink(1), pending: const ItemLink(2)), '/item/1');
      expect(currentAddress(section: home), '/');
    });
  });

  group('a link that is open over the page', () {
    final calls = <Map<dynamic, dynamic>>[];
    late ProviderContainer container;

    setUp(() {
      calls.clear();
      container = ProviderContainer();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, (call) async {
        if (call.method == 'routeInformationUpdated') calls.add(call.arguments as Map);
        return null;
      });
    });

    tearDown(() {
      container.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, null);
    });

    test('is the open one while it is, and its address is a new place in the history', () {
      final closed = linkOpened(container, const ItemLink(19721), announce: true, web: true);
      expect(container.read(openLinkProvider), const ItemLink(19721));
      expect(calls.single['uri'], '/item/19721');
      expect(calls.single['replace'], false, reason: 'back goes back from it');
      closed();
    });

    test('has no address put in the browser when it is one that was followed or that the app was opened with', () {
      linkOpened(container, const ItemLink(5), announce: false, web: true);
      expect(container.read(openLinkProvider), const ItemLink(5), reason: 'it is open all the same');
      expect(calls, isEmpty, reason: 'the browser is already there');
    });

    test('has no address outside a browser, which has none', () {
      final closed = linkOpened(container, const ItemLink(5), announce: true, web: false);
      expect(container.read(openLinkProvider), const ItemLink(5));
      closed();
      expect(container.read(openLinkProvider), isNull);
      expect(calls, isEmpty);
    });

    test('puts the address of the page back in place of its own when it is closed', () {
      container.read(sectionProvider.notifier).state = AppSection.wiki;
      final closed = linkOpened(container, const EventLink(eventId), announce: true, web: true);
      calls.clear();
      closed();
      expect(container.read(openLinkProvider), isNull);
      expect(calls.single['uri'], '/wiki');
      expect(calls.single['replace'], true, reason: 'in place, not a new place in the history');
    });

    test('puts the address of a link not opened yet back, when that is what the browser has to say', () {
      container.read(pendingLinkProvider.notifier).state = const ItemLink(9);
      final closed = linkOpened(container, const ItemLink(5), announce: false, web: true);
      closed();
      expect(calls.single['uri'], '/item/9');
    });

    test('is not closed by the closing of one that was open before it: the browser went from one link to another', () {
      final first = linkOpened(container, const ItemLink(1), announce: false, web: true);
      final second = linkOpened(container, const ItemLink(2), announce: false, web: true);
      calls.clear();
      first();
      expect(container.read(openLinkProvider), const ItemLink(2), reason: 'the second is still open');
      expect(calls, isEmpty);
      second();
      expect(container.read(openLinkProvider), isNull);
      expect(calls.length, 1);
    });

    test('is closed once, closing it again does nothing', () {
      final closed = linkOpened(container, const ItemLink(1), announce: false, web: true);
      closed();
      calls.clear();
      closed();
      expect(calls, isEmpty);
      expect(container.read(openLinkProvider), isNull);
    });

    test('is forgotten without the address being touched when the browser itself has closed it', () {
      final closed = linkOpened(container, const ItemLink(1), announce: true, web: true);
      calls.clear();
      // the app closes it for a browser that went back: it forgets it first, and the sheet's own closing then finds nothing to do
      container.read(openLinkProvider.notifier).state = null;
      closed();
      expect(calls, isEmpty);
    });
  });

  group('the browser going to a link', () {
    test('opens an item or an event, and no page is shown', () {
      final shown = <AppSection>[];
      final opened = <AppLink>[];
      expect(followBrowser(Uri.parse('/item/19721'), AppSection.home, shown.add, open: opened.add), isTrue);
      expect(followBrowser(Uri.parse('/event/$eventId'), AppSection.home, shown.add, open: opened.add), isTrue);
      expect(opened, [const ItemLink(19721), const EventLink(eventId)]);
      expect(shown, isEmpty);
    });

    test('does not open one that is none, and is not taken for a page to push either', () {
      final opened = <AppLink>[];
      expect(followBrowser(Uri.parse('/item/0'), AppSection.home, (_) {}, open: opened.add), isTrue);
      expect(followBrowser(Uri.parse('/event/nope'), AppSection.home, (_) {}, open: opened.add), isTrue);
      expect(opened, isEmpty);
    });

    test('goes back from a link to the page it was opened over by closing it', () {
      var closed = 0;
      final shown = <AppSection>[];
      expect(
          followBrowser(Uri.parse('/trading'), AppSection.trading, shown.add, linkIsOpen: true, close: () => closed++),
          isTrue);
      expect(closed, 1);
      expect(shown, isEmpty, reason: 'it is the page that is shown already');
    });

    test('does not close anything when nothing is open, and shows a page that is another', () {
      var closed = 0;
      final shown = <AppSection>[];
      followBrowser(Uri.parse('/trading'), AppSection.trading, shown.add, linkIsOpen: false, close: () => closed++);
      expect(closed, 0);
      followBrowser(Uri.parse('/wiki'), AppSection.trading, shown.add, linkIsOpen: true, close: () => closed++);
      expect(shown, [AppSection.wiki]);
      expect(closed, 0, reason: 'showing a page closes what is over it by itself');
      expect(sectionFromBrowser, AppSection.wiki);
      sectionFromBrowser = null;
    });

    test('needs no callbacks to be safe, a link or a page', () {
      expect(followBrowser(Uri.parse('/item/5'), AppSection.home, (_) {}), isTrue);
      expect(followBrowser(Uri.parse('/trading'), AppSection.trading, (_) {}, linkIsOpen: true), isTrue);
    });
  });

  const guildId = '7c1d8e2a-3b4f-4a5c-8d6e-9f0a1b2c3d4e';

  group('the address of the recruitment page of a guild', () {
    test('is /recruit/ and the number of the guild, and the list is a page of its own at /recruitment', () {
      expect(linkFromPath('/recruit/$guildId'), const RecruitLink(guildId));
      expect(linkFromPath('/recruitment'), const SectionLink(AppSection.recruitment));
      expect(sectionPath(AppSection.recruitment), '/recruitment');
    });

    test('is found whatever the case, a slash at the end, a query or a fragment', () {
      expect(linkFromPath('/RECRUIT/$guildId/'), const RecruitLink(guildId));
      expect(linkFromPath('recruit/$guildId'), const RecruitLink(guildId));
      expect(linkFromPath('/recruit/$guildId?x=1#top'), const RecruitLink(guildId));
      expect(linkFromPath('/recruit/${guildId.toUpperCase()}'), const RecruitLink(guildId),
          reason: 'a number is kept in small letters');
    });

    test('is none when what follows is not the number of a guild', () {
      expect(linkFromPath('/recruit/abc'), isNull);
      expect(linkFromPath('/recruit/'), isNull);
      expect(linkFromPath('/recruit'), isNull, reason: 'the list is /recruitment');
      expect(linkFromPath('/recruit/${guildId}x'), isNull);
      expect(linkFromPath('/recruit/${'z' * 36}'), isNull, reason: 'of the right length, and not a number');
    });

    test('is written as it is read, and shared as a whole address', () {
      expect(linkPath(const RecruitLink(guildId)), '/recruit/$guildId');
      expect(linkPath(RecruitLink(guildId.toUpperCase())), '/recruit/$guildId');
      expect(linkFromPath(linkPath(const RecruitLink(guildId))), const RecruitLink(guildId));
      expect(linkUrl(const RecruitLink(guildId)), 'https://yesanith.github.io/wc-frontend/app/#/recruit/$guildId');
    });

    test('is a link of its own, not equal to an event with the same number', () {
      expect(const RecruitLink(guildId), const RecruitLink(guildId));
      expect(const RecruitLink(guildId).hashCode, const RecruitLink(guildId).hashCode);
      expect(const RecruitLink(guildId), isNot(const EventLink(guildId)));
      expect(const RecruitLink(guildId), isNot(const RecruitLink('3f2a9c1e-5b7d-4e8a-9c6b-0d1e2f3a4b5c')));
      final set = <AppLink>{}
        ..add(const RecruitLink(guildId))
        ..add(const RecruitLink(guildId))
        ..add(const EventLink(guildId));
      expect(set.length, 2);
    });

    test('is behind the recruitment page, which is what the app begins at', () {
      expect(sectionForLink(const RecruitLink(guildId)), AppSection.recruitment);
      expect(initialLink(route: '/recruit/$guildId'), const RecruitLink(guildId));
      expect(initialSection(route: '/recruit/$guildId'), AppSection.recruitment);
      expect(initialSection(route: '/recruit/nope'), AppSection.home);
    });

    test('is what the address bar says while it is open', () {
      expect(currentAddress(section: AppSection.wiki, open: const RecruitLink(guildId)), '/recruit/$guildId');
      expect(currentAddress(section: AppSection.recruitment, open: null), '/recruitment');
    });

    test('is opened by the browser going to it, and no page is shown', () {
      final shown = <AppSection>[];
      final opened = <AppLink>[];
      expect(followBrowser(Uri.parse('/recruit/$guildId'), AppSection.home, shown.add, open: opened.add), isTrue);
      expect(opened, [const RecruitLink(guildId)]);
      expect(shown, isEmpty);
    });

    test('has its own place in the menu and the bar, with the other pages of the account', () {
      expect(siteGroupIndex(AppSection.recruitment), siteGroupIndex(AppSection.publicEvents));
    });
  });
}

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter/widgets.dart' show NavigatorObserver, Route, VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// top level sections shown in the side drawer.
/// the order is the menu's: the day first, then the account, the economy,
/// the world, reference pages and finally the app itself
enum AppSection {
  home,
  bosses,
  daily,
  weekly,
  characters,
  account,
  progression,
  collections,
  guilds,
  guildEvents,
  publicEvents,
  trading,
  recipes,
  maps,
  wvw,
  professions,
  wiki,
  news,
  settings,
  about
}

/// the address of each page in a browser, after the #: the page is where /trading is. the same ones are the links people share
const sectionPaths = <AppSection, String>{
  AppSection.home: '/',
  AppSection.bosses: '/bosses',
  AppSection.daily: '/daily',
  AppSection.weekly: '/weekly',
  AppSection.characters: '/characters',
  AppSection.account: '/account',
  AppSection.progression: '/progression',
  AppSection.collections: '/collections',
  AppSection.guilds: '/guilds',
  AppSection.guildEvents: '/guild-events',
  AppSection.publicEvents: '/events',
  AppSection.trading: '/trading',
  AppSection.recipes: '/recipes',
  AppSection.maps: '/map',
  AppSection.wvw: '/wvw',
  AppSection.professions: '/professions',
  AppSection.wiki: '/wiki',
  AppSection.news: '/news',
  AppSection.settings: '/settings',
  AppSection.about: '/about',
};

String sectionPath(AppSection section) => sectionPaths[section]!;

/// an address as it is compared: no query, no fragment, no case, a slash at the front and none at the end, "/" for none
String _cleanPath(String? path) {
  var p = (path ?? '').trim().toLowerCase();
  final cut = p.indexOf(RegExp(r'[?#]'));
  if (cut >= 0) p = p.substring(0, cut);
  if (p.isEmpty) return '/';
  if (!p.startsWith('/')) p = '/$p';
  if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
  return p;
}

/// the page an address is, or null for one that is none: a trailing slash, a query and the case do not matter
AppSection? sectionFromPath(String? path) {
  final p = _cleanPath(path);
  for (final entry in sectionPaths.entries) {
    if (entry.value == p) return entry.key;
  }
  return null;
}

/// what an address opens: a page, one item, or one public event. what is shared of the app is one of these
sealed class AppLink {
  const AppLink();
}

final class SectionLink extends AppLink {
  const SectionLink(this.section);

  final AppSection section;

  @override
  bool operator ==(Object other) => other is SectionLink && other.section == section;

  @override
  int get hashCode => Object.hash('section', section);
}

final class ItemLink extends AppLink {
  const ItemLink(this.itemId);

  final int itemId;

  @override
  bool operator ==(Object other) => other is ItemLink && other.itemId == itemId;

  @override
  int get hashCode => Object.hash('item', itemId);
}

final class EventLink extends AppLink {
  const EventLink(this.eventId);

  /// the public event's number, which is a UUID
  final String eventId;

  @override
  bool operator ==(Object other) => other is EventLink && other.eventId == eventId;

  @override
  int get hashCode => Object.hash('event', eventId);
}

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

/// whether a text is the number of a public event, and so may be put in an address and be asked of the database
bool isEventId(String? text) => text != null && _uuid.hasMatch(text.toLowerCase());

/// what an address opens, or null for one that opens nothing: /item/19721 is an item, /event/<number> a public event, the rest are pages
AppLink? linkFromPath(String? path) {
  final p = _cleanPath(path);
  final item = RegExp(r'^/item/(\d{1,9})$').firstMatch(p);
  if (item != null) {
    final id = int.parse(item.group(1)!);
    return id > 0 ? ItemLink(id) : null;
  }
  final event = RegExp(r'^/event/([0-9a-f-]{36})$').firstMatch(p);
  if (event != null) return isEventId(event.group(1)) ? EventLink(event.group(1)!) : null;
  final section = sectionFromPath(path);
  return section == null ? null : SectionLink(section);
}

/// the address of a link, after the #
String linkPath(AppLink link) => switch (link) {
      SectionLink(:final section) => sectionPath(section),
      ItemLink(:final itemId) => '/item/$itemId',
      EventLink(:final eventId) => '/event/${eventId.toLowerCase()}',
    };

/// where the app is on the web. a link to it is this, and the address of the link after the #
const appBase = 'https://yesanith.github.io/tyria-companion/app/';

/// the link as it is shared: the whole address, which opens the app at it
String linkUrl(AppLink link) => '$appBase#${linkPath(link)}';

/// what a notification opens, from what it carries: a public event, or an item. a guild's event and what is not known open nothing here
AppLink? linkFromPushData(Map<String, dynamic>? data) {
  if (data == null) return null;
  final event = data['open_event_id'];
  if (event is String && isEventId(event)) return EventLink(event.toLowerCase());
  final item = int.tryParse('${data['item_id'] ?? ''}');
  if (item != null && item > 0) return ItemLink(item);
  return null;
}

/// the page that is behind a link, which is where back goes to when it is closed: a page is itself, an item is among the trading post's, a public event among the events
AppSection sectionForLink(AppLink link) => switch (link) {
      SectionLink(:final section) => section,
      ItemLink() => AppSection.trading,
      EventLink() => AppSection.publicEvents,
    };

/// what the app was opened at: the address in the browser, nothing anywhere else and when it is not an address of the app
AppLink? initialLink({String? route}) =>
    kIsWeb || route != null ? linkFromPath(route ?? PlatformDispatcher.instance.defaultRouteName) : null;

/// the page the app was opened at: the address in the browser (the page behind it when it is a link to an item or an event), the home page anywhere else and when it is not a page
AppSection initialSection({String? route}) {
  final link = initialLink(route: route);
  return link == null ? AppSection.home : sectionForLink(link);
}

final sectionProvider = StateProvider<AppSection>((ref) => initialSection());

/// the page the back or forward button of the browser went to, so that it is not put in the history a second time
AppSection? sectionFromBrowser;

/// the page is a new address in the browser, which its back button goes back from. not when the browser itself went there
void announceSection(AppSection next) {
  if (sectionFromBrowser == next) {
    sectionFromBrowser = null;
    return;
  }
  sectionFromBrowser = null;
  SystemNavigator.routeInformationUpdated(uri: Uri(path: sectionPath(next)));
}

/// lets the back and forward buttons of the browser go between the pages of the app. an app that has a navigator and no router is given a history of one place: the
/// address changes but the history does not, and the back button would go to what was before the app. with this each page is a place in the history
Future<void> keepHistoryOfPages() => SystemNavigator.selectMultiEntryHistory();

/// what the address in the browser is while the app is as it is: what is open over the page, or what a link asked for and has not been opened yet, or the page
String currentAddress({required AppSection section, AppLink? open, AppLink? pending}) =>
    linkPath(open ?? pending ?? SectionLink(section));

/// puts an address in the browser in place of what is there, so without a new place in the history
void restoreAddress(String path) => SystemNavigator.routeInformationUpdated(uri: Uri(path: path), replace: true);

/// puts the address of the page the app is at back in the browser, in place of what is there, so without a new place in the history. the navigator of the app
/// tells the browser the name of the route it is at, which is "/" for the page of the app, and so puts out the address of a page that was opened by a link, and
/// does it again when a window or a page is closed. what the page is is the app's to say
void restoreSectionUrl(AppSection section) =>
    SystemNavigator.routeInformationUpdated(uri: Uri(path: sectionPath(section)), replace: true);

/// the navigator of the app, watched: whenever a route is pushed or taken off [restore] is called, to put the address of the page back
class UrlRestorer extends NavigatorObserver {
  UrlRestorer(this.restore);

  final VoidCallback restore;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => restore();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => restore();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => restore();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => restore();
}

/// the link that is open over the page (an item's sheet, a public event's page): its address is in the browser for as long as it is
final openLinkProvider = StateProvider<AppLink?>((ref) => null);

/// a link the app was opened with that is not open yet, because what opens it is not there yet (the page waits for a player to choose to go on). the page opens it when it is
final pendingLinkProvider = StateProvider<AppLink?>((ref) => null);

/// a link is open over the page. its address is put in the browser as a new place in the history, which the back button goes back from, unless the browser is already there
/// ([announce] false: a link that was followed, or the one the app was opened with). the one to call when it is closed
VoidCallback linkOpened(ProviderContainer container, AppLink link, {required bool announce, bool web = kIsWeb}) {
  container.read(openLinkProvider.notifier).state = link;
  if (announce && web) SystemNavigator.routeInformationUpdated(uri: Uri(path: linkPath(link)));
  return () => linkClosed(container, link, web: web);
}

/// the link is closed: the address of the page is in the browser again, in place of the link's. nothing when another has been opened since (the browser went from one link to another)
void linkClosed(ProviderContainer container, AppLink link, {bool web = kIsWeb}) {
  if (container.read(openLinkProvider) != link) return;
  container.read(openLinkProvider.notifier).state = null;
  if (!web) return;
  restoreAddress(currentAddress(
    section: container.read(sectionProvider),
    pending: container.read(pendingLinkProvider),
  ));
}

/// the browser went to an address (its back or forward button, or a link): the page it is is shown, without a new place in the history, and what is open over the page is closed
/// when it goes to a page; a link to an item or an event is opened by [open]. true when the address is dealt with, a page or not, so that it is not taken for a page of the
/// navigator to push
bool followBrowser(
  Uri uri,
  AppSection current,
  void Function(AppSection section) show, {
  void Function(AppLink link)? open,
  bool linkIsOpen = false,
  VoidCallback? close,
}) {
  switch (linkFromPath(uri.path)) {
    case SectionLink(:final section):
      if (section != current) {
        sectionFromBrowser = section;
        show(section);
      } else if (linkIsOpen) {
        // back from a link to the page it was opened over
        close?.call();
      }
    case final ItemLink link:
      open?.call(link);
    case final EventLink link:
      open?.call(link);
    case null:
      break;
  }
  return true;
}

/// what somebody asked to look up in the wiki from the search of the site: the wiki page takes it and clears it
final wikiSearchRequestProvider = StateProvider<String?>((ref) => null);

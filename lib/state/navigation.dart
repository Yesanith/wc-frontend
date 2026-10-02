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

/// the page an address is, or null for one that is none: a trailing slash, a query and the case do not matter
AppSection? sectionFromPath(String? path) {
  var p = (path ?? '').trim().toLowerCase();
  final cut = p.indexOf(RegExp(r'[?#]'));
  if (cut >= 0) p = p.substring(0, cut);
  if (p.isEmpty) return AppSection.home;
  if (!p.startsWith('/')) p = '/$p';
  if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
  for (final entry in sectionPaths.entries) {
    if (entry.value == p) return entry.key;
  }
  return null;
}

/// the page the app was opened at: the address in the browser, the home page anywhere else and when it is not a page
AppSection initialSection({String? route}) => kIsWeb || route != null
    ? sectionFromPath(route ?? PlatformDispatcher.instance.defaultRouteName) ?? AppSection.home
    : AppSection.home;

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

/// the browser went to an address (its back or forward button, or a link): the page it is is shown, without a new place in the history.
/// true when the address is dealt with, a page or not, so that it is not taken for a page of the navigator to push
bool followBrowser(Uri uri, AppSection current, void Function(AppSection section) show) {
  final section = sectionFromPath(uri.path);
  if (section != null && section != current) {
    sectionFromBrowser = section;
    show(section);
  }
  return true;
}

/// what somebody asked to look up in the wiki from the search of the site: the wiki page takes it and clears it
final wikiSearchRequestProvider = StateProvider<String?>((ref) => null);

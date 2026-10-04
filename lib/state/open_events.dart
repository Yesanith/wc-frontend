import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util.dart';
import 'guild_events.dart' show eventRoleKeys;

part 'open_events/actions.dart';
part 'open_events/models.dart';

/// what a public event can be about, the same as a guild's
const openEventActivities = ['raid', 'strike', 'fractal', 'worldboss', 'meta', 'wvw', 'pvp', 'dungeon', 'other'];

/// the regions of the game, and an event for all of them
const openEventRegions = ['eu', 'na', 'all'];

/// what an event can be tagged with, up to three
const openEventTags = ['meta', 'casual', 'achievement', 'training', 'speedrun', 'new_players'];

/// the kinds a player can ask to be told of in the official Discord server
const openEventRoleKinds = ['fractal', 'raid', 'strike', 'worldboss', 'meta', 'pvp', 'wvw'];

/// the languages an event can be run in, and any
const openEventLanguages = ['any', 'en', 'de', 'es', 'fr', 'tr', 'pt', 'ru', 'ja', 'zh'];

/// how long an event can last, in minutes
const openEventDurations = [30, 60, 90, 120, 180, 240, 360];

final openEventsFilterProvider = StateProvider<OpenEventsFilter>((ref) => const OpenEventsFilter());

Future<T> _call<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on PostgrestException catch (e) {
    throw OpenEventFailure(e.hint ?? e.code ?? 'failed');
  }
}

Future<dynamic> _rpc(String fn, Map<String, dynamic> params) =>
    _call(() async => await Supabase.instance.client.rpc(fn, params: params));

/// the events to come that everybody who is signed in may see
final openEventsFeedProvider = FutureProvider.autoDispose<List<OpenEvent>>((ref) async {
  final filter = ref.watch(openEventsFilterProvider);
  return parseOpenEvents(await _rpc('open_events_feed', {
    'p_activity': filter.activity,
    'p_language': filter.language,
    'p_region': filter.region,
    'p_tag': filter.tag,
    'p_limit': 100,
    'p_offset': 0,
  }));
});

/// the player's own: what they organize and what they signed up for
final myOpenEventsProvider = FutureProvider.autoDispose<List<OpenEvent>>((ref) async {
  return parseOpenEvents(await _rpc('my_open_events', {}));
});

/// one event, as the player sees it: from their own list when it is theirs or they signed up, else from the feed.
/// null when it is not there any more
final openEventProvider = FutureProvider.autoDispose.family<OpenEvent?, String>((ref, id) async {
  final mine = parseOpenEvents(await _rpc('my_open_events', {}));
  for (final e in mine) {
    if (e.id == id) return e;
  }
  final feed = parseOpenEvents(await _rpc('open_events_feed', {'p_limit': 100, 'p_offset': 0}));
  for (final e in feed) {
    if (e.id == id) return e;
  }
  return null;
});

/// who signed up to an event of the player's, by the name of their game account
final openRosterProvider = FutureProvider.autoDispose.family<List<OpenRosterEntry>, String>((ref, id) async {
  return parseOpenRoster(await _rpc('open_event_roster', {'p_event': id}));
});

/// the roles as the database takes them, in the order they are listed, the ones with no place left out
List<Map<String, Object>> _rolesJson(Map<String, int> roles) => [
      for (final k in eventRoleKeys)
        if ((roles[k] ?? 0) > 0) {'role': k, 'slots': roles[k]!}
    ];

String _utc(DateTime t) => t.toUtc().toIso8601String();

/// one of the player's game accounts, and the region the game says it is in (null while that is not known)
typedef OpenAccount = ({String id, String name, String? region});

/// the player's game accounts and the regions they are in, which is what they may make events for and sign up to
class MyRegions {
  const MyRegions({this.accounts = const []});

  factory MyRegions.fromJson(dynamic j) {
    if (j is! Map) return const MyRegions();
    final rows = j['accounts'];
    return MyRegions(accounts: [
      if (rows is List)
        for (final r in rows)
          if (r is Map) (id: '${r['id']}', name: '${r['name']}', region: r['region'] == null ? null : '${r['region']}')
    ]);
  }

  final List<OpenAccount> accounts;

  /// eu and na, those of the accounts the game has placed
  Set<String> get regions => {
        for (final a in accounts)
          if (a.region != null) a.region!
      };

  bool get hasAccount => accounts.isNotEmpty;

  /// accounts that may take part in an event of [region]: any for all, else those of it
  List<OpenAccount> forRegion(String region) => [
        for (final a in accounts)
          if (region == 'all' || a.region == region) a
      ];

  /// the regions an event can be made for: all, and each region the player has an account in
  List<String> get makeable => [
        'all',
        for (final r in ['eu', 'na'])
          if (regions.contains(r)) r
      ];
}

final myRegionsProvider = FutureProvider.autoDispose<MyRegions>((ref) async {
  return MyRegions.fromJson(await _rpc('my_regions', {}));
});

/// whether there is an official Discord server, and how to get in
typedef OfficialDiscord = ({bool configured, String? inviteUrl});

final officialDiscordProvider = FutureProvider.autoDispose<OfficialDiscord>((ref) async {
  final j = await _rpc('official_discord_info', {});
  if (j is! Map) return (configured: false, inviteUrl: null);
  return (configured: j['configured'] == true, inviteUrl: j['invite_url'] == null ? null : '${j['invite_url']}');
});

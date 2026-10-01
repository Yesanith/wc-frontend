import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util.dart';

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

/// why the database refused, as the hint it gave
class OpenEventFailure implements Exception {
  const OpenEventFailure(this.code);

  final String code;

  @override
  String toString() => 'OpenEventFailure($code)';
}

/// the text to tell the player about a failure: the key of a string
String openEventErrorKey(Object e) {
  const keys = {
    'banned': 'oe_err_banned',
    'no_account': 'oe_err_no_account',
    'bad_title': 'oe_err_title',
    'bad_description': 'oe_err_description',
    'start_in_past': 'oe_err_start_past',
    'start_too_far': 'oe_err_start_far',
    'bad_duration': 'oe_err_duration',
    'bad_capacity': 'oe_err_capacity',
    'too_many_open': 'oe_err_many_open',
    'too_many_today': 'oe_err_many_today',
    'event_gone': 'oe_err_gone',
    'own_event': 'oe_err_own',
    'event_full': 'oe_err_full',
    'below_going': 'oe_err_below',
    'already_reported': 'oe_err_reported',
    'wrong_region': 'oe_err_wrong_region',
    'bad_region': 'oe_err_region',
    'bad_tags': 'oe_err_tags',
    'bad_map': 'oe_err_map',
  };
  final code = e is OpenEventFailure ? e.code : (e is PostgrestException ? e.hint : null);
  return keys[code] ?? 'oe_err_generic';
}

class OpenEvent {
  const OpenEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.activity,
    required this.language,
    required this.region,
    required this.tags,
    required this.mapId,
    required this.startAt,
    required this.durationMinutes,
    required this.maxParticipants,
    required this.organizer,
    required this.mine,
    required this.going,
    required this.maybe,
    required this.myStatus,
    required this.status,
    required this.hidden,
  });

  factory OpenEvent.fromJson(Map<String, dynamic> j) => OpenEvent(
        id: '${j['id']}',
        title: '${j['title'] ?? ''}',
        description: '${j['description'] ?? ''}',
        activity: '${j['activity'] ?? 'other'}',
        language: '${j['language'] ?? 'any'}',
        region: '${j['region'] ?? 'all'}',
        tags: j['tags'] is List ? [for (final t in j['tags'] as List) '$t'] : const [],
        mapId: j['map_id'] == null ? null : asInt(j['map_id']),
        startAt: DateTime.tryParse('${j['start_at'] ?? ''}')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
        durationMinutes: asInt(j['duration_minutes']),
        maxParticipants: j['max_participants'] == null ? null : asInt(j['max_participants']),
        organizer: '${j['organizer'] ?? ''}',
        mine: j['mine'] == true,
        going: asInt(j['going']),
        maybe: asInt(j['maybe']),
        myStatus: j['my_status'] == null ? null : '${j['my_status']}',
        status: '${j['status'] ?? 'scheduled'}',
        hidden: j['hidden'] == true,
      );

  final String id;
  final String title;
  final String description;
  final String activity;
  final String language;

  /// eu, na or all: an event of a region is for those with an account in it
  final String region;
  final List<String> tags;

  /// the map the game says, if the organizer gave one
  final int? mapId;
  final DateTime startAt;
  final int durationMinutes;
  final int? maxParticipants;
  final String organizer;
  final bool mine;
  final int going;
  final int maybe;

  /// what the player said: going, maybe, or nothing
  final String? myStatus;

  /// scheduled or cancelled. the feed only has scheduled ones
  final String status;

  /// waiting for an administrator to look at it, which only its organizer is told
  final bool hidden;

  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));

  bool get cancelled => status == 'cancelled';

  /// with no more places, which does not stop somebody who is going already from staying
  bool get isFull => maxParticipants != null && going >= maxParticipants!;

  int? get placesLeft => maxParticipants == null ? null : math.max(0, maxParticipants! - going);

  bool isLive(DateTime now) => !cancelled && startAt.isBefore(now) && endAt.isAfter(now);

  bool isOver(DateTime now) => endAt.isBefore(now);
}

List<OpenEvent> parseOpenEvents(dynamic rows) => rows is List
    ? [
        for (final r in rows)
          if (r is Map) OpenEvent.fromJson(Map<String, dynamic>.from(r))
      ]
    : const [];

/// a name and whether they are going, from the organizer's list of who signed up
typedef OpenRosterEntry = ({String name, String status});

List<OpenRosterEntry> parseOpenRoster(dynamic rows) => rows is List
    ? [
        for (final r in rows)
          if (r is Map) (name: '${r['name']}', status: '${r['status']}')
      ]
    : const [];

/// what the discover list is narrowed to. an activity or a language, or neither
class OpenEventsFilter {
  const OpenEventsFilter({this.activity, this.language, this.region, this.tag});

  final String? activity;

  /// an event in any language is shown whatever this is
  final String? language;

  /// an event for all regions is shown whatever this is
  final String? region;
  final String? tag;

  OpenEventsFilter withActivity(String? a) =>
      OpenEventsFilter(activity: a, language: language, region: region, tag: tag);

  OpenEventsFilter withLanguage(String? l) =>
      OpenEventsFilter(activity: activity, language: l, region: region, tag: tag);

  OpenEventsFilter withRegion(String? r) =>
      OpenEventsFilter(activity: activity, language: language, region: r, tag: tag);

  OpenEventsFilter withTag(String? t) =>
      OpenEventsFilter(activity: activity, language: language, region: region, tag: t);

  @override
  bool operator ==(Object other) =>
      other is OpenEventsFilter &&
      other.activity == activity &&
      other.language == language &&
      other.region == region &&
      other.tag == tag;

  @override
  int get hashCode => Object.hash(activity, language, region, tag);
}

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

String _utc(DateTime t) => t.toUtc().toIso8601String();

Future<String> createOpenEvent({
  required String title,
  required DateTime startAt,
  required int durationMinutes,
  required String description,
  required String activity,
  required String language,
  int? maxParticipants,
  String region = 'all',
  List<String> tags = const [],
  int? mapId,
}) async {
  final id = await _rpc('create_open_event', {
    'p_title': title,
    'p_start_at': _utc(startAt),
    'p_duration_minutes': durationMinutes,
    'p_description': description,
    'p_activity': activity,
    'p_language': language,
    'p_max_participants': maxParticipants,
    'p_region': region,
    'p_tags': tags,
    'p_map_id': mapId,
  });
  return '$id';
}

Future<void> updateOpenEvent(
  String id, {
  required String title,
  required DateTime startAt,
  required int durationMinutes,
  required String description,
  required String activity,
  required String language,
  int? maxParticipants,
  List<String> tags = const [],
  int? mapId,
}) async {
  await _rpc('update_open_event', {
    'p_event': id,
    'p_title': title,
    'p_start_at': _utc(startAt),
    'p_duration_minutes': durationMinutes,
    'p_description': description,
    'p_activity': activity,
    'p_language': language,
    'p_max_participants': maxParticipants,
    'p_tags': tags,
    'p_map_id': mapId,
  });
}

Future<void> cancelOpenEvent(String id) async {
  await _rpc('cancel_open_event', {'p_event': id});
}

Future<void> deleteOpenEvent(String id) async {
  await _rpc('delete_open_event', {'p_event': id});
}

/// signs up as going or maybe, as the account asked for, or the first of the region of the event
Future<void> joinOpenEvent(String id, String status, {String? account}) async {
  await _rpc('join_open_event', {'p_event': id, 'p_status': status, 'p_account': account});
}

Future<void> leaveOpenEvent(String id) async {
  await _rpc('leave_open_event', {'p_event': id});
}

Future<void> reportOpenEvent(String id, String reason) async {
  await _rpc('report_open_event', {'p_event': id, 'p_reason': reason, 'p_note': ''});
}

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

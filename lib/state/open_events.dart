import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util.dart';

/// what a public event can be about, the same as a guild's
const openEventActivities = ['raid', 'strike', 'fractal', 'meta', 'wvw', 'pvp', 'dungeon', 'other'];

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
  const OpenEventsFilter({this.activity, this.language});

  final String? activity;

  /// an event in any language is shown whatever this is
  final String? language;

  OpenEventsFilter withActivity(String? a) => OpenEventsFilter(activity: a, language: language);

  OpenEventsFilter withLanguage(String? l) => OpenEventsFilter(activity: activity, language: l);

  @override
  bool operator ==(Object other) =>
      other is OpenEventsFilter && other.activity == activity && other.language == language;

  @override
  int get hashCode => Object.hash(activity, language);
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
}) async {
  final id = await _rpc('create_open_event', {
    'p_title': title,
    'p_start_at': _utc(startAt),
    'p_duration_minutes': durationMinutes,
    'p_description': description,
    'p_activity': activity,
    'p_language': language,
    'p_max_participants': maxParticipants,
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
  });
}

Future<void> cancelOpenEvent(String id) async {
  await _rpc('cancel_open_event', {'p_event': id});
}

Future<void> deleteOpenEvent(String id) async {
  await _rpc('delete_open_event', {'p_event': id});
}

/// signs up as going or maybe
Future<void> joinOpenEvent(String id, String status) async {
  await _rpc('join_open_event', {'p_event': id, 'p_status': status});
}

Future<void> leaveOpenEvent(String id) async {
  await _rpc('leave_open_event', {'p_event': id});
}

Future<void> reportOpenEvent(String id, String reason) async {
  await _rpc('report_open_event', {'p_event': id, 'p_reason': reason, 'p_note': ''});
}

part of '../guild_events.dart';

/// why an event action failed, the hint the backend sent
class EventFailure implements Exception {
  const EventFailure(this.code);
  final String code;

  @override
  String toString() => code;
}

Future<T> _call<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on PostgrestException catch (e) {
    final hint = e.hint;
    if (hint != null && hint.isNotEmpty) throw EventFailure(hint);
    throw EventFailure(e.code == '42501' ? 'not_allowed' : 'event_failed');
  }
}

/// answers an event, returns the status the player ended up with: a going on
/// a full event comes back as waitlist
Future<String> rsvp(String eventId, String status, {String? role, String? profession, String? accountId}) =>
    _call(() async {
      final res = await Supabase.instance.client.rpc('rsvp', params: {
        'p_event': eventId,
        'p_status': status,
        'p_role': role,
        'p_profession': profession,
        'p_account': accountId,
      });
      return '$res';
    });

/// names the roles the player could also play, besides the one they signed up in.
/// an empty list clears them
Future<void> setFlexRoles(String eventId, List<String> roles) => _call(() async {
      await Supabase.instance.client.rpc('set_flex_roles', params: {'p_event': eventId, 'p_roles': roles});
    });

List<Map<String, dynamic>> _rolesJson(Map<String, int> roles) => [
      for (final e in roles.entries)
        if (e.value > 0) {'role': e.key, 'slots': e.value},
    ];

Future<String> createEvent({
  required String guildId,
  required String? accountId,
  required String title,
  required DateTime startAt,
  required int durationMinutes,
  required String description,
  required String activity,
  required int? maxParticipants,
  required Map<String, int> roles,
}) =>
    _call(() async {
      final res = await Supabase.instance.client.rpc('create_event', params: {
        'p_guild': guildId,
        'p_title': title,
        'p_start_at': startAt.toUtc().toIso8601String(),
        'p_duration_minutes': durationMinutes,
        'p_description': description,
        'p_activity': activity,
        'p_max_participants': maxParticipants,
        'p_roles': _rolesJson(roles),
        'p_account': accountId,
      });
      return '$res';
    });

/// a weekly event at the local time of the device's time zone, so it keeps
/// its local time across daylight saving changes. without a zone name the
/// time is sent in utc, which then stays fixed in utc
Future<String> createWeeklyEvent({
  required String guildId,
  required String? accountId,
  required String title,
  required DateTime firstStart,
  required int durationMinutes,
  required String description,
  required String activity,
  required int? maxParticipants,
  required Map<String, int> roles,
}) =>
    _call(() async {
      final zone = await deviceTimeZone();
      final at = zone == null ? firstStart.toUtc() : firstStart.toLocal();
      final res = await Supabase.instance.client.rpc('create_event_series', params: {
        'p_guild': guildId,
        'p_title': title,
        'p_weekday': at.weekday,
        'p_time_of_day': '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
        'p_timezone': zone ?? 'UTC',
        'p_duration_minutes': durationMinutes,
        'p_description': description,
        'p_activity': activity,
        'p_max_participants': maxParticipants,
        'p_roles': _rolesJson(roles),
        'p_account': accountId,
      });
      return '$res';
    });

/// the device's iana time zone, e.g. Europe/Istanbul, null when unknown
Future<String?> deviceTimeZone() async {
  try {
    final id = (await FlutterTimezone.getLocalTimezone()).identifier;
    return isIanaZone(id) ? id : null;
  } catch (_) {
    return null;
  }
}

/// looks like an iana zone name the database knows, not an abbreviation
bool isIanaZone(String id) => id == 'UTC' || RegExp(r'^[A-Z][A-Za-z_+-]*(/[A-Za-z0-9_+-]+){1,2}$').hasMatch(id);

/// saves an edit made on [version]. somebody else's edit in between makes it
/// fail with version_conflict instead of being overwritten
Future<int> updateEvent({
  required String eventId,
  required int version,
  required String title,
  required DateTime startAt,
  required int durationMinutes,
  required String description,
  required String activity,
  required int? maxParticipants,
  required Map<String, int> roles,
}) =>
    _call(() async {
      final res = await Supabase.instance.client.rpc('update_event', params: {
        'p_event': eventId,
        'p_version': version,
        'p_title': title,
        'p_start_at': startAt.toUtc().toIso8601String(),
        'p_duration_minutes': durationMinutes,
        'p_description': description,
        'p_activity': activity,
        'p_max_participants': maxParticipants,
        'p_roles': _rolesJson(roles),
      });
      return (res as num).toInt();
    });

/// removes an event opened by mistake, with its sign ups and its discord
/// messages. on a week of a weekly event, [wholeSeries] also stops the series
/// and removes its coming weeks
Future<void> deleteEvent(String eventId, {bool wholeSeries = false}) => _call(() async {
      await Supabase.instance.client.rpc('delete_event', params: {'p_event': eventId, 'p_whole_series': wholeSeries});
    });

Future<void> cancelEvent(String eventId) => _call(() async {
      await Supabase.instance.client.rpc('cancel_event', params: {'p_event': eventId});
    });

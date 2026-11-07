part of '../open_events.dart';

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
    'role_required': 'oe_err_role_required',
    'profession_required': 'oe_err_profession',
    'bad_profession': 'oe_err_profession',
    'role_full': 'oe_err_role_full',
    'bad_roles': 'oe_err_roles',
    // the database counts reports, sign ups and changes per player and hour
    'rate_limited': 'err_rate_limited',
  };
  final code = e is OpenEventFailure ? e.code : (e is PostgrestException ? e.hint : null);
  return keys[code] ?? 'oe_err_generic';
}

/// a role of an event with its places and how many are going as it
typedef OpenRole = ({String role, int slots, int taken});

List<OpenRole> parseOpenRoles(dynamic rows) => rows is List
    ? [
        for (final r in rows)
          if (r is Map) (role: '${r['role']}', slots: asInt(r['slots']), taken: asInt(r['taken']))
      ]
    : const [];

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
    this.roles = const [],
    this.myRole,
    this.myProfession,
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
        roles: parseOpenRoles(j['roles']),
        myRole: j['my_role'] == null ? null : '${j['my_role']}',
        myProfession: j['my_profession'] == null ? null : '${j['my_profession']}',
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

  /// the composition, with how many are going as each. none when anybody may come as anything
  final List<OpenRole> roles;

  /// the role and the profession the player comes as
  final String? myRole;
  final String? myProfession;

  bool get hasRoles => roles.isNotEmpty;

  /// the places of all the roles
  int get totalSlots => roles.fold(0, (a, r) => a + r.slots);

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
typedef OpenRosterEntry = ({String name, String status, String? role, String? profession});

List<OpenRosterEntry> parseOpenRoster(dynamic rows) => rows is List
    ? [
        for (final r in rows)
          if (r is Map)
            (
              name: '${r['name']}',
              status: '${r['status']}',
              role: r['role'] == null ? null : '${r['role']}',
              profession: r['profession'] == null ? null : '${r['profession']}',
            )
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

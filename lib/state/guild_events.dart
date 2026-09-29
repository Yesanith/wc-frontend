import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community.dart';

/// the kinds of activity an event can be, in the order the form offers them
const eventActivities = ['raid', 'strike', 'fractal', 'meta', 'wvw', 'pvp', 'dungeon', 'other'];

/// role keys the backend accepts, in the order they are listed
const eventRoleKeys = ['tank', 'healer', 'boon_dps', 'dps', 'support'];

/// the professions a player can sign up as, the api's ids
const eventProfessions = [
  'Guardian',
  'Warrior',
  'Engineer',
  'Ranger',
  'Thief',
  'Elementalist',
  'Mesmer',
  'Necromancer',
  'Revenant',
];

/// ready made role sets for the usual group sizes
const eventRolePresets = <String, Map<String, int>>{
  'squad10': {'healer': 2, 'boon_dps': 2, 'dps': 6},
  'party5': {'healer': 1, 'boon_dps': 1, 'dps': 3},
};

class GuildEvent {
  const GuildEvent({
    required this.id,
    required this.guildId,
    required this.guildName,
    required this.guildTag,
    required this.creatorId,
    required this.title,
    required this.description,
    required this.activity,
    required this.startAt,
    required this.durationMinutes,
    required this.maxParticipants,
    required this.cancelled,
    required this.version,
    required this.seriesId,
  });

  final String id;
  final String guildId;
  final String guildName;
  final String guildTag;
  final String creatorId;
  final String title;
  final String description;
  final String activity;
  final DateTime startAt;
  final int durationMinutes;
  final int? maxParticipants;
  final bool cancelled;
  final int version;
  final String? seriesId;

  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));

  static GuildEvent fromRow(Map<String, dynamic> r) {
    final g = r['guilds'] is Map ? r['guilds'] as Map : const {};
    return GuildEvent(
      id: '${r['id']}',
      guildId: '${r['guild_id']}',
      guildName: '${g['name'] ?? ''}',
      guildTag: '${g['tag'] ?? ''}',
      creatorId: '${r['creator_id']}',
      title: '${r['title'] ?? ''}',
      description: '${r['description'] ?? ''}',
      activity: '${r['activity'] ?? 'other'}',
      startAt: DateTime.parse('${r['start_at']}').toLocal(),
      durationMinutes: (r['duration_minutes'] as num?)?.toInt() ?? 120,
      maxParticipants: (r['max_participants'] as num?)?.toInt(),
      cancelled: r['status'] == 'cancelled',
      version: (r['version'] as num?)?.toInt() ?? 1,
      seriesId: r['series_id'] as String?,
    );
  }
}

class EventParticipant {
  const EventParticipant({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.status,
    required this.role,
    required this.joinedAt,
    this.profession,
  });

  final String userId;

  /// the gw2 account they are in the guild with
  final String name;
  final String? avatarUrl;

  /// going, maybe, declined or waitlist
  final String status;
  final String? role;
  final DateTime joinedAt;

  /// the profession they come as, asked on events with roles
  final String? profession;
}

class EventDetail {
  const EventDetail(this.event, this.roles, this.participants);

  final GuildEvent event;

  /// role key -> slots, in the order of [eventRoleKeys]
  final Map<String, int> roles;
  final List<EventParticipant> participants;

  List<EventParticipant> withStatus(String status) => participants.where((p) => p.status == status).toList();

  int get going => participants.where((p) => p.status == 'going').length;

  int goingAs(String role) => participants.where((p) => p.status == 'going' && p.role == role).length;
}

/// an event in a list, with the counts and the player's own answer
class EventSummary {
  const EventSummary(this.event, this.going, this.waiting, this.myStatus);
  final GuildEvent event;
  final int going;
  final int waiting;
  final String? myStatus;
}

const _eventColumns = 'id, guild_id, creator_id, series_id, title, description, activity, start_at, '
    'duration_minutes, max_participants, status, version, guilds(name, tag)';

/// the player's guilds' events from a few hours ago on, soonest first
final upcomingEventsProvider = FutureProvider.autoDispose<List<EventSummary>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const [];
  final client = Supabase.instance.client;
  final from = DateTime.now().toUtc().subtract(const Duration(hours: 6));
  final rows = await client
      .from('events')
      .select(_eventColumns)
      .gte('start_at', from.toIso8601String())
      .order('start_at')
      .limit(100);
  final events = [for (final r in rows) GuildEvent.fromRow(r)];
  if (events.isEmpty) return const [];
  final signups = await client
      .from('event_participants')
      .select('event_id, user_id, status')
      .inFilter('event_id', [for (final e in events) e.id]);
  final going = <String, int>{};
  final waiting = <String, int>{};
  final mine = <String, String>{};
  for (final s in signups) {
    final id = '${s['event_id']}';
    if (s['status'] == 'going') going[id] = (going[id] ?? 0) + 1;
    if (s['status'] == 'waitlist') waiting[id] = (waiting[id] ?? 0) + 1;
    if (s['user_id'] == session.user.id) mine[id] = '${s['status']}';
  }
  return [
    for (final e in events)
      // an event that ended a while ago is no longer upcoming
      if (e.endAt.isAfter(DateTime.now())) EventSummary(e, going[e.id] ?? 0, waiting[e.id] ?? 0, mine[e.id]),
  ];
});

/// one event with its roles and everybody who answered, names included
final eventDetailProvider = FutureProvider.autoDispose.family<EventDetail?, String>((ref, id) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return null;
  final client = Supabase.instance.client;
  final row = await client.from('events').select(_eventColumns).eq('id', id).maybeSingle();
  if (row == null) return null;
  final roleRows = await client.from('event_roles').select('role, slots').eq('event_id', id);
  // names come from the roster: the gw2 accounts of other members are
  // readable only there, and only for the players of this event
  final roster = await client.rpc('event_roster', params: {'p_event': id}) as List<dynamic>;
  // the usual roles in their usual order, anything else after them
  final slots = {for (final r in roleRows) '${r['role']}': (r['slots'] as num).toInt()};
  final roles = {
    for (final key in [
      ...eventRoleKeys.where(slots.containsKey),
      ...slots.keys.where((k) => !eventRoleKeys.contains(k)),
    ])
      key: slots[key]!,
  };
  return EventDetail(GuildEvent.fromRow(row), roles, [
    for (final r in roster.whereType<Map<String, dynamic>>())
      EventParticipant(
        userId: '${r['user_id']}',
        name: '${r['name'] ?? '…'}',
        avatarUrl: r['avatar_url'] as String?,
        status: '${r['status']}',
        role: r['role'] as String?,
        profession: r['profession'] as String?,
        joinedAt: DateTime.tryParse('${r['joined_at']}') ?? DateTime.now(),
      ),
  ]);
});

/// guilds where the player may create events: leader or officer there
final creatableGuildsProvider = FutureProvider.autoDispose<List<MyGuild>>((ref) async {
  final guilds = await ref.watch(myGuildsProvider.future);
  return [
    for (final g in guilds)
      if (g.role == 'leader' || g.role == 'officer') g,
  ];
});

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
Future<String> rsvp(String eventId, String status, {String? role, String? profession}) => _call(() async {
      final res = await Supabase.instance.client.rpc('rsvp', params: {
        'p_event': eventId,
        'p_status': status,
        'p_role': role,
        'p_profession': profession,
      });
      return '$res';
    });

List<Map<String, dynamic>> _rolesJson(Map<String, int> roles) => [
      for (final e in roles.entries)
        if (e.value > 0) {'role': e.key, 'slots': e.value},
    ];

Future<String> createEvent({
  required String guildId,
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
      });
      return '$res';
    });

/// a weekly event. the time is sent in utc, so a weekly event keeps its utc
/// time across daylight saving changes
Future<String> createWeeklyEvent({
  required String guildId,
  required String title,
  required DateTime firstStart,
  required int durationMinutes,
  required String description,
  required String activity,
  required int? maxParticipants,
  required Map<String, int> roles,
}) =>
    _call(() async {
      final utc = firstStart.toUtc();
      final res = await Supabase.instance.client.rpc('create_event_series', params: {
        'p_guild': guildId,
        'p_title': title,
        'p_weekday': utc.weekday,
        'p_time_of_day': '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}',
        'p_timezone': 'UTC',
        'p_duration_minutes': durationMinutes,
        'p_description': description,
        'p_activity': activity,
        'p_max_participants': maxParticipants,
        'p_roles': _rolesJson(roles),
      });
      return '$res';
    });

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

/// whether the player may cancel or edit this event: its creator, or a
/// leader or officer of its guild
bool canManageEvent(GuildEvent event, String? myId, List<MyGuild> myGuilds) {
  if (myId != null && event.creatorId == myId) return true;
  return myGuilds.any((g) => g.id == event.guildId && (g.role == 'leader' || g.role == 'officer'));
}

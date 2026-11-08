import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community.dart';

part 'guild_events/actions.dart';
part 'guild_events/models.dart';
part 'guild_events/roster.dart';

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

const _eventColumns = 'id, guild_id, creator_id, organizer_name, series_id, title, description, activity, start_at, '
    'duration_minutes, max_participants, status, version, discord_only, guilds(name, tag)';

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
        accountId: r['account_id'] as String?,
        flex: stringList(r['flex_roles']),
        joinedAt: DateTime.tryParse('${r['joined_at']}') ?? DateTime.now(),
      ),
  ]);
});

/// guilds where the player may create events: leader or officer there, or
/// let in by them
final creatableGuildsProvider = FutureProvider.autoDispose<List<MyGuild>>((ref) async {
  final guilds = await ref.watch(myGuildsProvider.future);
  final accounts = await ref.watch(myGuildAccountsProvider.future);
  return creatableGuilds(guilds, accounts);
});

/// the guilds in which one of the player's accounts may make events
List<MyGuild> creatableGuilds(List<MyGuild> guilds, List<GuildAccount> accounts) => [
      for (final g in guilds)
        if (accounts.any((a) => a.guildId == g.id && a.mayCreate)) g,
    ];

/// a text from json, null when it is missing or empty
String? nonEmpty(Object? value) {
  final text = '${value ?? ''}';
  return text.isEmpty ? null : text;
}

/// a list of texts from json, empty when it is not one
List<String> stringList(Object? value) => value is List ? [for (final v in value) '$v'] : const <String>[];

/// whether the player may cancel or edit this event: its creator, or a
/// leader or officer of its guild
bool canManageEvent(GuildEvent event, String? myId, List<MyGuild> myGuilds) {
  if (myId != null && event.creatorId == myId) return true;
  return myGuilds.any((g) => g.id == event.guildId && (g.role == 'leader' || g.role == 'officer'));
}

// ---------------------------------------------------------------------------
// officers

/// the accounts that may create an event in [guildId], the one that leads
/// first, then the officers, each by name
List<GuildAccount> organizersFor(List<GuildAccount> all, String guildId) =>
    accountsIn(all, guildId).where((a) => a.mayCreate).toList();

/// the account already chosen for an event, while it is still one of the
/// player's in the guild, null when a choice is due
String? accountToKeep(String? chosen, List<GuildAccount> accounts) =>
    chosen != null && accounts.any((a) => a.accountId == chosen) ? chosen : null;

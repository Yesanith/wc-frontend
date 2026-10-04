part of '../guild_events.dart';

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
    this.organizer,
    this.discordOnly = false,
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

  /// the GW2 account the event was created with, unknown for older events
  final String? organizer;

  /// open only to certain Discord roles, or with roles that can only join the
  /// reserve. Discord roles are known only to Discord, so such an event is
  /// signed up for there, the app can only answer not going
  final bool discordOnly;

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
      organizer: r['organizer_name'] as String?,
      discordOnly: r['discord_only'] == true,
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
    this.accountId,
    this.flex = const <String>[],
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

  /// the id of the account signed up with. the server hands it out only in
  /// the player's own row, it is null in everybody else's
  final String? accountId;

  /// roles they could also play besides their own, for whoever puts the group together
  final List<String> flex;
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

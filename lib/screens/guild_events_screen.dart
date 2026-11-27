import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel, Supabase;

import '../l10n/strings.dart';
import '../state/community.dart';
import '../state/guild_events.dart';
import '../state/navigation.dart';
import '../state/professions.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/class_icon.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/meters.dart';
import 'guild_roster_screen.dart';
import 'open_event_labels.dart' show openEventDuration;

part 'guild_events/detail.dart';
part 'guild_events/roster.dart';
part 'guild_events/create.dart';

/// "Tue 29.09 · 21:00", in the app's language
String eventWhen(S s, DateTime local) =>
    '${s.t('wd_${local.weekday}')} ${pad2(local.day)}.${pad2(local.month)} · ${pad2(local.hour)}:${pad2(local.minute)}';

String _clock(DateTime local) => '${pad2(local.hour)}:${pad2(local.minute)}';

IconData activityIcon(String activity) => switch (activity) {
      'raid' => Icons.shield_outlined,
      'strike' => Icons.flash_on_outlined,
      'fractal' => Icons.blur_on,
      'worldboss' => Icons.whatshot_outlined,
      'meta' => Icons.public,
      'wvw' => Icons.castle_outlined,
      'pvp' => Icons.sports_kabaddi_outlined,
      'dungeon' => Icons.door_front_door_outlined,
      _ => Icons.event_outlined,
    };

Color statusColor(String? status) => switch (status) {
      'going' => AppColors.green,
      'maybe' => AppColors.gold,
      'waitlist' => AppColors.blue,
      'declined' => AppColors.muted,
      _ => AppColors.muted,
    };

String eventFailureText(S s, Object e) {
  final code = e is EventFailure ? e.code : 'event_failed';
  if (code == 'rate_limited') return s.t('err_rate_limited');
  const known = {
    'start_in_past',
    'version_conflict',
    'role_required',
    'profession_required',
    'account_not_allowed',
    'is_leader',
    'own_role',
    'not_member',
    'event_cancelled',
    'event_over',
    'not_allowed',
    'discord_only',
    'role_restricted',
    'not_signed_up',
    'bad_flex',
  };
  return known.contains(code) ? s.t('event_err_$code') : '${s.t('community_failed')} ($code)';
}

// ---------------------------------------------------------------------------
// list

/// the events of the player's guilds. needs a community account with a
/// linked gw2 account, and says how to get one otherwise
class GuildEventsScreen extends ConsumerWidget {
  const GuildEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (!communityReady) return _Blocked(text: s.t('events_unavailable'));
    final session = ref.watch(sessionProvider).valueOrNull;
    if (session == null) return _Blocked(text: s.t('events_sign_in'), toSettings: true);
    final guilds = ref.watch(myGuildsProvider);
    if (guilds.hasValue && guilds.value!.isEmpty) {
      return _Blocked(text: s.t('events_link_first'), toSettings: true);
    }
    final creatable = ref.watch(creatableGuildsProvider).valueOrNull ?? const <MyGuild>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: creatable.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bg,
              onPressed: () async {
                // the container outlives this page, which may be gone when the form is closed
                final container = ProviderScope.containerOf(context, listen: false);
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const CreateGuildEventScreen()),
                );
                if (created == true) container.invalidate(upcomingEventsProvider);
              },
              icon: const Icon(Icons.add),
              label: Text(s.t('event_create')),
            ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(upcomingEventsProvider);
          await ref.read(upcomingEventsProvider.future);
        },
        child: AsyncView<List<EventSummary>>(
          value: ref.watch(upcomingEventsProvider),
          onRetry: () => ref.invalidate(upcomingEventsProvider),
          builder: (events) {
            if (events.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const _GuildLinks(),
                  const SizedBox(height: 48),
                  Icon(Icons.event_available_outlined, size: 48, color: AppColors.muted),
                  const SizedBox(height: 12),
                  Text(
                    creatable.isEmpty ? s.t('events_none') : s.t('events_none_create'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.45),
                  ),
                ],
              );
            }
            // on a site the events are a week of days, with the chosen one in full beside it
            if (SiteScope.of(context)) return _EventsWeek(events: events);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              children: [
                const _GuildLinks(),
                const SizedBox(height: 10),
                // a phone has the week as a strip of days and the chosen day's events under it; a tablet has them in rows
                if (MediaQuery.sizeOf(context).width < 600)
                  _PhoneWeek(events: events)
                else
                  CardWrap(minWidth: 440, children: [for (final e in events) _EventCard(summary: e)]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Blocked extends ConsumerWidget {
  const _Blocked({required this.text, this.toSettings = false});

  final String text;
  final bool toSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.groups_2_outlined, size: 48, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.45)),
        if (toSettings) ...[
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: () => ref.read(sectionProvider.notifier).state = AppSection.settings,
              child: Text(s.t('events_open_settings')),
            ),
          ),
        ],
      ],
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.summary});

  final EventSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final e = summary.event;
    final now = DateTime.now();
    final live = !e.cancelled && e.startAt.isBefore(now) && e.endAt.isAfter(now);
    final capacity = e.maxParticipants == null ? '${summary.going}' : '${summary.going}/${e.maxParticipants}';
    return AppCard(
      onTap: () async {
        // an event deleted in its page is gone from the list, and this card with it, by the time the page closes
        final container = ProviderScope.containerOf(context, listen: false);
        await openPanel(context, (_) => GuildEventScreen(eventId: e.id));
        container.invalidate(upcomingEventsProvider);
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
            child: Icon(activityIcon(e.activity), color: e.cancelled ? AppColors.muted : AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: display(16).copyWith(
                    decoration: e.cancelled ? TextDecoration.lineThrough : null,
                    color: e.cancelled ? AppColors.muted : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${eventWhen(s, e.startAt)} · ${e.guildTag.isEmpty ? e.guildName : '[${e.guildTag}]'}',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (e.cancelled) Pill(s.t('event_cancelled'), color: AppColors.red),
                    if (live) Pill(s.t('event_live'), color: AppColors.green),
                    Pill('${s.t('event_going')} $capacity'),
                    if (summary.waiting > 0) Pill('${s.t('event_waitlist')} ${summary.waiting}', color: AppColors.blue),
                    if (summary.myStatus != null)
                      Pill(s.t('rsvp_${summary.myStatus}'), color: statusColor(summary.myStatus)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.chevron),
        ],
      ),
    );
  }
}

/// the player's guilds, each opening its members and officers
class _GuildLinks extends ConsumerWidget {
  const _GuildLinks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final guilds = ref.watch(myGuildsProvider).valueOrNull ?? const <MyGuild>[];
    if (guilds.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final g in guilds)
          ActionChip(
            avatar: const Icon(Icons.groups_outlined, size: 16),
            label: Text(s.t('roster_of', {'guild': g.tag.isEmpty ? g.name : g.tag})),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GuildRosterScreen(guild: g)),
            ),
          ),
      ],
    );
  }
}

/// the week on a phone: seven days in a strip, a dot under each that has events, and the events of the chosen day under it
class _PhoneWeek extends ConsumerStatefulWidget {
  const _PhoneWeek({required this.events});

  final List<EventSummary> events;

  @override
  ConsumerState<_PhoneWeek> createState() => _PhoneWeekState();
}

class _PhoneWeekState extends ConsumerState<_PhoneWeek> {
  var _week = 0;
  DateTime? _day;

  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final today = _date(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1)).add(Duration(days: 7 * _week));
    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    final chosen = _day != null && !_day!.isBefore(monday) && _day!.isBefore(monday.add(const Duration(days: 7)))
        ? _day!
        : (_week == 0 ? today : monday);
    List<EventSummary> on(DateTime day) => [
          for (final e in widget.events)
            if (_date(e.event.startAt.toLocal()) == day) e
        ]..sort((a, b) => a.event.startAt.compareTo(b.event.startAt));
    final list = on(chosen);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: s.t('week_previous'),
              onPressed: () => setState(() => _week--),
              icon: const Icon(Icons.chevron_left),
            ),
            for (final d in days)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _day = d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: d == chosen ? AppColors.header : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(s.t('wd_${d.weekday}').caps,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: d == chosen ? AppColors.accent : AppColors.muted)),
                        const SizedBox(height: 2),
                        Text('${d.day}',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: d == chosen ? const Color(0xFFFFF8E6) : AppColors.text)),
                        const SizedBox(height: 3),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                on(d).isEmpty ? Colors.transparent : (d == chosen ? AppColors.accent : AppColors.gold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: s.t('week_next'),
              onPressed: () => setState(() => _week++),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(s.t('events_none'), textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          )
        else
          for (final e in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _EventCard(summary: e)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// a week on a site

Color _activityTint(String activity) => switch (activity) {
      'raid' => AppColors.green,
      'strike' => AppColors.green,
      'fractal' => AppColors.blue,
      'meta' || 'worldboss' => AppColors.gold,
      'wvw' || 'pvp' => AppColors.red,
      _ => AppColors.muted,
    };

/// the guilds' events as a week: a column for each day, the events of it in the order they start, and the chosen one in full at the right
class _EventsWeek extends ConsumerStatefulWidget {
  const _EventsWeek({required this.events});

  final List<EventSummary> events;

  @override
  ConsumerState<_EventsWeek> createState() => _EventsWeekState();
}

class _EventsWeekState extends ConsumerState<_EventsWeek> {
  var _week = 0;
  String? _guild;
  String? _selected;

  DateTime _monday(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final now = DateTime.now();
    final monday = _monday(now).add(Duration(days: 7 * _week));
    final guilds = <String, String>{
      for (final e in widget.events) e.event.guildId: e.event.guildName,
    };
    final inWeek = [
      for (final e in widget.events)
        if (!e.event.startAt.toLocal().isBefore(monday) &&
            e.event.startAt.toLocal().isBefore(monday.add(const Duration(days: 7))) &&
            (_guild == null || e.event.guildId == _guild))
          e,
    ]..sort((a, b) => a.event.startAt.compareTo(b.event.startAt));
    final chosen = inWeek.where((e) => e.event.id == _selected).firstOrNull ?? (inWeek.isEmpty ? null : inWeek.first);
    String dm(DateTime d) => '${pad2(d.day)}.${pad2(d.month)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (guilds.length > 1) ...[
                ChoiceChip(
                    label: Text(s.t('all')),
                    selected: _guild == null,
                    onSelected: (_) => setState(() => _guild = null)),
                for (final g in guilds.entries)
                  ChoiceChip(
                    label: Text(g.value),
                    selected: _guild == g.key,
                    onSelected: (_) => setState(() => _guild = g.key),
                  ),
              ],
              IconButton(onPressed: () => setState(() => _week--), icon: const Icon(Icons.chevron_left)),
              Text('${dm(monday)} – ${dm(monday.add(const Duration(days: 6)))}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              IconButton(onPressed: () => setState(() => _week++), icon: const Icon(Icons.chevron_right)),
              if (_week != 0) TextButton(onPressed: () => setState(() => _week = 0), child: Text(s.t('this_week'))),
            ],
          ),
          // the members and officers of each guild, as on a phone
          const SizedBox(height: 6),
          const _GuildLinks(),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var d = 0; d < 7; d++) ...[
                        if (d > 0) const SizedBox(width: 8),
                        Expanded(
                          child: Builder(builder: (context) {
                            final day = monday.add(Duration(days: d));
                            final today = day.year == now.year && day.month == now.month && day.day == now.day;
                            final list = [
                              for (final e in inWeek)
                                if (e.event.startAt.toLocal().day == day.day &&
                                    e.event.startAt.toLocal().month == day.month)
                                  e,
                            ];
                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppRadius.card),
                                border:
                                    Border.all(color: today ? AppColors.gold : AppColors.line, width: today ? 1.5 : 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                                    child: Row(
                                      children: [
                                        Text(s.t('wd_${day.weekday}'),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                        const Spacer(),
                                        Text('${day.day}', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView(
                                      children: [
                                        for (final e in list)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Material(
                                              color: _activityTint(e.event.activity).withValues(alpha: 0.16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                side: e.event.id == chosen?.event.id
                                                    ? BorderSide(color: AppColors.gold, width: 2)
                                                    : BorderSide.none,
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: InkWell(
                                                onTap: () => setState(() => _selected = e.event.id),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(_clock(e.event.startAt.toLocal()),
                                                          style: TextStyle(
                                                              fontSize: 11.5,
                                                              fontWeight: FontWeight.w700,
                                                              color: AppColors.muted)),
                                                      Text(e.event.title,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.w800,
                                                              decoration: e.event.cancelled
                                                                  ? TextDecoration.lineThrough
                                                                  : null)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 390,
                  child: Panel(
                    padding: EdgeInsets.zero,
                    child: chosen == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(s.t('events_none'),
                                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                            ),
                          )
                        : GuildEventScreen(key: ValueKey(chosen.event.id), eventId: chosen.event.id, embedded: true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

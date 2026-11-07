import 'dart:async';

import 'package:flutter/material.dart';
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
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              children: [
                const _GuildLinks(),
                const SizedBox(height: 10),
                // one under the other on a phone, in rows where there is room
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

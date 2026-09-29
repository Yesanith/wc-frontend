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
import '../widgets/class_icon.dart';
import '../widgets/common.dart';
import '../widgets/meters.dart';
import 'guild_roster_screen.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// "Tue 29.09 · 21:00", in the app's language
String eventWhen(S s, DateTime local) =>
    '${s.t('wd_${local.weekday}')} ${_two(local.day)}.${_two(local.month)} · ${_two(local.hour)}:${_two(local.minute)}';

String _clock(DateTime local) => '${_two(local.hour)}:${_two(local.minute)}';

IconData activityIcon(String activity) => switch (activity) {
      'raid' => Icons.shield_outlined,
      'strike' => Icons.flash_on_outlined,
      'fractal' => Icons.blur_on,
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
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const CreateGuildEventScreen()),
                );
                if (created == true) ref.invalidate(upcomingEventsProvider);
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
                  const Icon(Icons.event_available_outlined, size: 48, color: AppColors.muted),
                  const SizedBox(height: 12),
                  Text(
                    creatable.isEmpty ? s.t('events_none') : s.t('events_none_create'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, height: 1.45),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              itemCount: events.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => i == 0 ? const _GuildLinks() : _EventCard(summary: events[i - 1]),
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
        const Icon(Icons.groups_2_outlined, size: 48, color: AppColors.muted),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.45)),
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
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuildEventScreen(eventId: e.id)));
        ref.invalidate(upcomingEventsProvider);
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
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
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
          const Icon(Icons.chevron_right, color: AppColors.chevron),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// detail

class GuildEventScreen extends ConsumerStatefulWidget {
  const GuildEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<GuildEventScreen> createState() => _GuildEventScreenState();
}

class _GuildEventScreenState extends ConsumerState<GuildEventScreen> {
  bool _busy = false;
  RealtimeChannel? _live;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  /// sign ups and edits by others arrive while the page is open. realtime
  /// sends only what row level security lets this player read
  void _follow() {
    if (!communityReady) return;
    final id = widget.eventId;
    final byEvent = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: id);
    final byId = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: id);
    _live = Supabase.instance.client
        .channel('event-$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_participants',
          filter: byEvent,
          callback: (_) => _changed(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'events',
          filter: byId,
          callback: (_) => _changed(),
        )
        .subscribe();
  }

  /// a burst of changes, say a promotion from the waitlist, reloads once
  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) ref.invalidate(eventDetailProvider(widget.eventId));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final live = _live;
    if (live != null) Supabase.instance.client.removeChannel(live);
    super.dispose();
  }

  Future<void> _answer(EventDetail d, String status) async {
    final s = ref.read(stringsProvider);
    String? role;
    String? profession;
    if (status == 'going' && d.roles.isNotEmpty) {
      role = await _pickRole(d);
      if (role == null) return;
      // the others see which profession fills the role
      profession = await _pickProfession(role);
      if (profession == null) return;
    }
    // then, with several accounts in the guild, which one signs up. the choice
    // made for this event before is kept, the server picks when there is one
    String? account;
    if (status != 'declined') {
      final accounts = await _accountsInGuild(d.event.guildId);
      final me = ref.read(sessionProvider).valueOrNull?.user.id;
      final mine = d.participants.where((p) => p.userId == me).firstOrNull;
      account = accountToKeep(mine?.accountId, accounts);
      if (account == null && accounts.length >= 2) {
        account = await _pickAccount(accounts);
        if (account == null) return;
      }
    }
    setState(() => _busy = true);
    try {
      final result = await rsvp(widget.eventId, status, role: role, profession: profession, accountId: account);
      if (mounted && result == 'waitlist') showToast(context, s.t('rsvp_waitlisted'));
    } catch (e) {
      if (mounted) showToast(context, eventFailureText(s, e));
    } finally {
      ref.invalidate(eventDetailProvider(widget.eventId));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickRole(EventDetail d) {
    final s = ref.read(stringsProvider);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(s.t('event_pick_role'), style: display(18)),
            ),
            for (final r in d.roles.entries)
              ListTile(
                title: Text(s.t('role_${r.key}')),
                trailing: Text(
                  '${d.goingAs(r.key)}/${r.value}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: d.goingAs(r.key) >= r.value ? AppColors.muted : AppColors.gold,
                  ),
                ),
                subtitle: d.goingAs(r.key) >= r.value ? Text(s.t('event_role_full')) : null,
                onTap: () => Navigator.of(ctx).pop(r.key),
              ),
          ],
        ),
      ),
    );
  }

  /// the player's accounts in the event's guild, best first
  Future<List<GuildAccount>> _accountsInGuild(String guildId) async {
    try {
      return accountsIn(await ref.read(myGuildAccountsProvider.future), guildId);
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _pickAccount(List<GuildAccount> accounts, {String? current}) {
    final s = ref.read(stringsProvider);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(s.t('event_pick_account'), style: display(18)),
            ),
            for (final a in accounts)
              ListTile(
                leading: Icon(
                  a.accountId == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: a.accountId == current ? AppColors.gold : AppColors.muted,
                ),
                title: Text(a.accountName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(s.t('guild_role_${a.role}'), style: const TextStyle(color: AppColors.muted)),
                onTap: () => Navigator.of(ctx).pop(a.accountId),
              ),
          ],
        ),
      ),
    );
  }

  /// signs up again as the same answer, role and profession, with another account
  Future<void> _changeAccount(EventDetail d, EventParticipant mine) async {
    final s = ref.read(stringsProvider);
    final accounts = await _accountsInGuild(d.event.guildId);
    if (accounts.length < 2 || !mounted) return;
    final picked = await _pickAccount(accounts, current: accountToKeep(mine.accountId, accounts));
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      // waiting means going that did not fit, going again keeps the place in line
      await rsvp(
        widget.eventId,
        mine.status == 'maybe' ? 'maybe' : 'going',
        role: mine.role,
        profession: mine.profession,
        accountId: picked,
      );
      if (mounted) showToast(context, s.t('event_account_changed'));
    } catch (e) {
      if (mounted) showToast(context, eventFailureText(s, e));
    } finally {
      ref.invalidate(eventDetailProvider(widget.eventId));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickProfession(String role) {
    final s = ref.read(stringsProvider);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final professions = ref.watch(professionsProvider).valueOrNull ?? const <String, ProfessionInfo>{};
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(s.t('event_pick_profession', {'role': s.t('role_$role')}), style: display(18)),
                ),
                for (final p in eventProfessions)
                  ListTile(
                    leading: ProfessionIcon(url: professions[p]?.icon, size: 28),
                    title: Text(professions[p]?.name ?? p),
                    onTap: () => Navigator.of(ctx).pop(p),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _cancel() async {
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(s.t('event_cancel')),
        content: Text(s.t('event_cancel_body')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.t('event_cancel')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await cancelEvent(widget.eventId);
    } catch (e) {
      if (mounted) showToast(context, eventFailureText(s, e));
    }
    ref.invalidate(eventDetailProvider(widget.eventId));
  }

  /// null when the player backed out, otherwise whether the whole weekly
  /// series goes
  Future<bool?> _confirmDelete(GuildEvent e) {
    final s = ref.read(stringsProvider);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(s.t('event_delete')),
        content: Text(e.seriesId == null ? s.t('event_delete_body') : s.t('event_delete_weekly_body')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.t('cancel'))),
          if (e.seriesId != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.t('event_delete_series')),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(e.seriesId == null ? s.t('event_delete') : s.t('event_delete_week')),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(GuildEvent e) async {
    final s = ref.read(stringsProvider);
    final whole = await _confirmDelete(e);
    if (whole == null) return;
    setState(() => _busy = true);
    try {
      await deleteEvent(e.id, wholeSeries: whole);
      ref.invalidate(upcomingEventsProvider);
      if (mounted) {
        showToast(context, s.t('event_deleted'));
        Navigator.of(context).pop();
      }
    } catch (err) {
      if (mounted) {
        showToast(context, eventFailureText(s, err));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final detail = ref.watch(eventDetailProvider(widget.eventId));
    final me = ref.watch(sessionProvider).valueOrNull?.user.id;
    final myGuilds = ref.watch(myGuildsProvider).valueOrNull ?? const <MyGuild>[];
    // watched here, in build, so the page has the accounts by the time somebody signs up
    final myAccounts = ref.watch(myGuildAccountsProvider).valueOrNull ?? const <GuildAccount>[];

    return Scaffold(
      appBar: AppBar(title: Text(s.t('guild_events'))),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(eventDetailProvider(widget.eventId));
          await ref.read(eventDetailProvider(widget.eventId).future);
        },
        child: AsyncView<EventDetail?>(
          value: detail,
          onRetry: () => ref.invalidate(eventDetailProvider(widget.eventId)),
          builder: (d) {
            if (d == null) {
              return ListView(children: [
                const SizedBox(height: 80),
                Center(child: Text(s.t('event_gone'), style: const TextStyle(color: AppColors.muted))),
              ]);
            }
            final e = d.event;
            final mine = d.participants.where((p) => p.userId == me).firstOrNull;
            final over = e.endAt.isBefore(DateTime.now());
            final open = !e.cancelled && !over;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(
                  children: [
                    Icon(activityIcon(e.activity), color: AppColors.gold),
                    const SizedBox(width: 8),
                    Text(s.t('activity_${e.activity}').toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.gold)),
                    const Spacer(),
                    if (e.seriesId != null) Pill(s.t('event_weekly')),
                  ],
                ),
                const SizedBox(height: 8),
                Text(e.title, style: display(24)),
                const SizedBox(height: 6),
                Text('${eventWhen(s, e.startAt)} – ${_clock(e.endAt)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(e.guildTag.isEmpty ? e.guildName : '${e.guildName} [${e.guildTag}]',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                if (e.organizer != null)
                  Text('${s.t('event_organizer')}: ${e.organizer}',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                if (e.cancelled) ...[
                  const SizedBox(height: 10),
                  Pill(s.t('event_cancelled'), color: AppColors.red),
                ],
                if (e.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(e.description, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSoft)),
                ],
                const SizedBox(height: 18),
                if (open)
                  _RsvpBar(
                    mine: mine,
                    busy: _busy,
                    onAnswer: (status) => _answer(d, status),
                    // only with several accounts in the guild is there anything to change
                    onChangeAccount:
                        mine != null && mine.status != 'declined' && accountsIn(myAccounts, e.guildId).length >= 2
                            ? () => _changeAccount(d, mine)
                            : null,
                  ),
                if (d.roles.isNotEmpty) ...[
                  Eyebrow(s.t('event_roles')),
                  Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        for (final r in d.roles.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(s.t('role_${r.key}'))),
                                Text(
                                  '${d.goingAs(r.key)}/${r.value}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: d.goingAs(r.key) >= r.value ? AppColors.green : AppColors.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                _Group(
                  title: e.maxParticipants == null
                      ? '${s.t('rsvp_going')} · ${d.going}'
                      : '${s.t('rsvp_going')} · ${d.going}/${e.maxParticipants}',
                  people: d.withStatus('going'),
                  showRole: d.roles.isNotEmpty,
                  me: me,
                ),
                _Group(
                  title: '${s.t('event_waitlist')} · ${d.withStatus('waitlist').length}',
                  people: d.withStatus('waitlist'),
                  showRole: d.roles.isNotEmpty,
                  me: me,
                  numbered: true,
                ),
                _Group(
                  title: '${s.t('rsvp_maybe')} · ${d.withStatus('maybe').length}',
                  people: d.withStatus('maybe'),
                  showRole: false,
                  me: me,
                ),
                if (d.withStatus('declined').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text('${s.t('rsvp_declined')} · ${d.withStatus('declined').length}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                if (!e.cancelled && !over && canManageEvent(e, me, myGuilds)) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final saved = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => CreateGuildEventScreen(editing: d)),
                      );
                      if (saved == true) ref.invalidate(eventDetailProvider(widget.eventId));
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(s.t('event_edit')),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.red),
                    onPressed: _cancel,
                    icon: const Icon(Icons.event_busy_outlined),
                    label: Text(s.t('event_cancel')),
                  ),
                ],
                if (canManageEvent(e, me, myGuilds)) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                    onPressed: _busy ? null : () => _delete(e),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(s.t('event_delete')),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RsvpBar extends ConsumerWidget {
  const _RsvpBar({required this.mine, required this.busy, required this.onAnswer, this.onChangeAccount});

  final EventParticipant? mine;
  final bool busy;
  final ValueChanged<String> onAnswer;

  /// null unless the player has several accounts to choose from
  final VoidCallback? onChangeAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final current = mine?.status;
    Widget button(String status, IconData icon) {
      // waiting counts as having said going
      final selected = current == status || (status == 'going' && current == 'waitlist');
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: selected
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: statusColor(current)),
                  onPressed: busy ? null : () => onAnswer(status),
                  icon: Icon(icon, size: 18),
                  label: Text(s.t(current == 'waitlist' ? 'rsvp_waitlist' : 'rsvp_$status')),
                )
              : OutlinedButton.icon(
                  onPressed: busy ? null : () => onAnswer(status),
                  icon: Icon(icon, size: 18),
                  label: Text(s.t('rsvp_$status')),
                ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            button('going', Icons.check),
            button('maybe', Icons.help_outline),
            button('declined', Icons.close),
          ],
        ),
        if (mine?.role != null && (current == 'going' || current == 'waitlist'))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${s.t('event_your_role')}: ${s.t('role_${mine!.role}')}${mine!.profession == null ? '' : ' · ${mine!.profession}'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        if (onChangeAccount != null && mine != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  s.t('event_signed_up_as', {'name': mine!.name}),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              TextButton(
                onPressed: busy ? null : onChangeAccount,
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text(s.t('event_change_account'), style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
      ],
    );
  }
}

class _Group extends ConsumerWidget {
  const _Group({
    required this.title,
    required this.people,
    required this.showRole,
    required this.me,
    this.numbered = false,
  });

  final String title;
  final List<EventParticipant> people;
  final bool showRole;
  final String? me;
  final bool numbered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (people.isEmpty) return const SizedBox.shrink();
    final professions = ref.watch(professionsProvider).valueOrNull ?? const <String, ProfessionInfo>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow(title),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < people.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      if (numbered)
                        SizedBox(
                          width: 22,
                          child: Text('${i + 1}.', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.surface2,
                        foregroundImage: people[i].avatarUrl == null ? null : NetworkImage(people[i].avatarUrl!),
                        child: const Icon(Icons.person_outline, size: 16, color: AppColors.muted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          people[i].name,
                          style: TextStyle(fontWeight: people[i].userId == me ? FontWeight.w800 : FontWeight.w500),
                        ),
                      ),
                      if (people[i].profession != null) ...[
                        ProfessionIcon(url: professions[people[i].profession]?.icon, size: 18),
                        const SizedBox(width: 4),
                        Text(professions[people[i].profession]?.name ?? people[i].profession!,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
                        const SizedBox(width: 8),
                      ],
                      if (showRole && people[i].role != null)
                        Text(s.t('role_${people[i].role}'),
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// create

class CreateGuildEventScreen extends ConsumerStatefulWidget {
  const CreateGuildEventScreen({super.key, this.editing});

  /// the event to change, null to create a new one
  final EventDetail? editing;

  @override
  ConsumerState<CreateGuildEventScreen> createState() => _CreateGuildEventScreenState();
}

class _CreateGuildEventScreenState extends ConsumerState<CreateGuildEventScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _guildId;

  /// the gw2 account the event is created with, null until chosen
  String? _accountId;
  String _activity = 'raid';
  late DateTime _start;
  int _duration = 120;
  int? _max = 10;
  bool _weekly = false;
  Map<String, int> _roles = {...eventRolePresets['squad10']!};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      final e = editing.event;
      _title.text = e.title;
      _description.text = e.description;
      _guildId = e.guildId;
      _activity = eventActivities.contains(e.activity) ? e.activity : 'other';
      _start = e.startAt;
      _duration = e.durationMinutes;
      _max = e.maxParticipants;
      _roles = {...editing.roles};
      return;
    }
    // tomorrow at the next full hour, a sensible first guess
    final now = DateTime.now().add(const Duration(days: 1));
    _start = DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day != null) setState(() => _start = DateTime(day.year, day.month, day.day, _start.hour, _start.minute));
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start.hour, minute: _start.minute),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (time != null) setState(() => _start = DateTime(_start.year, _start.month, _start.day, time.hour, time.minute));
  }

  /// the account chosen, or the only one that may when there is just one
  String? _effectiveAccount(List<GuildAccount> all) {
    final guild = _guildId;
    if (guild == null) return null;
    final organizers = organizersFor(all, guild);
    if (_accountId != null && organizers.any((a) => a.accountId == _accountId)) return _accountId;
    return organizers.length == 1 ? organizers.first.accountId : null;
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final guild = _guildId;
    final title = _title.text.trim();
    final account = _effectiveAccount(ref.read(myGuildAccountsProvider).valueOrNull ?? const []);
    if (guild == null) {
      showToast(context, s.t('event_err_guild'));
      return;
    }
    if (title.isEmpty) {
      showToast(context, s.t('event_err_title'));
      return;
    }
    if (widget.editing == null && account == null) {
      showToast(context, s.t('event_err_account'));
      return;
    }
    setState(() => _busy = true);
    try {
      final description = _description.text.trim();
      final editing = widget.editing;
      if (editing != null) {
        await updateEvent(
          eventId: editing.event.id,
          version: editing.event.version,
          title: title,
          startAt: _start,
          durationMinutes: _duration,
          description: description,
          activity: _activity,
          maxParticipants: _max,
          roles: _roles,
        );
      } else if (_weekly) {
        await createWeeklyEvent(
          guildId: guild,
          accountId: account,
          title: title,
          firstStart: _start,
          durationMinutes: _duration,
          description: description,
          activity: _activity,
          maxParticipants: _max,
          roles: _roles,
        );
      } else {
        await createEvent(
          guildId: guild,
          accountId: account,
          title: title,
          startAt: _start,
          durationMinutes: _duration,
          description: description,
          activity: _activity,
          maxParticipants: _max,
          roles: _roles,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showToast(context, eventFailureText(s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final editing = widget.editing;
    final creatable = ref.watch(creatableGuildsProvider).valueOrNull ?? const <MyGuild>[];
    // the creator may edit an event in a guild where they are no officer
    final guilds = editing == null
        ? creatable
        : [MyGuild(editing.event.guildId, editing.event.guildName, editing.event.guildTag, 'member')];
    // no guild is preselected: choosing it is part of creating the event
    final guildId = _guildId;
    final accounts = ref.watch(myGuildAccountsProvider);
    final organizers =
        guildId == null ? const <GuildAccount>[] : organizersFor(accounts.valueOrNull ?? const [], guildId);
    final accountId = _effectiveAccount(accounts.valueOrNull ?? const []);
    final durations = {30, 60, 90, 120, 180, 240, _duration}.toList()..sort();
    final sizes = <int?>{5, 10, 20, 50, _max}.whereType<int>().toList()..sort();
    final roleTotal = _roles.values.fold<int>(0, (a, b) => a + b);

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(editing == null ? s.t('event_create') : s.t('event_edit'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          label(s.t('event_guild')),
          DropdownButtonFormField<String>(
            initialValue: guildId,
            dropdownColor: AppColors.surface,
            decoration: fieldDecoration(''),
            hint: Text(s.t('event_guild_hint'), style: const TextStyle(color: AppColors.muted)),
            items: [
              for (final g in guilds)
                DropdownMenuItem(value: g.id, child: Text(g.tag.isEmpty ? g.name : '${g.name} [${g.tag}]')),
            ],
            // another guild has other accounts to organize with
            onChanged: editing != null
                ? null
                : (v) => setState(() {
                      _guildId = v;
                      _accountId = null;
                    }),
          ),
          // which of the player's accounts creates it: roles are per account
          if (editing == null && guildId != null) ...[
            label(s.t('event_account')),
            if (organizers.isEmpty && accounts.hasValue)
              Text(s.t('event_account_none'), style: const TextStyle(fontSize: 13, color: AppColors.muted))
            else
              DropdownButtonFormField<String>(
                // a new field for every guild, its start value is read once
                key: ValueKey('organizer-$guildId'),
                initialValue: accountId,
                dropdownColor: AppColors.surface,
                decoration: fieldDecoration(''),
                hint: Text(s.t('event_account_hint'), style: const TextStyle(color: AppColors.muted)),
                items: [
                  for (final a in organizers)
                    DropdownMenuItem(
                        value: a.accountId, child: Text('${a.accountName} · ${s.t('guild_role_${a.role}')}')),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
          ],
          label(s.t('event_title')),
          TextField(controller: _title, maxLength: 80, decoration: fieldDecoration(s.t('event_title_hint'))),
          label(s.t('event_activity')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in eventActivities)
                ChoiceChip(
                  avatar: Icon(activityIcon(a), size: 16),
                  label: Text(s.t('activity_$a')),
                  selected: _activity == a,
                  onSelected: (_) => setState(() => _activity = a),
                ),
            ],
          ),
          label(s.t('event_when')),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label:
                      Text('${s.t('wd_${_start.weekday}')} ${_two(_start.day)}.${_two(_start.month)}.${_start.year}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(_clock(_start)),
                ),
              ),
            ],
          ),
          if (editing == null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _weekly,
              activeThumbColor: AppColors.gold,
              onChanged: (v) => setState(() => _weekly = v),
              title: Text(s.t('event_repeat_weekly')),
              subtitle: Text(s.t('event_repeat_note'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
          label(s.t('event_duration')),
          Wrap(
            spacing: 6,
            children: [
              for (final m in durations)
                ChoiceChip(
                  label: Text(m < 60 ? '$m min' : '${m ~/ 60}${m % 60 == 0 ? '' : '.5'} h'),
                  selected: _duration == m,
                  onSelected: (_) => setState(() => _duration = m),
                ),
            ],
          ),
          label(s.t('event_size')),
          Wrap(
            spacing: 6,
            children: [
              for (final n in <int?>[...sizes, null])
                ChoiceChip(
                  label: Text(n == null ? s.t('event_size_open') : '$n'),
                  selected: _max == n,
                  onSelected: (_) => setState(() => _max = n),
                ),
            ],
          ),
          label(s.t('event_roles')),
          Wrap(
            spacing: 6,
            children: [
              ActionChip(
                label: Text(s.t('event_preset_squad10')),
                onPressed: () => setState(() {
                  _roles = {...eventRolePresets['squad10']!};
                  _max = 10;
                }),
              ),
              ActionChip(
                label: Text(s.t('event_preset_party5')),
                onPressed: () => setState(() {
                  _roles = {...eventRolePresets['party5']!};
                  _max = 5;
                }),
              ),
              ActionChip(label: Text(s.t('event_preset_none')), onPressed: () => setState(() => _roles = {})),
            ],
          ),
          const SizedBox(height: 6),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                for (final key in eventRoleKeys)
                  Row(
                    children: [
                      Expanded(child: Text(s.t('role_$key'))),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: (_roles[key] ?? 0) == 0
                            ? null
                            : () => setState(() {
                                  final n = (_roles[key] ?? 0) - 1;
                                  n == 0 ? _roles.remove(key) : _roles[key] = n;
                                }),
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                      ),
                      SizedBox(
                        width: 24,
                        child: Text('${_roles[key] ?? 0}',
                            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _roles[key] = (_roles[key] ?? 0) + 1),
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_max != null && roleTotal > _max!)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(s.t('event_roles_over', {'n': roleTotal, 'max': _max!}),
                  style: const TextStyle(fontSize: 12, color: AppColors.gold)),
            ),
          label(s.t('event_description')),
          TextField(
            controller: _description,
            maxLength: 2000,
            minLines: 3,
            maxLines: 8,
            decoration: fieldDecoration(s.t('event_description_hint')),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || guilds.isEmpty ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(editing == null ? s.t('event_create') : s.t('event_save')),
          ),
          if (editing?.event.seriesId != null) ...[
            const SizedBox(height: 8),
            Text(s.t('event_edit_one_week'),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
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

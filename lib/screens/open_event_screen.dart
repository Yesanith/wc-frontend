import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/community.dart';
import '../state/navigation.dart';
import '../state/open_events.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/event_pickers.dart';
import '../widgets/responsive.dart';
import 'guild_events_screen.dart' show activityIcon, eventWhen, statusColor;
import 'open_event_form_screen.dart';
import 'open_event_labels.dart';

/// opens a public event's page over the page the app is at. it has an address of its own (/event/<number>), in the browser while it is open, and its button copies it.
/// [announce] is false for a link that was followed or that the app was opened with
Future<void> showOpenEvent(BuildContext context, String eventId, {bool announce = true}) {
  final closed = linkOpened(ProviderScope.containerOf(context, listen: false), EventLink(eventId), announce: announce);
  return Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => OpenEventScreen(eventId: eventId)))
      .whenComplete(closed);
}

/// whether the page of a public event can be shown to whoever opened it: the community account is what the events are read with, so a link that somebody was sent is
/// first asked of the account
enum EventAccess { unavailable, waiting, signInNeeded, open }

EventAccess eventAccess({required bool ready, required AsyncValue<Object?>? session}) {
  if (!ready || session == null) return EventAccess.unavailable;
  if (session.valueOrNull != null) return EventAccess.open;
  // the session is read when the app begins: until it has been, there is nothing to say
  return session.isLoading ? EventAccess.waiting : EventAccess.signInNeeded;
}

class OpenEventScreen extends ConsumerWidget {
  const OpenEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final access = eventAccess(ready: communityReady, session: communityReady ? ref.watch(sessionProvider) : null);
    // the event is asked of the database only when there is an account to ask with: a guest who follows a link is told to sign in, not shown what the database refused
    final event = access == EventAccess.open ? ref.watch(openEventProvider(eventId)) : null;
    return Scaffold(
      appBar: AppBar(
          title: Text(event?.valueOrNull?.title ?? s.t('public_events'), maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            // the address of this event, which opens the app at it
            if (isEventId(eventId))
              IconButton(
                tooltip: s.t('copy_page_link'),
                icon: const Icon(Icons.share_outlined),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: linkUrl(EventLink(eventId))));
                  showToast(context, s.t('copied'));
                },
              ),
          ]),
      body: switch (access) {
        EventAccess.unavailable => _EventNotice(text: s.t('oe_unavailable')),
        EventAccess.waiting => const Center(child: CircularProgressIndicator()),
        EventAccess.signInNeeded => _EventNotice(text: s.t('oe_sign_in'), toSettings: true),
        EventAccess.open => AsyncView<OpenEvent?>(
            value: event!,
            onRetry: () => ref.invalidate(openEventProvider(eventId)),
            builder: (e) => e == null
                ? Center(child: Text(s.t('oe_err_gone'), style: TextStyle(color: AppColors.muted)))
                : ContentFrame(maxWidth: readingMaxWidth, child: _EventBody(event: e)),
          ),
      },
    );
  }
}

/// what is said where the event would be: that events are not here, or that the player has to sign in, with the way to the settings where they do
class _EventNotice extends ConsumerWidget {
  const _EventNotice({required this.text, this.toSettings = false});

  final String text;
  final bool toSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public, size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.4)),
            if (toSettings) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  // the page of the event is closed, and the settings are where the app is
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ref.read(sectionProvider.notifier).state = AppSection.settings;
                },
                child: Text(s.t('nav_settings')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventBody extends ConsumerStatefulWidget {
  const _EventBody({required this.event});

  final OpenEvent event;

  @override
  ConsumerState<_EventBody> createState() => _EventBodyState();
}

class _EventBodyState extends ConsumerState<_EventBody> {
  bool _busy = false;

  /// the account the player picked to sign up as, when they have more than one of the region of the event
  String? _account;

  S get _s => ref.read(stringsProvider);

  void _refresh() {
    ref.invalidate(openEventProvider(widget.event.id));
    ref.invalidate(openEventsFeedProvider);
    ref.invalidate(myOpenEventsProvider);
    ref.invalidate(openRosterProvider(widget.event.id));
  }

  /// the accounts of the player that may take part, and what to ask for: nothing when there is no choice to make
  List<OpenAccount> _eligible(OpenEvent e) => ref.read(myRegionsProvider).valueOrNull?.forRegion(e.region) ?? const [];

  String? _chosenAccount(OpenEvent e) {
    final eligible = _eligible(e);
    if (eligible.length < 2) return null;
    return eligible.any((a) => a.id == _account) ? _account : eligible.first.id;
  }

  List<Widget> _accountChooser(S s, OpenEvent e) {
    final mine = ref.watch(myRegionsProvider).valueOrNull;
    if (mine == null) return const [];
    final eligible = mine.forRegion(e.region);
    if (mine.hasAccount && eligible.isEmpty) {
      return [
        Text(s.t('oe_err_wrong_region'), style: TextStyle(color: AppColors.amber, height: 1.4)),
        const SizedBox(height: 8),
      ];
    }
    if (eligible.length < 2) return const [];
    return [
      Kicker(s.t('oe_join_as')),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: eligible.any((a) => a.id == _account) ? _account : eligible.first.id,
        dropdownColor: AppColors.surface,
        decoration: fieldDecoration(''),
        items: [for (final a in eligible) DropdownMenuItem(value: a.id, child: Text(a.name))],
        onChanged: (v) => setState(() => _account = v),
      ),
      const SizedBox(height: 12),
    ];
  }

  /// signs up. going to an event with roles asks the role and the profession first
  Future<void> _join(OpenEvent e, String status) async {
    String? role;
    String? profession;
    if (status == 'going' && e.hasRoles) {
      role = await pickEventRole(context, _s, e.roles, current: e.myRole);
      if (role == null || !mounted) return;
      profession = await pickEventProfession(context, _s, role);
      if (profession == null) return;
    }
    await _act(() => joinOpenEvent(e.id, status, account: _chosenAccount(e), role: role, profession: profession));
  }

  Future<void> _act(Future<void> Function() action, {String? done, bool leave = false}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (done != null && mounted) showToast(context, done);
    } catch (e) {
      if (mounted) showToast(context, _s.t(openEventErrorKey(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _refresh();
    if (leave && mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirm(String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_s.t('cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _report() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(_s.t('oe_report_why')),
        children: [
          for (final r in const ['spam', 'offensive', 'not_gw2', 'other'])
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, r), child: Text(_s.t('oe_reason_$r'))),
        ],
      ),
    );
    if (reason == null) return;
    await _act(() => reportOpenEvent(widget.event.id, reason), done: _s.t('oe_reported'));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final e = widget.event;
    final over = e.isOver(DateTime.now());
    // the organizer is going already, and can change how they come
    final canSignUp = !e.cancelled && !e.hidden && !over;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
              child: Icon(activityIcon(e.activity), color: AppColors.gold),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, style: display(20)),
                  const SizedBox(height: 2),
                  Text('${eventWhen(s, e.startAt)} · ${openEventDuration(e.durationMinutes)}',
                      style: TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (e.cancelled) Pill(s.t('oe_cancelled'), color: AppColors.red),
            if (e.hidden) Pill(s.t('oe_hidden'), color: AppColors.amber),
            if (e.isLive(DateTime.now())) Pill(s.t('event_live'), color: AppColors.green),
            Pill(s.t('activity_${e.activity}')),
            Pill(s.t('oe_region_${e.region}')),
            Pill(openEventLanguageName(s, e.language)),
            if (e.mapId != null) Pill(s.t('oe_map_pill', {'id': e.mapId})),
            for (final t in e.tags) Pill(s.t('oe_tag_$t')),
            Pill(s.t('oe_going', {'n': e.going})),
            if (e.maybe > 0) Pill(s.t('oe_maybe', {'n': e.maybe})),
            if (e.maxParticipants != null) Pill(s.t('oe_places', {'n': e.going, 'max': e.maxParticipants})),
            if (e.myStatus != null) Pill(s.t('rsvp_${e.myStatus}'), color: statusColor(e.myStatus)),
            if (e.myRole != null) Pill(s.t('role_${e.myRole}')),
            if (e.myProfession != null) Pill(e.myProfession!),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(s.t('oe_by', {'name': e.organizer}),
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(
                    tooltip: s.t('oe_copy_name'),
                    icon: Icon(Icons.copy, size: 18, color: AppColors.gold),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: e.organizer));
                      if (context.mounted) showToast(context, s.t('oe_copied'));
                    },
                  ),
                ],
              ),
              if (!e.mine)
                Text(s.t('oe_find_note'), style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
            ],
          ),
        ),
        if (e.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Panel(child: Text(e.description, style: const TextStyle(height: 1.45))),
        ],
        if (e.hasRoles) ...[
          const SizedBox(height: 12),
          Kicker(s.t('event_roles').toUpperCase()),
          const SizedBox(height: 6),
          Panel(
            child: Column(
              children: [
                for (final r in e.roles)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(child: Text(s.t('role_${r.role}'))),
                        Text(
                          '${r.taken}/${r.slots}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: r.taken >= r.slots ? AppColors.muted : AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (canSignUp) ...[
          ..._accountChooser(s, e),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy || (e.isFull && e.myStatus != 'going') ? null : () => _join(e, 'going'),
                  child: Text(e.isFull && e.myStatus != 'going'
                      ? s.t('oe_full')
                      : (e.myStatus == 'going' ? s.t('oe_you_going') : s.t('oe_join'))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _join(e, 'maybe'),
                  child: Text(e.myStatus == 'maybe' ? s.t('oe_you_maybe') : s.t('oe_maybe_btn')),
                ),
              ),
            ],
          ),
          if (e.myStatus != null && !e.mine)
            TextButton(onPressed: _busy ? null : () => _act(() => leaveOpenEvent(e.id)), child: Text(s.t('oe_leave'))),
          if (!e.mine)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.t('oe_join_note'), style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
            ),
        ],
        if (e.mine) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!e.cancelled && !over)
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final saved = await Navigator.of(context)
                              .push<bool>(MaterialPageRoute(builder: (_) => OpenEventFormScreen(editing: e)));
                          if (saved == true) _refresh();
                        },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(s.t('oe_edit')),
                ),
              if (!e.cancelled && !over)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (await _confirm(s.t('oe_confirm_cancel'), s.t('oe_cancel_event'))) {
                            await _act(() => cancelOpenEvent(e.id));
                          }
                        },
                  child: Text(s.t('oe_cancel_event')),
                ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                onPressed: _busy
                    ? null
                    : () async {
                        if (await _confirm(s.t('oe_confirm_delete'), s.t('oe_delete'))) {
                          await _act(() => deleteOpenEvent(e.id), leave: true);
                        }
                      },
                child: Text(s.t('oe_delete')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Kicker(s.t('oe_roster').toUpperCase()),
          const SizedBox(height: 8),
          _Roster(eventId: e.id),
        ] else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy ? null : _report,
              icon: Icon(Icons.flag_outlined, size: 18, color: AppColors.muted),
              label: Text(s.t('oe_report'), style: TextStyle(color: AppColors.muted)),
            ),
          ),
      ],
    );
  }
}

/// who signed up, for the organizer
class _Roster extends ConsumerWidget {
  const _Roster({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ref.watch(openRosterProvider(eventId)).when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
                child: SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))),
          ),
          error: (e, _) => Panel(child: Text(s.t(openEventErrorKey(e)), style: TextStyle(color: AppColors.amber))),
          data: (people) => Panel(
            child: people.isEmpty
                ? Text(s.t('oe_roster_none'), style: TextStyle(color: AppColors.muted))
                : Column(
                    children: [
                      for (final p in people)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name),
                                    if (p.role != null || p.profession != null)
                                      Text(
                                        [
                                          if (p.role != null) s.t('role_${p.role}'),
                                          if (p.profession != null) p.profession!
                                        ].join(' · '),
                                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                                      ),
                                  ],
                                ),
                              ),
                              Pill(s.t('rsvp_${p.status}'), color: statusColor(p.status)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        );
  }
}

// ---------------------------------------------------------------------------
// making and changing one

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
import '../widgets/responsive.dart';
import 'guild_events_screen.dart' show activityIcon, eventWhen, statusColor;

String _two(int n) => n.toString().padLeft(2, '0');

/// 90 min, 2 h, 2 h 30 min
String openEventDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

String _languageName(S s, String code) {
  if (code == 'any') return s.t('oe_any_language');
  for (final l in AppLang.values) {
    if (l.code == code) return l.nativeName;
  }
  return code;
}

/// events anybody who is signed in makes for everybody, apart from the guilds' own. discover them, sign up, make
/// one, see the ones that are yours
class OpenEventsScreen extends ConsumerWidget {
  const OpenEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (!communityReady) return _Blocked(text: s.t('oe_unavailable'));
    if (ref.watch(sessionProvider).valueOrNull == null) return _Blocked(text: s.t('oe_sign_in'), toSettings: true);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.bg,
          onPressed: () async {
            final made =
                await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const OpenEventFormScreen()));
            if (made == true) {
              ref.invalidate(openEventsFeedProvider);
              ref.invalidate(myOpenEventsProvider);
            }
          },
          icon: const Icon(Icons.add),
          label: Text(s.t('oe_create')),
        ),
        body: Column(
          children: [
            AppTabBar(labels: [s.t('oe_tab_discover'), s.t('oe_tab_mine')]),
            const Expanded(child: TabBarView(children: [_Discover(), _Mine()])),
          ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public, size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
            if (toSettings) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref.read(sectionProvider.notifier).state = AppSection.settings,
                child: Text(s.t('nav_settings')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// the lists

class _Discover extends ConsumerWidget {
  const _Discover();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Column(
      children: [
        const _FilterBar(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () async {
              ref.invalidate(openEventsFeedProvider);
              await ref.read(openEventsFeedProvider.future);
            },
            child: AsyncView<List<OpenEvent>>(
              value: ref.watch(openEventsFeedProvider),
              onRetry: () => ref.invalidate(openEventsFeedProvider),
              builder: (events) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                children: [
                  if (events.isEmpty)
                    Padding(padding: const EdgeInsets.all(24), child: EmptyNote(s.t('oe_none')))
                  else
                    CardWrap(children: [for (final e in events) _OpenEventCard(event: e)]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final filter = ref.watch(openEventsFilterProvider);
    void set(OpenEventsFilter f) => ref.read(openEventsFilterProvider.notifier).state = f;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChoiceChip(
            label: Text(s.t('oe_all')),
            selected: filter.activity == null,
            onSelected: (_) => set(filter.withActivity(null)),
          ),
          for (final a in openEventActivities)
            ChoiceChip(
              avatar: Icon(activityIcon(a), size: 16),
              label: Text(s.t('activity_$a')),
              selected: filter.activity == a,
              onSelected: (_) => set(filter.withActivity(a)),
            ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: filter.language,
              dropdownColor: AppColors.surface2,
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(s.t('oe_any_language'))),
                for (final l in AppLang.values) DropdownMenuItem<String?>(value: l.code, child: Text(l.nativeName)),
              ],
              onChanged: (v) => set(filter.withLanguage(v)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mine extends ConsumerWidget {
  const _Mine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async {
        ref.invalidate(myOpenEventsProvider);
        await ref.read(myOpenEventsProvider.future);
      },
      child: AsyncView<List<OpenEvent>>(
        value: ref.watch(myOpenEventsProvider),
        onRetry: () => ref.invalidate(myOpenEventsProvider),
        builder: (events) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            if (events.isEmpty)
              Padding(padding: const EdgeInsets.all(24), child: EmptyNote(s.t('oe_none_mine')))
            else
              CardWrap(children: [for (final e in events) _OpenEventCard(event: e)]),
          ],
        ),
      ),
    );
  }
}

class _OpenEventCard extends ConsumerWidget {
  const _OpenEventCard({required this.event});

  final OpenEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final e = event;
    final live = e.isLive(DateTime.now());
    return AppCard(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OpenEventScreen(eventId: e.id)));
        ref.invalidate(openEventsFeedProvider);
        ref.invalidate(myOpenEventsProvider);
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
                  '${eventWhen(s, e.startAt)} · ${e.organizer}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (e.cancelled) Pill(s.t('oe_cancelled'), color: AppColors.red),
                    if (e.hidden) Pill(s.t('oe_hidden'), color: AppColors.amber),
                    if (live) Pill(s.t('event_live'), color: AppColors.green),
                    Pill(_languageName(s, e.language)),
                    Pill(e.maxParticipants == null
                        ? s.t('oe_going', {'n': e.going})
                        : s.t('oe_places', {'n': e.going, 'max': e.maxParticipants})),
                    if (e.isFull && !e.mine && e.myStatus != 'going') Pill(s.t('oe_full'), color: AppColors.red),
                    if (e.myStatus != null) Pill(s.t('rsvp_${e.myStatus}'), color: statusColor(e.myStatus)),
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
// one event

class OpenEventScreen extends ConsumerWidget {
  const OpenEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final event = ref.watch(openEventProvider(eventId));
    return Scaffold(
      appBar: AppBar(
          title: Text(event.valueOrNull?.title ?? s.t('public_events'), maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: AsyncView<OpenEvent?>(
        value: event,
        onRetry: () => ref.invalidate(openEventProvider(eventId)),
        builder: (e) => e == null
            ? Center(child: Text(s.t('oe_err_gone'), style: const TextStyle(color: AppColors.muted)))
            : ContentFrame(maxWidth: readingMaxWidth, child: _EventBody(event: e)),
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

  S get _s => ref.read(stringsProvider);

  void _refresh() {
    ref.invalidate(openEventProvider(widget.event.id));
    ref.invalidate(openEventsFeedProvider);
    ref.invalidate(myOpenEventsProvider);
    ref.invalidate(openRosterProvider(widget.event.id));
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
    final canSignUp = !e.mine && !e.cancelled && !e.hidden && !over;
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
                      style: const TextStyle(color: AppColors.muted)),
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
            Pill(_languageName(s, e.language)),
            Pill(s.t('oe_going', {'n': e.going})),
            if (e.maybe > 0) Pill(s.t('oe_maybe', {'n': e.maybe})),
            if (e.maxParticipants != null) Pill(s.t('oe_places', {'n': e.going, 'max': e.maxParticipants})),
            if (e.myStatus != null) Pill(s.t('rsvp_${e.myStatus}'), color: statusColor(e.myStatus)),
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
                    icon: const Icon(Icons.copy, size: 18, color: AppColors.gold),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: e.organizer));
                      if (context.mounted) showToast(context, s.t('oe_copied'));
                    },
                  ),
                ],
              ),
              if (!e.mine)
                Text(s.t('oe_find_note'), style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
            ],
          ),
        ),
        if (e.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Panel(child: Text(e.description, style: const TextStyle(height: 1.45))),
        ],
        const SizedBox(height: 16),
        if (canSignUp) ...[
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy || (e.isFull && e.myStatus != 'going')
                      ? null
                      : () => _act(() => joinOpenEvent(e.id, 'going')),
                  child: Text(e.isFull && e.myStatus != 'going'
                      ? s.t('oe_full')
                      : (e.myStatus == 'going' ? s.t('oe_you_going') : s.t('oe_join'))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _act(() => joinOpenEvent(e.id, 'maybe')),
                  child: Text(e.myStatus == 'maybe' ? s.t('oe_you_maybe') : s.t('oe_maybe_btn')),
                ),
              ),
            ],
          ),
          if (e.myStatus != null)
            TextButton(onPressed: _busy ? null : () => _act(() => leaveOpenEvent(e.id)), child: Text(s.t('oe_leave'))),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s.t('oe_join_note'), style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
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
              icon: const Icon(Icons.flag_outlined, size: 18, color: AppColors.muted),
              label: Text(s.t('oe_report'), style: const TextStyle(color: AppColors.muted)),
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
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold))),
          ),
          error: (e, _) =>
              Panel(child: Text(s.t(openEventErrorKey(e)), style: const TextStyle(color: AppColors.amber))),
          data: (people) => Panel(
            child: people.isEmpty
                ? Text(s.t('oe_roster_none'), style: const TextStyle(color: AppColors.muted))
                : Column(
                    children: [
                      for (final p in people)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(child: Text(p.name)),
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

class OpenEventFormScreen extends ConsumerStatefulWidget {
  const OpenEventFormScreen({super.key, this.editing});

  final OpenEvent? editing;

  @override
  ConsumerState<OpenEventFormScreen> createState() => _OpenEventFormScreenState();
}

class _OpenEventFormScreenState extends ConsumerState<OpenEventFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _max;
  late String _activity;
  late String _language;
  late DateTime _start;
  late int _duration;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _max = TextEditingController(text: e?.maxParticipants?.toString() ?? '');
    _activity = e?.activity ?? 'raid';
    _language = e?.language ?? 'any';
    // tomorrow at eight in the evening, which is when most are played
    final base = DateTime.now().add(const Duration(days: 1));
    _start = e?.startAt ?? DateTime(base.year, base.month, base.day, 20);
    _duration = e?.durationMinutes ?? 120;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateUtils.dateOnly(_start).isBefore(today) ? DateUtils.dateOnly(_start) : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: first,
      lastDate: today.add(const Duration(days: 91)),
    );
    if (picked != null)
      setState(() => _start = DateTime(picked.year, picked.month, picked.day, _start.hour, _start.minute));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (picked != null)
      setState(() => _start = DateTime(_start.year, _start.month, _start.day, picked.hour, picked.minute));
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final title = _title.text.trim();
    if (title.length < 3 || title.length > 80) {
      showToast(context, s.t('oe_err_title'));
      return;
    }
    final maxText = _max.text.trim();
    final max = maxText.isEmpty ? null : int.tryParse(maxText);
    if (maxText.isNotEmpty && (max == null || max < 2 || max > 100)) {
      showToast(context, s.t('oe_err_capacity'));
      return;
    }
    setState(() => _busy = true);
    try {
      final editing = widget.editing;
      if (editing == null) {
        await createOpenEvent(
          title: title,
          startAt: _start,
          durationMinutes: _duration,
          description: _description.text.trim(),
          activity: _activity,
          language: _language,
          maxParticipants: max,
        );
      } else {
        await updateOpenEvent(
          editing.id,
          title: title,
          startAt: _start,
          durationMinutes: _duration,
          description: _description.text.trim(),
          activity: _activity,
          language: _language,
          maxParticipants: max,
        );
      }
      if (!mounted) return;
      showToast(context, s.t(editing == null ? 'oe_created' : 'oe_saved'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showToast(context, s.t(openEventErrorKey(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final editing = widget.editing != null;
    return Scaffold(
      appBar: AppBar(title: Text(s.t(editing ? 'oe_form_edit' : 'oe_form_create'))),
      body: ContentFrame(
        maxWidth: readingMaxWidth,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Kicker(s.t('event_title')),
            const SizedBox(height: 6),
            TextField(
              controller: _title,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration(''),
            ),
            const SizedBox(height: 8),
            Kicker(s.t('event_activity')),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _activity,
              dropdownColor: AppColors.surface,
              decoration: fieldDecoration(''),
              items: [for (final a in openEventActivities) DropdownMenuItem(value: a, child: Text(s.t('activity_$a')))],
              onChanged: (v) => setState(() => _activity = v ?? _activity),
            ),
            const SizedBox(height: 16),
            Kicker(s.t('oe_language')),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _language,
              dropdownColor: AppColors.surface,
              decoration: fieldDecoration(''),
              items: [for (final l in openEventLanguages) DropdownMenuItem(value: l, child: Text(_languageName(s, l)))],
              onChanged: (v) => setState(() => _language = v ?? _language),
            ),
            const SizedBox(height: 16),
            Kicker(s.t('event_when')),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text('${_two(_start.day)}.${_two(_start.month)}.${_start.year}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text('${_two(_start.hour)}:${_two(_start.minute)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Kicker(s.t('event_duration')),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: openEventDurations.contains(_duration) ? _duration : null,
              dropdownColor: AppColors.surface,
              decoration: fieldDecoration(''),
              items: [
                for (final d in openEventDurations) DropdownMenuItem(value: d, child: Text(openEventDuration(d)))
              ],
              onChanged: (v) => setState(() => _duration = v ?? _duration),
            ),
            const SizedBox(height: 16),
            Kicker(s.t('oe_places_field')),
            const SizedBox(height: 6),
            TextField(
              controller: _max,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: fieldDecoration(''),
            ),
            const SizedBox(height: 16),
            Kicker(s.t('event_description')),
            const SizedBox(height: 6),
            TextField(
              controller: _description,
              maxLength: 1000,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDecoration(''),
            ),
            const SizedBox(height: 8),
            Text(s.t('oe_form_note'), style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(s.t('oe_save')),
            ),
          ],
        ),
      ),
    );
  }
}

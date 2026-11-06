import 'package:flutter/material.dart';
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
import 'open_event_form_screen.dart';
import 'open_event_labels.dart';
import 'open_event_roles_screen.dart';
import 'open_event_screen.dart';

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
            Icon(Icons.public, size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.4)),
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
              builder: (all) {
                final hidden = ref.watch(hiddenOrganizersProvider);
                final events = [
                  for (final e in all)
                    if (!hidden.contains(e.organizer)) e
                ];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                  children: [
                    if (events.isEmpty)
                      Padding(padding: const EdgeInsets.all(24), child: EmptyNote(s.t('oe_none')))
                    else
                      CardWrap(children: [for (final e in events) _OpenEventCard(event: e)]),
                    if (hidden.isNotEmpty)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () => _showHiddenOrganizers(context),
                          child: Text(
                            s.t('oe_hidden_manage', {'n': hidden.length}),
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ),
                  ],
                );
              },
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
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: filter.region,
              dropdownColor: AppColors.surface2,
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(s.t('oe_region_all'))),
                for (final r in const ['eu', 'na'])
                  DropdownMenuItem<String?>(value: r, child: Text(s.t('oe_region_$r'))),
              ],
              onChanged: (v) => set(filter.withRegion(v)),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: filter.tag,
              dropdownColor: AppColors.surface2,
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(s.t('oe_tag_any'))),
                for (final t in openEventTags) DropdownMenuItem<String?>(value: t, child: Text(s.t('oe_tag_$t'))),
              ],
              onChanged: (v) => set(filter.withTag(v)),
            ),
          ),
          TextButton.icon(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OpenEventRolesScreen())),
            icon: const Icon(Icons.forum_outlined, size: 18),
            label: Text(s.t('oe_roles_title')),
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
        await showOpenEvent(context, e.id);
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
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (e.cancelled) Pill(s.t('oe_cancelled'), color: AppColors.red),
                    if (e.hidden) Pill(s.t('oe_hidden'), color: AppColors.amber),
                    if (live) Pill(s.t('event_live'), color: AppColors.green),
                    Pill(s.t('oe_region_${e.region}')),
                    Pill(openEventLanguageName(s, e.language)),
                    for (final t in e.tags) Pill(s.t('oe_tag_$t')),
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
          Icon(Icons.chevron_right, color: AppColors.chevron),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// one event

/// the organizers whose events are hidden, each with a way to show them again
void _showHiddenOrganizers(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final s = ref.watch(stringsProvider);
        final hidden = ref.watch(hiddenOrganizersProvider).toList()..sort();
        if (hidden.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(ctx).maybePop());
        return SimpleDialog(
          title: Text(s.t('oe_hidden_manage', {'n': hidden.length})),
          children: [
            for (final name in hidden)
              ListTile(
                title: Text(name),
                trailing: TextButton(
                  onPressed: () => ref.read(hiddenOrganizersProvider.notifier).show(name),
                  child: Text(s.t('oe_show_again')),
                ),
              ),
          ],
        );
      },
    ),
  );
}

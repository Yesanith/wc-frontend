part of '../events_screen.dart';

/// one run of an event from the timeline: when it runs, how long until it
/// starts, and buttons to pin it or read about it on the wiki
void showEventSheet(BuildContext context, WidgetRef ref, Occurrence o) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final s = ref.watch(stringsProvider);
        final key = eventKey(o.map, o.event);
        final pinned = ref.watch(pinnedEventsProvider).contains(key);
        final now = DateTime.now();
        final when = o.activeAt(now)
            ? s.t('event_running')
            : o.start.isAfter(now)
            ? s.t('event_starts_in', {'t': countdown(o.start.difference(now))})
            : s.t('event_ended');
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.event.name, style: display(19)),
                const SizedBox(height: 4),
                Text(
                  '${o.map.name} · ${localClock(o.start)}–${localClock(o.end)}',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  when,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => togglePin(context, ref, key),
                        icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18),
                        label: Text(pinned ? s.t('unpin') : s.t('pin')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // read what the page needs before the sheet goes away
                          openWikiPage(context, ref, o.event.name);
                          Navigator.of(ctx).pop();
                        },
                        icon: const Icon(Icons.menu_book_outlined, size: 18),
                        label: Text(s.t('wiki')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// pins or unpins an event. a pin also asks for the notification permission
/// the first time and says what the player can expect, alerts come before
/// every start of a pinned event
Future<void> togglePin(BuildContext context, WidgetRef ref, String key) async {
  final wasPinned = ref.read(pinnedEventsProvider).contains(key);
  await ref.read(pinnedEventsProvider.notifier).toggle(key);
  if (wasPinned) return;
  final settings = ref.read(bossAlertSettingsProvider);
  final s = ref.read(stringsProvider);
  final plan = alertsFor(ref.read(pinnedEventsProvider), settings.lead, s);
  final feedback = await pinFeedback(
    settings: settings,
    prefs: ref.read(prefsProvider),
    pinFitted: !plan.skipped.contains(key),
  );
  if (!context.mounted || feedback == PinFeedback.none) return;
  showToast(context, switch (feedback) {
    PinFeedback.alertsOn => s.t('boss_alert_on', {'n': settings.lead}),
    PinFeedback.noRoom => s.t('boss_alert_limit', {'n': plan.skipped.length, 'max': maxBossAlerts}),
    _ => s.t('push_denied'),
  }, duration: const Duration(seconds: 5));
}

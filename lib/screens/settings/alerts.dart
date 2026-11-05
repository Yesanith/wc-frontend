part of '../settings_screen.dart';

/// the notifications of the trading post: an item that was sold, a buy order that was filled. the phone looks at the history with the player's own key, which stays on it
class _TradeNotifyPanel extends ConsumerStatefulWidget {
  const _TradeNotifyPanel();

  @override
  ConsumerState<_TradeNotifyPanel> createState() => _TradeNotifyPanelState();
}

class _TradeNotifyPanelState extends ConsumerState<_TradeNotifyPanel> {
  bool _busy = false;

  Future<void> _set(bool on) async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      final outcome = await ref.read(tradeNotifyProvider.notifier).set(on);
      if (!mounted) return;
      switch (outcome) {
        case TradeNotifyOutcome.needsKey:
          showToast(context, s.t('tp_notify_needs_key'));
        case TradeNotifyOutcome.denied:
          showToast(context, s.t('push_denied'));
        case TradeNotifyOutcome.on:
        case TradeNotifyOutcome.off:
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Panel(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: ref.watch(tradeNotifyProvider),
        onChanged: _busy ? null : _set,
        title: Text(s.t('tp_notify_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        subtitle: Text(s.t('tp_notify_hint'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ),
    );
  }
}

/// alerts before the world events the player pinned. they come from the
/// phone's own alarms, so they need no account and no server
class _BossAlertsPanel extends ConsumerStatefulWidget {
  const _BossAlertsPanel();

  @override
  ConsumerState<_BossAlertsPanel> createState() => _BossAlertsPanelState();
}

class _BossAlertsPanelState extends ConsumerState<_BossAlertsPanel> {
  bool _busy = false;

  Future<void> _turnOn(bool on) async {
    final s = ref.read(stringsProvider);
    await ref.read(bossAlertSettingsProvider.notifier).setEnabled(on);
    if (!on) return;
    setState(() => _busy = true);
    final allowed = await requestBossAlertPermission();
    ref.read(bossAlertsRecheckProvider.notifier).bump();
    if (mounted) {
      setState(() => _busy = false);
      if (!allowed) showToast(context, s.t('push_denied'));
    }
  }

  Future<void> _test() async {
    final s = ref.read(stringsProvider);
    if (!await requestBossAlertPermission()) {
      if (mounted) showToast(context, s.t('push_denied'));
      return;
    }
    await showBossAlertTest(
      title: 'Wondrous Compass',
      body: s.t('boss_alert_test_body'),
      channelName: s.t('boss_alerts_title'),
      channelDescription: s.t('boss_alerts_note'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(bossAlertSettingsProvider);
    final pins = ref.watch(pinnedEventsProvider);
    final status = ref.watch(bossAlertStatusProvider).valueOrNull;
    final plan = settings.enabled ? alertsFor(pins, settings.lead, s) : const BossAlertPlan([], []);
    final count = plan.alerts.length;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.enabled,
            onChanged: _busy ? null : _turnOn,
            title: Text(s.t('boss_alerts_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            subtitle: Text(s.t('boss_alerts_note'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
          if (settings.enabled) ...[
            const SizedBox(height: 8),
            Text(s.t('boss_alerts_lead'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final m in bossAlertLeads)
                  ChoiceChip(
                    label: Text(s.t('minutes_short', {'n': m})),
                    selected: settings.lead == m,
                    onSelected: (_) => ref.read(bossAlertSettingsProvider.notifier).setLead(m),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              pins.isEmpty ? s.t('boss_alert_none') : s.t('boss_alert_scheduled', {'pins': pins.length, 'n': count}),
              style: TextStyle(fontSize: 12, color: AppColors.textSoft),
            ),
            if (plan.skipped.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                s.t('boss_alert_limit', {'n': plan.skipped.length, 'max': maxBossAlerts}),
                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.gold),
              ),
            ],
            if (status != null && !status.notifications) ...[
              const SizedBox(height: 10),
              FilledButton(onPressed: _busy ? null : () => _turnOn(true), child: Text(s.t('boss_alert_allow'))),
            ],
            if (status != null && status.notifications && !status.exact) ...[
              const SizedBox(height: 10),
              Text(s.t('boss_alert_exact_note'), style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: () async {
                  await openExactAlarmSettings();
                  ref.read(bossAlertsRecheckProvider.notifier).bump();
                },
                child: Text(s.t('boss_alert_exact_button')),
              ),
            ],
            const SizedBox(height: 6),
            TextButton(onPressed: _test, child: Text(s.t('boss_alert_test'))),
          ],
        ],
      ),
    );
  }
}

/// a reminder an hour before the daily and the weekly reset, for the Wizard's Vault and the dailies that would be forgotten. like the
/// alerts of the events they come from the alarms of the phone
class _ResetAlertsPanel extends ConsumerStatefulWidget {
  const _ResetAlertsPanel();

  @override
  ConsumerState<_ResetAlertsPanel> createState() => _ResetAlertsPanelState();
}

class _ResetAlertsPanelState extends ConsumerState<_ResetAlertsPanel> {
  bool _busy = false;

  Future<void> _set({required bool daily, required bool on}) async {
    final s = ref.read(stringsProvider);
    final settings = ref.read(bossAlertSettingsProvider.notifier);
    setState(() => _busy = true);
    try {
      await (daily ? settings.setResetDaily(on) : settings.setResetWeekly(on));
      if (!on) return;
      final allowed = await requestBossAlertPermission();
      ref.read(bossAlertsRecheckProvider.notifier).bump();
      if (mounted && !allowed) showToast(context, s.t('push_denied'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(bossAlertSettingsProvider);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(s.t('reset_alerts_title').toUpperCase()),
          const SizedBox(height: 4),
          Text(s.t('reset_alerts_note'), style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.resetDaily,
            onChanged: _busy ? null : (on) => _set(daily: true, on: on),
            title: Text(s.t('reset_alert_daily'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: settings.resetWeekly,
            onChanged: _busy ? null : (on) => _set(daily: false, on: on),
            title: Text(s.t('reset_alert_weekly'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

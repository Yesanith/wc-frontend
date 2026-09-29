import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../services/boss_alerts.dart';
import 'settings.dart';

/// how long before an event starts the alert comes, in minutes
const bossAlertLeads = [5, 10, 15, 30];
const defaultBossAlertLead = 10;

class BossAlertSettings {
  const BossAlertSettings({this.enabled = true, this.lead = defaultBossAlertLead});

  final bool enabled;
  final int lead;
}

class BossAlertSettingsNotifier extends Notifier<BossAlertSettings> {
  static const _enabledKey = 'boss_alerts_enabled';
  static const _leadKey = 'boss_alerts_lead';

  @override
  BossAlertSettings build() {
    final prefs = ref.read(prefsProvider);
    final lead = prefs.getInt(_leadKey);
    return BossAlertSettings(
      enabled: prefs.getBool(_enabledKey) ?? true,
      lead: lead != null && bossAlertLeads.contains(lead) ? lead : defaultBossAlertLead,
    );
  }

  Future<void> setEnabled(bool on) async {
    state = BossAlertSettings(enabled: on, lead: state.lead);
    await ref.read(prefsProvider).setBool(_enabledKey, on);
  }

  Future<void> setLead(int minutes) async {
    if (!bossAlertLeads.contains(minutes)) return;
    state = BossAlertSettings(enabled: state.enabled, lead: minutes);
    await ref.read(prefsProvider).setInt(_leadKey, minutes);
  }
}

final bossAlertSettingsProvider =
    NotifierProvider<BossAlertSettingsNotifier, BossAlertSettings>(BossAlertSettingsNotifier.new);

/// bumped when the app comes back to the foreground, or a permission may have
/// changed: the alerts are checked again then, which is cheap when nothing
/// differs
class BossAlertsRecheck extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final bossAlertsRecheckProvider = NotifierProvider<BossAlertsRecheck, int>(BossAlertsRecheck.new);

/// the alerts for the pinned events, in the app's language
BossAlertPlan alertsFor(Set<String> pins, int lead, S s) =>
    planBossAlerts(pins: pins, lead: lead, body: (map) => s.t('boss_alert_body', {'n': lead, 'map': map.name}));

const _sigKey = 'boss_alerts_sig';
const _onToldKey = 'boss_alerts_on_told';
const _deniedToldKey = 'boss_alerts_denied_told';

/// brings the phone's alarms in line with the pinned events. does nothing
/// when they already match, and nothing without the notification permission
Future<void> syncBossAlerts({
  required Set<String> pins,
  required BossAlertSettings settings,
  required S s,
  required SharedPreferences prefs,
}) async {
  if (!bossAlertsReady) return;
  final alerts = settings.enabled ? alertsFor(pins, settings.lead, s).alerts : const <BossAlert>[];
  if (alerts.isEmpty) {
    if (prefs.getString(_sigKey) != null || await pendingBossAlerts() > 0) {
      await cancelBossAlerts();
      await prefs.remove(_sigKey);
    }
    return;
  }
  if (!await bossAlertsAllowed()) return;
  final exact = await exactAlarmsAllowed();
  final signature = alertsSignature(alerts, exact: exact);
  // android drops alarms when the app is force stopped, so the count is
  // checked as well as what was scheduled last time
  if (prefs.getString(_sigKey) == signature && await pendingBossAlerts() == alerts.length) return;
  await scheduleBossAlerts(
    alerts,
    exact: exact,
    channelName: s.t('boss_alerts_title'),
    channelDescription: s.t('boss_alerts_note'),
  );
  await prefs.setString(_sigKey, signature);
}

/// keeps the alarms current while the app runs: after the pins, the settings
/// or the language change, and when the app comes back. pins change in bursts,
/// so one pass follows the last change
final bossAlertsSyncProvider = Provider<void>((ref) {
  final pins = ref.watch(pinnedEventsProvider);
  final settings = ref.watch(bossAlertSettingsProvider);
  final s = ref.watch(stringsProvider);
  ref.watch(bossAlertsRecheckProvider);
  final prefs = ref.read(prefsProvider);
  final timer = Timer(const Duration(milliseconds: 700), () {
    syncBossAlerts(pins: pins, settings: settings, s: s, prefs: prefs).catchError((_) {});
  });
  ref.onDispose(timer.cancel);
});

/// what the phone allows right now, for the settings panel
class BossAlertStatus {
  const BossAlertStatus({required this.notifications, required this.exact});

  final bool notifications;
  final bool exact;
}

final bossAlertStatusProvider = FutureProvider.autoDispose<BossAlertStatus>((ref) async {
  ref.watch(bossAlertsRecheckProvider);
  return BossAlertStatus(notifications: await bossAlertsAllowed(), exact: await exactAlarmsAllowed());
});

/// what to tell the player after they pinned an event
enum PinFeedback { none, alertsOn, denied, noRoom }

/// asks for the notification permission when a pin needs it, and decides
/// whether there is anything to say. "alerts are on" is said once, the
/// blocked notice once too, not at every pin
Future<PinFeedback> pinFeedback({
  required BossAlertSettings settings,
  required SharedPreferences prefs,
  required bool pinFitted,
}) async {
  if (!settings.enabled || !bossAlertsReady) return PinFeedback.none;
  // said every time: unlike the others it is about this very pin
  if (!pinFitted) return PinFeedback.noRoom;
  if (await requestBossAlertPermission()) {
    if (prefs.getBool(_onToldKey) == true) return PinFeedback.none;
    await prefs.setBool(_onToldKey, true);
    return PinFeedback.alertsOn;
  }
  if (prefs.getBool(_deniedToldKey) == true) return PinFeedback.none;
  await prefs.setBool(_deniedToldKey, true);
  return PinFeedback.denied;
}

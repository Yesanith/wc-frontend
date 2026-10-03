import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/metas.dart';

/// One alert of a pinned event. World events run on a fixed daily schedule
/// (minutes after midnight utc), so an alert is a time of day that repeats
/// every day: the phone's alarm system keeps it going with the app closed
/// and after a reboot, no server and no need to open the app again.
class BossAlert {
  const BossAlert({required this.id, required this.minuteOfDay, required this.title, required this.body});

  final int id;

  /// when it fires, minutes after midnight utc
  final int minuteOfDay;
  final String title;
  final String body;
}

int _fnv1a(String text) {
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(text)) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// a stable notification id for one start time of one event, so the same
/// alert is always the same alert between runs. Android wants a positive int
int bossAlertId(String key, int startMinute) => _fnv1a('$key|$startMinute') & 0x7fffffff;

/// how many alerts the app schedules at most. Android allows an app 500
/// alarms at once and throws past that, and the whole schedule has 866 start
/// times a day, so somebody pinning every hourly event would hit the limit
const maxBossAlerts = 400;

/// the alerts to schedule, and the pinned events that did not fit
class BossAlertPlan {
  const BossAlertPlan(this.alerts, this.skipped);

  final List<BossAlert> alerts;

  /// event keys left without alerts because [maxBossAlerts] was reached
  final List<String> skipped;
}

/// the alerts for the pinned events: one per start time, [lead] minutes
/// before it. [body] writes the text of an alert in the app's language.
/// [pins] is taken in the order the events were pinned: when the limit is
/// reached the events pinned last go without, and an event gets all of its
/// alerts or none, never a part of them
BossAlertPlan planBossAlerts({
  required Iterable<String> pins,
  required int lead,
  required String Function(MetaMap map) body,
  Iterable<MetaMap>? maps,
  int limit = maxBossAlerts,
}) {
  final byKey = <String, List<(MetaMap, MetaEvent)>>{};
  for (final map in maps ?? metaMaps) {
    for (final event in map.events) {
      byKey.putIfAbsent(eventKey(map, event), () => []).add((map, event));
    }
  }
  final out = <BossAlert>[];
  final skipped = <String>[];
  final used = <int>{};
  for (final key in pins.toSet()) {
    final found = byKey[key];
    if (found == null) continue;
    final starts = found.fold<int>(0, (n, e) => n + e.$2.times.length);
    if (out.length + starts > limit) {
      skipped.add(key);
      continue;
    }
    for (final (map, event) in found) {
      for (final start in event.times) {
        var id = bossAlertId(key, start);
        // a clash between two of a few hundred ids is unlikely, never ignored
        while (!used.add(id)) {
          id = (id + 1) & 0x7fffffff;
        }
        out.add(BossAlert(
          id: id,
          // a start just after midnight alerts before it, on the day before
          minuteOfDay: (start - lead) % 1440,
          title: event.name,
          body: body(map),
        ));
      }
    }
  }
  out.sort((a, b) {
    final byTime = a.minuteOfDay.compareTo(b.minuteOfDay);
    return byTime != 0 ? byTime : a.title.compareTo(b.title);
  });
  return BossAlertPlan(out, skipped);
}

/// the next moment, utc, this time of day comes round
DateTime nextAlertAt(DateTime now, int minuteOfDay) {
  final n = now.toUtc();
  var at = DateTime.utc(n.year, n.month, n.day).add(Duration(minutes: minuteOfDay));
  // a few seconds of grace: the plugin refuses a moment that has passed
  if (!at.isAfter(n.add(const Duration(seconds: 10)))) at = at.add(const Duration(days: 1));
  return at;
}

/// changes when anything about the scheduled alerts changes, so an
/// unchanged plan is not scheduled again
String alertsSignature(List<BossAlert> alerts, {required bool exact}) {
  final text = [
    exact ? 'exact' : 'inexact',
    for (final a in alerts) '${a.id}:${a.minuteOfDay}:${a.title}:${a.body}',
  ].join('\n');
  return _fnv1a(text).toRadixString(16);
}

// ---------------------------------------------------------------------------
// the phone side

const _channelId = 'world_events';
const _payload = 'world_events';

final _plugin = FlutterLocalNotificationsPlugin();
bool _ready = false;

/// whether the notification plugin started. false switches alerts off, the
/// rest of the app never depends on it
bool get bossAlertsReady => _ready;

/// the payload of taps on an alert, so the app can open the events
final bossAlertTaps = StreamController<String?>.broadcast();

/// set when a tap on an alert is what started the app
String? bossAlertLaunchPayload;

bool isBossAlertPayload(String? payload) => payload == _payload;

const _tradeChannelId = 'trading_post';
const _tradePayload = 'trading_post';

/// a tap on what the trading post did for the player: the app opens at the trading post
bool isTradePayload(String? payload) => payload == _tradePayload;

/// tells the player what the trading post did: items sold, or buy orders filled. [id] is the notification's own, so that the next does not replace it
Future<void> showTradeNotification({
  required int id,
  required String title,
  required String body,
  required String channelName,
  required String channelDescription,
}) =>
    _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _tradeChannelId,
          channelName,
          channelDescription: channelDescription,
          // the lines of what sold are all there when it is opened
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      payload: _tradePayload,
    );

Future<void> initBossAlerts() async {
  try {
    await _plugin.initialize(
      // the emblem in white, filling its square: android shows only its outline, and a
      // full colour icon would be a white square
      settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_stat_tyria')),
      onDidReceiveNotificationResponse: (response) => bossAlertTaps.add(response.payload),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      bossAlertLaunchPayload = launch?.notificationResponse?.payload;
    }
    _ready = true;
  } catch (_) {
    _ready = false;
  }
}

AndroidFlutterLocalNotificationsPlugin? get _android =>
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

/// notifications are allowed for the app right now
Future<bool> bossAlertsAllowed() async {
  try {
    return await _android?.areNotificationsEnabled() ?? false;
  } catch (_) {
    return false;
  }
}

/// asks for the permission on Android 13 and later, true when granted
Future<bool> requestBossAlertPermission() async {
  try {
    if (await bossAlertsAllowed()) return true;
    return await _android?.requestNotificationsPermission() ?? false;
  } catch (_) {
    return false;
  }
}

/// exact alarms are allowed. without them Android may hold an alert back by a
/// few minutes to save power
Future<bool> exactAlarmsAllowed() async {
  try {
    return await _android?.canScheduleExactNotifications() ?? false;
  } catch (_) {
    return false;
  }
}

/// opens the system page where the player allows exact alarms for the app
Future<void> openExactAlarmSettings() async {
  try {
    await _android?.requestExactAlarmsPermission();
  } catch (_) {}
}

NotificationDetails _details(String channelName, String channelDescription) => NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

/// how many alerts the alarm system holds for the app right now
Future<int> pendingBossAlerts() async {
  try {
    return (await _plugin.pendingNotificationRequests()).length;
  } catch (_) {
    return 0;
  }
}

Future<void> cancelBossAlerts() async {
  try {
    await _plugin.cancelAllPendingNotifications();
  } catch (_) {}
}

/// replaces every scheduled alert with [alerts], each repeating daily
Future<void> scheduleBossAlerts(
  List<BossAlert> alerts, {
  required bool exact,
  required String channelName,
  required String channelDescription,
  DateTime? now,
}) async {
  await _plugin.cancelAllPendingNotifications();
  final details = _details(channelName, channelDescription);
  final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  final at = now ?? DateTime.now();
  for (final a in alerts) {
    final when = nextAlertAt(at, a.minuteOfDay);
    await _plugin.zonedSchedule(
      id: a.id,
      scheduledDate: tz.TZDateTime.utc(when.year, when.month, when.day, when.hour, when.minute),
      notificationDetails: details,
      androidScheduleMode: mode,
      title: a.title,
      body: a.body,
      payload: _payload,
      // the time of day repeats daily, in utc where the schedule lives
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}

/// shows an alert right now, to see that they work on this phone
Future<void> showBossAlertTest({
  required String title,
  required String body,
  required String channelName,
  required String channelDescription,
}) =>
    _plugin.show(
      id: 1,
      title: title,
      body: body,
      notificationDetails: _details(channelName, channelDescription),
      payload: _payload,
    );

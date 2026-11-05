import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../data/metas.dart';
import '../l10n/strings.dart';
import '../state/settings.dart';

/// the widget exists on a phone that runs Android, nowhere else
bool get homeWidgetReady => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// the class of the widget in the android project, which ci/widget.py puts there
const homeWidgetProvider = 'com.yesanith.wondrous_compass.TyriaWidgetProvider';

/// the start times the widget counts down to, one line for each: the minute of the day (UTC) the event
/// starts, its name and its map, apart by tabs. the events that are pinned, and when none is, the
/// world bosses. the events run on a fixed daily schedule, so the widget needs this only once, and
/// works out what comes next from the clock
String widgetSchedule(Set<String> pins, {Iterable<MetaMap>? maps}) {
  final all = maps ?? metaMaps;
  final pinned = <(int, String, String)>[];
  final bosses = <(int, String, String)>[];
  for (final map in all) {
    for (final event in map.events) {
      final isPinned = pins.contains(eventKey(map, event));
      final isBoss = event.kind == MetaKind.boss || event.kind == MetaKind.hardBoss;
      for (final minute in event.times) {
        if (isPinned) pinned.add((minute, event.name, map.name));
        if (isBoss) bosses.add((minute, event.name, map.name));
      }
    }
  }
  final chosen = pinned.isNotEmpty ? pinned : bosses;
  chosen.sort((a, b) => a.$1.compareTo(b.$1));
  return chosen.map((e) => '${e.$1}\t${_clean(e.$2)}\t${_clean(e.$3)}').join('\n');
}

String _clean(String text) => text.replaceAll(RegExp(r'[\t\n]'), ' ');

/// writes the schedule and the words of the widget where it reads them, and asks it to draw again
Future<void> syncHomeWidget({required Set<String> pins, required S s}) async {
  if (!homeWidgetReady) return;
  await HomeWidget.saveWidgetData<String>('schedule', widgetSchedule(pins));
  await HomeWidget.saveWidgetData<String>('label_next', pins.isEmpty ? s.t('widget_next_boss') : s.t('widget_next'));
  await HomeWidget.saveWidgetData<String>('label_daily', s.t('widget_daily'));
  await HomeWidget.saveWidgetData<String>('label_weekly', s.t('widget_weekly'));
  await HomeWidget.saveWidgetData<String>('label_none', s.t('widget_open_app'));
  await HomeWidget.updateWidget(qualifiedAndroidName: homeWidgetProvider);
}

/// keeps the widget current while the app runs: after the pins or the language change. pins change in
/// bursts, so one pass follows the last change
final homeWidgetSyncProvider = Provider<void>((ref) {
  final pins = ref.watch(pinnedEventsProvider);
  final s = ref.watch(stringsProvider);
  final timer = Timer(const Duration(milliseconds: 900), () {
    syncHomeWidget(pins: pins, s: s).catchError((_) {});
  });
  ref.onDispose(timer.cancel);
});

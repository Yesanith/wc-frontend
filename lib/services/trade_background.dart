import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../l10n/strings.dart';
import '../state/api.dart';
import '../state/trade_alerts.dart';
import 'boss_alerts.dart';
import 'trade_check.dart';

const _task = 'trading-post-check';

/// only Android runs a task of the app when the app is closed, at a time of its choosing and not sooner than every quarter of an hour. a browser and the other platforms have none
bool get tradeBackgroundSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// the language the app is in, from what it kept of the player's choice, or else the phone's
AppLang langFromPrefs(SharedPreferences prefs, {String? deviceLanguage}) {
  final code = prefs.getString('lang') ?? deviceLanguage ?? PlatformDispatcher.instance.locale.languageCode;
  return AppLang.values.firstWhere((l) => l.code == code, orElse: () => AppLang.en);
}

/// what Android runs in a process of its own when the time comes. it has no providers and nothing the app started: it reads what it needs where it is kept, and a failure is
/// only a look that did not happen, the next is in a quarter of an hour
@pragma('vm:entry-point')
void tradeBackgroundEntry() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(tradeNotifyPref) != true) return true;
      final keys = parseStoredKeys(await const FlutterSecureStorage().read(key: storedKeysStorageKey));
      if (keys.isEmpty) return true;
      await initBossAlerts();
      await checkTradingPost(keys: keys, prefs: prefs, lang: langFromPrefs(prefs));
    } catch (_) {
      // not this time
    }
    return true;
  });
}

bool _started = false;

/// tells the system what to run: once, where the app begins
Future<void> initTradeBackground() async {
  if (!tradeBackgroundSupported || _started) return;
  try {
    await Workmanager().initialize(tradeBackgroundEntry);
    _started = true;
  } catch (_) {
    // without it there are only the looks the app makes while it is open
  }
}

/// the look every quarter of an hour, with a connection, is asked for or let go of. asked for again it is the same one, not a second
Future<void> setTradeBackground(bool on) async {
  if (!tradeBackgroundSupported) return;
  try {
    await initTradeBackground();
    if (on) {
      await Workmanager().registerPeriodicTask(
        _task,
        _task,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } else {
      await Workmanager().cancelByUniqueName(_task);
    }
  } catch (_) {
    // the looks in the app go on
  }
}

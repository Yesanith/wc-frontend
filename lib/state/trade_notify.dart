import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/boss_alerts.dart';
import '../services/trade_background.dart';
import '../services/trade_check.dart';
import 'api.dart';
import 'settings.dart';
import 'trade_alerts.dart';

/// what turning the notifications of the trading post on or off does to the phone: the permission, the look every quarter of an hour while the app is closed, and the first look.
/// a pretend one in a test
abstract interface class TradeNotifyEffects {
  /// the player allows notifications for the app
  Future<bool> allowNotifications();

  /// the look while the app is closed is asked for or let go of
  Future<void> background(bool on);

  /// what is in the history now is noted, so that only what happens after is told
  Future<void> firstLook();
}

class PlatformTradeNotifyEffects implements TradeNotifyEffects {
  const PlatformTradeNotifyEffects(this.ref);

  final Ref ref;

  @override
  Future<bool> allowNotifications() => requestBossAlertPermission();

  @override
  Future<void> background(bool on) => setTradeBackground(on);

  @override
  Future<void> firstLook() async {
    final keys = ref.read(keysProvider).valueOrNull ?? const <StoredKey>[];
    if (keys.isEmpty) return;
    await checkTradingPost(keys: keys, prefs: ref.read(prefsProvider), lang: ref.read(langProvider));
  }
}

final tradeNotifyEffectsProvider = Provider<TradeNotifyEffects>((ref) => PlatformTradeNotifyEffects(ref));

/// how a request to turn them on or off went
enum TradeNotifyOutcome { on, off, needsKey, denied }

/// whether the player asked to be told what the trading post did for them
class TradeNotifyNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider).getBool(tradeNotifyPref) ?? false;

  Future<TradeNotifyOutcome> set(bool on) async {
    final prefs = ref.read(prefsProvider);
    final effects = ref.read(tradeNotifyEffectsProvider);
    if (!on) {
      state = false;
      await prefs.setBool(tradeNotifyPref, false);
      await effects.background(false);
      return TradeNotifyOutcome.off;
    }
    // there is nothing to look at without a key, and nothing to show without the permission
    final keys = ref.read(keysProvider).valueOrNull ?? const <StoredKey>[];
    if (keys.isEmpty) return TradeNotifyOutcome.needsKey;
    if (!await effects.allowNotifications()) return TradeNotifyOutcome.denied;
    state = true;
    await prefs.setBool(tradeNotifyPref, true);
    await effects.background(true);
    try {
      await effects.firstLook();
    } catch (_) {
      // the first look is made by the next one
    }
    return TradeNotifyOutcome.on;
  }
}

final tradeNotifyProvider = NotifierProvider<TradeNotifyNotifier, bool>(TradeNotifyNotifier.new);

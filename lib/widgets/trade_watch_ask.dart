import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/push.dart';
import '../state/api.dart';
import '../state/community.dart';
import '../state/settings.dart';
import '../state/trade_notify.dart';
import '../state/trade_watch.dart';
import '../theme.dart';
import 'common.dart';

/// the question asked once, after the game account is linked: may the server tell the player what their trading post
/// did, and what it is given for that, in plain words. true for yes
class TradeWatchAsk extends ConsumerWidget {
  const TradeWatchAsk({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      icon: Icon(Icons.storefront_outlined, color: AppColors.gold),
      title: Text(s.t('trade_watch_title')),
      content: SingleChildScrollView(
        child: Text(s.t('trade_watch_ask'), style: TextStyle(height: 1.45, color: AppColors.textSoft)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.t('trade_watch_no'))),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s.t('trade_watch_yes'))),
      ],
    );
  }
}

/// turns the server's watch on for the account of the active key: the notifications of this device first, then the
/// subtoken. the phone's own look is let go of, or every sale would be told twice. whether it is on
Future<bool> turnOnTradeWatch(BuildContext context, ProviderContainer container) async {
  final s = container.read(stringsProvider);
  final prefs = container.read(prefsProvider);
  void say(String key) {
    if (context.mounted) showToast(context, s.t(key), duration: const Duration(seconds: 5));
  }

  try {
    final bool allowed;
    try {
      allowed = await enablePush(container.read(langProvider).code);
    } catch (e) {
      // the browser turned the subscription down although notifications are allowed: Brave, for one, leaves the push
      // service of Google off until it is switched on in its settings
      if (context.mounted) {
        showToast(context, '${s.t('push_browser_blocked')} (${'$e'.split('\n').first})',
            duration: const Duration(seconds: 12));
      }
      return false;
    }
    if (!allowed) {
      say('push_denied');
      return false;
    }
    await prefs.setBool(pushPref, true);
    await startTradeWatch(container.read(gw2ApiProvider));
  } on LinkFailure catch (e) {
    final key = switch (e.code) {
      'not_linked' || 'missing_permission' || 'subtoken_failed' => 'trade_watch_needs',
      'rate_limited' => 'err_rate_limited',
      _ => 'trade_watch_failed',
    };
    // the code goes with the words, so that a report says which step failed
    if (context.mounted) showToast(context, '${s.t(key)} (${e.code})', duration: const Duration(seconds: 6));
    return false;
  } catch (e) {
    if (context.mounted) {
      showToast(context, '${s.t('trade_watch_failed')} (${'$e'.split('\n').first})', duration: const Duration(seconds: 6));
    }
    return false;
  } finally {
    container.invalidate(tradeWatchesProvider);
  }
  if (container.read(tradeNotifyProvider)) await container.read(tradeNotifyProvider.notifier).set(false);
  say('trade_watch_on');
  return true;
}

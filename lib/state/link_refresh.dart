import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account.dart';
import 'api.dart';
import 'community.dart';
import 'settings.dart';

const _refreshedKey = 'gw2_link_refreshed_at';

/// how long the link with the community account is left as it is. a guild
/// leader's app also brings what only the leader may read of the guild, which
/// the other members see, so it comes more often than a member's refresh
Duration linkRefreshEvery({required bool leads}) => leads ? const Duration(minutes: 30) : const Duration(hours: 12);

/// whether it is time to refresh the link
bool linkRefreshDue(DateTime? last, DateTime now, {required bool leads}) =>
    last == null || now.difference(last) >= linkRefreshEvery(leads: leads);

bool _running = false;
DateTime? _lastAttempt;

/// quietly refreshes the link when the app is opened, so the membership stays
/// counted and, for a guild's leader, the guild's details reach the backend.
/// it uses a subtoken that lives ten minutes, the key stays on the device.
///
/// only an account that is linked already is refreshed, never one the player
/// did not choose to link. a failure is ignored and tried again later, not
/// within five minutes. [force] skips the waiting, for pulling down to refresh
Future<void> refreshLink(WidgetRef ref, {bool force = false}) async {
  if (_running) return;
  final now = DateTime.now();
  final attempt = _lastAttempt;
  if (!force && attempt != null && now.difference(attempt) < const Duration(minutes: 5)) return;
  if (ref.read(sessionProvider).valueOrNull == null || !ref.read(hasKeyProvider)) return;
  _running = true;
  _lastAttempt = now;
  try {
    final guilds = await ref.read(myGuildsProvider.future);
    final leads = guilds.any((g) => g.role == 'leader');
    final prefs = ref.read(prefsProvider);
    final last = DateTime.tryParse(prefs.getString(_refreshedKey) ?? '');
    if (!force && !linkRefreshDue(last, now, leads: leads)) return;

    final linked = await ref.read(linkedAccountsProvider.future);
    if (linked.isEmpty) return;
    final account = await ref.read(accountProvider.future);
    final name = '${account['name'] ?? ''}'.toLowerCase();
    if (!linked.any((a) => a.name.toLowerCase() == name)) return;

    final permissions = [
      for (final p in ((await ref.read(tokenInfoProvider.future))['permissions'] as List?) ?? const []) '$p',
    ];
    await linkGw2Account(ref.read(gw2ApiProvider), permissions);
    await prefs.setString(_refreshedKey, DateTime.now().toIso8601String());
    ref.invalidate(linkedAccountsProvider);
    ref.invalidate(myGuildsProvider);
    ref.invalidate(guildDetailsProvider);
  } catch (e) {
    debugPrint('link refresh: $e');
  } finally {
    _running = false;
  }
}

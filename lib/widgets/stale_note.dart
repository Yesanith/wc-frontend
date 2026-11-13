import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/account.dart';
import '../state/clock.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';

/// when the game last told the api about the account, from its last_modified, or null when it does not say
DateTime? accountUpdatedAt(Json? account) => DateTime.tryParse('${account?['last_modified'] ?? ''}')?.toUtc();

/// whether what the api has for the account is from before the last reset: the game sends it while the player plays,
/// so the vault and the dailies the api gives are still the previous day's until then
bool updatedBeforeReset(DateTime? updated, {required bool weekly, DateTime? now}) {
  if (updated == null) return false;
  final reset = weekly ? lastWeeklyReset(now) : lastDailyReset(now);
  return updated.isBefore(reset);
}

/// whether the vault's [track] the api gives is the previous period's: the game hands out the new objectives only when
/// the player logs in after the reset, and the api has the old ones until then. the special track does not reset
final vaultStaleProvider = Provider.family<bool, String>((ref, track) {
  if (track != 'daily' && track != 'weekly') return false;
  final updated = accountUpdatedAt(ref.watch(accountProvider).valueOrNull);
  return updatedBeforeReset(updated, weekly: track == 'weekly');
});

/// in place of the vault's objectives while they are the previous period's: the new ones come with the next login
class VaultAwaitingLogin extends ConsumerWidget {
  const VaultAwaitingLogin({super.key, required this.track});

  final String track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final updated = accountUpdatedAt(ref.watch(accountProvider).valueOrNull);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.login, size: 20, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t(track == 'weekly' ? 'vault_after_login_weekly' : 'vault_after_login_daily'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.35)),
                const SizedBox(height: 4),
                Text(s.t('vault_after_login_note'),
                    style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSoft)),
                if (updated != null) ...[
                  const SizedBox(height: 4),
                  Text(s.t('api_last_sent', {'t': _when(s, updated)}),
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _when(S s, DateTime updated) {
  final local = updated.toLocal();
  return '${shortDateText(s, local)} ${pad2(local.hour)}:${pad2(local.minute)}';
}

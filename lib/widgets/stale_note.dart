import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
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

/// says so above the vault and the dailies when the api has not had the account since the reset, so that yesterday's
/// ticks are not taken for today's
class StaleSinceResetNote extends ConsumerWidget {
  const StaleSinceResetNote({super.key, this.weekly = false, this.padding = EdgeInsets.zero});

  final bool weekly;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updated = accountUpdatedAt(ref.watch(accountProvider).valueOrNull);
    if (!updatedBeforeReset(updated, weekly: weekly)) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final local = updated!.toLocal();
    final m = MaterialLocalizations.of(context);
    final when =
        '${m.formatShortDate(local)} ${m.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
    return Padding(
      padding: padding,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule, size: 18, color: AppColors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.t(weekly ? 'api_stale_weekly' : 'api_stale_daily', {'t': when}),
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

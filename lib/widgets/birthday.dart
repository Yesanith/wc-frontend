import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/clock.dart';
import '../state/settings.dart';
import '../theme.dart';

/// when a character's next birthday is, and how old it will be. a week out
/// it turns amber, on the day it says so
class BirthdayLine extends ConsumerWidget {
  const BirthdayLine({super.key, required this.created, this.pill = false});

  final String? created;

  /// a pill for the detail header, a plain line for the list
  final bool pill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final at = DateTime.tryParse(created ?? '');
    if (at == null) return const SizedBox.shrink();
    final now = DateTime.now().toUtc();
    final next = nextBirthday(at, now);
    final left = next.difference(now);
    final age = yearsSince(at, next);
    final today = left.inHours < 24;
    final soon = left.inDays < 7;
    final color = today || soon ? AppColors.amber : AppColors.muted;
    // one year and one day are said as one, not as "1 years"
    final days = left.inDays == 1 ? s.t('n_days_one') : s.t('n_days', {'n': left.inDays});
    final text = today
        ? s.t(age == 1 ? 'birthday_today_one' : 'birthday_today', {'n': age})
        : s.t(age == 1 ? 'birthday_in_one' : 'birthday_in', {'t': left.inDays > 0 ? days : countdown(left), 'n': age});
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cake_outlined, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: color, fontWeight: soon ? FontWeight.w700 : FontWeight.w400)),
        ),
      ],
    );
    if (!pill) return row;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: soon ? AppColors.amber.withValues(alpha: 0.12) : AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: soon ? AppColors.amber.withValues(alpha: 0.4) : AppColors.line),
      ),
      child: row,
    );
  }
}

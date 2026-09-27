import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';

/// pins an achievement to the home screen, or takes it off again
class AchievementPinButton extends ConsumerWidget {
  const AchievementPinButton({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final pinned = ref.watch(pinnedAchievementsProvider).contains(id);
    return IconButton(
      tooltip: s.t(pinned ? 'unpin' : 'pin'),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () => ref.read(pinnedAchievementsProvider.notifier).toggle(id),
      icon: Icon(
        pinned ? Icons.push_pin : Icons.push_pin_outlined,
        size: 18,
        color: pinned ? AppColors.gold : AppColors.chevron,
      ),
    );
  }
}

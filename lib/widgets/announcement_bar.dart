import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/presence.dart';
import '../theme.dart';

/// the administrator's announcement, a line at the top of the app and the site. an ordinary one can be closed, a maintenance
/// notice stays while it lasts
class AnnouncementBar extends ConsumerWidget {
  const AnnouncementBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(announcementProvider).valueOrNull;
    if (a == null || (!a.maintenance && ref.watch(closedAnnouncementProvider) == a.id)) return const SizedBox.shrink();
    final color = a.maintenance ? AppColors.amber : AppColors.gold;
    return Material(
      color: color.withValues(alpha: 0.14),
      child: SafeArea(
        bottom: false,
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              Icon(a.maintenance ? Icons.build_circle_outlined : Icons.campaign_outlined, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(a.text, style: TextStyle(fontSize: 13, height: 1.35, color: AppColors.text))),
              if (!a.maintenance)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.read(closedAnnouncementProvider.notifier).close(a.id),
                  icon: Icon(Icons.close, size: 18, color: AppColors.muted),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

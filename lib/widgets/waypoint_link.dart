import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/waypoints.dart';
import '../state/settings.dart';
import '../theme.dart';
import 'common.dart';

/// puts the waypoint's chat code on the clipboard and says what to do with it: pasted in the game's chat it is a link
/// that opens the map at the waypoint, and a click on it travels there
Future<void> copyWaypoint(BuildContext context, WidgetRef ref, Waypoint waypoint) async {
  final s = ref.read(stringsProvider);
  try {
    await Clipboard.setData(ClipboardData(text: waypoint.code));
  } catch (_) {
    // a browser can refuse the clipboard; the code is in the message then, to be copied by hand
    if (context.mounted) showToast(context, waypoint.code, duration: const Duration(seconds: 6));
    return;
  }
  if (!context.mounted) return;
  showToast(context, s.t('waypoint_copied', {'name': waypoint.name}), duration: const Duration(seconds: 4));
}

/// the waypoint under an event, with its name: a tap copies its chat code
class WaypointLink extends ConsumerWidget {
  const WaypointLink(this.waypoint, {super.key});

  final Waypoint waypoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Tooltip(
      message: s.t('copy_waypoint'),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => copyWaypoint(context, ref, waypoint),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place_outlined, size: 14, color: AppColors.gold),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  waypoint.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gold),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.content_copy_rounded, size: 12, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

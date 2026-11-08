import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_open.dart' show platformName;
import 'community.dart';
import 'settings.dart';

// How many have the app or the site open right now, for the administrator's dashboard. The app says it is open every minute, by a random id it
// makes when it starts: nothing of who, and a new one every time it starts. And the line the administrator wants everybody to read.

const _letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

/// a random id for this run of the app, 24 letters
String newPresenceSession([Random? random]) {
  final r = random ?? Random.secure();
  return String.fromCharCodes(List.generate(24, (_) => _letters.codeUnitAt(r.nextInt(_letters.length))));
}

/// says every minute that the app is open while [child] is shown. it never fails the app
class AppPresence extends StatefulWidget {
  const AppPresence({super.key, required this.child});

  final Widget child;

  @override
  State<AppPresence> createState() => _AppPresenceState();
}

class _AppPresenceState extends State<AppPresence> {
  final _session = newPresenceSession();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!communityConfigured) return;
    _ping();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _ping());
  }

  Future<void> _ping() async {
    try {
      await Supabase.instance.client.rpc('app_ping', params: {'p_session': _session, 'p_platform': platformName()});
    } catch (_) {
      // a minute that is not counted is not counted
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// the line the administrator wants everybody to read: info, or maintenance
class Announcement {
  const Announcement(this.text, this.kind, this.setAt);

  final String text;
  final String kind;
  final String setAt;

  /// what tells one announcement from another, to remember that it was closed
  String get id => '$setAt|$text';

  bool get maintenance => kind == 'maintenance';

  static Announcement? fromJson(Object? json) {
    if (json is! Map || json['text'] is! String || (json['text'] as String).trim().isEmpty) return null;
    return Announcement((json['text'] as String).trim(), '${json['kind'] ?? 'info'}', '${json['set_at'] ?? ''}');
  }
}

/// the announcement now, null when there is none or it cannot be read
final announcementProvider = FutureProvider.autoDispose<Announcement?>((ref) async {
  if (!communityConfigured) return null;
  // asked again every five minutes while the app is open
  final timer = Timer(const Duration(minutes: 5), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  try {
    return Announcement.fromJson(await Supabase.instance.client.rpc('app_announcement'));
  } catch (_) {
    return null;
  }
});

/// the announcement the player closed, which is not shown again. a maintenance notice cannot be closed
class ClosedAnnouncementNotifier extends Notifier<String?> {
  static const _key = 'closed_announcement';

  @override
  String? build() => ref.read(prefsProvider).getString(_key);

  Future<void> close(String id) async {
    state = id;
    await ref.read(prefsProvider).setString(_key, id);
  }
}

final closedAnnouncementProvider =
    NotifierProvider<ClosedAnnouncementNotifier, String?>(ClosedAnnouncementNotifier.new);

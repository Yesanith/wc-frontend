import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/update_check.dart';
import 'community.dart';

/// the version the database is told: 0.80.0, without the -web a build for the browser adds. null for a build
/// that is not a release (a build for development says dev), which is not counted
String? releaseVersion(String version) {
  final plain = version.replaceFirst(RegExp(r'-web$'), '');
  return RegExp(r'^\d{1,3}(\.\d{1,3}){0,3}$').hasMatch(plain) ? plain : null;
}

/// what the app runs on: android, ios, web, windows, linux or macos
String platformName() => kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

/// lets a count through once in a while: the app is opened many times a day, once in half an hour is one use
class OpenThrottle {
  OpenThrottle([this.every = const Duration(minutes: 30)]);

  final Duration every;
  DateTime? _last;

  bool due(DateTime now) {
    final last = _last;
    if (last != null && now.difference(last) < every) return false;
    _last = now;
    return true;
  }
}

final _throttle = OpenThrottle();

/// says the app was opened, for the dashboard's count of which versions are used. a count and nothing with it: no
/// player, no device. only for a signed in player (the database refuses anybody else), only for a release, and
/// never failing the app
Future<void> recordAppOpen(WidgetRef ref, {String version = appVersion}) async {
  final release = releaseVersion(version);
  if (release == null || !communityConfigured) return;
  if (ref.read(sessionProvider).valueOrNull == null) return;
  if (!_throttle.due(DateTime.now())) return;
  try {
    await Supabase.instance.client.rpc('record_app_open', params: {'p_version': release, 'p_platform': platformName()});
  } catch (_) {
    // a count that is lost is a count lost
  }
}

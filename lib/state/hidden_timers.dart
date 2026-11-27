import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/metas.dart';
import 'community.dart';

/// the timers the administrator keeps off the events page, by the id of their map: an event the game holds for a while only, a
/// fractal incursion, whose end the game says nothing of. none when the community backend cannot be reached
Future<Set<String>> _readHiddenTimers() async {
  try {
    final v = await Supabase.instance.client.rpc('app_hidden_timers');
    return {
      if (v is List)
        for (final e in v)
          if (e is String) e
    };
  } catch (_) {
    return const {};
  }
}

/// asked again every ten minutes while the app is open, and told to the pages only when it changed
class HiddenTimers extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    if (!communityReady) return const {};
    final timer = Timer.periodic(const Duration(minutes: 10), (_) async {
      final next = await _readHiddenTimers();
      final now = state.valueOrNull;
      if (now == null || now.length != next.length || !now.containsAll(next)) state = AsyncData(next);
    });
    ref.onDispose(timer.cancel);
    return _readHiddenTimers();
  }
}

final hiddenTimersProvider = AsyncNotifierProvider<HiddenTimers, Set<String>>(HiddenTimers.new);

/// the maps whose timers are shown: all of them until the list is read
final shownMetaMapsProvider = Provider<List<MetaMap>>((ref) {
  final hidden = ref.watch(hiddenTimersProvider).valueOrNull ?? const <String>{};
  if (hidden.isEmpty) return metaMaps;
  return [
    for (final m in metaMaps)
      if (!hidden.contains(m.id)) m
  ];
});

/// the pins of the hidden timers, which have no alerts while they are hidden
final hiddenEventKeysProvider = Provider<Set<String>>((ref) {
  final hidden = ref.watch(hiddenTimersProvider).valueOrNull ?? const <String>{};
  return {
    for (final m in metaMaps)
      if (hidden.contains(m.id))
        for (final e in m.events) eventKey(m, e)
  };
});

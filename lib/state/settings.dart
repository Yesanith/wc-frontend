import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../theme.dart' show AppPalette;

/// overridden in main() once SharedPreferences is loaded
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

class LangNotifier extends Notifier<AppLang> {
  static const _key = 'lang';

  @override
  AppLang build() {
    final saved = ref.read(prefsProvider).getString(_key);
    if (saved != null) return AppLang.fromCode(saved);
    // first launch: follow the phone language if we support it
    final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return AppLang.fromCode(device);
  }

  Future<void> set(AppLang lang) async {
    state = lang;
    await ref.read(prefsProvider).setString(_key, lang.code);
  }
}

final langProvider = NotifierProvider<LangNotifier, AppLang>(LangNotifier.new);

/// which look the app has: the palette of the day, the one of the night, or
/// whichever the phone is set to
enum LookMode { system, light, dark, mistlock }

class LookNotifier extends Notifier<LookMode> {
  static const _key = 'look';

  @override
  LookMode build() {
    final saved = ref.read(prefsProvider).getString(_key);
    return LookMode.values.where((m) => m.name == saved).firstOrNull ?? LookMode.system;
  }

  Future<void> set(LookMode mode) async {
    state = mode;
    await ref.read(prefsProvider).setString(_key, mode.name);
  }
}

final lookProvider = NotifierProvider<LookNotifier, LookMode>(LookNotifier.new);

/// the palette for a choice, which for "system" is read from the phone's own brightness
AppPalette paletteFor(LookMode mode, Brightness system) => switch (mode) {
      LookMode.light => AppPalette.light,
      LookMode.dark => AppPalette.night,
      LookMode.mistlock => AppPalette.mistlock,
      LookMode.system => system == Brightness.dark ? AppPalette.night : AppPalette.light,
    };

final stringsProvider = Provider<S>((ref) => S(ref.watch(langProvider)));

class WatchlistNotifier extends Notifier<List<int>> {
  static const _key = 'watchlist';

  @override
  List<int> build() {
    final raw = ref.read(prefsProvider).getStringList(_key) ?? const [];
    return raw.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
  }

  bool contains(int id) => state.contains(id);

  Future<void> replaceAll(List<int> ids) async {
    state = ids;
    await ref.read(prefsProvider).setStringList(_key, ids.map((e) => '$e').toList());
  }

  Future<void> toggle(int id) async {
    state = state.contains(id) ? state.where((e) => e != id).toList() : [...state, id];
    await ref.read(prefsProvider).setStringList(_key, state.map((e) => '$e').toList());
  }
}

final watchlistProvider = NotifierProvider<WatchlistNotifier, List<int>>(WatchlistNotifier.new);

/// the player chose to look around without an api key. it holds only while
/// there is no key: saving one clears it, so removing every key later leads
/// back to the welcome screen
class GuestModeNotifier extends Notifier<bool> {
  static const _key = 'guest_mode';

  @override
  bool build() => ref.read(prefsProvider).getBool(_key) ?? false;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(prefsProvider).setBool(_key, on);
  }
}

final guestModeProvider = NotifierProvider<GuestModeNotifier, bool>(GuestModeNotifier.new);

class PinnedEventsNotifier extends Notifier<Set<String>> {
  static const _key = 'pinned_events';

  @override
  Set<String> build() => (ref.read(prefsProvider).getStringList(_key) ?? const []).toSet();

  Future<void> toggle(String id) async {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    await replaceAll(next);
  }

  Future<void> replaceAll(Set<String> ids) async {
    state = ids;
    await ref.read(prefsProvider).setStringList(_key, ids.toList());
  }
}

final pinnedEventsProvider = NotifierProvider<PinnedEventsNotifier, Set<String>>(PinnedEventsNotifier.new);

class FavoriteCharactersNotifier extends Notifier<Set<String>> {
  static const _key = 'favorite_characters';

  @override
  Set<String> build() => (ref.read(prefsProvider).getStringList(_key) ?? const []).toSet();

  Future<void> toggle(String name) async {
    final next = {...state};
    if (!next.remove(name)) next.add(name);
    state = next;
    await ref.read(prefsProvider).setStringList(_key, next.toList());
  }
}

final favoriteCharactersProvider =
    NotifierProvider<FavoriteCharactersNotifier, Set<String>>(FavoriteCharactersNotifier.new);

/// how the character list is ordered
enum CharacterSort { lastPlayed, name, level, playtime }

class CharacterSortNotifier extends Notifier<CharacterSort> {
  static const _key = 'character_sort';

  @override
  CharacterSort build() {
    final saved = ref.read(prefsProvider).getString(_key);
    return CharacterSort.values.firstWhere((e) => e.name == saved, orElse: () => CharacterSort.lastPlayed);
  }

  Future<void> set(CharacterSort sort) async {
    state = sort;
    await ref.read(prefsProvider).setString(_key, sort.name);
  }
}

final characterSortProvider = NotifierProvider<CharacterSortNotifier, CharacterSort>(CharacterSortNotifier.new);

/// how large the interface is on the web: a number, or null for the automatic size that grows with a wide screen
class UiScaleNotifier extends Notifier<double?> {
  static const _key = 'ui_scale';

  @override
  double? build() => parseUiScale(ref.read(prefsProvider).getString(_key));

  Future<void> set(double? scale) async {
    state = scale;
    await ref.read(prefsProvider).setString(_key, scale == null ? 'auto' : '$scale');
  }
}

/// what was saved as the interface size: a size of the ones there are, anything else is automatic
double? parseUiScale(String? saved) {
  final n = double.tryParse(saved ?? '');
  return n != null && const [1.0, 1.25, 1.5, 1.75, 2.0].contains(n) ? n : null;
}

final uiScaleProvider = NotifierProvider<UiScaleNotifier, double?>(UiScaleNotifier.new);

/// material storage categories folded away on the account screen, by id
class CollapsedMaterialsNotifier extends Notifier<Set<int>> {
  static const _key = 'collapsed_materials';

  @override
  Set<int> build() => {
        for (final e in ref.read(prefsProvider).getStringList(_key) ?? const <String>[])
          if (int.tryParse(e) != null) int.parse(e),
      };

  Future<void> toggle(int id) async {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    await setAll(next);
  }

  Future<void> setAll(Set<int> ids) async {
    state = ids;
    await ref.read(prefsProvider).setStringList(_key, ids.map((e) => '$e').toList());
  }
}

final collapsedMaterialsProvider =
    NotifierProvider<CollapsedMaterialsNotifier, Set<int>>(CollapsedMaterialsNotifier.new);

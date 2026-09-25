import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';

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

final characterSortProvider =
    NotifierProvider<CharacterSortNotifier, CharacterSort>(CharacterSortNotifier.new);

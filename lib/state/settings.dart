import 'dart:convert';

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

class GoalItem {
  const GoalItem(this.itemId, this.need);
  final int itemId;
  final int need;

  Map<String, dynamic> toJson() => {'item': itemId, 'need': need};
  static GoalItem fromJson(Map<String, dynamic> j) => GoalItem((j['item'] as num).toInt(), (j['need'] as num).toInt());
}

class Goal {
  const Goal(this.id, this.name, this.items);
  final String id;
  final String name;
  final List<GoalItem> items;

  Goal copyWith({String? name, List<GoalItem>? items}) => Goal(id, name ?? this.name, items ?? this.items);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'items': items.map((e) => e.toJson()).toList()};

  static Goal fromJson(Map<String, dynamic> j) => Goal(
        '${j['id']}',
        '${j['name']}',
        ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => GoalItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class GoalsNotifier extends Notifier<List<Goal>> {
  static const _key = 'goals';

  @override
  List<Goal> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Goal.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<Goal> next) async {
    state = next;
    await ref.read(prefsProvider).setString(_key, jsonEncode(next.map((g) => g.toJson()).toList()));
  }

  Future<void> replaceAll(List<Goal> goals) => _save(goals);

  Future<Goal> create(String name) async {
    final goal = Goal(DateTime.now().microsecondsSinceEpoch.toString(), name, const []);
    await _save([...state, goal]);
    return goal;
  }

  Future<void> remove(String id) => _save(state.where((g) => g.id != id).toList());

  Future<void> setItem(String goalId, int itemId, int need) {
    return _save([
      for (final g in state)
        if (g.id != goalId)
          g
        else
          g.copyWith(items: [
            for (final i in g.items)
              if (i.itemId != itemId) i,
            if (need > 0) GoalItem(itemId, need),
          ]),
    ]);
  }
}

final goalsProvider = NotifierProvider<GoalsNotifier, List<Goal>>(GoalsNotifier.new);

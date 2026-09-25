import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';

/// discipline name the data job uses for forge recipes
const mysticForge = 'MysticForge';

/// one way to make an item. normal crafting and mystic forge share this shape
class BookRecipe {
  const BookRecipe({
    this.id = 0,
    required this.output,
    required this.outputCount,
    required this.disciplines,
    required this.minRating,
    required this.ingredients,
    this.unnamed = const [],
    this.legendary = false,
  });

  /// the api recipe id, 0 for forge recipes which have none
  final int id;
  final int output;
  final int outputCount;
  final List<String> disciplines;
  final int minRating;

  /// (item id, count) pairs
  final List<(int, int)> ingredients;

  /// forge ingredients the description named but no item matched
  final List<String> unnamed;
  final bool legendary;

  bool get isForge => disciplines.contains(mysticForge);

  static BookRecipe? fromJson(Map<String, dynamic> j) {
    final output = asInt(j['o']);
    if (output <= 0) return null;
    return BookRecipe(
      id: asInt(j['id']),
      output: output,
      outputCount: asInt(j['n']) <= 0 ? 1 : asInt(j['n']),
      disciplines: [for (final d in (j['d'] as List?) ?? const []) '$d'],
      minRating: asInt(j['r']),
      ingredients: [
        for (final pair in (j['i'] as List?) ?? const [])
          if (pair is List && pair.length >= 2) (asInt(pair[0]), asInt(pair[1])),
      ],
      unnamed: [for (final u in (j['u'] as List?) ?? const []) '$u'],
      legendary: j['L'] == 1,
    );
  }
}

/// every recipe the data job collected, keyed by the item it makes
class RecipeBook {
  RecipeBook(this.byOutput);

  final Map<int, List<BookRecipe>> byOutput;

  static final empty = RecipeBook(const {});

  bool get isEmpty => byOutput.isEmpty;

  /// the recipe used to expand a tree. regular crafting wins over the forge
  /// when an item can be made both ways
  BookRecipe? recipeFor(int itemId) {
    final options = byOutput[itemId];
    if (options == null || options.isEmpty) return null;
    for (final r in options) {
      if (!r.isForge) return r;
    }
    return options.first;
  }

  /// disciplines present in the book, forge last
  List<String> get disciplines {
    final all = <String>{};
    for (final list in byOutput.values) {
      for (final r in list) {
        all.addAll(r.disciplines);
      }
    }
    final sorted = all.where((d) => d != mysticForge).toList()..sort();
    if (all.contains(mysticForge)) sorted.add(mysticForge);
    return sorted;
  }

  static Future<RecipeBook> load() async {
    try {
      final bytes = await rootBundle.load('assets/data/recipe_book.json.gz');
      final raw = jsonDecode(
        utf8.decode(gzip.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))),
      );
      if (raw is! Map) return empty;
      final byOutput = <int, List<BookRecipe>>{};
      for (final row in (raw['recipes'] as List?) ?? const []) {
        if (row is! Map) continue;
        final recipe = BookRecipe.fromJson(Map<String, dynamic>.from(row));
        if (recipe == null) continue;
        byOutput.putIfAbsent(recipe.output, () => []).add(recipe);
      }
      return RecipeBook(byOutput);
    } catch (_) {
      return empty;
    }
  }
}

final recipeBookProvider = FutureProvider<RecipeBook>((ref) => RecipeBook.load());

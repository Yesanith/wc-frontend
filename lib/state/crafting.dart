import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gw2_api.dart';
import '../services/recipe_book.dart';
import '../util.dart';
import 'api.dart';
import 'characters.dart';

/// one step of a crafting tree, independent of how many you want to make.
/// [perRun] is how many the parent recipe needs for a single run of itself
class CraftNode {
  const CraftNode({
    required this.itemId,
    required this.item,
    required this.perRun,
    required this.outputCount,
    required this.children,
    required this.disciplines,
  });

  final int itemId;
  final Json? item;
  final int perRun;

  /// how many the recipe makes in one craft
  final int outputCount;
  final List<CraftNode> children;
  final List<String> disciplines;

  bool get isLeaf => children.isEmpty;
  String get name => (item?['name'] as String?) ?? 'Item #$itemId';
}

/// the same tree with real amounts filled in for a given quantity
class CraftLine {
  const CraftLine(this.node, this.count, this.children);

  final CraftNode node;
  final int count;
  final List<CraftLine> children;

  bool get isLeaf => children.isEmpty;
  int get itemId => node.itemId;
  String get name => node.name;
}

/// scaling happens on device, so changing the quantity never refetches
CraftLine planFor(CraftNode node, int count) {
  final runs = node.outputCount <= 0 ? count : (count / node.outputCount).ceil();
  return CraftLine(
    node,
    count,
    [for (final child in node.children) planFor(child, child.perRun * runs)],
  );
}

/// ids a book tree touches, so their details come in one batched request
Set<int> bookTreeIds(RecipeBook book, int rootId) {
  final ids = <int>{};
  void walk(int itemId, Set<int> seen, int depth) {
    ids.add(itemId);
    final recipe = depth >= 8 || seen.contains(itemId) ? null : book.recipeFor(itemId);
    if (recipe == null) return;
    for (final (id, _) in recipe.ingredients) {
      walk(id, {...seen, itemId}, depth + 1);
    }
  }

  walk(rootId, <int>{}, 0);
  return ids;
}

/// the whole tree straight from the shipped recipe book, no network needed
/// except for names and icons
CraftNode buildFromBook(RecipeBook book, int rootId, Map<int, Json> items) {
  CraftNode build(int itemId, int perRun, Set<int> seen, int depth) {
    final recipe = depth >= 8 || seen.contains(itemId) ? null : book.recipeFor(itemId);
    if (recipe == null) {
      return CraftNode(
        itemId: itemId,
        item: items[itemId],
        perRun: perRun,
        outputCount: 1,
        children: const [],
        disciplines: const [],
      );
    }
    return CraftNode(
      itemId: itemId,
      item: items[itemId],
      perRun: perRun,
      outputCount: recipe.outputCount,
      children: [
        for (final (id, count) in recipe.ingredients) build(id, count, {...seen, itemId}, depth + 1),
      ],
      disciplines: recipe.disciplines,
    );
  }

  return build(rootId, 1, <int>{}, 0);
}

/// keyed by item id only. items in the recipe book expand instantly, anything
/// else falls back to asking the api step by step
final craftTreeProvider = FutureProvider.family<CraftNode, int>((ref, rootId) async {
  final api = ref.watch(gw2ApiProvider);
  final book = await ref.watch(recipeBookProvider.future);
  if (book.recipeFor(rootId) != null) {
    final items = await api.items(bookTreeIds(book, rootId));
    return buildFromBook(book, rootId, items);
  }
  return _liveTree(api, rootId);
});

Future<CraftNode> _liveTree(Gw2Api api, int rootId) async {
  // branches still expand in parallel, but never more than a handful of
  // requests are in the air at once
  final pool = TaskPool(5);

  Future<CraftNode> expand(int itemId, int perRun, Set<int> seen, int depth) async {
    // item details and the recipe lookup do not depend on each other
    final lookups = await Future.wait([
      pool.run(() => api.items([itemId])),
      depth >= 6 || seen.contains(itemId) ? Future.value(const <int>[]) : pool.run(() => api.recipesForOutput(itemId)),
    ]);
    final item = (lookups[0] as Map<int, Json>)[itemId];
    CraftNode leaf() => CraftNode(
          itemId: itemId,
          item: item,
          perRun: perRun,
          outputCount: 1,
          children: const [],
          disciplines: const [],
        );
    final recipeIds = lookups[1] as List<int>;
    if (recipeIds.isEmpty) return leaf();
    final recipes = await pool.run(() => api.recipes(recipeIds));
    final recipe = recipes[recipeIds.first];
    if (recipe == null) return leaf();

    final output = asInt(recipe['output_item_count']);
    // ingredients are independent branches, expand them side by side instead
    // of one round trip after another
    final children = await Future.wait([
      for (final ingredient in (recipe['ingredients'] as List?) ?? const [])
        if (ingredient is Map && asInt(ingredient['item_id'] ?? ingredient['id']) > 0)
          expand(
            asInt(ingredient['item_id'] ?? ingredient['id']),
            asInt(ingredient['count']),
            {...seen, itemId},
            depth + 1,
          ),
    ]);
    return CraftNode(
      itemId: itemId,
      item: item,
      perRun: perRun,
      outputCount: output <= 0 ? 1 : output,
      children: children,
      disciplines: [for (final d in (recipe['disciplines'] as List?) ?? const []) '$d'],
    );
  }

  return expand(rootId, 1, <int>{}, 0);
}

/// everything at the bottom of a plan, with quantities summed
Map<int, int> craftLeaves(CraftLine line) {
  final out = <int, int>{};
  void walk(CraftLine l) {
    if (l.isLeaf) {
      out[l.itemId] = (out[l.itemId] ?? 0) + l.count;
      return;
    }
    for (final child in l.children) {
      walk(child);
    }
  }

  for (final child in line.children) {
    walk(child);
  }
  return out;
}

/// sell listing price per unit for every item in the tree, fetched once
final craftPricesProvider = FutureProvider.autoDispose.family<Map<int, int>, int>((ref, rootId) async {
  final api = ref.watch(gw2ApiProvider);
  final root = await ref.watch(craftTreeProvider(rootId).future);
  final ids = <int>{};
  void collect(CraftNode n) {
    ids.add(n.itemId);
    for (final child in n.children) {
      collect(child);
    }
  }

  collect(root);
  final prices = await api.prices(ids);
  return {
    for (final e in prices.entries)
      if (e.value['sells'] is Map) e.key: asInt((e.value['sells'] as Map)['unit_price']),
  };
});

/// one recipe an item goes into: what it makes and in which discipline
class UsedIn {
  const UsedIn(this.output, this.disciplines, {this.recipeId = 0});
  final int output;
  final List<String> disciplines;

  /// the api recipe id, 0 for mystic forge recipes
  final int recipeId;
}

/// recipes that use an item, from the api's input search and the shipped
/// book together. the book adds the mystic forge, the api anything newer
/// than the last data job. one entry per item made
List<UsedIn> mergeUsedIn(RecipeBook book, List<int> apiIds, Map<int, Json> apiRecipes, int itemId) {
  final byOutput = <int, UsedIn>{};
  void add(int output, List<String> disciplines, int recipeId) {
    if (output <= 0) return;
    final seen = byOutput[output];
    if (seen == null) {
      byOutput[output] = UsedIn(output, disciplines, recipeId: recipeId);
    } else {
      byOutput[output] = UsedIn(output, {...seen.disciplines, ...disciplines}.toList(),
          recipeId: seen.recipeId > 0 ? seen.recipeId : recipeId);
    }
  }

  for (final id in apiIds) {
    final known = book.byId[id];
    if (known != null) {
      add(known.output, known.disciplines, id);
      continue;
    }
    final raw = apiRecipes[id];
    if (raw != null) {
      add(asInt(raw['output_item_id']), [for (final d in (raw['disciplines'] as List?) ?? const []) '$d'], id);
    }
  }
  for (final r in book.usedIn(itemId)) {
    add(r.output, r.disciplines, r.id);
  }
  return byOutput.values.toList();
}

/// what an item is an ingredient of
final usedInProvider = FutureProvider.autoDispose.family<List<UsedIn>, int>((ref, itemId) async {
  final api = ref.watch(gw2ApiProvider);
  final book = await ref.watch(recipeBookProvider.future);
  var ids = const <int>[];
  try {
    ids = await api.recipesForInput(itemId);
  } catch (_) {
    // offline, the shipped book still answers
  }
  final unknown = ids.where((id) => book.byId[id] == null).toList();
  final raw = unknown.isEmpty ? const <int, Json>{} : await api.recipes(unknown);
  return mergeUsedIn(book, ids, raw, itemId);
});

/// the recipes a character learned, resolved to the items they make.
/// key is the character name
final characterRecipesProvider = FutureProvider.autoDispose.family<List<UsedIn>, String>((ref, name) async {
  final api = ref.watch(gw2ApiProvider);
  final book = await ref.watch(recipeBookProvider.future);
  final chars = await ref.watch(charactersProvider.future);
  final c = characterByName(chars, name);
  if (c == null) return const [];
  final ids = intList(c['recipes']);
  final unknown = ids.where((id) => book.byId[id] == null).toList();
  final raw = unknown.isEmpty ? const <int, Json>{} : await api.recipes(unknown);
  final out = <UsedIn>[];
  for (final id in ids) {
    final known = book.byId[id];
    if (known != null) {
      out.add(UsedIn(known.output, known.disciplines, recipeId: id));
    } else if (raw[id] != null) {
      out.add(UsedIn(
          asInt(raw[id]!['output_item_id']), [for (final d in (raw[id]!['disciplines'] as List?) ?? const []) '$d'],
          recipeId: id));
    }
  }
  return out;
});

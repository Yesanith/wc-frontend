import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';

/// one node of a mystic forge tree. leaves are the things you actually
/// farm or buy, [id] is null when the description named something the
/// api has no item for
class RecipeNode {
  const RecipeNode({
    required this.id,
    required this.name,
    required this.icon,
    required this.rarity,
    required this.count,
    required this.children,
  });

  final int? id;
  final String name;
  final String? icon;
  final String? rarity;
  final int count;
  final List<RecipeNode> children;

  bool get isLeaf => children.isEmpty;

  static RecipeNode fromJson(Map<String, dynamic> j) => RecipeNode(
        id: j['id'] == null ? null : (j['id'] as num).toInt(),
        name: '${j['name'] ?? ''}',
        icon: j['icon'] as String?,
        rarity: j['rarity'] as String?,
        count: j['count'] == null ? 1 : (j['count'] as num).toInt(),
        children: ((j['children'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => RecipeNode.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class RecipeRoot {
  const RecipeRoot(this.node, this.kind, this.type);

  final RecipeNode node;

  /// legendary or gift
  final String kind;
  final String? type;

  bool get isLegendary => kind == 'legendary';
}

class RecipeLibrary {
  const RecipeLibrary(this.roots, this.names, this.generatedAt);

  final List<RecipeRoot> roots;

  /// language code -> item id -> translated name
  final Map<String, Map<String, String>> names;
  final String? generatedAt;

  static const empty = RecipeLibrary([], {}, null);

  String label(RecipeNode node, AppLang lang) {
    final id = node.id;
    if (id == null) return node.name;
    return names[lang.apiLang]?['$id'] ?? node.name;
  }

  static Future<RecipeLibrary> load() async {
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/data/legendary_recipes.json'));
      if (raw is! Map) return empty;
      final roots = ((raw['roots'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map((e) => RecipeRoot(RecipeNode.fromJson(e), '${e['kind']}', e['type'] as String?))
          .toList();
      final names = <String, Map<String, String>>{};
      ((raw['names'] as Map?) ?? const {}).forEach((lang, rows) {
        if (rows is Map) {
          names['$lang'] = {for (final e in rows.entries) '${e.key}': '${e.value}'};
        }
      });
      return RecipeLibrary(roots, names, raw['generated_at'] as String?);
    } catch (_) {
      return empty;
    }
  }
}

/// everything you have to gather at the bottom of the tree, with the
/// quantities multiplied down from the root
Map<int, int> baseMaterials(RecipeNode node, [int multiplier = 1]) {
  final out = <int, int>{};
  void walk(RecipeNode n, int factor) {
    final total = n.count * factor;
    if (n.isLeaf) {
      final id = n.id;
      if (id != null) out[id] = (out[id] ?? 0) + total;
      return;
    }
    for (final child in n.children) {
      walk(child, total);
    }
  }

  for (final child in node.children) {
    walk(child, multiplier);
  }
  return out;
}

final recipeLibraryProvider = FutureProvider<RecipeLibrary>((ref) => RecipeLibrary.load());

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/settings.dart';

class IndexedItem {
  IndexedItem(this.id, this.name) : lower = name.toLowerCase();

  final int id;
  final String name;

  /// lowercased once at load, searching 70k names should not redo it
  final String lower;
}

class ItemIndex {
  ItemIndex(this.items);

  final List<IndexedItem> items;

  static final empty = ItemIndex(const []);

  bool get isEmpty => items.isEmpty;

  static Future<ItemIndex> load(AppLang lang) async {
    for (final code in {lang.apiLang, 'en'}) {
      try {
        final raw = await rootBundle.loadString('assets/data/item_index_$code.txt');
        final rows = <IndexedItem>[];
        for (final line in raw.split('\n')) {
          final tab = line.indexOf('\t');
          if (tab <= 0) continue;
          final id = int.tryParse(line.substring(0, tab));
          if (id == null) continue;
          rows.add(IndexedItem(id, line.substring(tab + 1)));
        }
        if (rows.isNotEmpty) return ItemIndex(rows);
      } catch (_) {
        // try the next language, then give up quietly
      }
    }
    return empty;
  }

  /// exact matches first, then names that start with the query
  List<IndexedItem> search(String query, {int limit = 40}) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    final starts = <IndexedItem>[];
    final contains = <IndexedItem>[];
    for (final item in items) {
      final name = item.lower;
      if (name == q) {
        starts.insert(0, item);
      } else if (name.startsWith(q)) {
        starts.add(item);
      } else if (name.contains(q)) {
        contains.add(item);
      }
      if (starts.length >= limit) break;
    }
    final out = [...starts, ...contains];
    return out.length > limit ? out.sublist(0, limit) : out;
  }
}

final itemIndexProvider = FutureProvider<ItemIndex>((ref) => ItemIndex.load(ref.watch(langProvider)));

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/item_index.dart';
import '../state/navigation.dart';
import '../theme.dart';

enum SearchKind { section, item, wiki }

/// something the search of the site found: a page of the site, an item, or the wiki, which is asked when nothing else is what was meant
class SearchHit {
  const SearchHit.section(this.section, this.label)
      : kind = SearchKind.section,
        itemId = null,
        query = null;

  const SearchHit.item(this.itemId, this.label)
      : kind = SearchKind.item,
        section = null,
        query = null;

  const SearchHit.wiki(this.query, this.label)
      : kind = SearchKind.wiki,
        section = null,
        itemId = null;

  final SearchKind kind;
  final String label;
  final AppSection? section;
  final int? itemId;

  /// what to look up in the wiki
  final String? query;
}

/// what a search for [query] finds: the pages whose name has it (the ones that begin with it first), the items whose name has it, and
/// last the wiki, with the query in the line that offers it ([wikiLabel] has {q} for it). nothing for less than two letters: it
/// would be every item there is
List<SearchHit> searchHits(
  String query, {
  required ItemIndex index,
  required Map<AppSection, String> labels,
  required String wikiLabel,
  int itemLimit = 6,
  int sectionLimit = 3,
}) {
  final typed = query.trim();
  final q = typed.toLowerCase();
  if (q.length < 2) return const [];
  final pages = [
    for (final e in labels.entries)
      if (e.value.toLowerCase().contains(q)) e,
  ]..sort((a, b) {
      final aStarts = a.value.toLowerCase().startsWith(q) ? 0 : 1;
      final bStarts = b.value.toLowerCase().startsWith(q) ? 0 : 1;
      return aStarts != bStarts ? aStarts - bStarts : a.key.index - b.key.index;
    });
  return [
    for (final e in pages.take(sectionLimit)) SearchHit.section(e.key, e.value),
    for (final item in index.search(typed, limit: itemLimit)) SearchHit.item(item.id, item.name),
    SearchHit.wiki(typed, wikiLabel.replaceAll('{q}', typed)),
  ];
}

/// the box of the search in the bar of the site: it opens its results under it as something is typed, with the keys to go through them,
/// and what is chosen is [onSelect]'s to take where it goes
class SiteSearch extends ConsumerStatefulWidget {
  const SiteSearch({
    super.key,
    required this.labels,
    required this.placeholder,
    required this.wikiLabel,
    required this.pageLabel,
    required this.itemLabel,
    required this.onSelect,
    this.width = 260,
    this.autofocus = false,
  });

  final Map<AppSection, String> labels;
  final String placeholder;

  /// the line that offers the wiki, with {q} for what was typed
  final String wikiLabel;

  /// what a page and an item are called, under what was found
  final String pageLabel;
  final String itemLabel;
  final ValueChanged<SearchHit> onSelect;
  final double width;

  /// the cursor is in it from the start, as when it was opened to be typed in
  final bool autofocus;

  @override
  ConsumerState<SiteSearch> createState() => _SiteSearchState();
}

class _SiteSearchState extends ConsumerState<SiteSearch> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _kind(SearchHit hit) => switch (hit.kind) {
        SearchKind.section => widget.pageLabel,
        SearchKind.item => widget.itemLabel,
        SearchKind.wiki => 'Wiki',
      };

  IconData _icon(SearchHit hit) => switch (hit.kind) {
        SearchKind.section => Icons.dashboard_outlined,
        SearchKind.item => Icons.inventory_2_outlined,
        SearchKind.wiki => Icons.menu_book_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(itemIndexProvider).valueOrNull ?? ItemIndex.empty;
    return SizedBox(
      width: widget.width,
      child: RawAutocomplete<SearchHit>(
        textEditingController: _controller,
        focusNode: _focus,
        optionsBuilder: (value) =>
            searchHits(value.text, index: index, labels: widget.labels, wikiLabel: widget.wikiLabel),
        // what is chosen is gone to, and the box is empty again
        displayStringForOption: (_) => '',
        onSelected: (hit) {
          widget.onSelect(hit);
          _controller.clear();
          _focus.unfocus();
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: widget.autofocus,
          onSubmitted: (_) => onSubmitted(),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            prefixIcon: Icon(Icons.search, size: 18, color: AppColors.muted),
            prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 36),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: AppColors.line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: AppColors.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: AppColors.gold)),
          ),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: AppColors.surface,
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14), side: BorderSide(color: AppColors.line)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.width + 140, maxHeight: 420),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  children: [
                    for (final (i, hit) in options.indexed)
                      Builder(builder: (context) {
                        final highlighted = AutocompleteHighlightedOption.of(context) == i;
                        return ListTile(
                          dense: true,
                          selected: highlighted,
                          selectedTileColor: AppColors.surface2,
                          leading: Icon(_icon(hit), size: 20, color: highlighted ? AppColors.gold : AppColors.muted),
                          title: Text(hit.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(_kind(hit), style: TextStyle(fontSize: 11, color: AppColors.hint)),
                          onTap: () => onSelected(hit),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

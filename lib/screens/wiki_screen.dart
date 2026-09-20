import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/wiki_api.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';

class WikiScreen extends ConsumerStatefulWidget {
  const WikiScreen({super.key});

  @override
  ConsumerState<WikiScreen> createState() => _WikiScreenState();
}

class _WikiScreenState extends ConsumerState<WikiScreen> {
  // key prefix in the strings table, color
  static const _categories = <(String, Color)>[
    ('cat_meta', AppColors.gold),
    ('cat_crafting', Color(0xFF5FC07F)),
    ('cat_mastery', Color(0xFF72C1D9)),
    ('cat_fractals', Color(0xFFC08BE0)),
  ];

  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<WikiResult> _results = const [];
  final List<String> _recent = [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String q) async {
    // drop responses that come back after a newer query was sent
    final id = ++_requestId;
    if (q.trim().isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ref.read(wikiApiProvider).search(q);
      if (!mounted || id != _requestId) return;
      setState(() => _results = r);
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() => _error = ref.read(stringsProvider).t('search_failed', {'e': e}));
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  void _searchFor(String q) {
    _ctrl.text = q;
    _search(q);
  }

  void _open(String title) {
    setState(() {
      _recent.remove(title);
      _recent.insert(0, title);
      if (_recent.length > 8) _recent.removeLast();
    });
    openWikiPage(context, ref, title);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(langProvider);
    final searching = _ctrl.text.trim().isNotEmpty;
    final error = _error;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(Uri.parse(lang.wikiBase).host, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          onChanged: (v) {
            setState(() {});
            _onChanged(v);
          },
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          decoration: fieldDecoration(
            s.t('search_wiki'),
            prefixIcon: const Icon(Icons.search, color: AppColors.gold),
            suffixIcon: searching
                ? IconButton(
                    tooltip: s.t('clear'),
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    onPressed: () {
                      _ctrl.clear();
                      _search('');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        if (searching) ...[
          if (_loading) const LinearProgressIndicator(minHeight: 2, color: AppColors.gold),
          if (error != null) ErrorBox(message: error, onRetry: () => _search(_ctrl.text)),
          if (!_loading && error == null && _results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(s.t('no_results'), style: const TextStyle(color: AppColors.muted))),
            ),
          if (_results.isNotEmpty)
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                children: [
                  for (final r in _results)
                    ListTile(
                      title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF6E6859)),
                      onTap: () => _open(r.title),
                    ),
                ],
              ),
            ),
        ] else ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              for (final c in _categories)
                _CategoryCard(s.t(c.$1), s.t('${c.$1}_sub'), c.$2, () => _searchFor(s.t('${c.$1}_q'))),
            ],
          ),
          const SizedBox(height: 22),
          SectionHeader(title: s.t('recently_viewed')),
          const SizedBox(height: 10),
          if (_recent.isEmpty)
            Panel(child: Text(s.t('recent_empty'), style: const TextStyle(color: AppColors.muted)))
          else
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                children: [
                  for (final t in _recent)
                    ListTile(
                      leading: const Icon(Icons.history, color: AppColors.muted),
                      title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () => _open(t),
                    ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 20),
        Text(s.t('wiki_attribution'), style: const TextStyle(fontSize: 11, height: 1.5, color: AppColors.hint)),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard(this.title, this.subtitle, this.color, this.onTap);

  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withAlpha(36),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: color),
                ),
                child: Transform.rotate(
                  angle: 0.785398,
                  child: Container(width: 9, height: 9, color: color),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/icon_cache.dart';
import '../state/news.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';

String _date(DateTime? d) {
  if (d == null) return '';
  final local = d.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
}

/// the official news of guildwars2.com and the update notes of the wiki
class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  @override
  void initState() {
    super.initState();
    // opening the section counts as having seen what it lists: what is
    // already loaded now, and what arrives while it is open
    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen(ref.read(newsProvider).valueOrNull));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    ref.listen<AsyncValue<List<NewsItem>>>(newsProvider, (_, next) => _markSeen(next.valueOrNull));

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          AppTabBar(labels: [s.t('news'), s.t('patch_notes')]),
          const Expanded(child: TabBarView(children: [_NewsTab(), _PatchNotesTab()])),
        ],
      ),
    );
  }

  void _markSeen(List<NewsItem>? items) {
    if (!mounted || items == null || items.isEmpty) return;
    final newest = items.first.date;
    if (newest != null) ref.read(newsSeenProvider.notifier).markSeen(newest);
  }
}

class _NewsTab extends ConsumerWidget {
  const _NewsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [newsProvider]),
      child: AsyncView<List<NewsItem>>(
        value: ref.watch(newsProvider),
        onRetry: () => ref.invalidate(newsProvider),
        builder: (items) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == items.length) {
              return Text(s.t('news_source'),
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.hint));
            }
            return _NewsCard(item: items[i]);
          },
        ),
      ),
    );
  }
}

class _NewsCard extends ConsumerWidget {
  const _NewsCard({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final image = item.image;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => openUrl(context, item.link, failMessage: s.t('open_failed')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(color: AppColors.surface2, child: CachedIcon(url: image)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_date(item.date), style: TextStyle(fontSize: 11, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(item.title, style: display(17)),
                if (item.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.excerpt, style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSoft)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PatchNotesTab extends ConsumerWidget {
  const _PatchNotesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [patchNotesProvider]),
      child: AsyncView<List<PatchNote>>(
        value: ref.watch(patchNotesProvider),
        onRetry: () => ref.invalidate(patchNotesProvider),
        builder: (notes) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(s.t('patch_notes_note'), style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
            const SizedBox(height: 12),
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => openUrl(context, n.url, failMessage: s.t('open_failed')),
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined, color: AppColors.gold, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.t('game_update_on', {'d': _date(n.date)}),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      Icon(Icons.open_in_new, size: 16, color: AppColors.chevron),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

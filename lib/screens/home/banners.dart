part of '../home_screen.dart';

/// shows up only while at least one price alert is met
class _AlertBanner extends ConsumerWidget {
  const _AlertBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final fired = ref.watch(triggeredAlertsProvider).valueOrNull ?? const <int>{};
    if (fired.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        onTap: () => ref.read(sectionProvider.notifier).state = AppSection.trading,
        child: Row(
          children: [
            Icon(Icons.notifications_active, color: AppColors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.t('alerts_fired', {'n': fired.length}),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            Icon(Icons.chevron_right, color: AppColors.chevron),
          ],
        ),
      ),
    );
  }
}

/// the achievements the player pinned, with how far along each one is.
/// nothing at all until something is pinned
class _PinnedAchievements extends ConsumerWidget {
  const _PinnedAchievements();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (ref.watch(pinnedAchievementsProvider).isEmpty) return const SizedBox.shrink();
    final rows = ref.watch(pinnedAchievementRowsProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: s.t('pinned_achievements'), trailing: '${ref.watch(pinnedAchievementsProvider).length}'),
          const SizedBox(height: 10),
          AsyncView<List<AchievementRow>>(
            value: rows,
            onRetry: () => ref.invalidate(pinnedAchievementRowsProvider),
            builder: (list) => Panel(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Column(
                children: [
                  for (final a in list)
                    InkWell(
                      onTap: () => openPanel(context, (_) => AchievementDetailScreen(row: a)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (a.done) ...[
                                        Icon(Icons.check_circle, size: 16, color: AppColors.green),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(a.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                      ),
                                      if (a.max > 0)
                                        Text('${fmtInt(a.current)} / ${fmtInt(a.max)}',
                                            style: TextStyle(
                                                fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted)),
                                    ],
                                  ),
                                  if (a.max > 0) ...[
                                    const SizedBox(height: 7),
                                    Bar(value: a.done ? 1 : a.ratio, color: a.done ? AppColors.green : AppColors.gold),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            AchievementPinButton(id: a.id),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "new articles" while the feed has something the user has not seen yet
class _NewsBanner extends ConsumerWidget {
  const _NewsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    // the first time the feed loads, what is there counts as seen
    ref.listen<AsyncValue<List<NewsItem>>>(newsProvider, (_, next) {
      final items = next.valueOrNull;
      final newest = items == null || items.isEmpty ? null : items.first.date;
      if (newest != null && ref.read(newsSeenProvider) == null) {
        ref.read(newsSeenProvider.notifier).markSeen(newest);
      }
    });
    final count = ref.watch(unseenNewsProvider);
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => ref.read(sectionProvider.notifier).state = AppSection.news,
        child: Row(
          children: [
            Icon(Icons.newspaper, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.t('news_new', {'n': count}),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            Icon(Icons.chevron_right, color: AppColors.chevron),
          ],
        ),
      ),
    );
  }
}

/// the home of a guest: what the app can do without a key, and how to get the rest
class _GuestCard extends ConsumerWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key_outlined, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(child: Text(s.t('guest_home_title'), style: display(17))),
              ],
            ),
            const SizedBox(height: 8),
            Text(s.t('guest_home_body'), style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.muted)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => openAddKey(context),
              icon: const Icon(Icons.add),
              label: Text(s.t('add_api_key')),
            ),
          ],
        ),
      ),
    );
  }
}

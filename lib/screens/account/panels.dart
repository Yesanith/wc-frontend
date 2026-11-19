part of '../account_screen.dart';

/// what the account itself says about the player: the points of the daily and monthly achievements, the fractal level, the
/// commander tag, the guilds led and the slots of the build storage
class _AccountProfile extends ConsumerWidget {
  const _AccountProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final a = ref.watch(accountProvider).valueOrNull;
    if (a == null) return const SizedBox.shrink();
    final leads = intList(a['guild_leader']).length;
    final tiles = <(IconData, String, String)>[
      if (a['daily_ap'] != null) (Icons.today_outlined, s.t('acc_daily_ap'), fmtInt(asInt(a['daily_ap']))),
      if (a['monthly_ap'] != null)
        (Icons.calendar_month_outlined, s.t('acc_monthly_ap'), fmtInt(asInt(a['monthly_ap']))),
      if (a['fractal_level'] != null)
        (Icons.blur_circular_outlined, s.t('acc_fractal_level'), '${asInt(a['fractal_level'])}'),
      if (a['commander'] == true) (Icons.flag_outlined, s.t('acc_commander'), '✓'),
      if (leads > 0) (Icons.shield_outlined, s.t('acc_guild_leader'), '$leads'),
      if (a['build_storage_slots'] != null)
        (Icons.save_outlined, s.t('acc_build_slots'), '${asInt(a['build_storage_slots'])}'),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(s.t('acc_profile').caps),
          const SizedBox(height: 10),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              for (final (icon, label, value) in tiles)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// luck and the fractal account augmentations, when the key may read them
class _AccountCounters extends ConsumerWidget {
  const _AccountCounters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final luck = ref.watch(accountLuckProvider).valueOrNull?['luck'] ?? 0;
    final progression = ref.watch(accountProgressionProvider).valueOrNull ?? const <String, int>{};
    final rows = <(String, int)>[
      if (luck > 0) (s.t('luck'), luck),
      for (final e in progression.entries)
        if (e.key != 'luck' && e.value > 0) (titleCase(e.key.replaceAll('_', ' ')), e.value),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(s.t('account_progress').caps),
          const SizedBox(height: 4),
          Text(s.t('account_progress_note'), style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.muted)),
          const SizedBox(height: 8),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSoft))),
                  Text(fmtInt(value),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.gold)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// gold over the recorded days as a small line, with the change over a week
/// and a month. the history only grows while the app is used
class _WealthPanel extends ConsumerWidget {
  const _WealthPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final name = '${ref.watch(accountProvider).valueOrNull?['name'] ?? ''}';
    final points = ref.watch(wealthProvider)[name] ?? const <WealthPoint>[];
    if (points.length < 2) {
      return Panel(
        child: Text(s.t('wealth_collecting'), style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
      );
    }
    final week = changeOver(points, 7, (p) => p.coins);
    final month = changeOver(points, 30, (p) => p.coins);
    Widget delta(String label, int? value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 2),
              if (value == null)
                Text('-', style: TextStyle(color: AppColors.muted))
              else
                Row(
                  children: [
                    Icon(value >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14, color: value >= 0 ? AppColors.green : AppColors.red),
                    const SizedBox(width: 2),
                    CoinText(value.abs(), size: 13),
                  ],
                ),
            ],
          ),
        );
    final recent = points.length > 60 ? points.sublist(points.length - 60) : points;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(s.t('wealth_history').caps),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            width: double.infinity,
            child: CustomPaint(painter: _SparkPainter([for (final p in recent) p.coins.toDouble()])),
          ),
          const SizedBox(height: 10),
          Row(children: [delta(s.t('last_7_days'), week), delta(s.t('last_30_days'), month)]),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = hi - lo == 0 ? 1 : hi - lo;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] - lo) / span * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values;
}

/// pull to refresh on one tab, dropping the cached values it reads
class _Pull extends ConsumerWidget {
  const _Pull({required this.providers, required this.child});

  final List<ProviderOrFamily> providers;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, providers),
      child: child,
    );
  }
}

/// an empty tab that still scrolls, so a pull reaches the refresh after
/// something changed in game
class _EmptyTab extends StatelessWidget {
  const _EmptyTab(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: Padding(padding: const EdgeInsets.all(24), child: EmptyNote(message)),
          ),
        ],
      ),
    );
  }
}

/// what the account says about itself, in the empty corner of the heading of the page on a site: the points, the fractal level, luck, and the
/// gold over the last week with its line
class AccountHeadingSummary extends ConsumerWidget {
  const AccountHeadingSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final a = ref.watch(accountProvider).valueOrNull;
    if (a == null) return const SizedBox.shrink();
    final luck = ref.watch(accountLuckProvider).valueOrNull?['luck'] ?? 0;
    final leads = intList(a['guild_leader']).length;
    final stats = <(String, String)>[
      if (a['daily_ap'] != null) (s.t('acc_daily_ap'), fmtInt(asInt(a['daily_ap']))),
      if (a['monthly_ap'] != null) (s.t('acc_monthly_ap'), fmtInt(asInt(a['monthly_ap']))),
      if (a['fractal_level'] != null) (s.t('acc_fractal_level'), '${asInt(a['fractal_level'])}'),
      if (luck > 0) (s.t('luck'), fmtInt(luck)),
      if (leads > 0) (s.t('acc_guild_leader'), '$leads'),
      if (a['build_storage_slots'] != null) (s.t('acc_build_slots'), '${asInt(a['build_storage_slots'])}'),
    ];
    final name = '${a['name'] ?? ''}';
    final points = ref.watch(wealthProvider)[name] ?? const <WealthPoint>[];
    final week = points.length < 2 ? null : changeOver(points, 7, (p) => p.coins);
    final recent = points.length > 60 ? points.sublist(points.length - 60) : points;
    return Padding(
      padding: const EdgeInsets.only(top: 22, right: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Panel(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Wrap(
                    spacing: 22,
                    runSpacing: 8,
                    children: [
                      for (final (label, value) in stats)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label, style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
                            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          ],
                        ),
                    ],
                  ),
                ),
                if (recent.length >= 2) ...[
                  const SizedBox(width: 18),
                  VerticalDivider(width: 1, color: AppColors.track),
                  const SizedBox(width: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 34,
                        child: CustomPaint(painter: _SparkPainter([for (final p in recent) p.coins.toDouble()])),
                      ),
                      const SizedBox(height: 4),
                      if (week != null)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(week >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 12, color: week >= 0 ? AppColors.green : AppColors.red),
                          const SizedBox(width: 2),
                          CoinText(week.abs(), size: 11.5),
                          Text('  ${s.t('last_7_days')}', style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
                        ]),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

part of '../trading_screen.dart';

/// a month of what 100 gems cost and bring, from the shared recording
class _GemHistoryChart extends ConsumerWidget {
  const _GemHistoryChart();

  static final _buyColor = AppColors.gold;
  static const _sellColor = Color(0xFF6FB7E0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final points = ref.watch(gemHistoryProvider).valueOrNull ?? const <GemPoint>[];
    Widget legend(Color color, String label, int value) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 3, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(width: 6),
            CoinText(value, size: 12),
          ],
        );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(s.t('gem_history_title').toUpperCase()),
          const SizedBox(height: 12),
          if (points.length < 2)
            Text(s.t('gem_history_collecting'),
                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted))
          else ...[
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(painter: _GemChartPainter(points, _buyColor, _sellColor)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(_shortDate(points.first.at), style: TextStyle(fontSize: 10, color: AppColors.hint)),
                const Spacer(),
                Text(_shortDate(points.last.at), style: TextStyle(fontSize: 10, color: AppColors.hint)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                legend(_buyColor, s.t('gem_buy_100'), points.last.buy),
                legend(_sellColor, s.t('gem_sell_100'), points.last.sell),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.t('gem_range', {
                'lo': fmtGold(points.map((p) => p.buy).reduce((a, b) => a < b ? a : b)),
                'hi': fmtGold(points.map((p) => p.buy).reduce((a, b) => a > b ? a : b)),
              }),
              style: TextStyle(fontSize: 11, color: AppColors.hint),
            ),
          ],
        ],
      ),
    );
  }
}

String _shortDate(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}';
}

/// whole gold with one decimal, enough for a range line
String fmtGold(int copper) => (copper / 10000).toStringAsFixed(1);

class _GemChartPainter extends CustomPainter {
  const _GemChartPainter(this.points, this.buyColor, this.sellColor);

  final List<GemPoint> points;
  final Color buyColor;
  final Color sellColor;

  @override
  void paint(Canvas canvas, Size size) {
    var lo = points.first.sell;
    var hi = points.first.buy;
    for (final p in points) {
      if (p.sell < lo) lo = p.sell;
      if (p.buy < lo) lo = p.buy;
      if (p.buy > hi) hi = p.buy;
      if (p.sell > hi) hi = p.sell;
    }
    final span = (hi - lo) == 0 ? 1 : hi - lo;
    final first = points.first.at.millisecondsSinceEpoch;
    final range = (points.last.at.millisecondsSinceEpoch - first).clamp(1, 9007199254740991);
    final grid = Paint()
      ..color = AppColors.track
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), grid);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), grid);
    // a little air above and below the lines
    double y(int v) => size.height - 4 - (v - lo) / span * (size.height - 8);
    double x(GemPoint p) => size.width * (p.at.millisecondsSinceEpoch - first) / range;
    void line(int Function(GemPoint) pick, Color color) {
      final path = Path()..moveTo(x(points.first), y(pick(points.first)));
      for (final p in points.skip(1)) {
        path.lineTo(x(p), y(pick(p)));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    line((p) => p.sell, sellColor);
    line((p) => p.buy, buyColor);
  }

  @override
  bool shouldRepaint(covariant _GemChartPainter old) => old.points != points;
}

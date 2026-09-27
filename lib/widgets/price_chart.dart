import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/price_history.dart';
import '../state/settings.dart';
import '../theme.dart';
import 'coin_text.dart';
import 'common.dart';

/// colours of the two lines, the sell price is the one people quote
const sellColor = AppColors.gold;
const buyColor = Color(0xFF5BC8E8);

/// an item's recorded trading post prices: sell and buy over the chosen
/// range, with the change over it
class PriceHistoryPanel extends ConsumerStatefulWidget {
  const PriceHistoryPanel({super.key, required this.itemId});

  final int itemId;

  @override
  ConsumerState<PriceHistoryPanel> createState() => _PriceHistoryPanelState();
}

class _PriceHistoryPanelState extends ConsumerState<PriceHistoryPanel> {
  /// days shown, null for everything recorded
  int? _days = 30;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final all = ref.watch(priceHistoryProvider)[widget.itemId] ?? const <PricePoint>[];
    if (all.length < 2) {
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker(s.t('price_history').toUpperCase()),
            const SizedBox(height: 8),
            Text(s.t('price_history_collecting'),
                style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
          ],
        ),
      );
    }
    final points = lastDays(all, _days);
    final shown = points.length < 2 ? all.sublist(all.length - 2) : points;
    final sellChange = percentChange(shown, (p) => p.sell);
    final buyChange = percentChange(shown, (p) => p.buy);
    final values = [
      for (final p in shown) ...[if (p.sell > 0) p.sell, if (p.buy > 0) p.buy],
    ];
    final hi = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    final lo = values.isEmpty ? 0 : values.reduce((a, b) => a < b ? a : b);

    Widget change(String label, Color color, double? pct) => Expanded(
          child: Row(
            children: [
              Container(width: 10, height: 3, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
              const SizedBox(width: 6),
              if (pct != null)
                Text(
                  '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: pct >= 0 ? AppColors.green : AppColors.red,
                  ),
                ),
            ],
          ),
        );

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Kicker(s.t('price_history').toUpperCase())),
              for (final (days, label) in [(7, '7d'), (30, '30d'), (90, '90d'), (null, s.t('all'))]) ...[
                const SizedBox(width: 4),
                ChoiceChip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  selected: _days == days,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _days = days),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: 110,
                  child: CustomPaint(painter: PriceChartPainter(shown, lo, hi)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [CoinText(hi, size: 11), CoinText(lo, size: 11)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(shown.first.day, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              Text(shown.last.day, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              change(s.t('lowest_sell'), sellColor, sellChange),
              change(s.t('highest_buy'), buyColor, buyChange),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.t('price_history_note'), style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.hint)),
        ],
      ),
    );
  }
}

/// sell and buy as two lines on one scale, days spaced evenly. a day with
/// no price on one side leaves a gap in that line
class PriceChartPainter extends CustomPainter {
  const PriceChartPainter(this.points, this.lo, this.hi);

  final List<PricePoint> points;
  final int lo;
  final int hi;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final span = (hi - lo) == 0 ? 1 : hi - lo;
    // a faint line top and bottom, where the labels beside the chart sit
    final grid = Paint()
      ..color = AppColors.track
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), grid);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), grid);

    void line(int Function(PricePoint) pick, Color color) {
      final path = Path();
      var drawing = false;
      for (var i = 0; i < points.length; i++) {
        final v = pick(points[i]);
        if (v <= 0) {
          drawing = false;
          continue;
        }
        final x = size.width * i / (points.length - 1);
        final y = size.height - (v - lo) / span * size.height;
        if (drawing) {
          path.lineTo(x, y);
        } else {
          path.moveTo(x, y);
          drawing = true;
        }
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

    line((p) => p.buy, buyColor);
    line((p) => p.sell, sellColor);
  }

  @override
  bool shouldRepaint(covariant PriceChartPainter old) => old.points != points || old.lo != lo || old.hi != hi;
}

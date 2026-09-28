import 'package:flutter/material.dart';

import '../theme.dart';
import '../util.dart';

/// gold / silver / copper with the in-game coin colors
class CoinText extends StatelessWidget {
  const CoinText(this.copper, {super.key, this.size = 16});

  final int copper;
  final double size;

  @override
  Widget build(BuildContext context) {
    final negative = copper < 0;
    final c = Coins(copper.abs());
    final unit = TextStyle(fontSize: size * 0.75, fontWeight: FontWeight.w800);
    final value = TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: negative ? AppColors.red : null);
    return Text.rich(
      TextSpan(children: [
        if (negative) TextSpan(text: '-', style: value),
        if (c.gold > 0) ...[
          TextSpan(text: fmtInt(c.gold), style: value),
          TextSpan(text: 'g ', style: unit.copyWith(color: AppColors.gold)),
        ],
        if (c.gold > 0 || c.silver > 0) ...[
          TextSpan(text: '${c.silver}', style: value),
          TextSpan(text: 's ', style: unit.copyWith(color: AppColors.silver)),
        ],
        TextSpan(text: '${c.copper}', style: value),
        TextSpan(text: 'c', style: unit.copyWith(color: AppColors.copper)),
      ]),
    );
  }
}

/// gold, silver and copper as numbers with the coloured coins after them
class CoinDots extends StatelessWidget {
  const CoinDots(this.copper, {super.key, this.size = 14, this.weight = FontWeight.w700, this.color});

  final int copper;
  final double size;
  final FontWeight weight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final negative = copper < 0;
    final c = Coins(copper.abs());
    final style = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget part(int v, Color coin) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(fmtInt(v), style: style),
            const SizedBox(width: 3),
            Container(
              width: size * 0.62,
              height: size * 0.62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color.lerp(coin, Colors.white, 0.35)!, coin]),
              ),
            ),
          ],
        );
    return Wrap(
      spacing: size * 0.45,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (negative) Text('−', style: style),
        if (c.gold > 0) part(c.gold, const Color(0xFFE8C04A)),
        if (c.gold > 0 || c.silver > 0) part(c.silver, AppColors.silver),
        part(c.copper, AppColors.copper),
      ],
    );
  }
}

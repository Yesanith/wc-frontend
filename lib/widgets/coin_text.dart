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

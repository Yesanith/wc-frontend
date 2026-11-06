import 'package:flutter/material.dart';

import '../data/metas.dart';
import '../theme.dart';

/// the short name and the colour each release is known by. the api has no
/// expansion logos, so the badge is drawn: the colour follows the release's
/// own look, the letters are what players call it
extension ExpansionLook on Expansion {
  String get code => switch (this) {
        Expansion.core => 'GW2',
        Expansion.lws => 'LW',
        Expansion.hot => 'HoT',
        Expansion.pof => 'PoF',
        Expansion.ibs => 'IBS',
        Expansion.eod => 'EoD',
        Expansion.soto => 'SotO',
        Expansion.jw => 'JW',
        Expansion.voe => 'VoE',
      };

  Color get color => legible(_base);

  Color get _base => switch (this) {
        Expansion.core => const Color(0xFFD0503F),
        Expansion.lws => const Color(0xFFD9A441),
        Expansion.hot => const Color(0xFF6DBB4E),
        Expansion.pof => const Color(0xFFC062D6),
        Expansion.ibs => const Color(0xFF7CC0EC),
        Expansion.eod => const Color(0xFF33B99E),
        Expansion.soto => const Color(0xFF7FA7F0),
        Expansion.jw => const Color(0xFFDB8A40),
        Expansion.voe => const Color(0xFFA284E6),
      };
}

/// a small tile with a release's letters in its colour
class ExpansionBadge extends StatelessWidget {
  const ExpansionBadge(this.expansion, {super.key, this.size = 30});

  final Expansion expansion;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = expansion.color;
    return Tooltip(
      message: expansion.label,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.frame),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              expansion.code,
              style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.2),
            ),
          ),
        ),
      ),
    );
  }
}

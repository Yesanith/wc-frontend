import 'dart:math' as math;

import 'package:flutter/material.dart';

/// the interface sizes a player may choose on the web. null is automatic
const uiScaleChoices = <double?>[null, 1.0, 1.25, 1.5, 1.75, 2.0];

/// how much larger everything is on a wide screen when nobody chose: nothing up to 1600 pixels wide, half as much again at
/// 2560 (a 2K screen), growing from there and never more than twice. a phone or a laptop is as it always was
double autoZoom(double width) => (1 + (width - 1600) / 960 * 0.5).clamp(1.0, 2.0);

/// the zoom for a screen of a width: the one chosen, or the automatic one. never so much that less than 360 pixels are left to lay
/// the interface out in
double uiZoomFor(double width, double? chosen) => math.max(1.0, math.min(chosen ?? autoZoom(width), width / 360));

/// shows everything [scale] times larger: the interface is laid out as if the screen were that much smaller, then drawn that much
/// bigger, so every text, icon and space grows together. what is shown, hit and typed in is the same as without it. put it as the
/// builder of the app, so the pages and what opens over them are all inside
class UiZoom extends StatelessWidget {
  const UiZoom({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale <= 1.001) return child;
    final mq = MediaQuery.of(context);
    final virtual = Size(mq.size.width / scale, mq.size.height / scale);
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: virtual.width,
          maxWidth: virtual.width,
          minHeight: virtual.height,
          maxHeight: virtual.height,
          child: MediaQuery(
            data: mq.copyWith(
              size: virtual,
              padding: mq.padding / scale,
              viewPadding: mq.viewPadding / scale,
              viewInsets: mq.viewInsets / scale,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

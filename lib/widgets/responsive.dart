import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// from this width the menu is a panel that stays open beside the page, on a computer or a tablet
/// held sideways, instead of a drawer behind a button
const sideMenuMinWidth = 900.0;

/// and from this height: a phone held sideways is wide enough but far too low for a menu that stays
const sideMenuMinHeight = 480.0;

/// how wide the panel is
const sideMenuWidth = 288.0;

/// how wide a page may grow. a list across a whole screen of a computer is hard to read
const contentMaxWidth = 1180.0;

bool useSideMenu(Size size) => size.width >= sideMenuMinWidth && size.height >= sideMenuMinHeight;

/// keeps a page to [maxWidth] and puts it in the middle when there is more room. the page gets
/// exactly the size it would get without this while it is narrower, and the widgets are always
/// the same ones, so nothing is rebuilt from scratch when a window is resized past the limit
class ContentFrame extends StatelessWidget {
  const ContentFrame({super.key, required this.child, this.maxWidth = contentMaxWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: math.min(constraints.maxWidth, maxWidth),
          height: constraints.maxHeight,
          child: child,
        ),
      ),
    );
  }
}

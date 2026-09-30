import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// from this width the menu is a panel that stays open beside the page, on a computer or a tablet
/// held sideways, instead of a drawer behind a button
const sideMenuMinWidth = 900.0;

/// and from this height: a phone held sideways is wide enough but far too low for a menu that stays
const sideMenuMinHeight = 480.0;

/// how wide the panel is
const sideMenuWidth = 288.0;

/// how wide a page may grow when it lays itself out in columns
const contentMaxWidth = 1560.0;

/// and a page that is a list, which is hard to read across a whole screen of a computer
const readingMaxWidth = 1000.0;

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

/// how many columns a grid has in [width]: [minColumns], what a phone gets, and more where there is
/// room, so that a tile is never wider than [maxTile]
int adaptiveColumns(double width, {required int minColumns, required double maxTile, double spacing = 0}) {
  final fit = ((width + spacing) / (maxTile + spacing)).ceil();
  return math.max(minColumns, fit);
}

/// a grid that keeps the size of its tiles and gets more columns instead of bigger tiles when it has room.
/// on a phone it is the grid it always was: [minColumns] columns
class AdaptiveGridDelegate extends SliverGridDelegate {
  const AdaptiveGridDelegate({
    required this.minColumns,
    required this.maxTile,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
    this.mainAxisExtent,
  });

  final int minColumns;
  final double maxTile;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final double? mainAxisExtent;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final columns = adaptiveColumns(
      constraints.crossAxisExtent,
      minColumns: minColumns,
      maxTile: maxTile,
      spacing: crossAxisSpacing,
    );
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
      mainAxisExtent: mainAxisExtent,
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(covariant AdaptiveGridDelegate oldDelegate) =>
      oldDelegate.minColumns != minColumns ||
      oldDelegate.maxTile != maxTile ||
      oldDelegate.mainAxisSpacing != mainAxisSpacing ||
      oldDelegate.crossAxisSpacing != crossAxisSpacing ||
      oldDelegate.childAspectRatio != childAspectRatio ||
      oldDelegate.mainAxisExtent != mainAxisExtent;
}

/// the parts of a page in one column while it is narrow, in the order given, and in two side by side
/// when there is room: [primary] wider on the left, [secondary] on the right. with nothing in
/// [secondary] the first takes the whole width
class SplitColumns extends StatelessWidget {
  const SplitColumns({
    super.key,
    required this.primary,
    this.secondary = const [],
    this.breakpoint = 900,
    this.primaryFlex = 3,
    this.secondaryFlex = 2,
    this.spacing = 24,
  });

  final List<Widget> primary;
  final List<Widget> secondary;

  /// the width from which the two stand side by side
  final double breakpoint;
  final int primaryFlex;
  final int secondaryFlex;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint || secondary.isEmpty) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...primary, ...secondary]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: primaryFlex, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: primary)),
          SizedBox(width: spacing),
          Expanded(
              flex: secondaryFlex, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: secondary)),
        ],
      );
    });
  }
}

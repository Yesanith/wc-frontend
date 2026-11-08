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

/// how many cards stand side by side in [width]: as many as fit at [minWidth] each, at most [maxColumns]
int cardColumns(double width, {required double minWidth, double gap = 0, int maxColumns = 3}) {
  final fit = ((width + gap) / (minWidth + gap)).floor();
  return math.max(1, math.min(maxColumns, fit));
}

/// cards one under the other while the window is narrow, as they always were, and in rows of two or
/// three when there is room. a row is as tall as its tallest card
class CardWrap extends StatelessWidget {
  const CardWrap({super.key, required this.children, this.minWidth = 420, this.gap = 10, this.maxColumns = 3});

  final List<Widget> children;
  final double minWidth;
  final double gap;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = cardColumns(constraints.maxWidth, minWidth: minWidth, gap: gap, maxColumns: maxColumns);
      if (columns == 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              children[i],
            ],
          ],
        );
      }
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    });
  }
}

/// whether the page is shown as a site (the bar along the top, in a wide browser) or as an app. a page that is laid out
/// differently on the site asks this
class SiteScope extends InheritedWidget {
  const SiteScope({super.key, required this.site, required super.child});

  final bool site;

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SiteScope>()?.site ?? false;

  @override
  bool updateShouldNotify(SiteScope oldWidget) => oldWidget.site != site;
}


import 'package:flutter/material.dart';

/// a row of filter chips. on a phone it is one line that scrolls sideways, which a thumb does without
/// thinking; where there is room it wraps onto more lines instead, so that every chip is in sight and
/// nothing is found only by scrolling with the shift key held
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.children,
    this.height = 44,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<Widget> children;
  final double height;
  final EdgeInsetsGeometry padding;

  /// from this width the chips wrap
  static const wrapFrom = 700.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= wrapFrom) {
          return Padding(
            padding: padding,
            child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: children),
          );
        }
        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: padding,
            itemCount: children.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => Center(child: children[i]),
          ),
        );
      },
    );
  }
}

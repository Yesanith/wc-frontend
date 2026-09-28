import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// opens the menu with a swipe to the right from anywhere on the page.
///
/// the scaffold's own edge swipe sits in the strip android keeps for its
/// back gesture, so on phones with gesture navigation it never fires. this
/// listens under the page instead: lists, tabs and the timeline that scroll
/// sideways still get their drags first, it only acts where nothing else
/// wanted one
class SwipeToOpen extends StatefulWidget {
  const SwipeToOpen({super.key, required this.onOpen, required this.child, this.enabled = true});

  final VoidCallback onOpen;
  final Widget child;

  /// off on pages that pan freely in every direction. a pan or pinch only
  /// claims the gesture after twice the distance a horizontal drag needs, so
  /// this listener would win every sideways pan on the world map
  final bool enabled;

  /// how far or how fast a swipe has to go before it counts
  static const distance = 60.0;
  static const speed = 400.0;

  @override
  State<SwipeToOpen> createState() => _SwipeToOpenState();
}

class _SwipeToOpenState extends State<SwipeToOpen> {
  double _dx = 0;
  double _dy = 0;

  @override
  Widget build(BuildContext context) {
    // the detector stays in the tree when switched off and only drops its
    // recognizer. returning the bare child instead would change the tree
    // above it, and every section of the menu would be rebuilt from scratch
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        if (widget.enabled)
          HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
            HorizontalDragGestureRecognizer.new,
            (r) => r
              ..onStart = (_) {
                _dx = 0;
                _dy = 0;
              }
              ..onUpdate = (d) {
                _dx += d.delta.dx;
                _dy += d.delta.dy.abs();
              }
              ..onEnd = (d) {
                final v = d.primaryVelocity ?? 0;
                // mostly sideways and to the right, a slanted scroll is not a swipe
                if (_dx > 0 && _dy < _dx && (_dx > SwipeToOpen.distance || v > SwipeToOpen.speed)) widget.onOpen();
              },
          ),
      },
      child: widget.child,
    );
  }
}

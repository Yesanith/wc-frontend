part of '../site_header.dart';

/// the foot of the page of a site: whose it is and the year, what the project is, and the links a site has. in a line where there is room
/// for it, one under another where there is not
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key, required this.note, required this.links, this.year});

  final String note;
  final List<({String label, VoidCallback onTap})> links;

  /// the year of the copyright line: this one when none is given
  final int? year;

  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    final owner = Text(
      '© ${year ?? DateTime.now().year} Wondrous Compass',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
    );
    final buttons = [
      for (final link in links)
        TextButton(
          onPressed: link.onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.muted,
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: Text(link.label),
        ),
    ];
    return Material(
      color: AppColors.navBg,
      child: Container(
        constraints: const BoxConstraints(minHeight: height),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
        child: LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth < 760) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    owner,
                    const SizedBox(height: 6),
                    Text(note, style: TextStyle(fontSize: 12, color: AppColors.hint)),
                    const SizedBox(height: 4),
                    Wrap(children: buttons),
                  ],
                ),
              );
            }
            // a fixed height, or the middle of it would fill the whole of the window
            return SizedBox(
              height: height,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        owner,
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: AppColors.hint),
                          ),
                        ),
                        ...buttons,
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// the name of a page of the site at the top of it: the group it is in above, small and in gold, then the name, and a short line of gold
/// under it. a page that stands alone has no group
class SitePageHeading extends StatelessWidget {
  const SitePageHeading({super.key, required this.title, this.kicker});

  final String title;
  final String? kicker;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kicker != null) ...[
          Kicker(kicker!.caps, color: AppColors.gold),
          const SizedBox(height: 4),
        ],
        Text(title, style: display(30)),
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2)),
        ),
      ],
    );
  }
}

/// the heading of a page of the site with the page under it. the heading goes out of the way once the page is scrolled
/// a little, so a long list has the whole window and not what is left under a name, and it comes back when the page is
/// at the top again. it is done here, from the scrolling of whatever page is under it, so no page has to know
class CollapsingHeading extends StatefulWidget {
  const CollapsingHeading({super.key, required this.heading, required this.body});

  final Widget heading;
  final Widget body;

  /// how far the page is scrolled before the heading goes
  static const collapseAt = 48.0;

  /// a page that is not longer than this beyond its window stays as it is: with the heading gone it would have no
  /// room to scroll, come back to the top and bring the heading with it
  static const minScrollable = 160.0;

  @override
  State<CollapsingHeading> createState() => _CollapsingHeadingState();
}

class _CollapsingHeadingState extends State<CollapsingHeading> {
  var _collapsed = false;

  void _set(bool value) {
    if (_collapsed == value) return;
    // the notification can come while the tree is being laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _collapsed != value) setState(() => _collapsed = value);
    });
  }

  bool _onMetrics(ScrollMetrics m) {
    if (m.axis != Axis.vertical) return false;
    if (!_collapsed && m.pixels > CollapsingHeading.collapseAt && m.maxScrollExtent > CollapsingHeading.minScrollable) {
      _set(true);
    } else if (_collapsed && m.pixels <= 0.5) {
      _set(false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRect(
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            heightFactor: _collapsed ? 0 : 1,
            widthFactor: 1,
            child: widget.heading,
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => _onMetrics(n.metrics),
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (n) => _onMetrics(n.metrics),
              child: widget.body,
            ),
          ),
        ),
      ],
    );
  }
}

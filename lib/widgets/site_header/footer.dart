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
    final owner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DiamondEmblem(size: 18),
        const SizedBox(width: 8),
        Text(
          '© ${year ?? DateTime.now().year} Wondrous Compass',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
        ),
      ],
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
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
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
        if (kicker != null) ...[Kicker(kicker!.toUpperCase(), color: AppColors.gold), const SizedBox(height: 4)],
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

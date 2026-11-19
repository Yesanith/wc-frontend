part of '../site_header.dart';

/// the way around the site: a narrow rail down the left side, the emblem at the head of it, the pages of the day and the groups of the others one under
/// another, and settings at the foot. a group opens its pages beside it. it is where the bar along the top was
class SiteRail extends StatelessWidget {
  const SiteRail({
    super.key,
    required this.current,
    required this.onSelect,
    required this.labels,
    required this.icons,
    required this.groupLabels,
    this.busy = false,
    this.progress,
  });

  final AppSection current;
  final ValueChanged<AppSection> onSelect;
  final Map<AppSection, String> labels;
  final Map<AppSection, IconData> icons;

  /// the heading of each group, in the order of [siteNavGroups]
  final List<String> groupLabels;

  /// something is being updated: the thin line along the right edge of the rail
  final bool busy;
  final double? progress;

  static const width = 84.0;

  /// the icon of each group of [siteNavGroups], in its order
  static const _groupIcons = [
    Icons.person_outline,
    Icons.groups_outlined,
    Icons.storefront_outlined,
    Icons.public,
    Icons.menu_book_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navBg,
      child: Container(
        width: width,
        decoration: BoxDecoration(border: Border(right: BorderSide(color: AppColors.line))),
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSelect(AppSection.home),
                  child: const Padding(padding: EdgeInsets.all(6), child: DiamondEmblem(size: 38)),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final sec in siteNavSingles)
                          _RailItem(
                            icon: icons[sec]!,
                            label: labels[sec]!,
                            selected: current == sec,
                            onTap: () => onSelect(sec),
                          ),
                        for (var i = 0; i < siteNavGroups.length; i++) _group(i),
                      ],
                    ),
                  ),
                ),
                _RailItem(
                  icon: icons[AppSection.settings]!,
                  label: labels[AppSection.settings]!,
                  selected: current == AppSection.settings,
                  onTap: () => onSelect(AppSection.settings),
                ),
                _RailItem(
                  icon: icons[AppSection.about]!,
                  label: labels[AppSection.about]!,
                  selected: current == AppSection.about,
                  onTap: () => onSelect(AppSection.about),
                ),
                const SizedBox(height: 8),
              ],
            ),
            if (busy)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 2,
                child: RotatedBox(
                  quarterTurns: 1,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    backgroundColor: AppColors.track,
                    color: AppColors.gold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _group(int i) {
    final sections = [
      for (final sec in siteNavGroups[i].$2)
        if (siteSectionAvailable(sec)) sec,
    ];
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.line)),
        ),
      ),
      menuChildren: [
        for (final sec in sections)
          MenuItemButton(
            leadingIcon: Icon(icons[sec], size: 20, color: sec == current ? AppColors.gold : AppColors.muted),
            onPressed: () => onSelect(sec),
            child: Text(
              labels[sec]!,
              style: TextStyle(fontWeight: FontWeight.w600, color: sec == current ? AppColors.gold : null),
            ),
          ),
      ],
      builder: (context, controller, _) => _RailItem(
        icon: _groupIcons[i],
        label: groupLabels[i],
        selected: sections.contains(current),
        more: true,
        // the pages open beside the rail, not under the item
        onTap: () => controller.isOpen ? controller.close() : controller.open(position: const Offset(width, 0)),
      ),
    );
  }
}

/// one place of the rail: its icon with its name under it, in gold with a line down the edge while it is the page. [more] marks a
/// group, which opens its pages instead of being one
class _RailItem extends StatelessWidget {
  const _RailItem(
      {required this.icon, required this.label, required this.selected, required this.onTap, this.more = false});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool more;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.surface2.withValues(alpha: 0.7),
        child: Container(
          width: SiteRail.width,
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 9),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: [AppColors.gold.withValues(alpha: 0.16), AppColors.gold.withValues(alpha: 0)])
                : null,
            border: Border(left: BorderSide(color: selected ? AppColors.gold : Colors.transparent, width: 3)),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 23, color: color),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: SiteRail.width - 14,
                    // the item is named by the Semantics above: the same name again from the text would read twice
                    child: ExcludeSemantics(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                      ),
                    ),
                  ),
                ],
              ),
              if (more) Positioned(right: 0, top: 6, child: Icon(Icons.chevron_right, size: 14, color: AppColors.hint)),
            ],
          ),
        ),
      ),
    );
  }
}

/// the thin strip over the pages of the site: the search and who is signed in, at the right, with nothing of its own at the left
class SiteTopStrip extends StatelessWidget {
  const SiteTopStrip({super.key, this.search, this.accountBadge, this.account});

  final Widget? search;
  final Widget? accountBadge;
  final String? account;

  static const height = 52.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (search != null) ...[search!, const SizedBox(width: 12)],
            if (accountBadge != null)
              accountBadge!
            else if (account != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline, size: 16, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(account!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

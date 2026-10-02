import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/update_check.dart' show appVersion;
import '../state/navigation.dart';
import '../theme.dart';
import 'common.dart';
import 'responsive.dart';

/// the page address of the static site, where the privacy policy and the terms are, in the language of the app: English at the root,
/// the others in a folder of their own
const siteBase = 'https://yesanith.github.io/tyria-companion/';

String sitePageUrl(AppLang lang, String page) =>
    lang == AppLang.en ? '$siteBase$page.html' : '$siteBase${lang.code}/$page.html';

/// the sections that stand on their own in the bar of a site, and the groups of the others, each with the key of its heading.
/// settings and about are at the end of the bar. every section is in one of them: what is not could not be reached
const siteNavSingles = [AppSection.home, AppSection.bosses, AppSection.daily, AppSection.weekly];

const siteNavGroups = <(String, List<AppSection>)>[
  (
    'nav_group_account',
    [
      AppSection.characters,
      AppSection.account,
      AppSection.progression,
      AppSection.collections,
      AppSection.guilds,
      AppSection.guildEvents,
      AppSection.publicEvents,
    ],
  ),
  ('nav_group_economy', [AppSection.trading, AppSection.recipes]),
  ('nav_group_world', [AppSection.maps, AppSection.wvw]),
  ('nav_group_reference', [AppSection.professions, AppSection.wiki, AppSection.news]),
];

/// which group a section is in, by its place in [siteNavGroups], or null for one that stands alone
int? siteGroupIndex(AppSection section) {
  for (var i = 0; i < siteNavGroups.length; i++) {
    if (siteNavGroups[i].$2.contains(section)) return i;
  }
  return null;
}

/// what the tab of the browser says: the name of the page and of the site, the site alone for its home page
String sitePageTitle(AppSection section, String name) =>
    section == AppSection.home ? 'Tyria Codex' : '$name · Tyria Codex';

/// the bar at the top of the page on a wide screen in a browser: the name, the sections along it, the groups opening under their heading,
/// the account and the settings at the end. it is what a site has in place of the menu beside the page that an app has
class SiteHeader extends StatelessWidget implements PreferredSizeWidget {
  const SiteHeader({
    super.key,
    required this.current,
    required this.onSelect,
    required this.labels,
    required this.icons,
    required this.groupLabels,
    required this.account,
    this.search,
    this.busy = false,
    this.progress,
  });

  final AppSection current;
  final ValueChanged<AppSection> onSelect;
  final Map<AppSection, String> labels;
  final Map<AppSection, IconData> icons;

  /// the heading of each group, in the order of [siteNavGroups]
  final List<String> groupLabels;
  final String? account;

  /// the box to search in, between the sections and the account
  final Widget? search;

  /// something is being updated: the thin bar along the foot of the header, with how far it is or none
  final bool busy;
  final double? progress;

  static const height = 64.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final nav = <Widget>[
      for (final sec in siteNavSingles)
        SiteNavButton(label: labels[sec]!, selected: current == sec, onTap: () => onSelect(sec)),
      for (var i = 0; i < siteNavGroups.length; i++)
        _SiteNavMenu(
          label: groupLabels[i],
          sections: siteNavGroups[i].$2,
          current: current,
          labels: labels,
          icons: icons,
          onSelect: onSelect,
        ),
    ];
    return Material(
      color: AppColors.navBg,
      child: Container(
        height: height,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onSelect(AppSection.home),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Row(
                            children: [
                              const DiamondEmblem(size: 30),
                              const SizedBox(width: 10),
                              Text('Tyria Codex', style: display(20)),
                              const SizedBox(width: 8),
                              const VersionPill(appVersion == 'dev' ? 'dev' : 'v$appVersion'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // a window just wide enough has more sections than room: the bar scrolls sideways rather than overflow
                      Expanded(
                        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: nav)),
                      ),
                      const SizedBox(width: 12),
                      if (search != null) ...[search!, const SizedBox(width: 12)],
                      Container(width: 1, height: 28, color: AppColors.line),
                      const SizedBox(width: 12),
                      if (account != null)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline, size: 16, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text(account!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      IconButton(
                        tooltip: labels[AppSection.settings],
                        onPressed: () => onSelect(AppSection.settings),
                        icon: Icon(
                          icons[AppSection.settings],
                          color: current == AppSection.settings ? AppColors.gold : AppColors.muted,
                        ),
                      ),
                      IconButton(
                        tooltip: labels[AppSection.about],
                        onPressed: () => onSelect(AppSection.about),
                        icon: Icon(
                          icons[AppSection.about],
                          color: current == AppSection.about ? AppColors.gold : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // a line of the colour of the site along the very top, fading at both ends
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.transparent, AppColors.gold.withValues(alpha: 0.7), Colors.transparent]),
                ),
              ),
            ),
            if (busy)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: AppColors.track,
                  color: AppColors.gold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// one entry of the bar: its name, in gold with a line under it while it is the page, and what comes after it (the arrow of a menu)
class SiteNavButton extends StatelessWidget {
  const SiteNavButton({super.key, required this.label, required this.selected, required this.onTap, this.trailing});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.surface2.withValues(alpha: 0.7),
      focusColor: AppColors.surface2,
      child: Container(
        height: SiteHeader.height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.07) : null,
          border: Border(bottom: BorderSide(color: selected ? AppColors.gold : Colors.transparent, width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.gold : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 2), trailing!],
          ],
        ),
      ),
    );
  }
}

/// a group of sections opening under its heading
class _SiteNavMenu extends StatelessWidget {
  const _SiteNavMenu({
    required this.label,
    required this.sections,
    required this.current,
    required this.labels,
    required this.icons,
    required this.onSelect,
  });

  final String label;
  final List<AppSection> sections;
  final AppSection current;
  final Map<AppSection, String> labels;
  final Map<AppSection, IconData> icons;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.line)),
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
      builder: (context, controller, _) => SiteNavButton(
        label: label,
        selected: sections.contains(current),
        trailing: const Icon(Icons.expand_more, size: 18, color: AppColors.muted),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// the line at the foot of the page of a site: what the project is, and the links a site has
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key, required this.note, required this.links, this.year});

  /// the year of the copyright line: this one when none is given
  final int? year;
  final String note;
  final List<({String label, VoidCallback onTap})> links;

  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navBg,
      child: Container(
        height: height,
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: contentMaxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const DiamondEmblem(size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '© ${year ?? DateTime.now().year} Tyria Codex',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.hint)),
                  ),
                  for (final link in links)
                    TextButton(
                      onPressed: link.onTap,
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      child: Text(link.label),
                    ),
                ],
              ),
            ),
          ),
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
          Kicker(kicker!.toUpperCase(), color: AppColors.gold),
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
